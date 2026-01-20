class AlocacaoFinalizacaoUiService {
  static Future<void> finalizar({
    required bool mounted,
    required void Function(void Function()) setState,
    required void Function() cancelarTimerProgresso,
    required void Function() inicializarFiltrosPiso,
    required void Function(bool) setIsCarregando,
    required void Function(double) setProgresso,
    required void Function(String) setMensagem,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      inicializarFiltrosPiso();
      cancelarTimerProgresso();
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        setIsCarregando(false);
        setProgresso(0.0);
        setMensagem('A iniciar...');
      });
    }
  }
}
