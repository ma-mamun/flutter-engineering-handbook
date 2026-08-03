import 'package:flutter/material.dart';

/// The smallest state management that works: [ValueNotifier] plus
/// [ValueListenableBuilder].
///
/// Reach for a package when you need dependency graphs, scoping, or shared
/// async state. For a single screen's state, this is fewer moving parts than
/// any of them, and it rebuilds strictly less than a `setState` at the top of
/// the page — only the builder below is invalidated.
class CounterController extends ValueNotifier<int> {
  CounterController([super.initial = 0]);

  void increment() => value++;

  void reset() => value = 0;
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  // Created here, disposed below. A controller that outlives its widget is the
  // most common leak in a Flutter app.
  final CounterController _controller = CounterController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        // Only this subtree rebuilds when the value changes. The Scaffold and
        // AppBar above are built once.
        child: ValueListenableBuilder<int>(
          valueListenable: _controller,
          builder: (BuildContext context, int count, Widget? child) {
            final TextStyle? style = Theme.of(context).textTheme.displayMedium;
            return Text('$count', style: style);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
