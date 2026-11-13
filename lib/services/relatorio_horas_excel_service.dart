import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/relatorio_horas_especialidade.dart';
import 'relatorio_horas_exportacao_service.dart';

class RelatorioHorasExcelService {
  static Uint8List gerar({
    required String unidade,
    required RelatorioHorasEspecialidade relatorio,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Horas Médico-Especialidade');
    final folha = excel['Horas Médico-Especialidade'];
    final dados = RelatorioHorasExportacaoDados(relatorio);
    final data = DateFormat('dd/MM/yyyy');
    folha.appendRow([TextCellValue(RelatorioHorasExportacaoDados.titulo)]);
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
      TextCellValue('Especialidades'),
      IntCellValue(relatorio.totalEspecialidades)
    ]);
    folha.appendRow(dados.cabecalhos.map(TextCellValue.new).toList());
    for (final linha in dados.linhas) {
      folha.appendRow(linha
          .map((valor) => switch (valor) {
                int n => IntCellValue(n),
                double n => DoubleCellValue(n),
                _ => TextCellValue('$valor'),
              })
          .toList());
    }
    for (var linha = 6; linha < folha.maxRows; linha++) {
      for (final coluna in relatorio.porMedico ? [2] : [3, 4]) {
        folha
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: coluna, rowIndex: linha))
                .cellStyle =
            CellStyle(numberFormat: NumFormat.custom(formatCode: '0.00'));
      }
    }
    for (var coluna = 0; coluna < dados.cabecalhos.length; coluna++) {
      folha.setColumnWidth(coluna, coluna == 0 ? 36 : 30);
      folha
              .cell(CellIndex.indexByColumnRow(columnIndex: coluna, rowIndex: 5))
              .cellStyle =
          CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'));
    }
    folha.appendRow([TextCellValue('Consulta'), TextCellValue(dados.consulta)]);
    folha.appendRow([TextCellValue('Seleção'), TextCellValue(dados.filtros)]);
    if (relatorio.porMedico) {
      folha.appendRow([
        TextCellValue('Total de horas da clínica'),
        DoubleCellValue(relatorio.totalHorasConsultaClinica)
      ]);
      folha.appendRow([
        TextCellValue('Médicos ativos da clínica'),
        IntCellValue(relatorio.totalMedicosAtivosClinica)
      ]);
      folha.appendRow([
        TextCellValue('Média por médico ativo (incluindo zero horas)'),
        DoubleCellValue(relatorio.mediaHorasPorMedicoClinica)
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Não foi possível criar o Excel.');
    return Uint8List.fromList(bytes);
  }
}
