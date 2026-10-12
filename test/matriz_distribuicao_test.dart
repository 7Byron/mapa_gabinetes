import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/mudanca_gabinete.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/matriz_distribuicao_service.dart';

void main() {
  Medico medico(String id, {bool ativo = true}) => Medico(
      id: id,
      nome: 'Médico $id',
      especialidade: 'ORL',
      disponibilidades: [],
      ativo: ativo);
  SerieRecorrencia serie(
          String id, String medicoId, String tipo, DateTime inicio,
          {String? gabinete = '101', Map<String, dynamic>? parametros}) =>
      SerieRecorrencia(
          id: id,
          medicoId: medicoId,
          tipo: tipo,
          dataInicio: inicio,
          horarios: ['08:00', '12:00'],
          gabineteId: gabinete,
          parametros: parametros);

  test('Semanal ocupa cinco semanas no gabinete base, ignorando realocações',
      () {
    final regra = serie('s', 'a', 'Semanal', DateTime(2026, 1, 5));
    regra.mudancasGabinete.add(
        MudancaGabinete(dataInicio: DateTime(2026, 1, 12), gabineteId: '202'));
    final matriz = MatrizDistribuicaoService.gerar(
        medicos: [medico('a')],
        series: [regra],
        referencia: DateTime(2026, 2, 2));
    expect(matriz.itens.map((i) => i.dia), [1, 8, 15, 22, 29]);
    expect(matriz.itens.every((i) => i.gabineteId == '101'), isTrue);
  });

  test('Quinzenas de médicos alternados ficam em semanas diferentes', () {
    final regras = [
      serie('a', 'a', 'Quinzenal', DateTime(2026, 1, 5)),
      serie('b', 'b', 'Quinzenal', DateTime(2026, 1, 12))
    ];
    final matriz = MatrizDistribuicaoService.gerar(
        medicos: [medico('a'), medico('b')],
        series: regras,
        referencia: DateTime(2026, 2, 2));
    expect(matriz.itens.where((i) => i.medicoId == 'a').map((i) => i.dia),
        [1, 15, 29]);
    expect(matriz.itens.where((i) => i.medicoId == 'b').map((i) => i.dia),
        [8, 22]);
    expect(matriz.itens.any((i) => i.conflito), isFalse);
    expect(matriz.itens.first.ciclo, contains('semanas 1, 3, 5'));
    final alternada = MatrizDistribuicaoService.gerar(
        medicos: [medico('a'), medico('b')],
        series: regras,
        referencia: DateTime(2026, 2, 2),
        alternarQuinzena: true);
    expect(alternada.itens.where((i) => i.medicoId == 'a').map((i) => i.dia),
        [8, 22]);
  });

  test('Rotação de 14 dias distingue-se das semanas mensais fixas', () {
    final regras = [
      serie('q', 'a', 'Quinzenal', DateTime(2026, 1, 5)),
      serie('m1', 'b', 'Mensal', DateTime(2026, 1, 5)),
      serie('m3', 'b', 'Mensal', DateTime(2026, 1, 19)),
    ];
    final matriz = MatrizDistribuicaoService.gerar(
      medicos: [medico('a'), medico('b')],
      series: regras,
      referencia: DateTime(2026, 2, 2),
    );
    expect(matriz.itens.where((i) => i.conflito).map((i) => i.dia),
        unorderedEquals([1, 1, 15, 15]));
    expect(matriz.itens.firstWhere((i) => i.tipo == 'Quinzenal').ciclo,
        '14 dias · semanas 1, 3, 5');
    final outraReferencia = MatrizDistribuicaoService.gerar(
      medicos: [medico('a'), medico('b')],
      series: regras,
      referencia: DateTime(2026, 2, 9),
    );
    expect(outraReferencia.itens.any((i) => i.conflito), isFalse);
    expect(
        outraReferencia.itens
            .where((i) => i.tipo == 'Mensal')
            .map((i) => i.dia),
        [1, 15]);
  });

  test('Mensais na primeira e segunda ocorrências mantêm ambas as semanas', () {
    final matriz = MatrizDistribuicaoService.gerar(medicos: [
      medico('a')
    ], series: [
      serie('1', 'a', 'Mensal', DateTime(2026, 1, 6)),
      serie('2', 'a', 'Mensal', DateTime(2026, 1, 13))
    ], referencia: DateTime(2026, 2, 2));
    expect(matriz.itens.map((i) => i.dia), [2, 9]);
    expect(matriz.itens.map((i) => i.ciclo),
        ['Mensal · 1.ª semana', 'Mensal · 2.ª semana']);
  });

  test('Última ocorrência e quinta ocorrência respeitam as 4 ou 5 semanas', () {
    final regra = serie('m', 'a', 'Mensal', DateTime(2026, 1, 27),
        parametros: {'usarUltimoQuandoExiste5': true});
    for (final semanas in [4, 5]) {
      final matriz = MatrizDistribuicaoService.gerar(
          medicos: [medico('a')],
          series: [regra],
          referencia: DateTime(2026, 2, 2),
          semanas: semanas);
      expect(matriz.itens.single.dia, (semanas - 1) * 7 + 2);
    }
    final quinta = serie('q', 'a', 'Mensal', DateTime(2026, 3, 31));
    expect(
        MatrizDistribuicaoService.gerar(
                medicos: [medico('a')],
                series: [quinta],
                referencia: DateTime(2026, 4, 1),
                semanas: 4)
            .itens,
        isEmpty);
    quinta.parametros['usarUltimoQuandoNaoExiste5'] = true;
    expect(
        MatrizDistribuicaoService.gerar(
                medicos: [medico('a')],
                series: [quinta],
                referencia: DateTime(2026, 4, 1),
                semanas: 4)
            .itens
            .single
            .dia,
        23);
  });

  test('Séries terminadas, futuras, inativas e médicos inativos não entram',
      () {
    final terminada = serie('t', 'a', 'Semanal', DateTime(2025))
      ..dataFim = DateTime(2026, 1, 31);
    final inativa = serie('i', 'a', 'Semanal', DateTime(2025))..ativo = false;
    final matriz = MatrizDistribuicaoService.gerar(medicos: [
      medico('a'),
      medico('b', ativo: false)
    ], series: [
      terminada,
      inativa,
      serie('f', 'a', 'Semanal', DateTime(2027)),
      serie('b', 'b', 'Semanal', DateTime(2025))
    ], referencia: DateTime(2026, 2, 2));
    expect(matriz.itens, isEmpty);
  });

  test('Horários separados não se sobrepõem; conflitos reais são destacados',
      () {
    final a = serie('a', 'a', 'Semanal', DateTime(2026, 1, 5))
      ..horarios = ['08:00', '10:00', '14:00', '16:00'];
    final b = serie('b', 'b', 'Semanal', DateTime(2026, 1, 5))
      ..horarios = ['10:00', '12:00'];
    var matriz = MatrizDistribuicaoService.gerar(
        medicos: [medico('a'), medico('b')],
        series: [a, b],
        referencia: DateTime(2026, 2, 2));
    expect(matriz.itens.any((i) => i.conflito), isFalse);
    b.horarios = ['09:00', '11:00'];
    matriz = MatrizDistribuicaoService.gerar(
        medicos: [medico('a'), medico('b')],
        series: [a, b],
        referencia: DateTime(2026, 2, 2));
    expect(matriz.itens.where((i) => i.conflito).length, 10);
    expect(
        matriz.itens
            .where((i) => i.inicioMinutos == 840)
            .any((i) => i.conflito),
        isFalse);
  });

  test('Sem gabinete é sinalizado; únicas e consecutivas são excluídas', () {
    final matriz = MatrizDistribuicaoService.gerar(medicos: [
      medico('a')
    ], series: [
      serie('s', 'a', 'Semanal', DateTime(2025), gabinete: null),
      serie('u', 'a', 'Única', DateTime(2025)),
      serie('c', 'a', 'Consecutivo', DateTime(2025))
    ], referencia: DateTime(2026, 2, 2));
    expect(matriz.itens, isEmpty);
    expect(matriz.regrasSemGabinete, ['Médico a · Semanal']);
  });

  test('Paridade quinzenal não depende de hora ou mudança de horário', () {
    final matriz = MatrizDistribuicaoService.gerar(
        medicos: [medico('a')],
        series: [serie('a', 'a', 'Quinzenal', DateTime(2026, 3, 16, 14))],
        referencia: DateTime(2026, 3, 30, 19));
    expect(matriz.itens.map((i) => i.dia), [1, 15, 29]);
  });
  test('Geração em lotes mantém conflitos entre lotes e liberta a interface',
      () async {
    final medicos = [for (var i = 0; i < 41; i++) medico('$i')];
    final regras = [
      for (var i = 0; i < 41; i++)
        serie('$i', '$i', 'Semanal', DateTime(2026, 1, 5),
            gabinete: i == 0 || i == 20 ? '101' : 'g$i'),
    ];
    final progresso = <double>[];
    final futuro = MatrizDistribuicaoService.gerarProgressivo(
      medicos: medicos,
      series: regras,
      referencia: DateTime(2026, 2, 2),
      onProgresso: progresso.add,
    );
    final passosAntes = progresso.length;
    await Future<void>.delayed(Duration.zero);
    expect(progresso.length, greaterThan(passosAntes));
    final resultado = await futuro;
    final sincrono = MatrizDistribuicaoService.gerar(
      medicos: medicos,
      series: regras,
      referencia: DateTime(2026, 2, 2),
    );
    expect(resultado.itens.length, sincrono.itens.length);
    expect(resultado.itens.where((i) => i.conflito).length, 10);
    expect(
        resultado.itens.map((i) => (i.serieId, i.dia, i.horario, i.conflito)),
        unorderedEquals(sincrono.itens
            .map((i) => (i.serieId, i.dia, i.horario, i.conflito))));
    expect(progresso.last, 1);
    for (var i = 1; i < progresso.length; i++) {
      expect(progresso[i], greaterThanOrEqualTo(progresso[i - 1]));
    }
  });

  test('Geração progressiva sem séries conclui sem divisão por zero', () async {
    final progresso = <double>[];
    final matriz = await MatrizDistribuicaoService.gerarProgressivo(
      medicos: [],
      series: [],
      referencia: DateTime(2026, 2, 2),
      onProgresso: progresso.add,
    );
    expect(matriz.itens, isEmpty);
    expect(progresso, [1]);
  });
}
