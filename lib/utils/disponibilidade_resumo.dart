import '../models/matriz_distribuicao.dart';

/// Descreve apenas padrões confirmados pelas datas de disponibilidade.
String resumirDisponibilidade(Iterable<DateTime> ocorrencias,
    {bool incluirQuintaNoPadraoMensal = true,
    Set<DateTime> encerramentos = const {}}) {
  final periodos = dividirDisponibilidade(ocorrencias,
      incluirQuintaNoPadraoMensal: incluirQuintaNoPadraoMensal,
      encerramentos: encerramentos);
  return periodos.isEmpty
      ? 'Sem datas disponíveis'
      : periodos.map((p) => p.resumo).join('\n');
}

/// Cada resumo conserva as datas exatas do respetivo subcartão.
List<MatrizDisponibilidadePeriodo> dividirDisponibilidade(
    Iterable<DateTime> ocorrencias,
    {bool incluirQuintaNoPadraoMensal = true,
    Set<DateTime> encerramentos = const {}}) {
  final datas = ocorrencias
      .map((d) => DateTime.utc(d.year, d.month, d.day))
      .toSet()
      .toList()
    ..sort();
  if (datas.isEmpty) return [];
  const meses = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez'
  ];
  const dias = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo'
  ];
  String formatar(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  final regulares =
      analisarDisponibilidadeRegular(datas, encerramentos: encerramentos);
  final ordinaisPorMes = <int, Set<int>>{};
  for (final data in datas) {
    final ordinal = (data.day - 1) ~/ 7 + 1;
    final conjuntoMes = ordinaisPorMes.putIfAbsent(data.month, () => {});
    if (ordinal < 5) conjuntoMes.add(ordinal);
  }
  final base = ordinaisPorMes.values.first;
  final quintaDisponivel = datas.any((d) => d.day > 28) &&
      ordinaisPorMes.values
          .every((s) => s.length == base.length && s.containsAll(base));
  final padroes = <(int, int, String, int?)>[];
  for (var mes = 1; mes <= 12; mes++) {
    final presentes = datas.where((d) => d.month == mes).toList();
    if (presentes.isEmpty) continue;
    final possiveis = <DateTime>[];
    for (var d = DateTime.utc(datas.first.year, mes);
        d.month == mes;
        d = d.add(const Duration(days: 1))) {
      if (d.weekday == datas.first.weekday) possiveis.add(d);
    }
    final feminino = datas.first.weekday <= 5;
    final ordinais = presentes.map((d) => (d.day - 1) ~/ 7 + 1).toSet().toList()
      ..sort();
    // Meses com quatro ocorrências também podem integrar um padrão que
    // inclui a quinta ocorrência, quando esta existe nos restantes meses.
    if (incluirQuintaNoPadraoMensal &&
        quintaDisponivel &&
        possiveis.length == 4) {
      ordinais.add(5);
    }
    String padrao;
    if (regulares[mes]?.semanal == true) {
      padrao = 'Todas as semanas';
    } else if (regulares[mes]?.quinzena != null) {
      padrao = '15 em 15 dias';
    } else {
      padrao =
          '${ordinais.map((n) => '$n.${feminino ? 'ª' : 'º'}').join(', ')} ${dias[datas.first.weekday - 1]} do mês';
    }
    if (padroes.isNotEmpty &&
        padroes.last.$2 == mes - 1 &&
        padroes.last.$3 == padrao &&
        padroes.last.$4 == regulares[mes]?.quinzena) {
      final anterior = padroes.removeLast();
      padroes.add((anterior.$1, mes, padrao, regulares[mes]?.quinzena));
    } else {
      padroes.add((mes, mes, padrao, regulares[mes]?.quinzena));
    }
  }
  // Uma data isolada fica mais clara com o dia exato.
  if (datas.length == 1) {
    return [
      MatrizDisponibilidadePeriodo(
          descricao: 'Apenas ${formatar(datas.single)}',
          datas: Set.unmodifiable(datas))
    ];
  }
  final detalhados = padroes.map((p) {
    final (inicio, fim, padrao, _) = p;
    final periodo = inicio == fim
        ? meses[inicio - 1]
        : '${meses[inicio - 1]} a ${meses[fim - 1]}';
    return MatrizDisponibilidadePeriodo(
      descricao: inicio == 1 && fim == 12 ? padrao : '$periodo · $padrao',
      datas: Set.unmodifiable(
          datas.where((d) => d.month >= inicio && d.month <= fim)),
    );
  }).toList();
  return _agruparPadroesMensais(detalhados, encerramentos);
}

