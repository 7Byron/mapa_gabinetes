import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/services/relatorio_ocupacao_excel_service.dart';

void main() {
  List<List<Data?>> gerar(bool porHora) {
    final bytes = RelatorioOcupacaoExcelService.gerar(
      unidade: 'Clínica',
      gabinete: '101',
      descricao: 'ORL',
      inicio: DateTime(2026, 10, 5),
      fim: DateTime(2026, 10, 11),
      filtroDias: 'Todos os dias',
      porHora: porHora,
      linhas: [
        LinhaOcupacaoExcel(
            data: DateTime(2026, 10, 5),
            horasOcupadas: 3,
            horasDisponiveis: 12,
            inicio: '08:00',
            fim: '11:00',
            horasIntervalo: 3),
        LinhaOcupacaoExcel(
            data: DateTime(2026, 10, 11),
            horasOcupadas: 0,
            horasDisponiveis: 0,
            fechado: true,
            motivo: 'Domingos'),
      ],
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.length, 1);
    return excel.tables.values.single.rows;
  }

  test('Exporta ocupação diária com valores numéricos e encerramentos', () {
    final linhas = gerar(false);
    expect(linhas[2][1]!.value, TextCellValue('101'));
    expect(linhas[3][1]!.value, TextCellValue('05/10/2026'));
    expect(linhas[7][1]!.value, IntCellValue(3));
    expect(linhas[7][3]!.value, DoubleCellValue(0.25));
    expect(linhas[8][3]!.value, IntCellValue(0));
    expect(linhas[8][4]!.value, TextCellValue('Domingos'));
  });

  test('Exporta intervalos horários sem perder o resumo do dia', () {
    final linhas = gerar(true);
    expect(linhas[7][1]!.value, TextCellValue('08:00'));
    expect(linhas[7][2]!.value, TextCellValue('11:00'));
    expect(linhas[7][3]!.value, IntCellValue(3));
    expect(linhas[7][6]!.value, DoubleCellValue(0.25));
    expect(linhas[8][7]!.value, TextCellValue('Domingos'));
  });
}
