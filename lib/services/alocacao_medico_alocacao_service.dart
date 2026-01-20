import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

typedef AtualizarUIAlocarCartaoUnico = Future<bool> Function({
  required String medicoId,
  required String gabineteId,
  required DateTime data,
  required List<Alocacao> alocacoes,
  required List<Medico> medicosDisponiveis,
  required List<Medico> medicos,
  required VoidCallback setState,
  String horarioInicio,
  String horarioFim,
});

class AlocacaoMedicoAlocacaoService {
  static Future<void> alocar({
    required Unidade unidade,
    required DateTime dataAlvo,
    required String medicoId,
    required String gabineteId,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required AtualizarUIAlocarCartaoUnico atualizarUIAlocarCartaoUnico,
    required VoidCallback onStateUpdate,
    List<String>? horarios,
  }) async {
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

    debugPrint(
        '🟢 [ALOCAÇÃO] Executando atualização otimista: médico=$medicoId, gabinete=$gabineteId');

    String horarioInicio = '00:00';
    String horarioFim = '00:00';
    if (horarios != null && horarios.length >= 2) {
      horarioInicio = horarios[0];
      horarioFim = horarios[1];
    } else {
      final dispDoDia = disponibilidades.where((disp) {
        final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId && dd == dataAlvoNormalizada;
      }).toList();
      if (dispDoDia.isNotEmpty) {
        horarioInicio = dispDoDia.first.horarios[0];
        horarioFim = dispDoDia.first.horarios[1];
      }
    }

    final alocacoesNoDestino = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteId &&
          aDate == dataAlvoNormalizada;
    }).toList();
    final alocacaoJaExisteNoDestino = alocacoesNoDestino.isNotEmpty;

    if (alocacaoJaExisteNoDestino) {
      debugPrint(
          '⚠️ [ALOCAÇÃO] Alocação já existe no destino, atualizando Firestore diretamente');

      final alocacaoExistente = alocacoes.firstWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteId &&
            aDate == dataAlvoNormalizada;
      });

      try {
        final firestore = FirebaseFirestore.instance;
        final unidadeId = unidade.id;
        final ano = dataAlvoNormalizada.year.toString();
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('alocacoes')
            .doc(ano)
            .collection('registos');

        await alocacoesRef.doc(alocacaoExistente.id).update({
          'gabineteId': gabineteId,
          'medicoId': medicoId,
          'data': alocacaoExistente.data.toIso8601String(),
          'horarioInicio': alocacaoExistente.horarioInicio,
          'horarioFim': alocacaoExistente.horarioFim,
        });

        debugPrint(
            '✅ [ALOCAÇÃO] Firestore atualizado diretamente (sem remover): ${alocacaoExistente.id}');
      } catch (e) {
        debugPrint('❌ [ALOCAÇÃO] Erro ao atualizar Firestore: $e');
      }

      return;
    }

    alocacoes.removeWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          aDate == dataAlvoNormalizada &&
          a.gabineteId != gabineteId;
    });

    final uiAtualizada = await atualizarUIAlocarCartaoUnico(
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataAlvoNormalizada,
      alocacoes: alocacoes,
      medicosDisponiveis: medicosDisponiveis,
      medicos: medicos,
      setState: onStateUpdate,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );

    if (!uiAtualizada) {
      debugPrint('⚠️ [ALOCAÇÃO] Falha ao atualizar UI, continuando mesmo assim...');
    }

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvoNormalizada);

    await logic.AlocacaoMedicosLogic.alocarMedico(
      selectedDate: dataAlvo,
      medicoId: medicoId,
      gabineteId: gabineteId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      onAlocacoesChanged: () {},
      unidade: unidade,
      horariosForcados: horarios,
    );

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvoNormalizada);

    debugPrint('✅ [ALOCAÇÃO] Alocação concluída com sucesso');
  }
}
