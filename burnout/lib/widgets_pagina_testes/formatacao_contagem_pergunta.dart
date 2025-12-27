import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';




Widget tituloNPergunta(String texto, {Key? key}) {
  return Text(
    texto,
    key: key, // Defina a key aqui
    style: TextStyle(
      fontSize: MyG.to.margens['margem085']!,
      fontWeight: FontWeight.bold,
      color: Colors.brown,
    ),
  );
}