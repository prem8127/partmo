import 'package:flutter/material.dart';

class QuantitySelector extends StatelessWidget {
  const QuantitySelector(
      {super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: value - 1, icon: const Icon(Icons.remove)),
        ButtonSegment(value: value, label: Text('$value')),
        ButtonSegment(value: value + 1, icon: const Icon(Icons.add)),
      ],
      selected: {value},
      onSelectionChanged: (selection) =>
          onChanged(selection.first.clamp(0, 99).toInt()),
    );
  }
}
