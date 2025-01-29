// lib/utils/conflict_utils.dart

import '../models/alocacao.dart';
import 'time_utils.dart';

class ConflictUtils {
  static bool temConflitoGabinete(List<Alocacao> alocs) {
    if (alocs.length < 2) return false;
    for (int i = 0; i < alocs.length; i++) {
      for (int j = i + 1; j < alocs.length; j++) {
        if (temConflitoEntre(alocs[i], alocs[j])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool temConflitoEntre(Alocacao a, Alocacao b) {
    final intervalsA = TimeUtils.parseHorarios(a.horarioInicio);
    final intervalsB = TimeUtils.parseHorarios(b.horarioInicio);
    for (final iA in intervalsA) {
      for (final iB in intervalsB) {
        if (TimeUtils.intervalsSeSobrepoem(iA, iB)) {
          return true;
        }
      }
    }
    return false;
  }
}
