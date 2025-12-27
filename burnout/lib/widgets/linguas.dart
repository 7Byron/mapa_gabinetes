import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';

///A fazer: traduzir strings do mudar idioma e idioma!

const List<String> _idiomaString = [
  "ar",
  "cs",
  "da",
  "de",
  "el",
  "en",
  "es",
  "fa",
  "fi",
  "fr",
  "he",
  "hi",
  "hr",
  "hu",
  "id",
  "is",
  "it",
  "iw",
  "ja",
  "ko",
  "lt",
  "lv",
  "mr",
  "ms",
  "nl",
  "nb",
  "no",
  "pl",
  "pt_BR",
  "pt_PT",
  "ro",
  "ru",
  "sk",
  "sl",
  "sq",
  "sv",
  "ta",
  "te",
  "th",
  "tr",
  "uk",
  "ur",
  "vi",
  "zh_CN",
  "zh_TW",
];

Widget linguas() {
  return Theme(
    data: Theme.of(Get.context!).copyWith(
      dividerColor: Colors.transparent,
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
    ),
    child: ExpansionTile(
    childrenPadding:
        EdgeInsets.symmetric(vertical: MyG.to.margens['margem01']!),
    title: Row(
      children: [
        const Icon(Icons.language_outlined, color: Colors.brown),
        SizedBox(
          width: MyG.to.margem,
        ),
        Expanded(
          child: AutoSizeText(
            "_mudarIdioma".tr,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: MyG.to.margens['margem075']!,
              color: Colors.brown,
            ),
          ),
        ),
      ],
    ),
    children: <Widget>[
      for (var i = 0; i < _idiomaString.length; i++)
        ListTile(
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          title: InkWell(
            onTap: () {
              // Inicializa localeInfo para quebrar idioma e país
              final List<String> localeInfo = _idiomaString[i].split('_');
              Locale selectedLocale;

              if (localeInfo.length > 1) {
                selectedLocale = Locale(localeInfo[0], localeInfo[1]);
              } else {
                selectedLocale = Locale(localeInfo[0]);
              }

              // Fecha o drawer primeiro
              Get.back();

              // Atualiza o idioma
              Get.updateLocale(selectedLocale);
              Get.toNamed(RotasPaginas.intro);
            },
            child: opcoesIdioma(
              _idiomaString[i],
              // Passa a bandeira correta baseada no código do idioma/país
              "flags/${_idiomaString[i].replaceAll('-', '_').toLowerCase()}.png",
            ),
          ),
        ),
    ],
  ),
  );
}

Padding opcoesIdioma(
  String titulo,
  String imagemBandeira,
) {
  return Padding(
    padding: const EdgeInsets.only(left: 50),
    child: Row(
      children: [
        Image.asset(
          imagemBandeira,
          height: MyG.to.margens['margem075']!,
        ),
        SizedBox(
          width: MyG.to.margens['margem075']!,
        ),
        Text(
          titulo.replaceAll('_', '-').toUpperCase(), // Mostra PT-BR, PT-PT etc.
          style: TextStyle(
            color: Colors.brown,
            fontSize: MyG.to.margens['margem065']!,
          ),
        ),
      ],
    ),
  );
}
