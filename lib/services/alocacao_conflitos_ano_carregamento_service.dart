import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_ano_alocacoes_service.dart';
import '../services/alocacao_conflitos_ano_service.dart';

class AlocacaoConflitosAnoCarregamentoService {
  static Future<List<Map<String, dynamic>>> carregar({
    required Unidade unidade,
    required int ano,
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    void Function(double)? onProgresso,
  }) async {
    onProgresso?.call(0.10);
    final todasAlocacoes = await AlocacaoAnoAlocacoesService.carregar(
      unidade: unidade,
      ano: ano,
      medicos: medicos,
    );

    onProgresso?.call(0.50);
    final conflitos = AlocacaoConflitosAnoService.calcular(
      alocacoes: todasAlocacoes,
      gabinetes: gabinetes,
      medicos: medicos,
      ano: ano,
      onProgress: (processed, total) {
        if (total > 0) {
          final progressoProcessamento = 0.50 + (processed / total) * 0.45;
          onProgresso?.call(progressoProcessamento.clamp(0.0, 0.95));
        }
      },
    );

    conflitos.sort((a, b) {
      final dataA = a['data'] as DateTime;
      final dataB = b['data'] as DateTime;
      final cmpData = dataA.compareTo(dataB);
      if (cmpData != 0) return cmpData;
      final gabA = a['gabinete'] as Gabinete;
      final gabB = b['gabinete'] as Gabinete;
      return gabA.nome.compareTo(gabB.nome);
    });

    return conflitos;
  }
}
