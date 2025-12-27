import 'package:flutter/material.dart';
import '../widgets/itens_reutilizaveis.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final double? topPadding;
  final Widget? trailing;
  final bool showDivider;

  const SectionTitle({
    super.key,
    required this.title,
    this.topPadding,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (topPadding != null) SizedBox(height: topPadding),
        Row(
          mainAxisAlignment:
              trailing == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Reuse.myTitulo,
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (showDivider) Reuse.myDivider,
      ],
    );
  }
}

