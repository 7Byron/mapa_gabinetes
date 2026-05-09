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
}

class RelatorioHorasEspecialidade {
  final DateTime inicio;
  final DateTime fim;
  final List<RelatorioHorasEspecialidadeLinha> linhas;

  const RelatorioHorasEspecialidade({
    required this.inicio,
    required this.fim,
    required this.linhas,
  });

  int get totalEspecialidades => linhas.length;

  int get totalMedicosAtivos =>
      linhas.fold(0, (total, linha) => total + linha.medicosAtivos);

  int get totalMedicosComDisponibilidade =>
      linhas.fold(0, (total, linha) => total + linha.medicosComDisponibilidade);

  double get totalHorasConsulta =>
      linhas.fold(0.0, (total, linha) => total + linha.horasConsulta);
}
