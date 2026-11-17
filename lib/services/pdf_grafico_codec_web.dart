import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Usa o codec nativo do navegador, em vez de descodificar e codificar
/// milhões de píxeis em Dart/JavaScript na interface.
Future<Uint8List> prepararGraficoPdf(Uint8List png) async {
  final blob =
      web.Blob([png.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final canvas = web.HTMLCanvasElement();
  try {
    final imagem = web.HTMLImageElement()..src = url;
    await imagem.decode().toDart;
    canvas.width = imagem.naturalWidth;
    canvas.height = imagem.naturalHeight;
    final contexto = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    contexto.drawImage(imagem, 0, 0);
    final pronto = Completer<web.Blob>();
    canvas.toBlob(
        ((web.Blob? jpeg) {
          if (jpeg == null || jpeg.type != 'image/jpeg') {
            pronto.completeError(
                StateError('Não foi possível preparar o gráfico.'));
          } else {
            pronto.complete(jpeg);
          }
        }).toJS,
        'image/jpeg',
        0.94.toJS);
    final jpeg = await pronto.future;
    final buffer = await jpeg.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
    canvas.width = 0;
    canvas.height = 0;
  }
}
