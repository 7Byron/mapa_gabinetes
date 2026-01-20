import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoRefreshService {
  static Future<void> executar({
    required DateTime selectedDate,
    required Future<void> Function() recarregarDados,
    required void Function(double) onProgresso,
  }) async {
    final anoAtual = selectedDate.year;
    final dataNormalizada =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    logic.AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoAtual, 1, 1));

    onProgresso(0.2);
    await Future.delayed(const Duration(milliseconds: 100));

    await recarregarDados();
  }
}
