# Dart FFI

Calling C directly — when it beats a channel, and the memory rules that make it safe.

## The recommendation

**Use FFI for existing C libraries and for CPU-bound work; use a
[platform channel](native-platform-channels.md) for platform services.** FFI is a synchronous
call into native code with no serialisation, which makes it dramatically faster per call and
means a mistake corrupts memory instead of throwing an exception. Choose it deliberately.

## FFI versus a channel

| | FFI | Platform channel |
| --- | --- | --- |
| Call overhead | Nanoseconds — a direct call | Tens of microseconds — serialise plus thread hop |
| Synchronous | Yes | Never |
| Reaches platform APIs | Only via C interop | Yes — that is the point |
| Language | C ABI (or C++/Rust/Swift with a C surface) | Kotlin, Swift, Java, Objective-C |
| Failure mode | Segfault, memory corruption | `PlatformException` |
| Code per platform | One implementation | One per platform |

**FFI wins for:** an existing C or C++ library (SQLite, libsodium, OpenCV, a codec, a solver),
tight loops where per-call overhead dominates, and shipping one implementation across all
platforms.

**A channel wins for:** anything the platform SDK exposes — camera, permissions,
notifications, Bluetooth, background execution — because reaching those from C means writing
the platform code anyway plus a C shim.

## Binding, by hand and generated

```c
// native/image_ops.h
int32_t sharpen(const uint8_t* pixels, int32_t length, float amount);
```

```dart
final DynamicLibrary _lib = switch (Platform.operatingSystem) {
  'android' => DynamicLibrary.open('libimage_ops.so'),
  'ios' || 'macos' => DynamicLibrary.process(),   // statically linked into the app
  'windows' => DynamicLibrary.open('image_ops.dll'),
  _ => DynamicLibrary.open('libimage_ops.so'),
};

// Two signatures: the C one, then the Dart one.
typedef _SharpenC = Int32 Function(Pointer<Uint8>, Int32, Float);
typedef _SharpenDart = int Function(Pointer<Uint8>, int, double);

final _sharpen = _lib.lookupFunction<_SharpenC, _SharpenDart>('sharpen');
```

Writing those by hand for more than a few functions is error-prone — a wrong integer width is
undefined behaviour, not a type error. Generate them:

```yaml
# ffigen.yaml
output: 'lib/src/image_ops_bindings.dart'
headers:
  entry-points: ['native/image_ops.h']
```

```bash
dart run ffigen --config ffigen.yaml
```

`ffigen` parses the headers with libclang and produces correct bindings including structs,
enums and typedefs. Regenerate whenever the header changes, and keep the header as the single
source of truth.

For Objective-C and Swift, `package:ffigen` (with `objc` support) and, as of Dart 3.7, the
experimental Swift interop path can generate bindings directly — worth checking the current
state before hand-writing a C shim over an Objective-C API.

## Memory: the part that bites

Dart's garbage collector knows nothing about memory C allocated. Every allocation crossing the
boundary needs an owner, decided explicitly.

```dart
Uint8List sharpenImage(Uint8List pixels, double amount) {
  // Allocate native memory, copy in.
  final buffer = calloc<Uint8>(pixels.length);
  try {
    buffer.asTypedList(pixels.length).setAll(0, pixels);

    final result = _sharpen(buffer, pixels.length, amount);
    if (result != 0) {
      throw ImageOpsException('sharpen failed with $result');
    }

    // Copy out before freeing: the returned view points at native memory that
    // is about to be released.
    return Uint8List.fromList(buffer.asTypedList(pixels.length));
  } finally {
    calloc.free(buffer);   // finally, or a thrown exception leaks the buffer
  }
}
```

The rules, all of which are learned the hard way otherwise:

- **Every `malloc`/`calloc` has a matching `free`, in a `finally`.** An exception between them
  is a leak with no stack trace pointing at it.
- **`asTypedList` is a view, not a copy.** Using it after the pointer is freed reads freed
  memory — sometimes plausible data, sometimes a crash, never reproducible.
- **Who frees what is part of the C API contract.** If C returns an allocated pointer, the
  header must say whether the caller frees it, and with which allocator.
- **`NativeFinalizer`** attaches cleanup to a Dart object's collection, which is the right tool
  for a handle whose lifetime follows a Dart object. It is a safety net, not a schedule —
  collection timing is not guaranteed.
- **Strings need conversion.** `toNativeUtf8()` allocates; free it. `.toDartString()` copies
  back.

## Threading and isolates

An FFI call is **synchronous and blocks the calling isolate**. A 200 ms C function called from
the UI isolate drops twelve frames just as surely as 200 ms of Dart.

```dart
// Long-running native work belongs on another isolate.
final result = await Isolate.run(() => sharpenImage(pixels, 1.4));
```

Two constraints when doing that: pointers cannot be sent between isolates (they are addresses
in a shared process, but ownership is not synchronised, so treat them as isolate-local), and
callbacks from C into Dart need `NativeCallable.listener` for calls arriving on a native
thread — `Pointer.fromFunction` only works when the call comes back on the same Dart thread.

## Building and shipping the native code

- **Android:** CMake or ndk-build via `android/build.gradle`, producing `.so` per ABI. Adds to
  build size per architecture — see [build size](performance-build-size.md).
- **iOS/macOS:** a static library or an xcframework referenced from the podspec.
  `DynamicLibrary.process()` finds symbols in a statically linked binary.
- **Watch the size.** OpenCV adds tens of megabytes per ABI. Link only what you use.
- **CI must build the native side**, on the right toolchain, for every architecture. This is
  usually the hardest part of adopting FFI, and it is worth prototyping before committing.

## Interview angles

**"When would you use FFI over a platform channel?"** For existing C libraries and CPU-bound
work where per-call overhead matters, and when one implementation should serve every platform.
Channels for platform services, because reaching those from C means writing the platform code
anyway.

**"What are the risks?"** Manual memory management with no GC help, a segfault instead of an
exception, undefined behaviour from a mismatched signature, and per-platform native builds in
CI. Say `asTypedList` is a view — that detail signals you have actually shipped it.

**"How do you keep FFI off the UI thread?"** It is a synchronous call, so the only answer is
another isolate — `Isolate.run` for one-off work, a long-lived worker for repeated work.

**"How do you generate bindings?"** `ffigen` from the C headers, regenerated whenever the
header changes, with the header as the single source of truth.

## See also

- [Platform channels](native-platform-channels.md) — the other direction
- [Isolates](../part-01-foundations/dart-isolates.md) — where long FFI calls belong
- [Build size](performance-build-size.md) — what native libraries cost per ABI
- [Writing plugins](native-plugins.md) — packaging native code for reuse
