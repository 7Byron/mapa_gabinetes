import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_excel_service.dart';

void main() {
  test(
      'Excel conserva as especialidades do relatório, datas e totais numéricos',
      () {
    final relatorio = RelatorioHorasEspecialidade(
      inicio: DateTime(2026, 10, 5),
      fim: DateTime(2026, 10, 11),
      linhas: const [
        RelatorioHorasEspecialidadeLinha(
            especialidade: 'ORL',
            medicosAtivos: 2,
            medicosComDisponibilidade: 2,
            horasConsulta: 7.5),
        RelatorioHorasEspecialidadeLinha(
            especialidade: 'Psicologia',
            medicosAtivos: 1,
            medicosComDisponibilidade: 1,
            horasConsulta: 3),
      ],
    );
    final bytes = RelatorioHorasExcelService.gerar(
        unidade: 'Clínica', relatorio: relatorio);
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, ['Horas de Especialidade']);
    final linhas = excel.tables.values.single.rows;
    expect(linhas[2][1]!.value, TextCellValue('05/10/2026'));
    expect(linhas[3][1]!.value, TextCellValue('11/10/2026'));
    expect(linhas[6][0]!.value, TextCellValue('ORL'));
    expect(linhas[6][3]!.value, DoubleCellValue(7.5));
    expect(linhas[6][4]!.value, DoubleCellValue(3.75));
    expect(linhas[8][0]!.value, TextCellValue('Total'));
    expect(linhas[8][1]!.value, IntCellValue(3));
    expect(linhas[8][3]!.value, DoubleCellValue(10.5));
  });

  test('Exporta relatório vazio com total zero', () {
    final bytes = RelatorioHorasExcelService.gerar(
        unidade: 'Clínica',
        relatorio: RelatorioHorasEspecialidade(
            inicio: DateTime(2026), fim: DateTime(2026), linhas: const []));
    final linhas = Excel.decodeBytes(bytes).tables.values.single.rows;
    expect(linhas[6][0]!.value, TextCellValue('Total'));
    expect(linhas[6][3]!.value, IntCellValue(0));
  });
}
