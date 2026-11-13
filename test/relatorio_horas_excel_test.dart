import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_excel_service.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_exportacao_service.dart';

void main() {
  test('Excel distingue as horas selecionadas do total e média da clínica', () {
    final relatorio = RelatorioHorasEspecialidade(
      inicio: DateTime(2026),
      fim: DateTime(2026),
      linhas: const [],
      totalHorasConsultaClinica: 200,
      totalMedicosAtivosClinica: 10,
      medicos: const [
        RelatorioHorasMedicoLinha(
            medicoId: 'ana',
            nome: 'Ana',
            especialidade: 'MGF',
            horasConsulta: 20)
      ],
    );
    final excel = Excel.decodeBytes(RelatorioHorasExcelService.gerar(
        unidade: 'Clínica', relatorio: relatorio));
    final linhas = excel.tables.values.single.rows;
    expect(linhas[7][2]!.value, IntCellValue(20));
    expect(linhas[10][0]!.value, TextCellValue('Total de horas da clínica'));
    expect(linhas[10][1]!.value, IntCellValue(200));
    expect(linhas[11][1]!.value, IntCellValue(10));
    expect(linhas[12][1]!.value, IntCellValue(20));
  });
  test('Exporta todos os médicos, incluindo zero horas, com total conjunto',
      () {
    final relatorio = RelatorioHorasEspecialidade(
      inicio: DateTime(2026, 11, 1),
      fim: DateTime(2026, 11, 30),
      linhas: const [],
      medicos: const [
        RelatorioHorasMedicoLinha(
            medicoId: 'ana',
            nome: 'Ana',
            especialidade: 'ORL',
            horasConsulta: 7.5),
        RelatorioHorasMedicoLinha(
            medicoId: 'rui',
            nome: 'Rui',
            especialidade: 'ORL',
            horasConsulta: 3),
        RelatorioHorasMedicoLinha(
            medicoId: 'rita',
            nome: 'Rita',
            especialidade: 'Cardiologia',
            horasConsulta: 0),
      ],
    );
    expect(relatorio.totalMedicosAtivos, 3);
    expect(relatorio.totalMedicosComDisponibilidade, 2);
    expect(relatorio.totalEspecialidades, 2);
    expect(relatorio.totalHorasConsulta, 10.5);

    // Excel, PDF e imagem partilham os mesmos dados e filtros.
    final dados = RelatorioHorasExportacaoDados(relatorio);
    expect(dados.linhas, [
      ['Ana', 'ORL', 7.5],
      ['Rui', 'ORL', 3.0],
      ['Rita', 'Cardiologia', 0.0],
      ['Total', '', 10.5],
    ]);
    expect(dados.filtros, 'Ana · ORL, Rui · ORL, Rita · Cardiologia');
    expect(dados.documento('Clínica').linhas, dados.linhas);
    final bytes = RelatorioHorasExcelService.gerar(
        unidade: 'Clínica', relatorio: relatorio);
    final linhas = Excel.decodeBytes(bytes).tables.values.single.rows;
    expect(linhas[4][1]!.value, IntCellValue(2));
    expect(linhas[6][0]!.value, TextCellValue('Ana'));
    expect(linhas[7][0]!.value, TextCellValue('Rui'));
    expect(linhas[8][0]!.value, TextCellValue('Rita'));
    expect(linhas[8][2]!.value, IntCellValue(0));
    expect(linhas[9][0]!.value, TextCellValue('Total'));
    expect(linhas[9][2]!.value, DoubleCellValue(10.5));
    expect(linhas[11][1]!.value, TextCellValue(dados.filtros));
  });

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
    expect(excel.tables.keys, ['Horas Médico-Especialidade']);
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
  for (final horas in [0.0, 7.5]) {
    test('Excel por médico mantém identificação e total de $horas horas', () {
      final relatorio = RelatorioHorasEspecialidade(
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2026, 11, 30),
        linhas: const [],
        medicos: [
          RelatorioHorasMedicoLinha(
            medicoId: 'ana',
            nome: 'Ana João',
            especialidade: 'Cardiologia',
            horasConsulta: horas,
          )
        ],
      );
      final bytes = RelatorioHorasExcelService.gerar(
          unidade: 'Clínica', relatorio: relatorio);
      final linhas = Excel.decodeBytes(bytes).tables.values.single.rows;
      expect(linhas[0][0]!.value, TextCellValue('Horas Médico/Especialidade'));
      expect(linhas[5].take(3).map((c) => c!.value), [
        TextCellValue('Médico'),
        TextCellValue('Especialidade'),
        TextCellValue('Horas de consulta'),
      ]);
      expect(linhas[6][0]!.value, TextCellValue('Ana João'));
      expect(linhas[6][1]!.value, TextCellValue('Cardiologia'));
      expect(linhas[6][2]!.value,
          horas == 0 ? IntCellValue(0) : DoubleCellValue(horas));
      expect(linhas[7][0]!.value, TextCellValue('Total'));
      expect(linhas[7][2]!.value,
          horas == 0 ? IntCellValue(0) : DoubleCellValue(horas));
      expect(linhas[8][1]!.value, TextCellValue('Por médico'));
      expect(linhas[9][1]!.value, TextCellValue('Ana João · Cardiologia'));
      expect(relatorio.totalMedicosAtivos, 1);
      expect(relatorio.totalMedicosComDisponibilidade, horas > 0 ? 1 : 0);
    });
  }
}
