import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoDesalocacaoDiaService {
  static Future<String> desalocar({
    required Unidade unidade,
    required DateTime data,
    required String medicoId,
    String? alocacaoId,
    String? serieId,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    final alocacaoAntesRemover = alocacoes.firstWhere(
      (a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            aDate == dataNormalizada &&
            (alocacaoId == null || a.id == alocacaoId);
      },
      orElse: () => Alocacao(
        id: '',
        medicoId: '',
        gabineteId: '',
        data: DateTime(1900, 1, 1),
        horarioInicio: '',
        horarioFim: '',
      ),
    );

    final gabineteOrigem = alocacaoAntesRemover.gabineteId;
    if (gabineteOrigem.isNotEmpty) {
      debugPrint(
          '🔍 [DESALOCAÇÃO] Gabinete de origem encontrado: $gabineteOrigem');
    }

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    await logic.AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
      selectedDate: data,
      medicoId: medicoId,
      alocacaoId: alocacaoAntesRemover.id,
      serieId: serieId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      onAlocacoesChanged: () {},
      unidade: unidade,
    );

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    debugPrint('💾 Cache invalidado após desalocação');

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    debugPrint('💾 Cache invalidado após desalocação');

    return gabineteOrigem;
  }
}
