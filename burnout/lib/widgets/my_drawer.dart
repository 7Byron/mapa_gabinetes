// lib/widgets/my_drawer.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../a_config_app/lista_testes.dart';
import '../controllers/theme_controller.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/lista_teste_unificada.dart';
import '../widgets/linguas.dart';
import '../funcoes/responsive.dart';
import '../funcoes/spacing.dart';

import 'my_dialog.dart';

class MyDrawer extends StatelessWidget {
  final VoidCallback? onHomePressed;

  const MyDrawer({
    super.key,
    this.onHomePressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();
    final r = ResponsiveConfig.of(context);
    // Aumenta ligeiramente o tamanho base do texto no Drawer
    final double drawerFont = r.clampFont(r.font(14));
    final double headerFont = r.clampFont(r.font(18));

    return GetBuilder<MyG>(
      id: 'compras',
      builder: (myG) {
        final bool ads = myG.adsPago;
        final bool allApps = myG.allApps;
        final double margem = MyG.to.margens['margem1']!;

        final double screenHeight = MediaQuery.of(context).size.height;
        final double statusBarHeight = MediaQuery.of(context).padding.top;
        final double bottomPadding = MediaQuery.of(context).padding.bottom;
        double bannerSpace = 0;
        if (!ads) {
          // Em mobile nativo, 50 é um valor seguro para banner
          bannerSpace = 50;
        }
        final double drawerHeight =
            screenHeight - statusBarHeight - bottomPadding - bannerSpace;

        return Align(
          alignment: Alignment.topLeft,
          child: ClipRect(
            child: SizedBox(
              height: drawerHeight,
              child: Drawer(
                width: (Get.width > 1024
                        ? 320.0
                        : (Get.width > 600 ? Get.width * 0.5 : Get.width * 0.8))
                    .clamp(0.0, 320.0)
                    .toDouble(),
                elevation: 0,
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.m),
                      child: Column(
                        children: [
                          Reuse.myHeigthBox1,
                          _buildCabecalho(headerFont),
                          Reuse.myHeigthBox025,
                          Center(
                            child: SizedBox(
                              height: MyG.to.margens['margem3']!,
                              child: Image.asset(RotaImagens.logoApp),
                            ),
                          ),
                          _buildDrawerList(
                              ads, margem, allApps, themeCtrl, drawerFont),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCabecalho(double fontSize) {
    return InkWell(
      onTap: () {},
      child: AutoSizeText(
        ListaTeste.nomeApp,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.brown,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildDrawerList(
    bool ads,
    double margem,
    bool allApps,
    ThemeController themeCtrl,
    double drawerFont,
  ) {
    return Column(
      children: [
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.home, color: Colors.blue),
          title: Text(
            "reiniciar".tr,
            style: TextStyle(fontSize: drawerFont),
          ),
          onTap: () {
            Get.back();
            if (onHomePressed != null) {
              onHomePressed!();
            } else {
              Get.toNamed(RotasPaginas.intro);
            }
          },
        ),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.dark_mode),
          title: Obx(() => Text(
                themeCtrl.isDark.value ? "Tclaro".tr : "Tescuro".tr,
                style: TextStyle(fontSize: drawerFont),
              )),
          onTap: () {
            themeCtrl.toggleDarkMode();
            Get.back();
          },
        ),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.format_italic),
          title: Text(
            "Tletra".tr,
            style: TextStyle(fontSize: drawerFont),
          ),
          onTap: () {
            themeCtrl.toggleKatimFont();
            Get.back();
          },
        ),
        linguas(),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.question_mark, color: Colors.brown),
          title: Text(
            "sobre_titulo".tr,
            style: TextStyle(fontSize: drawerFont),
          ),
          onTap: () {
            Get.dialog(MyAlertDialog(
              titulo: "sobre_titulo".tr,
              texto: "sobre_texto".tr,
            ));
          },
        ),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.receipt_long_outlined, color: Colors.brown),
          title: Text(
            "conselhos".tr,
            style: TextStyle(fontSize: drawerFont),
          ),
          onTap: () =>
              Get.toNamed(RotasPaginas.conselhos, arguments: [ads, margem]),
        ),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4),
          leading: const Icon(Icons.badge_outlined, color: Colors.brown),
          title: Text(
            "v_hist".tr,
            style: TextStyle(fontSize: drawerFont),
          ),
          onTap: () => Get.toNamed(RotasPaginas.historico),
        ),
        
        if (!ads) ...[
          Reuse.myDivider,
          ListTile(
            visualDensity: const VisualDensity(vertical: -4),
            leading: const Icon(Icons.campaign_outlined, color: Colors.brown),
            title: Text(
              "pq_anuncios_titulo".tr,
              style: TextStyle(fontSize: drawerFont),
            ),
            onTap: () {
              Get.dialog(MyAlertDialog(
                titulo: "pq_anuncios_titulo".tr,
                texto: "pq_anuncios_texto".tr,
              ));
            },
          ),
          if (!ads && (GetPlatform.isAndroid || GetPlatform.isIOS))
            ListTile(
              visualDensity: const VisualDensity(vertical: -4),
              leading: SizedBox(
                height: margem * 0.8,
                child: Image.asset(RotaImagens.adsOff),
              ),
              title: Text(
                "removerAds".tr,
                style: TextStyle(fontSize: drawerFont),
              ),
              onTap: () => Get.toNamed(RotasPaginas.pay),
            ),
          Reuse.myDivider,
        ],
        Padding(
          padding: EdgeInsets.symmetric(vertical: MyG.to.margens['margem025']!),
          child: const ListaTesteUnificada(isDrawerMode: true),
        ),
      ],
    );
  }
}
