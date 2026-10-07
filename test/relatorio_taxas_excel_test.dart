import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/taxa_ocupacao.dart';
import 'package:mapa_gabinetes/services/relatorio_taxas_excel_service.dart';

void main() {
  test('Excel preserva período, seleção, horas e percentagem numérica', () {
    final bytes = RelatorioTaxasExcelService.gerar(
      unidade: 'Clínica',
      inicio: DateTime(2026, 10, 5),
      fim: DateTime(2026, 10, 11),
      gabinetes: [
        Gabinete(
            id: '101',
            setor: 'Piso 1',
            nome: '101',
            especialidadesPermitidas: ['ORL']),
        Gabinete(
            id: '102',
            setor: 'Piso 1',
            nome: '102',
            especialidadesPermitidas: ['Geral']),
        Gabinete(
            id: '103',
            setor: 'Piso 1',
            nome: '103',
            especialidadesPermitidas: ['Geral']),
      ],
      taxas: {
        '101': const TaxaOcupacao(horasOcupadas: 6, horasDisponiveis: 12),
        '102': const TaxaOcupacao(horasDisponiveis: 12),
      },
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, ['Taxas de Ocupação']);
    final linhas = excel['Taxas de Ocupação'].rows;
    expect(linhas[2][1]!.value, TextCellValue('05/10/2026'));
    expect(linhas[3][1]!.value, TextCellValue('11/10/2026'));
    expect(linhas.length, 9);
    expect(linhas[6][0]!.value, TextCellValue('Geral'));
    expect(linhas[6][3]!.value, IntCellValue(6));
    expect(linhas[6][4]!.value, IntCellValue(24));
    expect(linhas[6][5]!.value, DoubleCellValue(0.25));
    expect(linhas[7][2]!.value, TextCellValue('ORL'));
    expect(linhas[7][5]!.value, DoubleCellValue(0.5));
    expect(linhas[8][5]!.value, IntCellValue(0));
  });
}
