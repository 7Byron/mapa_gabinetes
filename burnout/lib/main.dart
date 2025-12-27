import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'funcoes/variaveis_globais.dart';
import 'a_config_app/lista_testes.dart';
import 'admob/ad_manager.dart';
import 'outras_paginas/splash_screen.dart';
import 'funcoes/theme_default.dart';
import 'funcoes/rotas_paginas.dart';

import 'admob/services/banner_ad_controller.dart';
import 'controllers/theme_controller.dart';
import 'funcoes/messages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();

  if (!Get.isRegistered<MyG>()) {
    final myG = MyG();
    myG.carregarStatusComprasInicial(); // Carrega status das compras
    Get.put(myG);
  }

  if (!Get.isRegistered<ThemeController>()) {
    Get.put(ThemeController());
  }

  if (!Get.isRegistered<AdManager>()) {
    Get.put(AdManager());
  }
  if (!MyG.to.adsPago) {
    await AdManager.to.initializeAndConfigure();
    if (!Get.isRegistered<BannerAdController>()) {
      Get.put(BannerAdController());
    }
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      translations: Messages(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en'),
      debugShowCheckedModeBanner: false,
      title: ListaTeste.nomeApp,
      themeMode: ThemeMode.light,
      theme: lightThemeData(),
      darkTheme: darkThemeData(),
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 750),
      getPages: PaginasApp.paginas,
      routingCallback: (routing) {
        try {
          final current = routing?.current ?? '';
          if (current.isNotEmpty && Get.isRegistered<AdManager>()) {
            AdManager.to.onPageVisit(current);
          }
        } catch (_) {}
      },
      home: const SplashScreen(),
      builder: (context, child) {
        return Builder(
            builder: (context) {
              try {
                MyG.to.calcularMargensPorContexto(context);
              } catch (_) {}
            final width = MediaQuery.of(context).size.width;
              double textScale = 1.0;
              if (width <= 450) textScale = 0.9;
              if (width >= 801 && width <= 1200) textScale = 1.03;
              if (width > 1200) textScale = 1.08;

              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              );
            },
        );
      },
    );
  }
}
