import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';
import 'itens_reutilizaveis.dart';
import 'purchase_status_widget_otimizado.dart';
import 'base_app_bar.dart';

class AppBarSecondary extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final String image;
  final bool alignWithDrawer;

  const AppBarSecondary({
    super.key,
    required this.titulo,
    required this.image,
    this.alignWithDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    return BaseRoundedAppBar(
      title: Text(
        titulo,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: r.clampFont(r.font(16)),
        ),
      ),
      alignWithDrawer: alignWithDrawer,
      actions: [
        SizedBox(width: MyG.to.margens['margem1']!),
        if ((GetPlatform.isAndroid || GetPlatform.isIOS) &&
            PurchaseChecker.shouldShowAds())
          GestureDetector(
            onTap: () => Get.toNamed(RotasPaginas.pay),
            child: Reuse.myAdsOffIcon,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
