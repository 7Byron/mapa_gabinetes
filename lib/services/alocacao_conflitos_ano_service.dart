import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../utils/conflict_utils.dart';

class AlocacaoConflitosAnoService {
  static List<Map<String, dynamic>> calcular({
    required List<Alocacao> alocacoes,
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    required int ano,
    void Function(int processed, int total)? onProgress,
  }) {
    final alocacoesPorGabineteEData = <String, List<Alocacao>>{};
    for (final aloc in alocacoes) {
      if (aloc.data.year == ano) {
        final chave =
            '${aloc.gabineteId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        alocacoesPorGabineteEData.putIfAbsent(chave, () => []).add(aloc);
      }
    }

    final conflitos = <Map<String, dynamic>>[];
    final totalEntries = alocacoesPorGabineteEData.length;
    var processedEntries = 0;

    for (final entry in alocacoesPorGabineteEData.entries) {
      final alocs = entry.value;

      final alocacoesFiltradas = <Alocacao>[];
      final chavesAdicionadas = <String>{};

      for (final aloc in alocs) {
        final chave =
            '${aloc.medicoId}_${aloc.gabineteId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.horarioInicio}_${aloc.horarioFim}';

        if (chavesAdicionadas.contains(chave)) {
          final indiceExistente = alocacoesFiltradas.indexWhere((a) {
            return a.medicoId == aloc.medicoId &&
                a.gabineteId == aloc.gabineteId &&
                a.data.year == aloc.data.year &&
                a.data.month == aloc.data.month &&
                a.data.day == aloc.data.day &&
                a.horarioInicio == aloc.horarioInicio &&
                a.horarioFim == aloc.horarioFim;
          });

          if (indiceExistente >= 0) {
            final existente = alocacoesFiltradas[indiceExistente];
            if (aloc.id.startsWith('otimista_serie_') &&
                !existente.id.startsWith('otimista_')) {
              continue;
            } else if (!aloc.id.startsWith('otimista_') &&
                existente.id.startsWith('otimista_serie_')) {
              alocacoesFiltradas[indiceExistente] = aloc;
              continue;
            } else {
              continue;
            }
          }
        }

        if (aloc.id.startsWith('otimista_serie_')) {
          final temAlocacaoReal = alocs.any((a) {
            return a != aloc &&
                !a.id.startsWith('otimista_') &&
                a.medicoId == aloc.medicoId &&
                a.gabineteId == aloc.gabineteId &&
                a.data.year == aloc.data.year &&
                a.data.month == aloc.data.month &&
                a.data.day == aloc.data.day &&
                a.horarioInicio == aloc.horarioInicio &&
                a.horarioFim == aloc.horarioFim;
          });
          if (temAlocacaoReal) {
            continue;
          }
        }

        alocacoesFiltradas.add(aloc);
        chavesAdicionadas.add(chave);
      }

      if (alocacoesFiltradas.length >= 2 &&
          ConflictUtils.temConflitoGabinete(alocacoesFiltradas)) {
        for (int i = 0; i < alocacoesFiltradas.length; i++) {
          for (int j = i + 1; j < alocacoesFiltradas.length; j++) {
            if (alocacoesFiltradas[i].medicoId ==
                alocacoesFiltradas[j].medicoId) {
              continue;
            }

            if (ConflictUtils.temConflitoEntre(
                alocacoesFiltradas[i], alocacoesFiltradas[j])) {
              final medico1 = medicos.firstWhere(
                (m) => m.id == alocacoesFiltradas[i].medicoId,
                orElse: () => Medico(
                  id: alocacoesFiltradas[i].medicoId,
                  nome: 'Desconhecido',
                  especialidade: '',
                  disponibilidades: [],
                  ativo: false,
                ),
              );
              final medico2 = medicos.firstWhere(
                (m) => m.id == alocacoesFiltradas[j].medicoId,
                orElse: () => Medico(
                  id: alocacoesFiltradas[j].medicoId,
                  nome: 'Desconhecido',
                  especialidade: '',
                  disponibilidades: [],
                  ativo: false,
                ),
              );
              final gabinete = gabinetes.firstWhere(
                (g) => g.id == alocacoesFiltradas[i].gabineteId,
                orElse: () => Gabinete(
                  id: alocacoesFiltradas[i].gabineteId,
                  setor: '',
                  nome: alocacoesFiltradas[i].gabineteId,
                  especialidadesPermitidas: [],
                ),
              );
              conflitos.add({
                'gabinete': gabinete,
                'data': alocacoesFiltradas[i].data,
                'medico1': medico1,
                'horario1':
                    '${alocacoesFiltradas[i].horarioInicio} - ${alocacoesFiltradas[i].horarioFim}',
                'medico2': medico2,
                'horario2':
                    '${alocacoesFiltradas[j].horarioInicio} - ${alocacoesFiltradas[j].horarioFim}',
              });
            }
          }
        }
      }

      processedEntries++;
      onProgress?.call(processedEntries, totalEntries);
    }

    return conflitos;
  }
}
