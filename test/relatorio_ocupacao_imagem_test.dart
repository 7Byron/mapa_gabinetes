import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_graficos_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_ocupacao_excel_service.dart';
import 'package:mapa_gabinetes/services/relatorio_ocupacao_exportacao_service.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';

Future<({int largura, int altura, int corGrafico, int corTabela})> analisar(
    Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final imagem = (await codec.getNextFrame()).image;
  try {
    final dados = (await imagem.toByteData())!.buffer.asUint8List();
    final grafico = MyAppTheme.corOcupacao(50).toARGB32() & 0xffffff;
    var corGrafico = 0;
    var corTabela = 0;
    for (var i = 0; i < dados.length; i += 4) {
      final rgb = dados[i] << 16 | dados[i + 1] << 8 | dados[i + 2];
      if (rgb == grafico) corGrafico++;
      if (rgb == 0x17343c) corTabela++;
    }
    return (
      largura: imagem.width,
      altura: imagem.height,
      corGrafico: corGrafico,
      corTabela: corTabela
    );
  } finally {
    imagem.dispose();
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontes = FontLoader('Montserrat')
      ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf'))
      ..addFont(rootBundle.load('fonts/Montserrat-Bold.ttf'));
    await fontes.load();
  });

  DadosRelatorioExportacao dados({required bool porHora, int dias = 24}) =>
      RelatorioOcupacaoExportacaoService.gabinete(
        unidade: 'Clínica São João',
        gabinete: '101',
        descricao: 'ORL',
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2026, 11, dias),
        filtroDias: 'Todos os dias',
        porHora: porHora,
        horarios: {
          for (var i = 1; i <= dias; i++)
            DateTime(2026, 11, i): (inicio: 480, fim: 1200)
        },
        linhas: [
          for (var i = 1; i <= dias; i++)
            for (var intervalo = 0; intervalo < (porHora ? 2 : 1); intervalo++)
              LinhaOcupacaoExcel(
                  data: DateTime(2026, 11, i),
                  horasOcupadas: 6,
                  horasDisponiveis: 12,
                  inicio: intervalo == 0 ? '08:00' : '14:00',
                  fim: intervalo == 0 ? '11:00' : '17:00',
                  horasIntervalo: 3),
        ],
      );

  for (final porHora in [false, true]) {
    test(
        'Imagem ${porHora ? 'horária' : 'diária'} separa gráfico e tabela em horizontal',
        () async {
      final relatorio = dados(porHora: porHora);
      final grafico = await RelatorioExportacaoService.gerarImagem(
          dados: relatorio,
          conteudo: ConteudoImagemRelatorio.grafico,
          horizontal: true);
      final tabela = await RelatorioExportacaoService.gerarImagem(
          dados: relatorio,
          conteudo: ConteudoImagemRelatorio.tabela,
          horizontal: true);
      final imagemGrafico = await analisar(grafico);
      final imagemTabela = await analisar(tabela);
      expect(imagemGrafico.largura, 2400);
      expect(imagemGrafico.largura, greaterThan(imagemGrafico.altura));
      expect(imagemTabela.largura, greaterThan(imagemTabela.altura));
      expect(imagemGrafico.corGrafico, greaterThan(1000));
      expect(imagemTabela.corGrafico, 0);
      expect(imagemTabela.corTabela, greaterThan(imagemGrafico.corTabela * 2));
      final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
      if (destino != null) {
        final modo = porHora ? 'hora' : 'dia';
        await File('$destino/ocupacao_${modo}_grafico.png')
            .writeAsBytes(grafico);
        await File('$destino/ocupacao_${modo}_tabela.png').writeAsBytes(tabela);
      }
    });
  }

  test(
      'Imagem horizontal inclui todo o período; PDF conserva os painéis anteriores',
      () async {
    final relatorio = dados(porHora: false, dias: 25);
    final paineis = await RelatorioGraficosExportacaoService.gerar(
        relatorio.graficos,
        largura: 2304,
        diasPorPainel: 24);
    expect(paineis.length, 2);
    final imagem = await analisar(await RelatorioExportacaoService.gerarImagem(
        dados: relatorio,
        conteudo: ConteudoImagemRelatorio.grafico,
        horizontal: true));
    expect(imagem.largura, 4800);
    expect(imagem.largura, greaterThan(imagem.altura));
    expect(
        (await RelatorioGraficosExportacaoService.gerar(relatorio.graficos))
            .length,
        3);
    final pdf = latin1
        .decode(await RelatorioExportacaoService.gerarPdf(dados: relatorio));
    expect(RegExp(r'/Subtype\s*/Image\b').allMatches(pdf).length,
        greaterThanOrEqualTo(3));
  });
}
