import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';

class AlocacaoSerieOtimistaService {
  static void aplicar({
    required String medicoId,
    required String gabineteId,
    required DateTime data,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
  }) {
    debugPrint(
        '🟢 [ALOCAÇÃO-SÉRIE-OTIMISTA] INÍCIO: médico=$medicoId, gabinete=$gabineteId');

    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
        ativo: false,
      ),
    );
    if (medicosDisponiveis.contains(medico)) {
      medicosDisponiveis.remove(medico);
      debugPrint(
          '✅ [ALOCAÇÃO-SÉRIE-OTIMISTA] Médico removido dos desalocados: $medicoId');
    }

    String horarioInicio = '08:00';
    String horarioFim = '15:00';
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final dispDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataNormalizada;
    }).toList();
    if (dispDoDia.isNotEmpty) {
      horarioInicio = dispDoDia.first.horarios[0];
      horarioFim = dispDoDia.first.horarios[1];
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dataStr =
        '${dataNormalizada.year}${dataNormalizada.month.toString().padLeft(2, '0')}${dataNormalizada.day.toString().padLeft(2, '0')}';
    final alocacaoOtimista = Alocacao(
      id: 'otimista_serie_${timestamp}_${medicoId}_${gabineteId}_$dataStr',
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataNormalizada,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );

    alocacoes.add(alocacaoOtimista);

    debugPrint(
        '✅ [ALOCAÇÃO-SÉRIE-OTIMISTA] Cartão removido dos desalocados e adicionado ao gabinete');
  }
}
