import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class TextoPergunta extends StatefulWidget {
  final String questionText;
  final int questionIndex;
  final int numeroLinhas;
  final double? fontSizeOverride;

  const TextoPergunta({
    super.key,
    required this.questionText,
    required this.questionIndex,
    required this.numeroLinhas,
    this.fontSizeOverride,
  });

  @override
  State<TextoPergunta> createState() => _TextoPerguntaState();
}

class _TextoPerguntaState extends State<TextoPergunta>
    with TickerProviderStateMixin {
  late AnimationController _outController;
  late AnimationController _inController;
  late Animation<double> _scaleOutAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _scaleInAnimation;
  late Animation<double> _fadeInAnimation;

  late String _currentText;
  late String _newText;
  late int _currentIndex;
  bool _isAnimating = false;
  bool _showingNewText = false;

  @override
  void initState() {
    super.initState();
    _currentText = widget.questionText;
    _newText = widget.questionText;
    _currentIndex = widget.questionIndex;

    _outController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _inController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _outController,
      curve: Curves.easeInOut,
    ));

    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _outController,
      curve: Curves.easeInOut,
    ));

    _scaleInAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _inController,
      curve: Curves.easeInOut,
    ));

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _inController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inController.forward();
    });
  }

  @override
  void didUpdateWidget(TextoPergunta oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.questionIndex != widget.questionIndex ||
        oldWidget.questionText != widget.questionText) {
      _animateTextChange();
    }
  }

  void _animateTextChange() async {
    if (_isAnimating) return;

    _isAnimating = true;

    try {
      _newText = widget.questionText;

      _outController.reset();
      _inController.reset();

      setState(() {
        _showingNewText = true;
      });

      _outController.forward();
      _inController.forward();

      await Future.wait([
        _outController.forward(),
        _inController.forward(),
      ]);

      if (mounted) {
        setState(() {
          _currentText = widget.questionText;
          _currentIndex = widget.questionIndex;
          _showingNewText = false;
        });
      }
    } finally {
      _isAnimating = false;
    }
  }

  @override
  void dispose() {
    _outController.dispose();
    _inController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isTallScreen = screenH >= 800;
    // Aumenta a base para melhor legibilidade; permite override externo
    final double baseFontSize =
        widget.fontSizeOverride ?? (isTallScreen ? r.font(18) : r.font(16));
    final double alturaCalculada =
        MyG.to.margem * widget.numeroLinhas * (isTallScreen ? 2.0 : 1.5);
    final double alturaMin =
        MediaQuery.of(context).size.height * (isTallScreen ? 0.16 : 0.12);
    final double alturaFixa = math.max(alturaCalculada, alturaMin);

    return LayoutBuilder(builder: (context, constraints) {
      final double available =
          constraints.maxHeight.isFinite ? constraints.maxHeight : alturaFixa;
      final double altura = math.min(alturaFixa, available);
      return SizedBox(
        height: altura,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_showingNewText)
              AnimatedBuilder(
                animation: _outController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleOutAnimation.value,
                    child: Opacity(
                      opacity: _fadeOutAnimation.value,
                      child: Container(
                        height: alturaFixa,
                        alignment: Alignment.center,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: MyG.to.margens['margem05']!),
                          child: AutoSizeText(
                            _currentText,
                            textAlign: TextAlign.center,
                            maxLines: widget.numeroLinhas,
                            maxFontSize: widget.fontSizeOverride ?? 20,
                            minFontSize: isTallScreen
                                ? (widget.fontSizeOverride ?? 18)
                                : 14,
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.brown
                                  : Colors.white,
                              fontSize: r.clampFont(baseFontSize),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            AnimatedBuilder(
              animation: _showingNewText ? _inController : _inController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _showingNewText ? _scaleInAnimation.value : 1.0,
                  child: Opacity(
                    opacity: _showingNewText ? _fadeInAnimation.value : 1.0,
                    child: Container(
                      height: altura,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: MyG.to.margens['margem05']!),
                        child: AutoSizeText(
                          _showingNewText ? _newText : _currentText,
                          key: ValueKey(_showingNewText
                              ? widget.questionIndex
                              : _currentIndex),
                          textAlign: TextAlign.center,
                          maxLines: widget.numeroLinhas,
                          maxFontSize: widget.fontSizeOverride ?? 20,
                          minFontSize: isTallScreen
                              ? (widget.fontSizeOverride ?? 18)
                              : 14,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.brown
                                    : Colors.white,
                            fontSize: r.clampFont(baseFontSize),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
