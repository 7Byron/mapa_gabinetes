import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/grafico_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/models/taxa_ocupacao.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_graficos_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_ocupacao_excel_service.dart';
import 'package:mapa_gabinetes/services/relatorio_ocupacao_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_taxas_excel_service.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';

Object valor(Data? celula) => switch (celula?.value) {
      IntCellValue(:final value) => value,
      DoubleCellValue(:final value) => value,
      TextCellValue(:final value) => value.toString(),
      _ => '',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inicio = DateTime(2026, 11, 1);
  final fim = DateTime(2026, 11, 30);
  setUpAll(() async {
    final fontes = FontLoader('Montserrat')
      ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf'))
      ..addFont(rootBundle.load('fonts/Montserrat-Bold.ttf'));
    await fontes.load();
  });

  test(
      'Um único gabinete é exportado sem duplicar o geral nos gráficos e tabelas',
      () async {
    final gabinetes = [
      for (final id in ['104', '105'])
        Gabinete(
            id: id,
            nome: id,
            setor: 'Piso 1',
            especialidadesPermitidas: ['Ortopedia']),
    ];
    const taxas = {'104': TaxaOcupacao(horasOcupadas: 6, horasDisponiveis: 12)};
    final dados = RelatorioOcupacaoExportacaoService.taxas(
        unidade: 'Clínica',
        inicio: inicio,
        fim: fim,
        gabinetes: gabinetes,
        taxas: taxas);
    expect(dados.linhas.single, ['104', 'Piso 1', 'Ortopedia', 6.0, 12.0, 0.5]);
    expect(dados.linhasDestaque, isEmpty);
    final grafico = dados.graficos.single as GraficoTaxasExportacao;
    expect(grafico.taxas.single.titulo, '104 · Piso 1');
    expect(grafico.taxas.single.percentagem, 50);
    final excel = Excel.decodeBytes(RelatorioTaxasExcelService.gerar(
        unidade: 'Clínica',
        inicio: inicio,
        fim: fim,
        gabinetes: gabinetes,
        taxas: taxas));
    expect(
        excel.tables.values.single.rows
            .skip(6)
            .map((l) => l.map(valor).toList()),
        dados.linhas);
    final pdf = await RelatorioExportacaoService.gerarPdf(dados: dados);
    final png = await RelatorioExportacaoService.gerarImagem(dados: dados);
    expect(latin1.decode(pdf).startsWith('%PDF-'), isTrue);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) {
      await File('$destino/taxa_gabinete_unico.png').writeAsBytes(png);
      await File('$destino/taxa_gabinete_unico.pdf').writeAsBytes(pdf);
    }
  });

  test(
      'Taxas preservam seleção, geral ponderado, gabinete vazio e valores do Excel',
      () async {
    final gabinetes = [
      for (final id in ['101', '102', '103'])
        Gabinete(
            id: id,
            nome: id,
            setor: 'Piso 1',
            especialidadesPermitidas: ['ORL']),
    ];
    final taxas = {
      '101': const TaxaOcupacao(horasOcupadas: 6, horasDisponiveis: 12),
      '102': const TaxaOcupacao(horasDisponiveis: 12),
    };
    final dados = RelatorioOcupacaoExportacaoService.taxas(
        unidade: 'Clínica',
        inicio: inicio,
        fim: fim,
        gabinetes: gabinetes,
        taxas: taxas);
    final excel = Excel.decodeBytes(RelatorioTaxasExcelService.gerar(
        unidade: 'Clínica',
        inicio: inicio,
        fim: fim,
        gabinetes: gabinetes,
        taxas: taxas));
    final linhas = excel.tables.values.single.rows;
    expect(dados.linhas,
        linhas.skip(6).map((l) => l.map(valor).toList()).toList());
    expect(dados.cabecalhos, linhas[5].map(valor).toList());
    expect(dados.linhas.length, 3);
    expect(dados.linhasFormatadas.first.last, '25,0%');
    expect(dados.linhasFormatadas.last.last, '0,0%');
    expect(dados.detalhes.single, contains('101 (Piso 1)'));
    expect(dados.detalhes.single, isNot(contains('103')));
    final grafico = dados.graficos.single as GraficoTaxasExportacao;
    expect(grafico.taxas.map((t) => t.titulo),
        ['Geral', '101 · Piso 1', '102 · Piso 1']);
    expect(grafico.taxas.map((t) => t.percentagem), [25, 50, 0]);
    final pdf = await RelatorioExportacaoService.gerarPdf(dados: dados);
    expect(latin1.decode(pdf).startsWith('%PDF-'), isTrue);
    expect(RegExp(r'/Subtype\s*/Image\b').hasMatch(latin1.decode(pdf)), isTrue);
    final png = await RelatorioExportacaoService.gerarImagem(dados: dados);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    // A imagem final contém os arcos coloridos, além da tabela de dados.
    final codec = await ui.instantiateImageCodec(png);
    final imagem = (await codec.getNextFrame()).image;
    try {
      final pixels = (await imagem.toByteData())!.buffer.asUint8List();
      final cor = MyAppTheme.corOcupacao(50).toARGB32();
      var encontrados = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        if (pixels[i] == ((cor >> 16) & 255) &&
            pixels[i + 1] == ((cor >> 8) & 255) &&
            pixels[i + 2] == (cor & 255)) {
          encontrados++;
        }
      }
      expect(encontrados, greaterThan(1000));
    } finally {
      imagem.dispose();
      codec.dispose();
    }
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) {
      await File('$destino/taxas_ocupacao.pdf').writeAsBytes(pdf);
      await File('$destino/taxas_ocupacao.png').writeAsBytes(png);
    }
  });

  for (final porHora in [false, true]) {
    final linhas = [
      LinhaOcupacaoExcel(
          data: DateTime(2026, 11, 2),
          horasOcupadas: 3.5,
          horasDisponiveis: 14,
          inicio: '08:00',
          fim: '11:30',
          horasIntervalo: 3.5),
      LinhaOcupacaoExcel(
          data: DateTime(2026, 11, 9),
          horasOcupadas: 0,
          horasDisponiveis: 0,
          fechado: true,
          motivo: 'Feriado'),
    ];
    final dados = RelatorioOcupacaoExportacaoService.gabinete(
        unidade: 'Clínica São João',
        gabinete: '101',
        descricao: 'ORL',
        inicio: inicio,
        fim: fim,
        filtroDias: 'Segundas-feiras',
        porHora: porHora,
        linhas: linhas);
    test(
        'Ocupação por ${porHora ? 'hora' : 'dia'} mantém filtros, encerramentos e os valores do Excel',
        () {
      final excel = Excel.decodeBytes(RelatorioOcupacaoExcelService.gerar(
          unidade: 'Clínica São João',
          gabinete: '101',
          descricao: 'ORL',
          inicio: inicio,
          fim: fim,
          filtroDias: 'Segundas-feiras',
          porHora: porHora,
          linhas: linhas));
      final tabela = excel.tables.values.single.rows;
      expect(dados.cabecalhos, tabela[6].map(valor).toList());
      expect(dados.linhas,
          tabela.skip(7).map((l) => l.map(valor).toList()).toList());
      expect(dados.detalhes, contains('Dias da semana: Segundas-feiras'));
      final coluna = porHora ? 6 : 3;
      expect(dados.linhasFormatadas.first[coluna], '25,0%');
      expect(dados.linhasFormatadas.last[coluna], '0,0%');
      expect(dados.linhasFormatadas.last.last, 'Feriado');
      final grafico = dados.graficos.single as GraficoOcupacaoExportacao;
      expect(grafico.porHora, porHora);
      expect(grafico.dias.single.data, DateTime(2026, 11, 2));
      expect(grafico.dias.single.percentagem, 25);
      if (porHora) {
        expect(dados.linhasFormatadas.first.sublist(1, 4),
            ['08:00', '11:30', '3,5']);
      }
    });

    test('Gera PDF e PNG com ${porHora ? 8 : 5} colunas', () async {
      final pdf = await RelatorioExportacaoService.gerarPdf(dados: dados);
      expect(latin1.decode(pdf).startsWith('%PDF-'), isTrue);
      expect(
          RegExp(r'/Subtype\s*/Image\b').hasMatch(latin1.decode(pdf)), isTrue);
      final png = await RelatorioExportacaoService.gerarImagem(dados: dados);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
      if (destino != null) {
        await File('$destino/ocupacao_${porHora ? 'hora' : 'dia'}.pdf')
            .writeAsBytes(pdf);
        await File('$destino/ocupacao_${porHora ? 'hora' : 'dia'}.png')
            .writeAsBytes(png);
      }
    });
  }

  test('Gráfico horário preserva intervalos separados e conta cada dia uma vez',
      () async {
    final data = DateTime(2026, 11, 2);
    final dados = RelatorioOcupacaoExportacaoService.gabinete(
      unidade: 'Clínica',
      gabinete: '101',
      descricao: 'ORL',
      inicio: data,
      fim: data,
      filtroDias: 'Segundas-feiras',
      porHora: true,
      horarios: {data: (inicio: 8 * 60, fim: 20 * 60)},
      linhas: [
        LinhaOcupacaoExcel(
            data: data,
            horasOcupadas: 4,
            horasDisponiveis: 12,
            inicio: '08:00',
            fim: '10:00',
            horasIntervalo: 2),
        LinhaOcupacaoExcel(
            data: data,
            horasOcupadas: 4,
            horasDisponiveis: 12,
            inicio: '14:00',
            fim: '16:00',
            horasIntervalo: 2),
      ],
    );
    final grafico = dados.graficos.single as GraficoOcupacaoExportacao;
    final dia = grafico.dias.single;
    expect(dia.horasOcupadas, 4);
    expect(dia.horasDisponiveis, 12);
    expect(dia.inicioMinutos, 480);
    expect(dia.fimMinutos, 1200);
    expect(
        dia.intervalos.map((i) => (i.inicio, i.fim)), [(480, 600), (840, 960)]);
    final imagens =
        await RelatorioGraficosExportacaoService.gerar(dados.graficos);
    final codec = await ui.instantiateImageCodec(imagens.single.bytes);
    final imagem = (await codec.getNextFrame()).image;
    try {
      final pixels = (await imagem.toByteData())!.buffer.asUint8List();
      List<int> pixel(int x, int y) => pixels.sublist(
          (y * imagem.width + x) * 4, (y * imagem.width + x) * 4 + 3);
      // Centro da primeira coluna: ocupado às 09h e 15h, livre às 12h.
      const x = 190;
      expect(pixel(x, 179), isNot([255, 255, 255]));
      expect(pixel(x, 281), [255, 255, 255]);
      expect(pixel(x, 354), isNot([255, 255, 255]));
    } finally {
      imagem.dispose();
      codec.dispose();
    }
  });

  test('Vários gabinetes exportam todos os gráficos em páginas legíveis',
      () async {
    final gabinetes = [
      for (var i = 0; i < 9; i++)
        Gabinete(
            id: '$i',
            nome: 'Gabinete $i',
            setor: 'Piso 1',
            especialidadesPermitidas: ['ORL'])
    ];
    final dados = RelatorioOcupacaoExportacaoService.taxas(
      unidade: 'Clínica',
      inicio: inicio,
      fim: fim,
      gabinetes: gabinetes,
      taxas: {
        for (final g in gabinetes)
          g.id: const TaxaOcupacao(horasOcupadas: 6, horasDisponiveis: 12)
      },
    );
    // Geral e nove gabinetes, em quatro painéis.
    final imagens =
        await RelatorioGraficosExportacaoService.gerar(dados.graficos);
    expect(imagens.length, 4);
    final pdf =
        latin1.decode(await RelatorioExportacaoService.gerarPdf(dados: dados));
    expect(RegExp(r'/Subtype\s*/Image\b').allMatches(pdf).length,
        greaterThanOrEqualTo(4));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, greaterThan(1));
  });

  test('Imagem anual inclui todas as linhas em painéis de altura limitada',
      () async {
    final dados = RelatorioOcupacaoExportacaoService.gabinete(
      unidade: 'Clínica',
      gabinete: '101',
      descricao: 'ORL',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      filtroDias: 'Todos os dias',
      porHora: true,
      linhas: [
        for (var dia = 0; dia < 365; dia++)
          LinhaOcupacaoExcel(
              data: DateTime(2026, 1, 1 + dia),
              horasOcupadas: 4,
              horasDisponiveis: 12,
              inicio: '08:00',
              fim: '12:00',
              horasIntervalo: 4)
      ],
    );
    expect(dados.linhas.length, 365);
    final png = await RelatorioExportacaoService.gerarImagem(dados: dados);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(1600));
    expect(frame.image.width, lessThanOrEqualTo(16384));
    expect(frame.image.height, lessThanOrEqualTo(16384));
    frame.image.dispose();
    codec.dispose();
  });
}
