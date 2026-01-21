class MedicosDisponiveisLayoutUtils {
  static double calcularAlturaContainer({
    required int totalMedicos,
  }) {
    const double alturaTitulo = 14 + 40 + 8;
    const alturaCartao = 100.0;
    const paddingVerticalSection = 16.0; // 8px top + 8px bottom
    const paddingBottomContainer = 12.0;
    const alturaConteudoMax =
        alturaCartao + paddingVerticalSection + paddingBottomContainer;

    if (totalMedicos == 0) {
      return alturaTitulo;
    }

    return alturaTitulo + alturaConteudoMax;
  }
}
