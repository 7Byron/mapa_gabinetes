import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';
import 'itens_reutilizaveis.dart';
import '../funcoes/spacing.dart';

typedef VideoResultadoCallback = void Function();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showVideoResultadoDialog(
    VideoResultadoCallback onVideoIgnorar, VideoResultadoCallback onVideoVer) {
  Get.dialog(
    Builder(
      builder: (BuildContext dialogContext) {
        final bool isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final Color dialogColor =
            isDark ? Colors.grey.shade800 : Colors.amber.shade50;

        return Center(
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: SizedBox(
              width: Get.context!.isTablet
                  ? MyG.to.margens['margem22']!
                  : Get.width - MyG.to.margens['margem1']!,
              height: MyG.to.margens['margem18']!,
              child: Card(
                color: dialogColor,
                child: Padding(
                  padding: EdgeInsets.all(MyG.to.margens['margem1']!),
                  child: Column(
                    children: [
                      Reuse.myHeigthBox1,
                      _buildTitle(isDark),
                      Reuse.myHeigthBox1,
                      Divider(color: isDark ? Colors.grey.shade600 : null),
                      Expanded(child: _buildMessage(isDark)),
                      Reuse.myHeigthBox1,
                      _buildIgnoreButton(onVideoIgnorar, isDark),
                      Reuse.myHeigthBox1,
                      _buildViewButton(onVideoVer, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
    barrierDismissible: false,
  );
}

Widget _buildTitle(bool isDark) {
  return Text(
    "FimTeste_t".tr,
    style: TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: MyG.to.margens['margem1']!,
      fontWeight: FontWeight.bold,
    ),
  );
}

Widget _buildMessage(bool isDark) {
  return Center(
    child: Text(
      "FimTeste".tr,
      style: TextStyle(
        color: isDark ? Colors.grey.shade300 : Colors.brown,
        fontSize: MyG.to.margens['margem1']!,
        fontWeight: FontWeight.normal,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

Widget _buildIgnoreButton(VideoResultadoCallback onVideoIgnorar, bool isDark) {
  return GestureDetector(
    onTap: onVideoIgnorar,
    child: Text(
      "Ignorar".tr,
      style: TextStyle(
        fontSize: MyG.to.margens['margem075']!,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

Widget _buildViewButton(VideoResultadoCallback onVideoVer, bool isDark) {
  return Padding(
    padding: EdgeInsets.all(Spacing.s),
    child: SizedBox(
      height: MyG.to.margens['margem3']!,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey.shade700 : null,
        ),
        onPressed: onVideoVer,
        child: Text(
          "VerVideo".tr,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.brown,
            fontSize: MyG.to.margens['margem075']!,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