/// Só agrega segmentos mensais contíguos; nunca mistura semanas e quinzenas.
List<MatrizDisponibilidadePeriodo> _agruparPadroesMensais(
    List<MatrizDisponibilidadePeriodo> periodos, Set<DateTime> encerramentos) {
  final fechados =
      encerramentos.map((d) => DateTime.utc(d.year, d.month, d.day)).toSet();
  bool mensal(MatrizDisponibilidadePeriodo p) => p.descricao.endsWith('do mês');
  int primeiroMes(MatrizDisponibilidadePeriodo p) => p.datas.first.month;
  int ultimoMes(MatrizDisponibilidadePeriodo p) => p.datas.last.month;
  const meses = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez'
  ];
  const dias = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo'
  ];

  MatrizDisponibilidadePeriodo? juntar(
      List<MatrizDisponibilidadePeriodo> grupo) {
    final datas = grupo.expand((p) => p.datas).toSet().toList()..sort();
    final primeira = datas.first;
    final ultima = datas.last;
    if (ultima.month - primeira.month + 1 < 3) return null;
    final ordinais = datas.map((d) => (d.day - 1) ~/ 7 + 1).toSet().toList()
      ..sort();
    final presentes = datas.toSet();
    final excecoes = <DateTime>{};
    for (var d = DateTime.utc(primeira.year, primeira.month);
        d.isBefore(DateTime.utc(ultima.year, ultima.month + 1));
        d = d.add(const Duration(days: 1))) {
      if (d.weekday == primeira.weekday &&
          ordinais.contains((d.day - 1) ~/ 7 + 1) &&
          !presentes.contains(d) &&
          !fechados.contains(d)) {
        excecoes.add(d);
        if (excecoes.length > 3) return null;
      }
    }
    final padrao =
        '${ordinais.map((n) => '$n.${primeira.weekday <= 5 ? 'ª' : 'º'}').join(', ')} ${dias[primeira.weekday - 1]} do mês';
    final periodo = '${meses[primeira.month - 1]} a ${meses[ultima.month - 1]}';
    return MatrizDisponibilidadePeriodo(
      descricao: primeira.month == 1 && ultima.month == 12
          ? padrao
          : '$periodo · $padrao',
      datas: Set.unmodifiable(datas),
      excecoes: Set.unmodifiable(excecoes),
    );
  }

  final resultado = <MatrizDisponibilidadePeriodo>[];
  var inicio = 0;
  while (inicio < periodos.length) {
    var limite = inicio;
    while (limite + 1 < periodos.length &&
        mensal(periodos[limite]) &&
        mensal(periodos[limite + 1]) &&
        ultimoMes(periodos[limite]) + 1 == primeiroMes(periodos[limite + 1])) {
      limite++;
    }
    MatrizDisponibilidadePeriodo? agrupado;
    var fim = limite;
    for (; fim > inicio; fim--) {
      agrupado = juntar(periodos.sublist(inicio, fim + 1));
      if (agrupado != null) break;
    }
    resultado.add(agrupado ?? periodos[inicio]);
    inicio = agrupado == null ? inicio + 1 : fim + 1;
  }
  return resultado;
}

/// Verifica datas reais, mantendo a fase de 14 dias entre meses.
/// Um encerramento não transforma uma série semanal/quinzenal numa mensal.
Map<int, ({bool semanal, int? quinzena})> analisarDisponibilidadeRegular(
    Iterable<DateTime> ocorrencias,
    {Set<DateTime> encerramentos = const {}}) {
  DateTime dia(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final datas = ocorrencias.map(dia).toSet().toList()..sort();
  if (datas.isEmpty) return {};
  final presentes = datas.toSet();
  final fechados = encerramentos.map(dia).toSet();
  final referencia = DateTime.utc(datas.first.year);
  final resultado = <int, ({bool semanal, int? quinzena})>{};
  final candidatas = <int, int>{};
  for (final mes in datas.map((d) => d.month).toSet().toList()..sort()) {
    final esperadas = <DateTime>[];
    for (var d = DateTime.utc(datas.first.year, mes);
        d.month == mes;
        d = d.add(const Duration(days: 1))) {
      if (d.weekday == datas.first.weekday && !fechados.contains(d)) {
        esperadas.add(d);
      }
    }
    final reais = datas.where((d) => d.month == mes).toList();
    final semanal =
        esperadas.length == reais.length && esperadas.every(presentes.contains);
    resultado[mes] = (semanal: semanal, quinzena: null);
    if (semanal) continue;
    final fase = reais.first.difference(referencia).inDays % 14;
    final alternadas =
        esperadas.where((d) => d.difference(referencia).inDays % 14 == fase);
    if (reais.every((d) => d.difference(referencia).inDays % 14 == fase) &&
        alternadas.length == reais.length &&
        alternadas.every(presentes.contains)) {
      candidatas[mes] = fase;
    }
  }
  // Confirma o ciclo em meses vizinhos, evitando inferi-lo de uma data isolada.
  for (final entrada in candidatas.entries) {
    final mes = entrada.key;
    final fase = entrada.value;
    if (candidatas[mes - 1] == fase || candidatas[mes + 1] == fase) {
      resultado[mes] = (semanal: false, quinzena: fase);
    }
  }
  return resultado;
}
