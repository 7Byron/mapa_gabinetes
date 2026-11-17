import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/models/grafico_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Montserrat')
          ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf')))
        .load();
  });
  test('Divide gráficos e tabela sem perder seleção e atualiza progresso',
      () async {
    final dados = DadosRelatorioExportacao(
      titulo: 'Taxas',
      unidade: 'Clínica',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      cabecalhos: ['Gabinete', 'Ocupação'],
      linhas: [
        for (var i = 0; i < 50; i++) ['Gabinete $i', 0.5]
      ],
      colunasPercentagem: {1},
      graficos: [
        GraficoTaxasExportacao([
          for (var i = 0; i < 4; i++)
            TaxaGraficoExportacao(
                titulo: '$i',
                descricao: 'Teste',
                horasOcupadas: 1,
                horasDisponiveis: 2)
        ])
      ],
    );
    final valores = <double>[];
    final todas = await RelatorioExportacaoService.gerarImagensPaginadas(dados,
        onProgresso: (valor, mensagem) async {
      valores.add(valor);
    });
    final tabelas = await RelatorioExportacaoService.gerarImagensPaginadas(
        dados,
        conteudo: ConteudoImagemRelatorio.tabela);
    final graficos = await RelatorioExportacaoService.gerarImagensPaginadas(
        dados,
        conteudo: ConteudoImagemRelatorio.grafico);
    expect(graficos, hasLength(1));
    expect(tabelas.length, greaterThan(1));
    expect(todas.length, graficos.length + tabelas.length);
    expect(valores.last, greaterThan(valores.first));
    for (final png in todas) {
      final codec = await ui.instantiateImageCodec(png);
      final imagem = (await codec.getNextFrame()).image;
      expect(imagem.height, greaterThan(imagem.width));
      expect(imagem.height, lessThan(8192));
      imagem.dispose();
      codec.dispose();
    }
  });
}
