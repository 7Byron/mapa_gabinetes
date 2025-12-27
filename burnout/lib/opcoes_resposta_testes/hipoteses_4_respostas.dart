import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:get/get.dart';

import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class Botoes4respostas extends StatefulWidget {
  final int valSomar;
  final String pergunta;
  final String letter;
  final Function(int) obterDados;
  final double? heightOverride;
  final double? fontScaleFactor;

  const Botoes4respostas({
    super.key,
    required this.valSomar,
    required this.pergunta,
    required this.letter,
    required this.obterDados,
    this.heightOverride,
    this.fontScaleFactor,
  });

  @override
  State<Botoes4respostas> createState() => _Botoes4respostasState();
}

class _Botoes4respostasState extends State<Botoes4respostas> {
  int _selectedIndex = -1;
  final double altura = Get.height * 0.055;
  bool _buttonPressed = false;

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    double fontScale = 1.2 * r.textScale; // progressivo
    final double heightScale = r.buttonHeightScale; // progressivo
    if (widget.fontScaleFactor != null) {
      fontScale *= widget.fontScaleFactor!;
    }
    return Container(
      // Usa a largura disponível do pai (Grid, Column, etc.)
      width: double.infinity,
      decoration: !_buttonPressed
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(
                  12.0), // Bordas arredondadas para a sombra seguir
              // Sombra mais natural (Material-like)
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, 2),
                  blurRadius: 10,
                  color: Color(0x1F000000), // preto com ~12% opacidade
                ),
                BoxShadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Color(0x14000000), // preto com ~8% opacidade
                ),
              ],
            )
          : null,
      child: Card(
        elevation: 0, // Remove a elevação padrão do Card
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12.0), // Mesmo borderRadius do Container
        ),
        color: _getButtonColor(widget.letter),
        child: InkWell(
          onTap: () async {
            setState(() {
              _selectedIndex = widget.valSomar;
              _buttonPressed = true;
            });
            await Future.delayed(const Duration(milliseconds: 750));
            widget.obterDados(widget.valSomar);
            setState(() {
              _buttonPressed = false;
              _selectedIndex = -1;
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
            child: SizedBox(
              width: double.infinity,
              height: widget.heightOverride ??
                  ((altura * 1.6) * 1.2 * heightScale).clamp(40.0, 72.0),
              child: Center(
                child: AutoSizeText(
                  widget.pergunta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: _buttonPressed && _selectedIndex != widget.valSomar
                        ? Colors.grey
                        : Colors.brown,
                    fontSize:
                        r.clampFont(MyG.to.margens['margem085']! * fontScale),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(String letter) {
    switch (letter) {
      case 'a':
        return Colors.amber[100]!;
      case 'b':
        return Colors.amber[200]!;
      case 'c':
        return Colors.amber[300]!;
      case 'd':
        return Colors.amber[500]!;
      default:
        return Colors.amber[100]!;
    }
  }
}
