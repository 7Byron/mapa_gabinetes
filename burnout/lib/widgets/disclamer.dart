import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';

Padding disclaimer() {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: MyG.to.margens['margem1']!),
    child: AutoSizeText(
      "* ${"disclamer".tr}",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.brown,
        fontSize: MyG.to.margens['margem05']!,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 3,
    ),
  );
}
