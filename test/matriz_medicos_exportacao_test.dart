import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/services/matriz_medicos_service.dart';
import 'package:mapa_gabinetes/services/matriz_medicos_exportacao_service.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Montserrat')
          ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf')))
        .load();
  });
  MatrizMedicoLinha linha(
          String id, String nome, String especialidade, int horas) =>
      MatrizMedicoLinha(
          Medico(
              id: id,
              nome: nome,
              especialidade: especialidade,
              disponibilidades: []),
          ['5.ª feira · 14:00 – 17:30 · Quinzenal · A partir de 01/10/2026'],
          horas,
          horas * 4,
          horas * 40);
  final previstas = [
    linha('a', 'Ana', 'Cirurgia Geral', 120),
    linha('b', 'Bruno', 'Cardiologia', 600),
    linha('c', 'Carla', 'Cirurgia Geral', 240)
  ];
  final reais = [
    linha('a', 'Ana', 'Cirurgia Geral', 60),
    linha('b', 'Bruno', 'Cardiologia', 600),
    linha('c', 'Carla', 'Cirurgia Geral', 30)
  ];
  MatrizMedicosExportacaoDados selecao(
          {String pesquisa = 'cirurgia geral',
          List<bool> descontos = const [true, false, true]}) =>
      MatrizMedicosExportacaoDados(
          linhas: previstas,
          reais: reais,
          descontos: descontos,
          pesquisa: pesquisa,
          ordenacao: 2,
          periodoPercentagem: 0,
          referencia: DateTime(2026, 10),
          semanaReferencia: DateTime(2026, 11, 16));

  test('Seleção comum respeita especialidade, ordenação, modos e períodos', () {
    final s = selecao();
    final dados = s.documento('Clínica');
    expect(s.visiveis.map((l) => l.medico.nome), ['Ana', 'Carla']);
    expect(dados.linhas.map((l) => l[1]), everyElement('Cirurgia Geral'));
    expect(dados.linhas.first.sublist(3, 6), ['1:00', '8:00', '40:00']);
    expect(dados.linhas.first.last, closeTo(60 / 690, 0.00001));
    expect(dados.detalhes.join('\n'), contains('16/11/2026 a 22/11/2026'));
    expect(dados.detalhes.join('\n'), contains('Mês: 10/2026'));
    expect(selecao(descontos: [false, false, false]).visiveis.first.medico.nome,
        'Carla');
    expect(selecao(pesquisa: 'sem resultados').documento('Clínica').linhas,
        isEmpty);
  });

  test('Horas ordena pelo ano mesmo quando a semana tem ordem diferente', () {
    final a = MatrizMedicoLinha(previstas[0].medico, [], 600, 600, 120);
    final c = MatrizMedicoLinha(previstas[2].medico, [], 60, 60, 1200);
    final dados = MatrizMedicosExportacaoDados(
        linhas: [a, c],
        reais: [],
        descontos: [false, false, false],
        pesquisa: '',
        ordenacao: 2,
        periodoPercentagem: 0,
        referencia: DateTime(2026),
        semanaReferencia: DateTime(2026));
    expect(dados.visiveis.map((l) => l.medico.nome), ['Carla', 'Ana']);
  });

  test('Excel contém apenas os médicos filtrados e mantém valores', () {
    final dados = selecao().documento('Clínica');
    final excel =
        Excel.decodeBytes(MatrizMedicosExportacaoDados.gerarExcel(dados));
    final linhas = excel['Matriz de Médicos'].rows;
    final texto =
        linhas.map((r) => r.map((c) => c?.value).join('|')).join('\n');
    expect(texto, contains('Ana|Cirurgia Geral'));
    expect(texto, contains('Carla|Cirurgia Geral'));
    expect(texto, isNot(contains('Bruno')));
    expect(linhas.last[6]!.value, isA<DoubleCellValue>());
  });

  test('Lista longa divide-se em imagens verticais de altura limitada',
      () async {
    final linhas = [
      for (var i = 0; i < 40; i++) linha('$i', 'Médico $i', 'MGF', 120)
    ];
    final dados = MatrizMedicosExportacaoDados(
            linhas: linhas,
            reais: [],
            descontos: [false, false, false],
            pesquisa: '',
            ordenacao: 0,
            periodoPercentagem: 2,
            referencia: DateTime(2026),
            semanaReferencia: DateTime(2026))
        .documento('Clínica');
    final imagens = await MatrizMedicosExportacaoDados.gerarImagens(dados);
    expect(imagens.length, greaterThan(1));
    expect(imagens.length, lessThan(7));
    final pdfSemProgresso = await RelatorioExportacaoService.gerarPdf(
        dados: dados, portrait: true, centrarCelulas: true);
    final progressos = <double>[];
    final pdfComProgresso = await RelatorioExportacaoService.gerarPdf(
        dados: dados,
        portrait: true,
        centrarCelulas: true,
        onProgresso: (valor, mensagem) async {
          progressos.add(valor);
        });
    int paginas(List<int> bytes) =>
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;
    expect(paginas(pdfComProgresso), paginas(pdfSemProgresso));
    expect(paginas(pdfComProgresso), greaterThan(1));
    expect(progressos.length, greaterThan(2));
    final destino = Platform.environment['MATRIZ_PAGINACAO_PREVIEW'];
    if (destino != null) {
      await File('$destino.png').writeAsBytes(imagens.first);
      await File('$destino.pdf').writeAsBytes(pdfComProgresso);
    }
    for (final png in imagens) {
      final codec = await ui.instantiateImageCodec(png);
      final imagem = (await codec.getNextFrame()).image;
      expect(imagem.width, 1600);
      expect(imagem.height, greaterThan(imagem.width));
      expect(imagem.height, lessThan(8192));
      imagem.dispose();
      codec.dispose();
    }
  });

  test('PDF e imagem são gerados com o mesmo documento filtrado', () async {
    final dados = selecao().documento('Clínica de exemplo');
    final pdf = await RelatorioExportacaoService.gerarPdf(
        dados: dados, portrait: true, centrarCelulas: true);
    final png = await RelatorioExportacaoService.gerarImagem(
        dados: dados, horizontal: true, centrarCelulas: true);
    expect(latin1.decode(pdf.take(4).toList()), '%PDF');
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
    if (destino != null) {
      await File('$destino/matriz_medicos.pdf').writeAsBytes(pdf);
      await File('$destino/matriz_medicos.png').writeAsBytes(png);
    }
  });
}
