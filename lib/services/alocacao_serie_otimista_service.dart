import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';

class AlocacaoSerieOtimistaService {
  static void aplicar({
    required String medicoId,
    required String gabineteId,
    required DateTime data,
    required List<String> horarios,
    String? serieId,
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
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final disponibilidadesDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataNormalizada;
    }).toList();

    // Um médico pode ter mais do que uma série no mesmo dia. Só retirar o
    // médico da área de disponíveis quando este era o seu último cartão.
    if (disponibilidadesDoDia.length <= 1 &&
        medicosDisponiveis.contains(medico)) {
      medicosDisponiveis.remove(medico);
      debugPrint(
          '✅ [ALOCAÇÃO-SÉRIE-OTIMISTA] Médico removido dos desalocados: $medicoId');
    }

    String horarioInicio = horarios.isNotEmpty ? horarios.first : '08:00';
    String horarioFim = horarios.length > 1 ? horarios[1] : '15:00';
    final dispDoDia = disponibilidadesDoDia;
    if (dispDoDia.isNotEmpty) {
      // Escolher o cartão ainda não representado nas alocações. Isto permite
      // que duas sequências do mesmo médico no mesmo dia tenham atualizações
      // otimistas independentes.
      final disponibilidadePendente = dispDoDia.firstWhere(
        (disp) {
          if (disp.horarios.length < 2) return false;
          if (serieId != null) {
            final idDisponibilidade = disp.id;
            if (!idDisponibilidade.contains(serieId)) return false;
          }
          if (horarios.length >= 2 &&
              (disp.horarios[0] != horarios[0] ||
                  disp.horarios[1] != horarios[1])) {
            return false;
          }
          return !alocacoes.any((a) =>
              a.medicoId == medicoId &&
              DateTime(a.data.year, a.data.month, a.data.day) ==
                  dataNormalizada &&
              a.horarioInicio == disp.horarios[0] &&
              a.horarioFim == disp.horarios[1]);
        },
        orElse: () => dispDoDia.first,
      );
      if (disponibilidadePendente.horarios.length >= 2 && horarios.isEmpty) {
        horarioInicio = disponibilidadePendente.horarios[0];
        horarioFim = disponibilidadePendente.horarios[1];
      }
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
