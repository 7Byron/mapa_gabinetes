import 'dart:typed_data';
import 'excel_progresso_service.dart';
import 'relatorio_exportacao_service.dart';
import 'package:excel/excel.dart';
import '../models/dados_relatorio_exportacao.dart';
import '../models/gabinete.dart';
import '../models/matriz_distribuicao.dart';

class MatrizGabinetesExportacaoService {
  static DadosRelatorioExportacao documento({
    required List<Gabinete> gabinetes,
    required List<MatrizDistribuicaoItem> itens,
    required int ano,
    required bool livres,
    required String pesquisa,
  }) {
    String cartao(MatrizDistribuicaoItem i) => [
          if (!livres) i.medicoNome,
          if (!livres) i.especialidade,
          i.horario,
          if (!livres) i.ciclo,
          if (i.periodo != null) i.periodo!,
          if (i.conflito) 'Sobreposição',
          ...i.disponibilidades.map((d) => d.resumo),
        ].join('\n');
    return DadosRelatorioExportacao(
      titulo: 'Matriz de Gabinetes · ${livres ? 'Livres' : 'Ocupação'}',
      unidade: 'Semana tipo · $ano',
      inicio: DateTime(ano),
      fim: DateTime(ano, 12, 31),
      detalhes: [
        'Gabinetes selecionados: ${gabinetes.length}',
        if (pesquisa.isNotEmpty) 'Pesquisa destacada no ecrã: $pesquisa',
      ],
      cabecalhos: [
        'Piso / Gabinete',
        '2.ª feira',
        '3.ª feira',
        '4.ª feira',
        '5.ª feira',
        '6.ª feira',
        'Sábado',
        'Domingo'
      ],
      linhas: [
        for (final g in gabinetes)
          [
            '${g.setor}\n${g.nome}',
            for (var dia = 1; dia <= 7; dia++)
              (itens
                      .where((i) =>
                          i.gabineteId == g.id && (i.dia - 1) % 7 + 1 == dia)
                      .toList()
                    ..sort(
                        (a, b) => a.inicioMinutos.compareTo(b.inicioMinutos)))
                  .map(cartao)
                  .join('\n\n'),
          ]
      ],
      colunasCentradas: {0, 1, 2, 3, 4, 5, 6, 7},
      colunasNegrito: {0},
      proporcoes: [0.12, for (var i = 0; i < 7; i++) 0.88 / 7],
    );
  }

  /// As tabelas PDF só paginam entre linhas. Divide células longas em
  /// segmentos pequenos e repete o gabinete para manter o contexto.
  static DadosRelatorioExportacao paginarParaExportacao(
      DadosRelatorioExportacao dados) {
    // Quebra apenas entre palavras; cartões diferentes são separados por uma
    // linha vazia e passam inteiros para o segmento seguinte quando necessário.
    List<String> palavras(String texto) {
      final resultado = <String>[];
      for (final paragrafo in texto.split('\n')) {
        var atual = '';
        for (final palavra
            in paragrafo.split(RegExp(r'\s+')).where((p) => p.isNotEmpty)) {
          if (atual.isNotEmpty && atual.length + palavra.length + 1 > 16) {
            resultado.add(atual);
            atual = palavra;
          } else {
            atual = atual.isEmpty ? palavra : '$atual $palavra';
          }
        }
        resultado.add(atual);
      }
      return resultado;
    }

    List<String> segmentos(String texto) {
      final resultado = <String>[];
      var atual = <String>[];
      for (final bloco in texto.split('\n\n')) {
        final linhas = palavras(bloco);
        if (atual.isNotEmpty && atual.length + linhas.length + 1 > 12) {
          resultado.add(atual.join('\n'));
          atual = [];
        }
        if (linhas.length > 12) {
          for (var i = 0; i < linhas.length; i += 12) {
            resultado.add(linhas.skip(i).take(12).join('\n'));
          }
        } else {
          if (atual.isNotEmpty) atual.add('');
          atual.addAll(linhas);
        }
      }
      if (atual.isNotEmpty) resultado.add(atual.join('\n'));
      return resultado;
    }

    final linhas = <List<Object>>[];
    for (final linha in dados.linhasFormatadas) {
      final celulas = linha.skip(1).map(segmentos).toList();
      final maximo =
          celulas.fold<int>(1, (m, c) => c.length > m ? c.length : m);
      for (var i = 0; i < maximo; i++) {
        linhas.add(
            [linha.first, for (final c in celulas) i < c.length ? c[i] : '']);
      }
    }
    return DadosRelatorioExportacao(
      titulo: dados.titulo,
      unidade: dados.unidade,
      inicio: dados.inicio,
      fim: dados.fim,
      detalhes: dados.detalhes,
      cabecalhos: dados.cabecalhos,
      linhas: linhas,
      proporcoes: dados.proporcoes,
      colunasCentradas: {0, 1, 2, 3, 4, 5, 6, 7},
      colunasNegrito: {0},
      grelhaImagem: true,
      tamanhoFonteImagem: 18,
    );
  }

