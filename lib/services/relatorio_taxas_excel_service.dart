import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/gabinete.dart';
import '../models/taxa_ocupacao.dart';

class RelatorioTaxasExcelService {
  static Uint8List gerar({
    required String unidade,
    required DateTime inicio,
    required DateTime fim,
    required List<Gabinete> gabinetes,
    required Map<String, TaxaOcupacao> taxas,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Taxas de Ocupação');
    final folha = excel['Taxas de Ocupação'];
    final data = DateFormat('dd/MM/yyyy');
    folha.appendRow([TextCellValue('Taxas de Ocupação')]);
    folha.appendRow([TextCellValue('Unidade'), TextCellValue(unidade)]);
    folha.appendRow(
        [TextCellValue('Data inicial'), TextCellValue(data.format(inicio))]);
    folha.appendRow(
        [TextCellValue('Data final'), TextCellValue(data.format(fim))]);
    folha.appendRow([TextCellValue('')]);
    folha.appendRow([
      TextCellValue('Gabinete'),
      TextCellValue('Piso'),
      TextCellValue('Descrição'),
      TextCellValue('Horas ocupadas'),
      TextCellValue('Horas disponíveis'),
      TextCellValue('Taxa de ocupação'),
    ]);
    void adicionar(
        String nome, String piso, String descricao, TaxaOcupacao taxa) {
      folha.appendRow([
        TextCellValue(nome),
        TextCellValue(piso),
        TextCellValue(descricao),
        DoubleCellValue(taxa.horasOcupadas),
        DoubleCellValue(taxa.horasDisponiveis),
        DoubleCellValue(taxa.percentagem / 100),
      ]);
      final linha = folha.maxRows - 1;
      for (final coluna in [3, 4, 5]) {
        folha
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: coluna, rowIndex: linha))
                .cellStyle =
            CellStyle(
                numberFormat:
                    NumFormat.custom(formatCode: coluna == 5 ? '0.0%' : '0.0'));
      }
    }

    adicionar('Geral', '', '',
        taxas.values.fold(const TaxaOcupacao(), (a, b) => a.somar(b)));
    for (final gabinete in gabinetes.where((g) => taxas.containsKey(g.id))) {
      adicionar(gabinete.nome, gabinete.setor,
          gabinete.especialidadesPermitidas.join(', '), taxas[gabinete.id]!);
    }
    for (var coluna = 0; coluna < 6; coluna++) {
      folha.setColumnWidth(coluna, coluna == 2 ? 40 : 22);
      folha
              .cell(CellIndex.indexByColumnRow(columnIndex: coluna, rowIndex: 5))
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
