import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class LinhaOcupacaoExcel {
  final DateTime data;
  final double horasOcupadas;
  final double horasDisponiveis;
  final bool fechado;
  final String? motivo;
  final String? inicio;
  final String? fim;
  final double? horasIntervalo;

  const LinhaOcupacaoExcel({
    required this.data,
    required this.horasOcupadas,
    required this.horasDisponiveis,
    this.fechado = false,
    this.motivo,
    this.inicio,
    this.fim,
    this.horasIntervalo,
  });
}

class RelatorioOcupacaoExcelService {
  static Uint8List gerar({
    required String unidade,
    required String gabinete,
    required String descricao,
    required DateTime inicio,
    required DateTime fim,
    required String filtroDias,
    required bool porHora,
    required List<LinhaOcupacaoExcel> linhas,
  }) {
    final excel = Excel.createExcel();
    final nome = porHora ? 'Ocupação dia e hora' : 'Ocupação por dia';
    excel.rename('Sheet1', nome);
    final folha = excel[nome];
    final data = DateFormat('dd/MM/yyyy');
    folha.appendRow([TextCellValue(nome)]);
    folha.appendRow([TextCellValue('Unidade'), TextCellValue(unidade)]);
    folha.appendRow([
      TextCellValue('Gabinete'),
      TextCellValue(gabinete),
      TextCellValue(descricao)
    ]);
    folha.appendRow(
        [TextCellValue('Data inicial'), TextCellValue(data.format(inicio))]);
    folha.appendRow(
        [TextCellValue('Data final'), TextCellValue(data.format(fim))]);
    folha.appendRow(
        [TextCellValue('Dias da semana'), TextCellValue(filtroDias)]);
    final cabecalho = [
      'Data',
      if (porHora) ...['Início ocupado', 'Fim ocupado', 'Horas do intervalo'],
      'Horas ocupadas no dia',
      'Horas disponíveis no dia',
      'Taxa de ocupação do dia',
      'Estado',
    ];
    folha.appendRow(cabecalho.map(TextCellValue.new).toList());
    for (final linha in linhas) {
      folha.appendRow([
        TextCellValue(data.format(linha.data)),
        if (porHora) ...[
          TextCellValue(linha.inicio ?? ''),
          TextCellValue(linha.fim ?? ''),
          DoubleCellValue(linha.horasIntervalo ?? 0),
        ],
        DoubleCellValue(linha.horasOcupadas),
        DoubleCellValue(linha.horasDisponiveis),
        DoubleCellValue(linha.horasDisponiveis > 0
            ? linha.horasOcupadas / linha.horasDisponiveis
            : 0),
        TextCellValue(linha.fechado ? (linha.motivo ?? 'Encerrado') : 'Aberto'),
      ]);
      final indice = folha.maxRows - 1;
      final colunaPercentagem = porHora ? 6 : 3;
      for (var coluna = porHora ? 3 : 1;
          coluna <= colunaPercentagem;
          coluna++) {
        folha
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: coluna, rowIndex: indice))
                .cellStyle =
            CellStyle(
                numberFormat: NumFormat.custom(
                    formatCode: coluna == colunaPercentagem ? '0.0%' : '0.0'));
      }
    }
    for (var coluna = 0; coluna < cabecalho.length; coluna++) {
      folha.setColumnWidth(coluna, coluna < (porHora ? 3 : 1) ? 20 : 28);
      folha
              .cell(CellIndex.indexByColumnRow(columnIndex: coluna, rowIndex: 6))
              .cellStyle =
          CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'));
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Não foi possível criar o Excel.');
    return Uint8List.fromList(bytes);
  }
}
