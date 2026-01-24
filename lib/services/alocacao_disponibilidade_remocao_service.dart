import 'package:cloud_firestore/cloud_firestore.dart';
import 'cache_version_service.dart';
import '../utils/alocacao_medicos_logic.dart';

/// Serviço para remover alocações e disponibilidades do Firestore
/// Extracted from cadastro_medicos.dart to reduce code duplication
class AlocacaoDisponibilidadeRemocaoService {
  /// Remove alocações e disponibilidades únicas do Firestore para um período de datas
  /// Retorna o número de alocações e disponibilidades removidas
  static Future<Map<String, int>> removerAlocacoesEDisponibilidades(
    String unidadeId,
    String medicoId,
    DateTime dataInicio,
    DateTime dataFim,
  ) async {
    final firestore = FirebaseFirestore.instance;
    int alocacoesRemovidas = 0;
    int disponibilidadesRemovidas = 0;

    DateTime dataAtual = dataInicio;
    while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
      final ano = dataAtual.year.toString();
      final inicio = DateTime(dataAtual.year, dataAtual.month, dataAtual.day);
      bool houveRemocaoNoDia = false;

      try {
        // 1. Remover alocações
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('alocacoes')
            .doc(ano)
            .collection('registos');

        final todasAlocacoes = await alocacoesRef.get();
        final alocacoesParaRemover = todasAlocacoes.docs.where((doc) {
          final data = doc.data();
          final medicoIdAloc = data['medicoId']?.toString();
          final dataAloc = data['data']?.toString();
          if (medicoIdAloc != medicoId) return false;
          if (dataAloc == null) return false;
          try {
            final dataAlocDateTime = DateTime.parse(dataAloc);
            return dataAlocDateTime.year == inicio.year &&
                dataAlocDateTime.month == inicio.month &&
                dataAlocDateTime.day == inicio.day;
          } catch (e) {
            return false;
          }
        }).toList();

        for (final doc in alocacoesParaRemover) {
          await doc.reference.delete();
          alocacoesRemovidas++;
          houveRemocaoNoDia = true;
        }

        // 2. Remover disponibilidades únicas da coleção de ocupantes
        final disponibilidadesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .doc(medicoId)
            .collection('disponibilidades')
            .doc(ano)
            .collection('registos');

        final todasDisponibilidades = await disponibilidadesRef.get();
        final disponibilidadesParaRemover =
            todasDisponibilidades.docs.where((doc) {
          final data = doc.data();
          final dataDisp = data['data']?.toString();
          final tipoDisp = data['tipo']?.toString();
          final medicoIdDisp = data['medicoId']?.toString();

          if (dataDisp == null ||
              tipoDisp != 'Única' ||
              medicoIdDisp != medicoId) {
            return false;
          }

          try {
            final dataDispDateTime = DateTime.parse(dataDisp);
            return dataDispDateTime.year == inicio.year &&
                dataDispDateTime.month == inicio.month &&
                dataDispDateTime.day == inicio.day;
          } catch (e) {
            return false;
          }
        }).toList();

        for (final doc in disponibilidadesParaRemover) {
          await doc.reference.delete();
          disponibilidadesRemovidas++;
          houveRemocaoNoDia = true;
        }

        // 3. Remover da vista diária (dias/{dayKey}/disponibilidades)
        final keyDia =
            '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
        final diasDisponibilidadesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('dias')
            .doc(keyDia)
            .collection('disponibilidades');

        final todasDisponibilidadesDias = await diasDisponibilidadesRef.get();
        final disponibilidadesDiasParaRemover =
            todasDisponibilidadesDias.docs.where((doc) {
          final data = doc.data();
          final medicoIdDisp = data['medicoId']?.toString();
          final tipoDisp = data['tipo']?.toString();
          if (medicoIdDisp != medicoId || tipoDisp != 'Única') {
            return false;
          }
          final dataDisp = data['data']?.toString();
          if (dataDisp == null) return false;
          try {
            final dataDispDateTime = DateTime.parse(dataDisp);
            return dataDispDateTime.year == inicio.year &&
                dataDispDateTime.month == inicio.month &&
                dataDispDateTime.day == inicio.day;
          } catch (e) {
            return false;
          }
        }).toList();

        for (final doc in disponibilidadesDiasParaRemover) {
          await doc.reference.delete();
          houveRemocaoNoDia = true;
        }

        if (houveRemocaoNoDia) {
          AlocacaoMedicosLogic.invalidateCacheForDay(inicio);
        }
      } catch (e) {
        // Erro ao remover - continuar para próxima data
      }

      dataAtual = dataAtual.add(const Duration(days: 1));
    }

    if (alocacoesRemovidas > 0 || disponibilidadesRemovidas > 0) {
      await CacheVersionService.bumpVersions(
        unidadeId: unidadeId,
        fields: [
          CacheVersionService.fieldAlocacoes,
          CacheVersionService.fieldDisponibilidades,
        ],
      );
    }

    return {
      'alocacoesRemovidas': alocacoesRemovidas,
      'disponibilidadesRemovidas': disponibilidadesRemovidas,
    };
  }

  /// Remove alocações e disponibilidades únicas do Firestore para uma data específica
  static Future<Map<String, int>> removerAlocacoesEDisponibilidadesPorData(
    String unidadeId,
    String medicoId,
    DateTime data,
  ) async {
    return removerAlocacoesEDisponibilidades(
      unidadeId,
      medicoId,
      data,
      data,
    );
  }
}
