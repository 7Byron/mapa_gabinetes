
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

class HistoricOperator {
  final GetStorage box = GetStorage();
  static const int maxHistoryRecords = 4;

  void gravarHistorico(String tipoTeste, dynamic valor) {
    final List<String> historico = List.generate(
      maxHistoryRecords,
      (index) => box.read<String>("$tipoTeste${index + 1}") ?? '',
    );

    final String dataRegisto =
        "${DateFormat('yyyy-MM-dd').format(DateTime.now())}|$valor";

    for (int i = maxHistoryRecords - 1; i > 0; i--) {
      historico[i] = historico[i - 1];
    }
    historico[0] = dataRegisto;

    for (int i = 0; i < maxHistoryRecords; i++) {
      try {
        box.write("$tipoTeste${i + 1}", historico[i]);
      } catch (e) {
        // Ignora erros de escrita - o histórico não é crítico
        // Se houver erro, continua para o próximo registro
      }
    }
  }
}
