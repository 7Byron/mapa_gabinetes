part of '../alocacao_medicos_logic.dart';

List<Medico> _filtrarMedicosPorData({
  required DateTime dataSelecionada,
  required List<Disponibilidade> disponibilidades,
  required List<Alocacao> alocacoes,
  required List<Medico> medicos,
}) {
  final dataAlvo = DateTime(
      dataSelecionada.year, dataSelecionada.month, dataSelecionada.day);

  final dispNoDia = disponibilidades.where((disp) {
    final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
    return d == dataAlvo;
  }).toList();

  final idsMedicosNoDia = dispNoDia.map((d) => d.medicoId).toSet();
  final alocadosNoDia = alocacoes
      .where((a) {
        final aData = DateTime(a.data.year, a.data.month, a.data.day);
        return aData == dataAlvo;
      })
      .map((a) => a.medicoId)
      .toSet();

  return medicos
      .where((m) =>
          idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
      .toList();
}

List<Gabinete> _filtrarGabinetesPorUI({
  required List<Gabinete> gabinetes,
  required List<Alocacao> alocacoes,
  required DateTime selectedDate,
  required List<String> pisosSelecionados,
  required String filtroOcupacao,
  required bool mostrarConflitos,
  String? filtroEspecialidadeGabinete,
}) {
  // Filtro por piso
  final filtradosPiso =
      gabinetes.where((g) => pisosSelecionados.contains(g.setor)).toList();

  // Filtro por especialidade do gabinete
  final filtrados = filtroEspecialidadeGabinete != null &&
          filtroEspecialidadeGabinete.isNotEmpty
      ? filtradosPiso
          .where((g) => g.especialidadesPermitidas
              .contains(filtroEspecialidadeGabinete))
          .toList()
      : filtradosPiso;

  List<Gabinete> filtradosOcupacao = [];
  for (final gab in filtrados) {
    final alocacoesDoGab = alocacoes.where((a) {
      return a.gabineteId == gab.id &&
          a.data.year == selectedDate.year &&
          a.data.month == selectedDate.month &&
          a.data.day == selectedDate.day;
    }).toList();

    final estaOcupado = alocacoesDoGab.isNotEmpty;

    if (filtroOcupacao == 'Todos') {
      filtradosOcupacao.add(gab);
    } else if (filtroOcupacao == 'Livres' && !estaOcupado) {
      filtradosOcupacao.add(gab);
    } else if (filtroOcupacao == 'Ocupados' && estaOcupado) {
      filtradosOcupacao.add(gab);
    }
  }

  if (mostrarConflitos) {
    return filtradosOcupacao.where((gab) {
      final alocacoesDoGab = alocacoes.where((a) {
        return a.gabineteId == gab.id &&
            a.data.year == selectedDate.year &&
            a.data.month == selectedDate.month &&
            a.data.day == selectedDate.day;
      }).toList();
      return ConflictUtils.temConflitoGabinete(alocacoesDoGab);
    }).toList();
  } else {
    return filtradosOcupacao;
  }
}
