import 'package:flutter/material.dart';

class ButtonsRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const ButtonsRow({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: children,
    );
  }
}

