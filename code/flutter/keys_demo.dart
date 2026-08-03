/// The reorderable-list bug, in the smallest form that reproduces it.
///
/// Two rows of identical stateful tiles. One row gives its tiles keys, the
/// other does not. Swap them and the unkeyed row's state stays behind, because
/// element matching walks children in order and compares runtime type first.
library;

import 'package:flutter/material.dart';

/// A tile that owns state the widget above it cannot see.
class CounterTile extends StatefulWidget {
  const CounterTile({required this.label, super.key});

  final String label;

  @override
  State<CounterTile> createState() => _CounterTileState();
}

class _CounterTileState extends State<CounterTile> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count++),
      child: Text(
        '${widget.label}:$_count',
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

/// Renders two tiles that can be swapped, with or without keys.
class SwappableRow extends StatefulWidget {
  const SwappableRow({required this.keyed, super.key});

  /// When false, the tiles are built without keys — which is the bug.
  final bool keyed;

  @override
  State<SwappableRow> createState() => SwappableRowState();
}

class SwappableRowState extends State<SwappableRow> {
  List<String> _labels = <String>['a', 'b'];

  void swap() => setState(() => _labels = _labels.reversed.toList());

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      children: <Widget>[
        for (final String label in _labels)
          CounterTile(
            // The key is the only thing that lets the framework recognise a
            // tile that moved. Without it, position is identity.
            key: widget.keyed ? ValueKey<String>(label) : null,
            label: label,
          ),
      ],
    );
  }
}
