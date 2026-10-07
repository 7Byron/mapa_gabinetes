class TaxaOcupacao {
  final double horasOcupadas;
  final double horasDisponiveis;

  const TaxaOcupacao({this.horasOcupadas = 0, this.horasDisponiveis = 0});

  double get percentagem =>
      horasDisponiveis > 0 ? horasOcupadas / horasDisponiveis * 100 : 0;

  TaxaOcupacao somar(TaxaOcupacao outra) => TaxaOcupacao(
        horasOcupadas: horasOcupadas + outra.horasOcupadas,
        horasDisponiveis: horasDisponiveis + outra.horasDisponiveis,
      );
}
