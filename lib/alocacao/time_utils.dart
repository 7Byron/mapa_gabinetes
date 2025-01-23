// time_utils.dart

class TimeUtils {
  /// Converte uma string de horários em pares de [início, fim] em minutos.
  /// Exemplo: "08:00, 12:00" -> [[480, 720]]
  static List<List<int>> parseHorarios(String horarios) {
    if (horarios.trim().isEmpty) return [];

    // Divide por vírgula, remove espaços e pega apenas as partes não vazias
    final parts = horarios
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Converte cada "hh:mm" em minutos a partir da meia-noite
    final times = <int>[];
    for (final p in parts) {
      final hm = p.split(':');
      if (hm.length == 2) {
        final h = int.tryParse(hm[0]) ?? 0;
        final m = int.tryParse(hm[1]) ?? 0;
        times.add(h * 60 + m);
      }
    }

    // Agrupa de 2 em 2 para representar intervalos
    final result = <List<int>>[];
    for (int i = 0; i + 1 < times.length; i += 2) {
      result.add([times[i], times[i + 1]]);
    }

    return result;
  }

  /// Retorna true se os intervalos [startA, endA] e [startB, endB] tiverem sobreposição
  static bool intervalsSeSobrepoem(List<int> a, List<int> b) {
    final startA = a[0], endA = a[1];
    final startB = b[0], endB = b[1];
    return (startA < endB) && (startB < endA);
  }
}
