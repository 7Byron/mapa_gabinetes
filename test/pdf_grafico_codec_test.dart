import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:mapa_gabinetes/models/grafico_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';
import 'package:mapa_gabinetes/services/pdf_grafico_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('Montserrat')
          ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf')))
        .load();
  });
  test('Compara PDF de matriz e taxas com três painéis de gráficos', () async {
    final matriz = DadosRelatorioExportacao(
      titulo: 'Matriz de Médicos',
      unidade: 'Clínica',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      cabecalhos: [
        'Médico',
        'Especialidade',
        'Horário',
        'Semana',
        'Mês',
        'Ano',
        '%'
      ],
      linhas: [
        for (var i = 0; i < 100; i++)
          [
            'Médico $i',
            'MGF',
            '2.ª feira 09:00–17:00',
            '8:00',
            '32:00',
            '400:00',
            0.01
          ]
      ],
      proporcoes: [0.17, 0.14, 0.30, 0.095, 0.095, 0.095, 0.105],
      colunasPercentagem: {6},
    );
    final taxas = DadosRelatorioExportacao(
      titulo: 'Taxas de Ocupação',
      unidade: 'Clínica',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      cabecalhos: ['Gabinete', 'Taxa'],
      linhas: [
        for (var i = 0; i < 27; i++) ['$i', 0.5]
      ],
      colunasPercentagem: {1},
      graficos: [
        GraficoTaxasExportacao([
          for (var i = 0; i < 27; i++)
            TaxaGraficoExportacao(
                titulo: 'Gabinete $i',
                descricao: 'Medicina Geral',
                horasOcupadas: 5,
                horasDisponiveis: 10)
        ])
      ],
    );
    final relogio = Stopwatch()..start();
    final pdfMatriz = await RelatorioExportacaoService.gerarPdf(
        dados: matriz, portrait: true);
    final matrizMs = relogio.elapsedMilliseconds;
    relogio.reset();
    var inicioFinalizacao = 0;
    final pdfTaxas = await RelatorioExportacaoService.gerarPdf(
        dados: taxas,
        portrait: true,
        onProgresso: (valor, mensagem) async {
          if (valor == 0.94) inicioFinalizacao = relogio.elapsedMilliseconds;
          await Future<void>.delayed(Duration.zero);
        });
    final taxasMs = relogio.elapsedMilliseconds;
    expect(pdfMatriz.take(4), [37, 80, 68, 70]);
    expect(pdfTaxas.take(4), [37, 80, 68, 70]);
    debugPrint(
        'PDF_COMPARACAO matriz100=${matrizMs}ms taxas27=${taxasMs}ms finalizacao=${taxasMs - inicioFinalizacao}ms');
  }, skip: kIsWeb);

  test('Codec preserva resolução dos gráficos e compara custo de conversão',
      () async {
    final original = im.Image(width: 1504, height: 1500);
    im.fill(original, color: im.ColorRgb8(255, 255, 255));
    for (var i = 0; i < 9; i++) {
      im.fillCircle(original,
          x: 250 + (i % 3) * 500,
          y: 250 + (i ~/ 3) * 480,
          radius: 90,
          color: im.ColorRgb8(40, 124, 112));
    }
    final png = im.encodePng(original);
    final relogio = Stopwatch()..start();
    final antigo = im.encodeJpg(im.decodePng(png)!, quality: 94);
    final antes = relogio.elapsedMilliseconds;
    relogio.reset();
    final novo = await prepararGraficoPdf(png);
    final depois = relogio.elapsedMilliseconds;
    final imagem = im.decodeJpg(novo)!;
    expect(imagem.width, 1504);
    expect(imagem.height, 1500);
    expect(novo.take(2), [255, 216]);
    expect(antigo.take(2), [255, 216]);
    // Medição comparativa; não impõe tempos dependentes do equipamento.
    debugPrint(
        'CODEC_PDF antes=${antes}ms depois=${depois}ms bytes=${novo.length}');
  });
}
