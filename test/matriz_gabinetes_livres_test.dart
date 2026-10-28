import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/services/alocacao_clinica_config_service.dart';
import 'package:mapa_gabinetes/services/matriz_gabinetes_livres_service.dart';

void main() {
  final gabinete =
      Gabinete(id: '1', setor: '', nome: '1', especialidadesPermitidas: []);
  final segunda = DateTime.utc(2026, 1, 5);
  final segundasTrimestre = <DateTime>{
    for (var d = segunda; d.month <= 3; d = d.add(const Duration(days: 7))) d,
  };
  MatrizDistribuicaoItem ocupado(int inicio, int fim, {Set<DateTime>? datas}) =>
      MatrizDistribuicaoItem(
          serieId: '$inicio',
          medicoId: 'm',
          medicoNome: 'M',
          especialidade: '',
          gabineteId: '1',
          tipo: 'Quinzenal',
          ciclo: '',
          dia: 1,
          inicioMinutos: inicio,
          fimMinutos: fim,
          ocorrencias: datas ?? segundasTrimestre);
  MatrizDistribuicao gerar(
    List<MatrizDistribuicaoItem> itens, {
    Set<DateTime> encerramentos = const {},
    bool nuncaEncerra = false,
    Map<int, bool> encerraDias = const {},
  }) =>
      MatrizGabinetesLivresService.gerar(
          gabinetes: [gabinete],
          ano: 2026,
          ocupacao: MatrizDistribuicao(itens: itens, regrasSemGabinete: []),
          config: ClinicaConfiguracoes(
              horariosClinica: {
                1: ['08:00', '18:00']
              },
              nuncaEncerra: nuncaEncerra,
              encerraFeriados: false,
              encerraDias: encerraDias),
          encerramentos: encerramentos);

  test('Une sobreposições e limita intervalos ao horário de funcionamento', () {
    final matriz = gerar([
      ocupado(420, 600),
      ocupado(570, 660),
      ocupado(780, 810),
      ocupado(1020, 1200)
    ]);
    final nessaData =
        matriz.itens.where((i) => i.ocorrencias.contains(segunda));
    expect(
        nessaData.map((i) => (i.inicioMinutos, i.fimMinutos)), [(810, 1020)]);
  });

  test('Ignora intervalos até 2 horas e mantém intervalos de 121 minutos', () {
    final matriz = gerar([
      ocupado(540, 600), // Livre 08:00–09:00: 60 minutos.
      ocupado(720, 780), // Livre 10:00–12:00: 120 minutos.
      ocupado(901, 1080), // Livre 13:00–15:01: 121 minutos.
    ]);
    final nessaData =
        matriz.itens.where((i) => i.ocorrencias.contains(segunda));
    expect(nessaData.map((i) => (i.inicioMinutos, i.fimMinutos)), [(780, 901)]);
  });

  test('Mantém livres as semanas sem ocorrência quinzenal', () {
    final matriz = gerar([
      ocupado(480, 1080, datas: {segunda})
    ]);
    expect(matriz.itens.any((i) => i.ocorrencias.contains(segunda)), isFalse);
    expect(matriz.itens.single.ocorrencias,
        contains(segunda.add(const Duration(days: 7))));
    expect(matriz.itens.single.horario, '08:00 – 18:00');
  });

  test('Exclui encerramentos, dias fechados e dias sem horário', () {
    expect(gerar([], encerraDias: {1: true}).itens, isEmpty);
    final matriz = gerar([], encerramentos: {DateTime(2026, 1, 5)});
    expect(matriz.itens.single.ocorrencias, isNot(contains(segunda)));
    expect(matriz.itens.single.dia, 1);
  });

  Set<DateTime> fecharForaDosMeses(Set<int> meses) => {
        for (var d = DateTime.utc(2026);
            d.year == 2026;
            d = d.add(const Duration(days: 1)))
          if (!meses.contains(d.month)) d,
      };

  test('Ignora um ou dois meses e mantém três meses consecutivos', () {
    for (final meses in [
      {1},
      {1, 2}
    ]) {
      expect(
          gerar([], encerramentos: fecharForaDosMeses(meses)).itens, isEmpty);
    }
    final matriz = gerar([], encerramentos: fecharForaDosMeses({1, 2, 3}));
    expect(matriz.itens.single.ciclo, 'Jan a Mar · Todas as semanas');
    expect(
        matriz.itens.single.ocorrencias.map((d) => d.month).toSet(), {1, 2, 3});
  });

  test(
      'Não soma meses de períodos separados e remove o período curto do cartão',
      () {
    expect(gerar([], encerramentos: fecharForaDosMeses({1, 2, 7, 8})).itens,
        isEmpty);
    final matriz =
        gerar([], encerramentos: fecharForaDosMeses({1, 2, 3, 11, 12}));
    expect(matriz.itens.single.ciclo, 'Jan a Mar · Todas as semanas');
    expect(matriz.itens.single.ocorrencias.every((d) => d.month <= 3), isTrue);
  });

  final segundasAno = <DateTime>{
    for (var d = segunda; d.year == 2026; d = d.add(const Duration(days: 7))) d,
  };

  test('Remove quintas ocorrências dos padrões mensais esporádicos', () {
    final ocupadas =
        segundasAno.where((d) => (d.day - 1) ~/ 7 + 1 == 3).toSet();
    final matriz = gerar([ocupado(480, 1080, datas: ocupadas)]);
    expect(matriz.itens.single.ciclo, '1.ª, 2.ª, 4.ª segunda-feira do mês');
    expect(matriz.itens.single.ocorrencias.every((d) => d.day <= 28), isTrue);
  });

  test('Preserva quintas ocorrências em disponibilidade semanal e quinzenal',
      () {
    expect(gerar([]).itens.single.ocorrencias.any((d) => d.day > 28), isTrue);
    final ocupadas = segundasAno
        .where((d) => d.difference(segunda).inDays % 14 == 0)
        .toSet();
    final matriz = gerar([ocupado(480, 1080, datas: ocupadas)]);
    expect(matriz.itens.single.ciclo, '15 em 15 dias');
    expect(matriz.itens.single.ocorrencias.any((d) => d.day > 28), isTrue);
  });

  test(
      'Cenário 101: sexta quinzenal desde junho e encerramentos não quebram o ciclo',
      () {
    final sextasOcupadas = <DateTime>{
      for (var d = DateTime.utc(2026, 6, 5);
          d.year == 2026;
          d = d.add(const Duration(days: 14)))
        d,
    };
    final matriz = MatrizGabinetesLivresService.gerar(
      gabinetes: [gabinete],
      ano: 2026,
      config: const ClinicaConfiguracoes(
          horariosClinica: {
            5: ['08:00', '20:00']
          },
          nuncaEncerra: false,
          encerraFeriados: true,
          encerraDias: {}),
      encerramentos: {
        DateTime.utc(2026, 4, 3),
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 12, 25)
      },
      ocupacao: MatrizDistribuicao(itens: [
        MatrizDistribuicaoItem(
            serieId: 'quinzenal',
            medicoId: 'm',
            medicoNome: 'M',
            especialidade: '',
            gabineteId: '1',
            tipo: 'Quinzenal',
            ciclo: 'Quinzenal',
            dia: 5,
            inicioMinutos: 540,
            fimMinutos: 750,
            ocorrencias: sextasOcupadas)
      ], regrasSemGabinete: []),
    );
    final diaInteiro = matriz.itens.singleWhere((i) => i.inicioMinutos == 480);
    expect(diaInteiro.ciclo,
        'Jan a Mai · Todas as semanas\nJun a Dez · 15 em 15 dias');
    expect(diaInteiro.ocorrencias, contains(DateTime.utc(2026, 10, 30)));
    expect(diaInteiro.ocorrencias, isNot(contains(DateTime.utc(2026, 12, 25))));
    final tarde = matriz.itens.singleWhere((i) => i.inicioMinutos == 750);
    expect(tarde.ciclo, 'Jun a Dez · 15 em 15 dias');
    expect(tarde.ocorrencias, contains(DateTime.utc(2026, 7, 31)));
    expect(diaInteiro.ocorrencias.intersection(tarde.ocorrencias), isEmpty);
  });

  test(
      'Gabinete 104: padrão geral exclui ocupações e preserva os horários parciais',
      () {
    final mensal = <DateTime>{
      for (var d = DateTime.utc(2026);
          d.year == 2026;
          d = d.add(const Duration(days: 1)))
        if (d.weekday == 5 && (d.day - 1) ~/ 7 + 1 == 2) d,
    };
    final quinzenal = <DateTime>{
      for (var d = DateTime.utc(2026, 10, 9);
          d.year == 2026;
          d = d.add(const Duration(days: 14)))
        d,
    };
    MatrizDistribuicaoItem regra(
            String tipo, int inicio, int fim, Set<DateTime> datas) =>
        MatrizDistribuicaoItem(
            serieId: tipo,
            medicoId: 'm',
            medicoNome: 'M',
            especialidade: '',
            gabineteId: '1',
            tipo: tipo,
            ciclo: tipo,
            dia: 5,
            inicioMinutos: inicio,
            fimMinutos: fim,
            ocorrencias: datas);
    final matriz = MatrizGabinetesLivresService.gerar(
      gabinetes: [gabinete],
      ano: 2026,
      ocupacao: MatrizDistribuicao(itens: [
        regra('Mensal', 540, 705, mensal),
        regra('Quinzenal', 840, 1080, quinzenal)
      ], regrasSemGabinete: []),
      config: const ClinicaConfiguracoes(
          horariosClinica: {
            5: ['08:00', '20:00']
          },
          nuncaEncerra: false,
          encerraFeriados: true,
          encerraDias: {}),
      encerramentos: {
        DateTime.utc(2026, 4, 3),
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 12, 25)
      },
    );
    final diaCompleto = matriz.itens
        .singleWhere((i) => i.inicioMinutos == 480 && i.fimMinutos == 1200);
    expect(diaCompleto.disponibilidades, hasLength(1));
    expect(diaCompleto.disponibilidades.single.descricao,
        'Jan a Nov · 1.ª, 3.ª, 4.ª sexta-feira do mês');
    expect(diaCompleto.disponibilidades.single.observacao,
        'Exceto: 23/10, 06/11, 20/11');
    expect(diaCompleto.ocorrencias, hasLength(28));
    final manha = matriz.itens
        .singleWhere((i) => i.inicioMinutos == 480 && i.fimMinutos == 840);
    final excecoes = diaCompleto.disponibilidades.single.excecoes;
    expect(manha.ocorrencias.containsAll(excecoes), isTrue);
    expect(diaCompleto.ocorrencias.intersection(excecoes), isEmpty);
  });

  test('Nunca encerra disponibiliza 24 horas nos sete dias', () {
    final matriz = gerar([], nuncaEncerra: true);
    expect(matriz.itens.length, 7);
    expect(
        matriz.itens.every((i) => i.inicioMinutos == 0 && i.fimMinutos == 1440),
        isTrue);
  });
}
