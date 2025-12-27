// lib/controllers/theme_controller.dart

import 'package:get/get.dart';
import '../funcoes/theme_default.dart';

class ThemeController extends GetxController {
  RxBool isDark = false.obs;
  RxBool isKatim = false.obs;

  void toggleDarkMode() {
    isDark.value = !isDark.value;
    _aplicarTema();
  }

  void toggleKatimFont() {
    isKatim.value = !isKatim.value;
    _aplicarTema();
  }

  void _aplicarTema() {
    if (isDark.value && isKatim.value) {
      Get.changeTheme(darkThemeDatakalim());
    } else if (!isDark.value && isKatim.value) {
      Get.changeTheme(lightThemeDataKalim());
    } else if (isDark.value && !isKatim.value) {
      Get.changeTheme(darkThemeData());
    } else {
      Get.changeTheme(lightThemeData());
    }
  }
}
