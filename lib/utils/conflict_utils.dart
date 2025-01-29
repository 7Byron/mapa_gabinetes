// lib/utils/conflict_utils.dart

import '../models/alocacao.dart';
import 'time_utils.dart';

class ConflictUtils {
  static bool temConflitoGabinete(List<Alocacao> alocs) {
    // Converte todas as alocações para intervalos de tempo (em minutos)
    final intervals = alocs.map((a) {
      final start = TimeUtils.parseTimeToMinutes(a.horarioInicio);
      final end = TimeUtils.parseTimeToMinutes(a.horarioFim);
      return [start, end];
    }).toList();

    // Verifica sobreposições entre todos os pares de intervalos
    for (int i = 0; i < intervals.length; i++) {
      for (int j = i + 1; j < intervals.length; j++) {
        if (TimeUtils.intervalsSeSobrepoem(intervals[i], intervals[j])) {
          return true;
        }
      }
    }
    return false;
  }
}