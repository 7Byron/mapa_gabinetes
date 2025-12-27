import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class MyCustomText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign? textAlign;
  final TextDecoration? decoration;

  const MyCustomText({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.textAlign,
    this.decoration,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      text,
      textAlign: textAlign ?? TextAlign.start,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        decoration: decoration,
      ),
    );
  }
}
