import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/dados_relatorio_exportacao.dart';
import '../utils/text_search_utils.dart';
import 'matriz_medicos_service.dart';

/// Mesma seleção e ordenação para o ecrã e os três formatos de exportação.
class MatrizMedicosExportacaoDados {
  final List<MatrizMedicoLinha> linhas, reais;
  final List<bool> descontos;
  final String pesquisa;
  final int ordenacao, periodoPercentagem;
  final DateTime referencia, semanaReferencia;

  MatrizMedicosExportacaoDados(
      {required this.linhas,
      required this.reais,
      required List<bool> descontos,
      required this.pesquisa,
      required this.ordenacao,
      required this.periodoPercentagem,
      required this.referencia,
      required this.semanaReferencia})
      : descontos = List.unmodifiable(descontos);

  int minutos(MatrizMedicoLinha linha, int periodo) {
    final real =
        reais.where((r) => r.medico.id == linha.medico.id).firstOrNull ?? linha;
    final valor = descontos[periodo] ? real : linha;
    return [valor.semana, valor.mes, valor.ano][periodo];
  }

  List<MatrizMedicoLinha> get visiveis => linhas
      .where((l) => TextSearchUtils.matchesAllTerms(
          pesquisa, [l.medico.nome, l.medico.especialidade]))
      .toList()
    ..sort((a, b) {
      if (ordenacao >= 2) {
        final comparacao = minutos(b, 2).compareTo(minutos(a, 2));
        if (comparacao != 0) return comparacao;
      }
      if (ordenacao == 1) {
        final comparacao = a.medico.especialidade
            .toLowerCase()
            .compareTo(b.medico.especialidade.toLowerCase());
        if (comparacao != 0) return comparacao;
      }
      return a.medico.nome.toLowerCase().compareTo(b.medico.nome.toLowerCase());
    });

  double percentagem(MatrizMedicoLinha linha) {
    final total =
        linhas.fold<int>(0, (soma, l) => soma + minutos(l, periodoPercentagem));
    return total == 0 ? 0 : minutos(linha, periodoPercentagem) / total;
  }

  DadosRelatorioExportacao documento(String unidade) {
    final segunda =
        semanaReferencia.subtract(Duration(days: semanaReferencia.weekday - 1));
    final data = DateFormat('dd/MM/yyyy');
    const periodos = ['Semana', 'Mês', 'Ano'];
    String modo(int i) =>
        descontos[i] ? 'Real (com descontos)' : 'Previsto (sem descontos)';
    return DadosRelatorioExportacao(
      titulo: 'Matriz de Médicos',
      unidade: unidade,
      inicio: DateTime(referencia.year),
      fim: DateTime(referencia.year, 12, 31),
      detalhes: [
        'Pesquisa por nome ou especialidade: ${pesquisa.isEmpty ? 'Todos' : pesquisa}',
        'Ordenação: ${const [
          'Nome do médico',
          'Especialidade',
          'Horas (total anual, decrescente)'
        ][ordenacao]}',
        'Semana: ${data.format(segunda)} a ${data.format(segunda.add(const Duration(days: 6)))} | Mês: ${referencia.month}/${referencia.year}',
        for (var i = 0; i < 3; i++) '${periodos[i]}: ${modo(i)}',
        '% Clínica: ${periodos[periodoPercentagem]} · ${modo(periodoPercentagem)}. Base: todos os médicos da clínica.',
      ],
      cabecalhos: [
        'Médico',
        'Especialidade',
        'Horário habitual',
        'Total\nSemana',
        'Total\nMês',
        'Total\nAno',
        '% Clínica'
      ],
      linhas: [
        for (final l in visiveis)
          [
            l.medico.nome,
            l.medico.especialidade,
            l.horarios.isEmpty
                ? 'Sem horário recorrente'
                : l.horarios.join('\n'),
            for (var i = 0; i < 3; i++)
              MatrizMedicosService.horas(minutos(l, i)),
            percentagem(l),
          ]
      ],
      colunasPercentagem: {6},
      proporcoes: [0.17, 0.14, 0.30, 0.095, 0.095, 0.095, 0.105],
    );
  }

  static Uint8List gerarExcel(DadosRelatorioExportacao dados) {
    final excel = Excel.createExcel()..rename('Sheet1', 'Matriz de Médicos');
    final folha = excel['Matriz de Médicos'];
    folha.appendRow([TextCellValue(dados.titulo)]);
    folha.appendRow([TextCellValue(dados.unidade)]);
    for (final detalhe in dados.detalhes) {
      folha.appendRow([TextCellValue(detalhe)]);
    }
    final cabecalho = folha.maxRows;
    folha.appendRow(dados.cabecalhos.map(TextCellValue.new).toList());
    for (final linha in dados.linhas) {
      folha.appendRow(linha
          .map((v) => v is double ? DoubleCellValue(v) : TextCellValue('$v'))
          .toList());
      final indiceLinha = folha.maxRows - 1;
      folha
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 2, rowIndex: indiceLinha))
              .cellStyle =
          CellStyle(
              textWrapping: TextWrapping.WrapText,
              verticalAlign: VerticalAlign.Center);
      final linhasHorario = '${linha[2]}'.split('\n').fold<int>(0,
          (total, texto) => total + (texto.length / 60).ceil().clamp(1, 1000));
      folha.setRowHeight(indiceLinha, linhasHorario * 16.0 + 6);
      folha
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: 6, rowIndex: folha.maxRows - 1))
              .cellStyle =
          CellStyle(numberFormat: NumFormat.custom(formatCode: '0.0%'));
      for (var coluna = 0; coluna < dados.cabecalhos.length; coluna++) {
        final celula = folha.cell(CellIndex.indexByColumnRow(
            columnIndex: coluna, rowIndex: indiceLinha));
        celula.cellStyle = (celula.cellStyle ?? CellStyle())
            .copyWith(verticalAlignVal: VerticalAlign.Center);
      }
    }
    for (var c = 0; c < dados.cabecalhos.length; c++) {
      folha.setColumnWidth(
          c,
          c == 2
              ? 65
              : c < 2
                  ? 30
                  : 18);
      folha
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: cabecalho))
              .cellStyle =
          CellStyle(
              bold: true,
              verticalAlign: VerticalAlign.Center,
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'));
    }
    return Uint8List.fromList(excel.encode()!);
  }
}
