import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class ResultHeader extends StatelessWidget {
  final ImageProvider image;
  final String percentText;

  const ResultHeader({
    super.key,
    required this.image,
    required this.percentText,
  });

  @override
  Widget build(BuildContext context) {
    final double imgHeight = MyG.to.margens['margem5']!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image(
          image: image,
          height: imgHeight,
        ),
        SizedBox(width: MyG.to.margens['margem05']!),
        Text(
          percentText,
          style: TextStyle(
            fontSize: ResponsiveConfig.of(context).clampFont(MyG.to.margem),
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: Colors.brown,
          ),
        ),
      ],
    );
  }
}

