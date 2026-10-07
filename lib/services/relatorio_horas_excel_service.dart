import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/relatorio_horas_especialidade.dart';

class RelatorioHorasExcelService {
  static Uint8List gerar({
    required String unidade,
    required RelatorioHorasEspecialidade relatorio,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Horas de Especialidade');
    final folha = excel['Horas de Especialidade'];
    final data = DateFormat('dd/MM/yyyy');
    folha.appendRow([TextCellValue('Horas de Especialidade')]);
    folha.appendRow([TextCellValue('Unidade'), TextCellValue(unidade)]);
    folha.appendRow([
      TextCellValue('Data inicial'),
      TextCellValue(data.format(relatorio.inicio))
    ]);
    folha.appendRow([
      TextCellValue('Data final'),
      TextCellValue(data.format(relatorio.fim))
    ]);
    folha.appendRow([
      TextCellValue('Especialidades com disponibilidade'),
      IntCellValue(relatorio.totalEspecialidades)
    ]);
    folha.appendRow([
      TextCellValue('Especialidade'),
      TextCellValue('Médicos ativos'),
      TextCellValue('Médicos com disponibilidade'),
      TextCellValue('Horas de consulta'),
      TextCellValue('Média de horas por médico com disponibilidade'),
    ]);
    for (final linha in relatorio.linhas) {
      folha.appendRow([
        TextCellValue(linha.especialidade),
        IntCellValue(linha.medicosAtivos),
        IntCellValue(linha.medicosComDisponibilidade),
        DoubleCellValue(linha.horasConsulta),
        DoubleCellValue(linha.mediaHorasPorMedico),
      ]);
    }
    folha.appendRow([
      TextCellValue('Total'),
      IntCellValue(relatorio.totalMedicosAtivos),
      IntCellValue(relatorio.totalMedicosComDisponibilidade),
      DoubleCellValue(relatorio.totalHorasConsulta),
    ]);
    for (var linha = 6; linha < folha.maxRows; linha++) {
      for (final coluna in [3, 4]) {
        folha
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: coluna, rowIndex: linha))
                .cellStyle =
            CellStyle(numberFormat: NumFormat.custom(formatCode: '0.00'));
      }
    }
    for (var coluna = 0; coluna < 5; coluna++) {
      folha.setColumnWidth(coluna, coluna == 0 ? 36 : 30);
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
