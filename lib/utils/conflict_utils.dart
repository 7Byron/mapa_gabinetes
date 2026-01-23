// lib/utils/conflict_utils.dart

import '../models/alocacao.dart';
import 'time_utils.dart';

class _IntervaloAlocacao {
  final String medicoId;
  final int inicio;
  final int fim;

  const _IntervaloAlocacao({
    required this.medicoId,
    required this.inicio,
    required this.fim,
  });
}

class ConflictUtils {
  /// Verifica se há conflito entre quaisquer alocações em um gabinete
  static bool temConflitoGabinete(List<Alocacao> alocs) {
    if (alocs.length < 2) return false;

    // Converte todas as alocações para intervalos em minutos
    final intervals = alocs
        .map((a) => _IntervaloAlocacao(
              medicoId: a.medicoId,
              inicio: TimeUtils.parseTimeToMinutes(a.horarioInicio),
              fim: TimeUtils.parseTimeToMinutes(a.horarioFim),
            ))
        .toList();

    // Compara todos os pares de alocações
    for (int i = 0; i < intervals.length; i++) {
      for (int j = i + 1; j < intervals.length; j++) {
        final a = intervals[i];
        final b = intervals[j];

        // Não considerar sobreposição do mesmo médico como conflito de gabinete
        if (a.medicoId == b.medicoId) {
          continue;
        }

        if (TimeUtils.intervalsSeSobrepoem(
          a.inicio,
          a.fim,
          b.inicio,
          b.fim,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Verifica conflito entre duas alocações específicas
  static bool temConflitoEntre(Alocacao a, Alocacao b) {
    final inicioA = TimeUtils.parseTimeToMinutes(a.horarioInicio);
    final fimA = TimeUtils.parseTimeToMinutes(a.horarioFim);
    final inicioB = TimeUtils.parseTimeToMinutes(b.horarioInicio);
    final fimB = TimeUtils.parseTimeToMinutes(b.horarioFim);

    return TimeUtils.intervalsSeSobrepoem(inicioA, fimA, inicioB, fimB);
  }
}