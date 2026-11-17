import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/dados_relatorio_exportacao.dart';
import 'package:mapa_gabinetes/services/matriz_medicos_exportacao_service.dart';

void main() {
  test(
      'Excel progressivo preserva dados e estilos e cede a interface por blocos',
      () async {
    final dados = DadosRelatorioExportacao(
      titulo: 'Matriz',
      unidade: 'Clínica',
      inicio: DateTime(2026),
      fim: DateTime(2026, 12, 31),
      cabecalhos: [
        'Médico',
        'Especialidade',
        'Horário',
        'Semana',
        'Mês',
        'Ano',
        '%'
      ],
      linhas: [
        for (var i = 0; i < 120; i++)
          [
            'Médico $i',
            'MGF',
            '2.ª feira · 09:00 – 17:00',
            '8:00',
            '32:00',
            '400:00',
            0.01
          ]
      ],
      colunasCentradas: {3, 4, 5},
      colunasPercentagem: {6},
    );
    final valores = <double>[];
    final mensagens = <String>[];
    var turnosInterface = 0;
    final bytes = await MatrizMedicosExportacaoDados.gerarExcelProgressivo(
        dados, onProgresso: (valor, mensagem) async {
      valores.add(valor);
      mensagens.add(mensagem);
      await Future<void>.delayed(Duration.zero);
      turnosInterface++;
    });
    final atual = Excel.decodeBytes(bytes).tables['Matriz de Médicos']!;
    final anterior =
        Excel.decodeBytes(MatrizMedicosExportacaoDados.gerarExcel(dados))
            .tables['Matriz de Médicos']!;
    expect(
        atual.rows
            .map((r) => r.map((c) => c?.value.toString()).toList())
            .toList(),
        anterior.rows
            .map((r) => r.map((c) => c?.value.toString()).toList())
            .toList());
    expect(atual.rows.last[6]!.cellStyle!.numberFormat,
        anterior.rows.last[6]!.cellStyle!.numberFormat);
    expect(atual.rows[2][0]!.cellStyle!.isBold, isTrue);
    expect(valores.length, greaterThan(5));
    expect(turnosInterface, valores.length);
    expect(valores, orderedEquals([...valores]..sort()));
    expect(valores.last, lessThan(1));
    expect(mensagens.any((m) => m.contains('linhas')), isTrue);
  });
}
