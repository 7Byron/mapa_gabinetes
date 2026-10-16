import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/mudanca_gabinete.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/matriz_distribuicao_service.dart';
import 'package:mapa_gabinetes/services/matriz_distribuicao_cache_service.dart';

void main() {
  final medicos = [
    for (final id in ['x', 'y', 'z'])
      Medico(
          id: id, nome: 'Dr. $id', especialidade: 'ORL', disponibilidades: [])
  ];
  SerieRecorrencia regra(
    String id,
    DateTime inicio, {
    String tipo = 'Semanal',
    DateTime? fim,
    String? gabinete = '101',
    List<MudancaGabinete>? mudancas,
    Map<String, dynamic>? parametros,
  }) =>
      SerieRecorrencia(
          id: id,
          medicoId: id,
          tipo: tipo,
          dataInicio: inicio,
          dataFim: fim,
          gabineteId: gabinete,
          horarios: ['09:00', '12:00'],
          mudancasGabinete: mudancas,
          parametros: parametros);

  test('Inclui passado e futuro e separa gabinetes pelas datas de mudança', () {
    final matriz = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos,
        referencia: DateTime(2026, 10, 10),
        series: [
          regra('x', DateTime(2025, 1, 6), mudancas: [
            MudancaGabinete(
                dataInicio: DateTime(2026, 10, 20), gabineteId: '102')
          ]),
          regra('y', DateTime(2026, 11, 1)),
          regra('z', DateTime(2025, 1, 6), fim: DateTime(2026, 3, 31)),
        ]);
    final x = matriz.itens.where((i) => i.medicoId == 'x').toList();
    expect(x.map((i) => i.gabineteId), ['101', '102']);
    expect(x.first.validadeInicio, DateTime.utc(2026));
    expect(x.first.validadeFim, DateTime.utc(2026, 10, 19));
    expect(x.last.validadeInicio, DateTime.utc(2026, 10, 20));
    expect(x.last.validadeFim, DateTime.utc(2026, 12, 31));
    expect(x.last.ocorrencias.first, DateTime.utc(2026, 10, 26));
    expect(matriz.itens.singleWhere((i) => i.medicoId == 'y').validadeInicio,
        DateTime.utc(2026, 11, 1));
    expect(matriz.itens.singleWhere((i) => i.medicoId == 'z').validadeFim,
        DateTime.utc(2026, 3, 31));
  });

  test('Sem conflitos entre períodos separados ou quinzenas alternadas', () {
    final matriz = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos,
        referencia: DateTime(2026),
        series: [
          regra('x', DateTime(2025, 12, 29), tipo: 'Quinzenal'),
          regra('y', DateTime(2026, 1, 5), tipo: 'Quinzenal'),
        ]);
    expect(matriz.itens.every((i) => !i.conflito), isTrue);
    expect(matriz.itens.first.ocorrencias.first, DateTime.utc(2026, 1, 12));
    final separados = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos,
        referencia: DateTime(2026),
        series: [
          regra('x', DateTime(2026, 1, 5), fim: DateTime(2026, 10, 19)),
          regra('y', DateTime(2026, 10, 26)),
        ]);
    expect(separados.itens.every((i) => !i.conflito), isTrue);
  });

  test('Conflitos reais entre lotes preservam datas e rotação mensal',
      () async {
    final series = [
      regra('x', DateTime(2026, 1, 5)),
      for (var i = 0; i < 20; i++) regra('inexistente$i', DateTime(2026)),
      regra('y', DateTime(2026, 2, 9), tipo: 'Mensal'),
    ];
    final matriz = await MatrizDistribuicaoService.gerarProgressivo(
        medicos: medicos,
        series: series,
        referencia: DateTime(2026),
        anual: true);
    expect(matriz.itens.every((i) => i.conflito), isTrue);
    final mensal = matriz.itens.singleWhere((i) => i.tipo == 'Mensal');
    expect(mensal.ciclo, 'Mensal · 2.ª semana');
    expect(mensal.ocorrencias.first, DateTime.utc(2026, 2, 9));
    expect(mensal.periodo, 'De 09/02/2026 a 31/12/2026');
    final sincrona = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos, series: series, referencia: DateTime(2026));
    expect(matriz.itens.map((i) => (i.serieId, i.periodo, i.conflito)),
        sincrona.itens.map((i) => (i.serieId, i.periodo, i.conflito)));
  });

  test('Última ocorrência mensal respeita os meses com quatro e cinco dias',
      () {
    final matriz = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos,
        referencia: DateTime(2026),
        series: [
          regra('x', DateTime(2026, 1, 26),
              tipo: 'Mensal', parametros: {'usarUltimoQuandoExiste5': true}),
        ]);
    expect(matriz.itens.single.ciclo, contains('última'));
    expect(matriz.itens.single.ocorrencias,
        containsAll([DateTime.utc(2026, 2, 23), DateTime.utc(2026, 3, 30)]));
    expect(matriz.itens.single.ocorrencias,
        isNot(contains(DateTime.utc(2026, 3, 23))));
  });

  test('Cache copia mudanças e aplica mudanças anteriores ao ano', () {
    final mudanca =
        MudancaGabinete(dataInicio: DateTime(2025, 12, 1), gabineteId: '102');
    final serie = regra('x', DateTime(2025, 1, 6), mudancas: [mudanca]);
    final dados = MatrizDistribuicaoDados(
        gabinetes: [], medicos: medicos, series: [serie]);
    mudanca.gabineteId = '999';
    serie.mudancasGabinete.clear();
    final matriz = dados.matrizPara(DateTime(2026, 10, 10));
    expect(matriz.itens.single.gabineteId, '102');
    expect(dados.matrizPara(DateTime(2026, 1, 1)), same(matriz));
  });

  test(
      'Exclui regras fora do ano e períodos sem ocorrências, informa falta de gabinete',
      () {
    final matriz = MatrizDistribuicaoService.gerarAnual(
        medicos: medicos,
        referencia: DateTime(2026),
        series: [
          regra('x', DateTime(2027, 1, 4)),
          regra('y', DateTime(2025, 1, 6), fim: DateTime(2025, 12, 31)),
          regra('z', DateTime(2026, 12, 28), gabinete: null),
        ]);
    expect(matriz.itens, isEmpty);
    expect(
        matriz.regrasSemGabinete.single, contains('28/12/2026 a 31/12/2026'));
  });
}
