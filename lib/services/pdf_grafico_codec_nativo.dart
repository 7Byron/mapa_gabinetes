import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as im;

Future<Uint8List> prepararGraficoPdf(Uint8List png) => compute(_converter, png);

Uint8List _converter(Uint8List png) {
  final imagem = im.decodePng(png);
  if (imagem == null) throw StateError('Não foi possível preparar o gráfico.');
  return im.encodeJpg(imagem, quality: 94);
}
