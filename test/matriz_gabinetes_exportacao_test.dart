import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/services/relatorio_exportacao_service.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/services/matriz_gabinetes_exportacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Montserrat')
          ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf')))
        .load();
  });
  test('Preserva palavras, datas e cartões completos ao dividir o gabinete',
      () async {
    final cartoes = [
      'Luís Filipe Gomes\nPsicologia\n09:00 – 13:00\nSemanal\nA partir de 02/01/2026',
      'Sofia Caldeira Santos\nPsicologia\n14:00 – 18:00\nQuinzenal\nA partir de 03/02/2026',
      'Valdemar Barbosa\nPsicologia\n17:00 – 19:30\nSemanal',
    ];
    final dados = DadosRelatorioExportacao(
      titulo: 'Matriz de Gabinetes · Ocupação',
      unidade: 'Semana tipo · 2026',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      cabecalhos: [
        'Piso / Gabinete',
        '2ª',
        '3ª',
        '4ª',
        '5ª',
        '6ª',
        'Sáb',
        'Dom'
      ],
      linhas: [
        ['Piso 1\n107', cartoes.join('\n\n'), '', '', '', '', '', '']
      ],
      proporcoes: [0.12, for (var i = 0; i < 7; i++) 0.88 / 7],
    );
    final paginado =
        MatrizGabinetesExportacaoService.paginarParaExportacao(dados);
    final textos = paginado.linhas.map((l) => l[1].toString()).toList();
    for (final cartao in cartoes) {
      expect(
          textos.any((t) =>
              t.replaceAll(RegExp(r'\s+'), ' ') ==
                  cartao.replaceAll(RegExp(r'\s+'), ' ') ||
              t
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .contains(cartao.replaceAll(RegExp(r'\s+'), ' '))),
          isTrue);
    }
    expect(textos.join(' '), contains('02/01/2026'));
    expect(textos.join(' '), contains('Gomes'));
    expect(textos.join(' '), contains('Santos'));
    final imagens = await MatrizGabinetesExportacaoService.gerarImagens(dados);
    final destino = Platform.environment['MATRIZ_PREVIEW'];
    if (destino != null) await File(destino).writeAsBytes(imagens.first);
  });
  test('Paginação aproveita altura e preserva todas as linhas na ordem', () {
    final linhas = [
      for (var i = 0; i < 24; i++)
        <Object>['Piso 1\n$i', '09:00–12:00', '', '', '', '', '', '']
    ];
    final dados = DadosRelatorioExportacao(
      titulo: 'Matriz',
      unidade: 'Clínica',
      inicio: DateTime(2027),
      fim: DateTime(2028),
      cabecalhos: ['Gabinete', '2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom'],
      linhas: linhas,
      colunasNegrito: {0},
      proporcoes: [0.12, for (var i = 0; i < 7; i++) 0.88 / 7],
    );
    final paginas =
        RelatorioExportacaoService.dividirLinhasImagemVertical(dados);
    expect(paginas.length, lessThan(6)); // Antes: quatro linhas por imagem.
    expect(paginas.first.length, greaterThan(4));
    expect(paginas.expand((p) => p).toList(), linhas);
  });
  test('Imagem extensa divide-se em PNG verticais com dimensões limitadas',
      () async {
    final dados = DadosRelatorioExportacao(
      titulo: 'Matriz',
      unidade: 'Clínica',
      inicio: DateTime(2027),
      fim: DateTime(2028),
      cabecalhos: ['Gabinete', '2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom'],
      linhas: [
        [
          '101',
          List.filled(100, 'Ana 09:00–18:00').join('\n'),
          '',
          '',
          '',
          '',
          '',
          ''
        ]
      ],
      proporcoes: [0.12, for (var i = 0; i < 7; i++) 0.88 / 7],
    );
    final progressos = <double>[];
    final imagens = await MatrizGabinetesExportacaoService.gerarImagens(dados,
        onProgresso: (valor, mensagem) async {
      progressos.add(valor);
    });
    expect(progressos.length, greaterThan(1));
    expect(progressos.last, greaterThan(progressos.first));
    expect(imagens.length, greaterThan(1));
    for (final bytes in imagens) {
      final codec = await ui.instantiateImageCodec(bytes);
      final imagem = (await codec.getNextFrame()).image;
      expect(imagem.width, 1600);
      expect(imagem.height, greaterThan(imagem.width));
      expect(imagem.height, lessThan(8192));
      imagem.dispose();
      codec.dispose();
    }
  });
  test('PDF pagina gabinete com célula maior do que uma página', () async {
    final dados = DadosRelatorioExportacao(
      titulo: 'Matriz',
      unidade: 'Teste',
      inicio: DateTime(2027),
      fim: DateTime(2028),
      cabecalhos: ['Gabinete', '2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom'],
      linhas: [
        [
          '101',
          List.filled(180, 'Ana — 09:00–18:00').join('\n'),
          '',
          '',
          '',
          '',
          '',
          ''
        ]
      ],
      proporcoes: [0.12, for (var i = 0; i < 7; i++) 0.88 / 7],
    );
    await expectLater(
        RelatorioExportacaoService.gerarPdf(dados: dados), throwsA(anything));
    final progressos = <double>[];
    final bytes = await MatrizGabinetesExportacaoService.gerarPdf(dados,
        onProgresso: (valor, mensagem) async {
      progressos.add(valor);
    });
    expect(progressos.length, greaterThan(2));
    expect(progressos.last, greaterThan(progressos.first));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final caixa = RegExp(r'/MediaBox\s*\[0\s+0\s+([\d.]+)\s+([\d.]+)\]')
        .firstMatch(latin1.decode(bytes));
    expect(caixa, isNotNull);
    expect(double.parse(caixa!.group(2)!),
        greaterThan(double.parse(caixa.group(1)!)));
  });

  test('Exporta apenas gabinetes selecionados e coloca horários no dia correto',
      () {
    final dados = MatrizGabinetesExportacaoService.documento(
      gabinetes: [
        Gabinete(
            id: 'a', setor: 'Piso 1', nome: '101', especialidadesPermitidas: [])
      ],
      itens: [
        for (final id in ['a', 'oculto'])
          MatrizDistribuicaoItem(
            serieId: id,
            medicoId: 'm',
            medicoNome: 'Ana',
            especialidade: 'MGF',
            gabineteId: id,
            tipo: 'semanal',
            ciclo: 'Semanal',
            dia: 2,
            inicioMinutos: 540,
            fimMinutos: 720,
          )
      ],
      ano: 2027,
      livres: false,
      pesquisa: 'Ana',
    );
    expect(dados.linhas, hasLength(1));
    expect(dados.linhas.single[1], isEmpty);
    expect(dados.linhas.single[2], contains('Ana\nMGF\n09:00 – 12:00'));
    final excel =
        Excel.decodeBytes(MatrizGabinetesExportacaoService.gerarExcel(dados));
    final folha = excel.tables['Matriz de Gabinetes']!;
    expect(folha.rows.last[0]!.cellStyle!.isBold, isTrue);
    expect(folha.rows[folha.maxRows - 2][2]!.cellStyle!.isBold, isTrue);
    expect(excel.tables['Matriz de Gabinetes']!.rows.last[2]!.value.toString(),
        contains('Ana'));
  });
}
