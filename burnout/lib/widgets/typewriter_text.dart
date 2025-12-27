import 'package:flutter/material.dart';

class FadeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration characterDelay;
  final Duration startDelay;

  const FadeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.characterDelay = const Duration(milliseconds: 20),
    this.startDelay = const Duration(milliseconds: 500),
  });

  @override
  State<FadeText> createState() => _FadeTextState();
}

class _FadeTextState extends State<FadeText> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late String _fullText;
  bool _isAnimating = false;
  List<double> _letterOpacities = [];

  @override
  void initState() {
    super.initState();
    _fullText = widget.text;
    _letterOpacities = List.filled(_fullText.length, 0.0);
    _startAnimation();
  }

  @override
  void didUpdateWidget(FadeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _fullText = widget.text;
      _resetAnimation();
    }
  }

  void _startAnimation() async {
    if (_isAnimating) return;

    _isAnimating = true;

    // Delay inicial para garantir que o widget está visível
    await Future.delayed(widget.startDelay);

    if (!mounted) return;

    // Reset do estado
    setState(() {
      _currentIndex = 0;
      _letterOpacities = List.filled(_fullText.length, 0.0);
    });

    // Animação fade letra por letra
    while (_currentIndex < _fullText.length && mounted) {
      await Future.delayed(widget.characterDelay);

      if (!mounted) break;

      setState(() {
        _letterOpacities[_currentIndex] = 1.0;
        _currentIndex++;
      });
    }

    _isAnimating = false;
  }

  void _resetAnimation() {
    _isAnimating = false;
    _currentIndex = 0;
    _letterOpacities = List.filled(_fullText.length, 0.0);
    _startAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: widget.textAlign ?? TextAlign.start,
      text: TextSpan(
        style: widget.style,
        children: _fullText.split('').asMap().entries.map((entry) {
          final int index = entry.key;
          final String char = entry.value;

          return TextSpan(
            text: char,
            style: widget.style?.copyWith(
              color: widget.style?.color
                  ?.withValues(alpha: _letterOpacities[index]),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _isAnimating = false;
    super.dispose();
  }
}
