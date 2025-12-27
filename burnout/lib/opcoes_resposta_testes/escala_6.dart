import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';

class Botoes6Resposta extends StatefulWidget {
  final Function(int) onSelectedResponse;
  final bool crescente;

  const Botoes6Resposta({
    super.key,
    required this.onSelectedResponse,
    required this.crescente,
  });

  @override
  Botoes6RespostaState createState() => Botoes6RespostaState();
}

class Botoes6RespostaState extends State<Botoes6Resposta> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: MyG.to.margens['margem1']! * 6,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildResponseColumn(
                  'nunca'.tr, Colors.indigo, _getValueForIndex(0), 35),
              _buildResponseColumn(
                  'muito_pouco'.tr, Colors.cyan, _getValueForIndex(1), 15),
              _buildResponseColumn(
                  'as_vezes'.tr, Colors.green, _getValueForIndex(2), 0),
              _buildResponseColumn(
                  'varias_vezes'.tr, Colors.yellow, _getValueForIndex(3), 0),
              _buildResponseColumn(
                  'muitas_vezes'.tr, Colors.orange, _getValueForIndex(4), 15),
              _buildResponseColumn(
                  'sempre'.tr, Colors.red, _getValueForIndex(5), 35),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponseColumn(
      String label, Color color, int value, double offset) {
    return Expanded(
      child: Column(
        children: [
          Transform.translate(
            offset: Offset(0, offset),
            child: _buildScaleEntry(color, value),
          ),
          SizedBox(height: Spacing.s), // espaçamento normalizado
          Transform.translate(
            offset: Offset(0, offset),
            child: _buildAlignedLabel(label),
          ),
        ],
      ),
    );
  }

  int _getValueForIndex(int index) {
    if (widget.crescente) {
      return index;
    } else {
      return 5 - index;
    }
  }

  Widget _buildScaleEntry(Color color, int value) {
    final bool isSelected = _selectedIndex == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = value;
        });

        widget.onSelectedResponse(value);

        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _selectedIndex = -1;
          });
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.brown,
            width: 2.0,
          ),
          boxShadow: !isSelected
              ? [
                  const BoxShadow(
                    color: Colors.black45,
                    offset: Offset(0, 6),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: MyG.to.margens['margem1_25']!,
        ),
      ),
    );
  }

  Widget _buildAlignedLabel(String label) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Usa AutoSizeText com configurações que garantem que palavras não sejam cortadas
        // O AutoSizeText reduz a fonte automaticamente se necessário, mas preserva palavras inteiras
        return SizedBox(
          width: constraints.maxWidth,
          child: AutoSizeText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MyG.to.margens['margem05']!,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.brown
                  : Colors.white,
            ),
            maxFontSize: MyG.to.margens['margem1']!,
            minFontSize: 7.0, // Tamanho mínimo para garantir legibilidade
            maxLines: 2,
            stepGranularity: 0.5, // Reduz em passos menores para melhor ajuste
            // O AutoSizeText automaticamente:
            // - Preserva quebras de linha existentes (\n)
            // - Quebra em espaços quando necessário
            // - Reduz a fonte se o texto não couber, mas nunca corta palavras no meio
          ),
        );
      },
    );
  }
}
