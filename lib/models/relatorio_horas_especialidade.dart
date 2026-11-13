class RelatorioHorasMedicoLinha {
  final String medicoId;
  final String nome;
  final String especialidade;
  final double horasConsulta;

  const RelatorioHorasMedicoLinha({
    required this.medicoId,
    required this.nome,
    required this.especialidade,
    required this.horasConsulta,
  });

  double percentagemContribuicao(double totalHorasClinica) =>
      totalHorasClinica > 0 ? horasConsulta / totalHorasClinica * 100 : 0;
}

class RelatorioHorasEspecialidadeLinha {
  final String especialidade;
  final int medicosAtivos;
  final int medicosComDisponibilidade;
  final double horasConsulta;

  const RelatorioHorasEspecialidadeLinha({
    required this.especialidade,
    required this.medicosAtivos,
    required this.medicosComDisponibilidade,
    required this.horasConsulta,
  });

  double get mediaHorasPorMedico {
    if (medicosComDisponibilidade <= 0) return 0.0;
    return horasConsulta / medicosComDisponibilidade;
  }

  /// A comparação inclui todos os médicos ativos, mesmo sem horas no período.
  double get mediaHorasPorMedicoAtivo =>
      medicosAtivos > 0 ? horasConsulta / medicosAtivos : 0;
}

class RelatorioHorasEspecialidade {
  final DateTime inicio;
  final DateTime fim;
  final List<RelatorioHorasEspecialidadeLinha> linhas;
  final int totalMedicosAtivosClinica;
  final double totalHorasConsultaClinica;
  final List<RelatorioHorasMedicoLinha> medicos;
  final List<String> especialidadesSelecionadas;
  final Map<String, RelatorioHorasEspecialidadeLinha> especialidadesClinica;

  const RelatorioHorasEspecialidade({
    required this.inicio,
    required this.fim,
    required this.linhas,
    this.totalMedicosAtivosClinica = 0,
    this.totalHorasConsultaClinica = 0,
    this.medicos = const [],
    this.especialidadesSelecionadas = const [],
    this.especialidadesClinica = const {},
  });

  bool get porMedico => medicos.isNotEmpty;

  double get mediaHorasPorMedicoClinica => totalMedicosAtivosClinica > 0
      ? totalHorasConsultaClinica / totalMedicosAtivosClinica
      : 0;

  /// Mantém as barras comparáveis entre os médicos do mesmo relatório.
  double get limiteComparacaoHoras {
    var maior = mediaHorasPorMedicoClinica;
    for (final medico in medicos) {
      if (medico.horasConsulta > maior) maior = medico.horasConsulta;
      final mediaEspecialidade = especialidadesClinica[medico.especialidade]
              ?.mediaHorasPorMedicoAtivo ??
          0;
      if (mediaEspecialidade > maior) maior = mediaEspecialidade;
    }
    return maior > 0 ? maior * 1.15 : 1;
  }

  int get totalEspecialidades => porMedico
      ? medicos.map((medico) => medico.especialidade).toSet().length
      : linhas.length;

  int get totalMedicosAtivos => porMedico
      ? medicos.length
      : linhas.fold(0, (total, linha) => total + linha.medicosAtivos);

  int get totalMedicosComDisponibilidade => porMedico
      ? medicos.where((medico) => medico.horasConsulta > 0).length
      : linhas.fold(
          0, (total, linha) => total + linha.medicosComDisponibilidade);

  double get totalHorasConsulta => porMedico
      ? medicos.fold(0.0, (total, medico) => total + medico.horasConsulta)
      : linhas.fold(0.0, (total, linha) => total + linha.horasConsulta);
}
