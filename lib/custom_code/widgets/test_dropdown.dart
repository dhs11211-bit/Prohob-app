import 'package:flutter/material.dart';

class TestDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: LayoutBuilder(builder: (context, constraints) {
      return DropdownMenu<String>(
          width: constraints.maxWidth,
          dropdownMenuEntries: [
            DropdownMenuEntry(value: '1', label: 'Item 1')
          ]);
    }));
  }
}
