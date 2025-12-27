import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/botao_icon.dart';
import '../funcoes/responsive.dart';
import '../funcoes/spacing.dart';

class ThankPage extends StatefulWidget {
  const ThankPage({super.key});

  @override
  State<ThankPage> createState() => _ThankPageState();
}

class _ThankPageState extends State<ThankPage> {
  final box = GetStorage();
  final int itemPurchased = Get.arguments[0];

  @override
  void initState() {
    super.initState();
    if (itemPurchased == 1) {
      MyG.to.atualizarAposCompra(adsRemovidos: true);
    } else if (itemPurchased == 2) {
      MyG.to.atualizarAposCompra(todosApps: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offNamed(RotasPaginas.intro);
          });
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: EdgeInsets.all(Spacing.xs),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20.0,
                    offset: Offset(0.0, 5.0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: AppBar(
                  elevation: 4.0,
                  automaticallyImplyLeading: false,
                  title: AutoSizeText(
                    "okcompra".tr,
                    style: TextStyle(
                      fontSize: ResponsiveConfig.of(context)
                          .clampFont(ResponsiveConfig.of(context).font(18)),
                      color: Colors.brown,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    minFontSize: 14,
                    maxFontSize: ResponsiveConfig.of(context)
                        .clampFont(ResponsiveConfig.of(context).font(18)),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Image.asset(RotaImagens.logoApp, height: 200),
              Padding(
                padding: EdgeInsets.all(Spacing.s),
                child: Text(
                  itemPurchased == 1 ? "okcompra2".tr : "okcompra3".tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: ResponsiveConfig.of(context)
                          .clampFont(ResponsiveConfig.of(context).font(18)),
                      fontWeight: FontWeight.bold),
                ),
              ),
              MyBotaoIcon(
                onPressed: () {
                  Get.offNamed(RotasPaginas.intro);
                },
                titulo: "reiniciar".tr,
                linhas: 1,
                myIcon: Icons.home,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
