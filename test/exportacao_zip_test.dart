import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';

void main() {
  test('ZIP preserva conteúdo, evita recompressão e avança por imagem',
      () async {
    final imagens = [
      for (var i = 0; i < 4; i++)
        Uint8List.fromList(List.generate(65536, (n) => (n * 31 + i) % 256))
    ];
    final valores = <double>[];
    final mensagens = <String>[];
    final bytes = await RelatorioExportacaoService.gerarZipImagens(
        imagens, 'matriz', onProgresso: (valor, mensagem) async {
      valores.add(valor);
      mensagens.add(mensagem);
    });
    final arquivo = ZipDecoder().decodeBytes(bytes, verify: true);
    expect(arquivo.files.length, imagens.length);
    for (var i = 0; i < imagens.length; i++) {
      expect(arquivo.files[i].name, 'matriz_00${i + 1}.png');
      expect(arquivo.files[i].compressionType, ArchiveFile.STORE);
      expect(arquivo.files[i].content, imagens[i]);
    }
    expect(valores.length, imagens.length);
    expect(valores.last, greaterThan(valores.first));
    expect(valores.last, lessThan(1));
    expect(mensagens.last, contains('4 de 4'));
  });
}
