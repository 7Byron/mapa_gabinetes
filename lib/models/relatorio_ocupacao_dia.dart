class RelatorioOcupacaoDia {
  final DateTime data;
  final double horasOcupadas;
  final double horasTotais;
  final bool fechado;
  final String? motivoFecho;

  const RelatorioOcupacaoDia({
    required this.data,
    required this.horasOcupadas,
    required this.horasTotais,
    required this.fechado,
    this.motivoFecho,
  });

  double get percentual {
    if (horasTotais <= 0) return 0.0;
    return (horasOcupadas / horasTotais) * 100.0;
  }
}
