import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';

class Likert5Respostas extends StatefulWidget {
  final Function(int) onOptionSelected;

  const Likert5Respostas({required this.onOptionSelected, super.key});

  @override
  Likert5RespostasState createState() => Likert5RespostasState();
}

class Likert5RespostasState extends State<Likert5Respostas> {
  final List<Map<String, dynamic>> options = [
    {"value": 0, "image": RotaImagens.likert1, "label": "nunca".tr},
    {"value": 1, "image": RotaImagens.likert2, "label": "rara".tr},
    {"value": 2, "image": RotaImagens.likert3, "label": "asvezes".tr},
    {"value": 3, "image": RotaImagens.likert4, "label": "mtvezes".tr},
    {"value": 4, "image": RotaImagens.likert5, "label": "sempre".tr},
  ];

  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: options.asMap().entries.map((entry) {
            final int index = entry.key;
            final Map<String, dynamic> option = entry.value;

            return Expanded(
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                onTapUp: (_) async {
                  await Future.delayed(const Duration(milliseconds: 750));
                  setState(() {
                    _selectedIndex = -1;
                  });
                  widget.onOptionSelected(option["value"] as int);
                },
                child: AnimatedScale(
                  scale: _selectedIndex == index ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  // Limita o tamanho máximo do botão em -20%
                  child: FractionallySizedBox(
                    widthFactor: 0.95,
                    child: Image.asset(option["image"] as String),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: Spacing.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: options.map((option) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MyG.to.margens['margem025']!,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      option["label"],
                      textAlign: TextAlign.center,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.brown,
                        fontSize: 16.0, // dentro do limite 8-18
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
