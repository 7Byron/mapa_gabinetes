import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/utils/disponibilidade_resumo.dart';

void main() {
  List<DateTime> tercas({int inicio = 1, int fim = 12}) => [
        for (var d = DateTime.utc(2026, inicio);
            d.isBefore(DateTime.utc(2026, fim + 1));
            d = d.add(const Duration(days: 1)))
          if (d.weekday == DateTime.tuesday) d,
      ];

  test('Resume semanas de janeiro a março e o ano completo', () {
    expect(resumirDisponibilidade(tercas(inicio: 1, fim: 3)),
        'Jan a Mar · Todas as semanas');
    expect(resumirDisponibilidade(tercas()), 'Todas as semanas');
  });

  test('Reconhece alternância quinzenal entre meses', () {
    final datas = tercas()
        .where((d) => d.difference(DateTime.utc(2026, 1, 6)).inDays % 14 == 0);
    expect(resumirDisponibilidade(datas), '15 em 15 dias');
  });

  test('Mostra as ocorrências livres e considera meses com quinta terça', () {
    final datas = tercas().where((d) => (d.day - 1) ~/ 7 + 1 != 3);
    expect(
        resumirDisponibilidade(datas), '1.ª, 2.ª, 4.ª, 5.ª terça-feira do mês');
  });

  test('Mantém separados períodos que mudam ou têm meses sem disponibilidade',
      () {
    final datas = [...tercas(fim: 3), ...tercas(inicio: 7, fim: 9)];
    expect(resumirDisponibilidade(datas),
        'Jan a Mar · Todas as semanas\nJul a Set · Todas as semanas');
  });

  test('Uma exceção não é apresentada como disponibilidade semanal', () {
    final datas = tercas(fim: 3)..remove(DateTime.utc(2026, 2, 17));
    expect(resumirDisponibilidade(datas),
        'Jan · Todas as semanas\nFev · 1.ª, 2.ª, 4.ª terça-feira do mês\nMar · Todas as semanas');
  });

  test(
      'Reconhece quinzenas apenas numa parte do ano, sem as dividir por ordinais',
      () {
    final ancora = DateTime.utc(2026, 6, 12);
    final datas = <DateTime>[];
    for (var d = DateTime.utc(2026, 1, 2);
        d.year == 2026;
        d = d.add(const Duration(days: 7))) {
      if (d.month < 6 || d.difference(ancora).inDays % 14 == 0) datas.add(d);
    }
    final fechados = {
      DateTime.utc(2026, 4, 3),
      DateTime.utc(2026, 5, 1),
      DateTime.utc(2026, 12, 25)
    };
    datas.removeWhere(fechados.contains);
    expect(resumirDisponibilidade(datas, encerramentos: fechados),
        'Jan a Mai · Todas as semanas\nJun a Dez · 15 em 15 dias');
  });

  test('Uma primeira terça-feira fixa continua a ser mensal', () {
    final datas = tercas().where((d) => d.day <= 7);
    expect(resumirDisponibilidade(datas), '1.ª terça-feira do mês');
  });

  test('Não une fases quinzenais opostas em meses consecutivos', () {
    final datas = tercas().where((d) =>
        d.difference(DateTime.utc(2026, 1, 6)).inDays % 14 ==
        (d.month <= 6 ? 0 : 7));
    expect(resumirDisponibilidade(datas),
        'Jan a Jun · 15 em 15 dias\nJul a Dez · 15 em 15 dias');
  });

  test('Subperíodos conservam apenas as suas próprias datas', () {
    final datas = tercas()
      ..removeWhere((d) => d.month == 1 && (d.day - 1) ~/ 7 + 1 != 4);
    final periodos = dividirDisponibilidade(datas);
    expect(periodos.map((p) => p.descricao), [
      'Jan · 4.ª terça-feira do mês',
      'Fev a Dez · Todas as semanas',
    ]);
    expect(periodos.first.datas, {DateTime.utc(2026, 1, 27)});
    expect(periodos.last.datas.every((d) => d.month >= 2), isTrue);
    expect(periodos.first.datas.intersection(periodos.last.datas), isEmpty);
    expect(periodos.expand((p) => p.datas).toSet(), datas.toSet());
  });

  test('Agrupa o padrão do gabinete 104 e mantém as três exceções visíveis',
      () {
    final fechados = {DateTime.utc(2026, 4, 3), DateTime.utc(2026, 5, 1)};
    final excecoes = {
      DateTime.utc(2026, 10, 23),
      DateTime.utc(2026, 11, 6),
      DateTime.utc(2026, 11, 20)
    };
    final datas = <DateTime>{
      for (var d = DateTime.utc(2026);
          d.month <= 11;
          d = d.add(const Duration(days: 1)))
        if (d.weekday == 5 &&
            [1, 3, 4].contains((d.day - 1) ~/ 7 + 1) &&
            !fechados.contains(d) &&
            !excecoes.contains(d))
          d,
    };
    final periodos = dividirDisponibilidade(datas,
        encerramentos: fechados, incluirQuintaNoPadraoMensal: false);
    expect(periodos, hasLength(1));
    expect(periodos.single.descricao,
        'Jan a Nov · 1.ª, 3.ª, 4.ª sexta-feira do mês');
    expect(periodos.single.excecoes, excecoes);
    expect(periodos.single.observacao, 'Exceto: 23/10, 06/11, 20/11');
    expect(periodos.single.datas, datas);
    expect(periodos.single.datas.length, 28);
    expect(periodos.single.datas.intersection(excecoes), isEmpty);
    expect(periodos.single.datas.intersection(fechados), isEmpty);
    expect(
        resumirDisponibilidade(datas,
            encerramentos: fechados, incluirQuintaNoPadraoMensal: false),
        contains('Exceto: 23/10, 06/11, 20/11'));
  });

  test('Muitas exceções mantêm períodos separados sem acrescentar datas livres',
      () {
    final datas = tercas()
        .where((d) => d.month <= 6
            ? [1, 3, 4].contains((d.day - 1) ~/ 7 + 1)
            : (d.day - 1) ~/ 7 + 1 == 4)
        .toSet();
    final periodos =
        dividirDisponibilidade(datas, incluirQuintaNoPadraoMensal: false);
    expect(periodos.length, greaterThan(1));
    expect(periodos.every((p) => p.excecoes.length <= 3), isTrue);
    expect(periodos.expand((p) => p.datas).toSet(), datas);
  });

  test(
      'Agrupa diferenças causadas por encerramentos sem as apresentar como ocupação',
      () {
    final fechado = DateTime.utc(2026, 4, 7);
    final datas = tercas()
        .where((d) => [1, 3, 4].contains((d.day - 1) ~/ 7 + 1) && d != fechado)
        .toSet();
    final periodos = dividirDisponibilidade(datas,
        encerramentos: {fechado}, incluirQuintaNoPadraoMensal: false);
    expect(periodos, hasLength(1));
    expect(periodos.single.excecoes, isEmpty);
    expect(periodos.single.datas, datas);
  });

  test('Data isolada indica o dia exato', () {
    expect(resumirDisponibilidade([DateTime.utc(2026, 3, 10)]), 'Apenas 10/03');
  });
}
