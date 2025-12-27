import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../funcoes/responsive.dart';

class LinhaContadorPergunta extends StatefulWidget {
  final int currentQuestion;
  final int totalQuestions;
  final bool canGoBack;
  final bool showAdsIcon;
  final int adsCount;
  final VoidCallback onBackPressed;
  final bool compact; // quando true, usa altura e fonte menores
  final double? heightOverride; // permite controlar altura externamente
  final double? fontSizeOverride; // permite controlar fonte externamente

  const LinhaContadorPergunta({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.canGoBack,
    this.showAdsIcon = false,
    this.adsCount = 0,
    required this.onBackPressed,
    this.compact = false,
    this.heightOverride,
    this.fontSizeOverride,
  });

  @override
  State<LinhaContadorPergunta> createState() => _LinhaContadorPerguntaState();
}

class _LinhaContadorPerguntaState extends State<LinhaContadorPergunta>
    with TickerProviderStateMixin {
  late AnimationController _outController; // Para o número que sai
  late AnimationController _inController; // Para o número que entra
  late Animation<double> _scaleOutAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _scaleInAnimation;
  late Animation<double> _fadeInAnimation;

  late int _currentQuestion;
  late int _newQuestion;
  bool _isAnimating = false;
  bool _showingNewNumber = false;

  @override
  void initState() {
    super.initState();
    _currentQuestion = widget.currentQuestion;
    _newQuestion = widget.currentQuestion;

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
  void didUpdateWidget(LinhaContadorPergunta oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentQuestion != widget.currentQuestion) {
      _animateNumberChange();
    }
  }

  void _animateNumberChange() async {
    if (_isAnimating) return;

    _isAnimating = true;

    try {
      _newQuestion = widget.currentQuestion;

      _outController.reset();
      _inController.reset();

      setState(() {
        _showingNewNumber = true;
      });

      _outController.forward();
      _inController.forward();

      await Future.wait([
        _outController.forward(),
        _inController.forward(),
      ]);

      if (mounted) {
        setState(() {
          _currentQuestion = widget.currentQuestion;
          _showingNewNumber = false;
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
    final double altura = widget.heightOverride ??
        (widget.compact
            ? MyG.to.margens['margem075']!
            : MyG.to.margens['margem1_5']!);
    final r = ResponsiveConfig.of(context);
    final double? fonteCompacta =
        widget.compact ? r.clampFont(widget.fontSizeOverride ?? 18) : null;

    return SizedBox(
      height: altura,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          tituloNPergunta("Perg".tr, fontSizeOverride: fonteCompacta),
          SizedBox(
            width: 50, // Largura fixa para evitar mudanças de layout
            height: altura, // Altura fixa também
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Número antigo que sai
                if (_showingNewNumber)
                  AnimatedBuilder(
                    animation: _outController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleOutAnimation.value,
                        child: Opacity(
                          opacity: _fadeOutAnimation.value,
                          child: Container(
                            alignment: Alignment.center,
                            child: tituloNPergunta(" $_currentQuestion ",
                                fontSizeOverride: fonteCompacta),
                          ),
                        ),
                      );
                    },
                  ),

                // Número novo que entra
                AnimatedBuilder(
                  animation: _showingNewNumber ? _inController : _inController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _showingNewNumber ? _scaleInAnimation.value : 1.0,
                      child: Opacity(
                        opacity:
                            _showingNewNumber ? _fadeInAnimation.value : 1.0,
                        child: Container(
                          alignment: Alignment.center,
                          child: tituloNPergunta(
                            " ${_showingNewNumber ? _newQuestion : _currentQuestion} ",
                            key: ValueKey(_showingNewNumber
                                ? widget.currentQuestion
                                : _currentQuestion),
                            fontSizeOverride: fonteCompacta,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          tituloNPergunta("/ ${widget.totalQuestions}",
              fontSizeOverride: fonteCompacta),
          Reuse.myWidthBox050,
          if (widget.canGoBack)
            InkWell(
              onTap: widget.onBackPressed,
              child: Reuse.myIconUndo,
            ),
          if (widget.showAdsIcon)
            Row(
              children: [
                Reuse.myImagemAdsOn,
                Text(
                  "(${widget.adsCount})",
                  style: Reuse.myFontSize075,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Widget tituloNPergunta(String texto, {Key? key, double? fontSizeOverride}) {
  final r = ResponsiveConfig.of(Get.context!);
  final double screenH = MediaQuery.of(Get.context!).size.height;
  final bool isTallScreen = screenH >= 800;
  final double baseFontSize =
      fontSizeOverride ?? (isTallScreen ? 18 : r.font(16));
  return Text(
    texto,
    key: key,
    style: TextStyle(
      fontSize: r.clampFont(baseFontSize),
      fontWeight: FontWeight.bold,
      color: Colors.brown,
    ),
  );
}
