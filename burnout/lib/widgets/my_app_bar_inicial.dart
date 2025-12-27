import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../funcoes/responsive.dart';
import '../a_config_app/lista_testes.dart';
import '../funcoes/variaveis_globais.dart';
import 'base_app_bar.dart';

class AppBarInitial extends StatelessWidget implements PreferredSizeWidget {
  const AppBarInitial({super.key});

  // Ciclo de debug: 0 -> allApps=true, 1 -> adsPago=true, 2 -> ambos=false
  static int _debugTapCycle = 0;

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();
    final r = ResponsiveConfig.of(context);

    return BaseRoundedAppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!kDebugMode) return;
                // Avança o ciclo de estados de teste
                final int step = _debugTapCycle % 3;
                switch (step) {
                  case 0:
                    MyG.to.atualizarAposCompra(todosApps: true);
                    Get.snackbar('DEBUG', 'allApps = true',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(milliseconds: 900));
                    break;
                  case 1:
                    MyG.to.atualizarAposCompra(adsRemovidos: true);
                    Get.snackbar('DEBUG', 'adsPago = true (sem anúncios)',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(milliseconds: 900));
                    break;
                  default:
                    MyG.to.atualizarAposCompra(
                      todosApps: false,
                      adsRemovidos: false,
                    );
                    Get.snackbar('DEBUG', 'allApps = false, adsPago = false',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(milliseconds: 900));
                }
                _debugTapCycle++;
              },
            child: Text(
              ListaTeste.nomeApp,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: r.clampFont(r.font(16)),
              ),
              maxLines: 1,
              ),
            ),
          ),
          Obx(() {
            final double size = r.icon(18).clamp(10.0, 18.0);
            return IconButton(
              icon: Icon(
                themeCtrl.isKatim.value
                    ? Icons.font_download_outlined
                    : Icons.format_italic,
                size: size,
              ),
              onPressed: () => themeCtrl.toggleKatimFont(),
            );
          }),
          Obx(() {
            final double size = r.icon(18).clamp(10.0, 18.0);
            return IconButton(
              icon: Icon(
                themeCtrl.isDark.value ? Icons.light_mode : Icons.dark_mode,
                size: size,
              ),
              onPressed: () => themeCtrl.toggleDarkMode(),
            );
          }),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(56); // altura base; toolbarHeight define o real
}