  static Future<Uint8List> gerarPdf(DadosRelatorioExportacao dados,
          {ProgressoExportacao? onProgresso}) =>
      RelatorioExportacaoService.gerarPdf(
          dados: paginarParaExportacao(dados),
          onProgresso: onProgresso,
          portrait: true,
          centrarCelulas: true);

  /// Evita uma única textura com dezenas de milhares de píxeis de altura.
  /// Preenche a altura disponível e repete o cabeçalho em cada imagem.
  static Future<List<Uint8List>> gerarImagens(DadosRelatorioExportacao dados,
      {ProgressoExportacao? onProgresso}) async {
    final paginado = paginarParaExportacao(dados);
    final paginas =
        RelatorioExportacaoService.dividirLinhasImagemVertical(paginado);
    final imagens = <Uint8List>[];
    for (var indice = 0; indice < paginas.length; indice++) {
      final parte = indice + 1;
      final total = paginas.length;
      await onProgresso?.call(0.08 + 0.82 * imagens.length / total,
          'A gerar imagem ${imagens.length + 1} de $total…');
      imagens.add(await RelatorioExportacaoService.gerarImagem(
        dados: DadosRelatorioExportacao(
          titulo: '${dados.titulo} · Parte $parte de $total',
          unidade: dados.unidade,
          inicio: dados.inicio,
          fim: dados.fim,
          detalhes: dados.detalhes,
          cabecalhos: dados.cabecalhos,
          linhas: paginas[indice],
          proporcoes: dados.proporcoes,
          colunasCentradas: {0, 1, 2, 3, 4, 5, 6, 7},
          colunasNegrito: {0},
          grelhaImagem: true,
          tamanhoFonteImagem: 18,
        ),
        centrarCelulas: true,
        dividirEmPaineis: false,
        paginaVertical: true,
      ));
    }
    return imagens;
  }

  static Future<void> guardarImagens(
      DadosRelatorioExportacao dados, String nome,
      {ProgressoExportacao? onProgresso}) async {
    final imagens = await gerarImagens(dados, onProgresso: onProgresso);
    await onProgresso?.call(0.92, 'A preparar o download…');
    await RelatorioExportacaoService.guardarImagens(imagens, nome,
        onProgresso: onProgresso);
  }

  static Uint8List gerarExcel(DadosRelatorioExportacao dados) =>
      Uint8List.fromList(_prepararExcel(dados).last.encode()!);

  static Future<Uint8List> gerarExcelProgressivo(DadosRelatorioExportacao dados,
          {ProgressoExportacao? onProgresso}) =>
      ExcelProgressoService.gerar(_prepararExcel(dados),
          totalLinhas: dados.linhas.length, onProgresso: onProgresso);

  static Iterable<Excel> _prepararExcel(DadosRelatorioExportacao dados) sync* {
    final excel = Excel.createExcel()..rename('Sheet1', 'Matriz de Gabinetes');
    final folha = excel['Matriz de Gabinetes'];
    for (final texto in [dados.titulo, dados.unidade, ...dados.detalhes]) {
      folha.appendRow([TextCellValue(texto)]);
    }
    folha.appendRow(dados.cabecalhos.map(TextCellValue.new).toList());
    final indiceCabecalho = folha.maxRows - 1;
    for (var c = 0; c < dados.cabecalhos.length; c++) {
      folha
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: c, rowIndex: indiceCabecalho))
              .cellStyle =
          CellStyle(bold: true, verticalAlign: VerticalAlign.Center);
    }
    for (final linha in dados.linhas) {
      folha.appendRow(linha.map((v) => TextCellValue('$v')).toList());
      final altura = linha.fold<int>(1, (maior, valor) {
        final linhas = '$valor'.split('\n').fold<int>(
            0,
            (total, texto) =>
                total + (texto.length / 32).ceil().clamp(1, 10000));
        return linhas > maior ? linhas : maior;
      });
      folha.setRowHeight(folha.maxRows - 1, altura * 16.0 + 12);
      for (var c = 0; c < linha.length; c++) {
        folha
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: c, rowIndex: folha.maxRows - 1))
                .cellStyle =
            CellStyle(
                textWrapping: TextWrapping.WrapText,
                verticalAlign: VerticalAlign.Center,
                bold: c == 0);
      }
      yield excel;
    }
    for (var c = 0; c < 8; c++) {
      folha.setColumnWidth(c, c == 0 ? 22 : 35);
    }
    yield excel;
  }
}
