// lib/utils/time_utils.dart

class TimeUtils {
  static List<List<int>> parseHorarios(String horarios) {
    if (horarios.trim().isEmpty) return [];

    final parts = horarios
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final times = <int>[];
    for (final p in parts) {
      final hm = p.split(':');
      if (hm.length == 2) {
        final h = int.tryParse(hm[0]) ?? 0;
        final m = int.tryParse(hm[1]) ?? 0;
        times.add(h * 60 + m);
      }
    }

    final result = <List<int>>[];
    for (int i = 0; i + 1 < times.length; i += 2) {
      result.add([times[i], times[i + 1]]);
    }

    return result;
  }

  static int parseTimeToMinutes(String timeStr) {
    // Substitui vírgulas por dois pontos para normalizar entradas inválidas
    timeStr = timeStr.replaceAll(',', ':');

    // Verifica se a string contém um intervalo de tempo, como "15:00: 20:00"
    if (timeStr.contains(':') && timeStr.split(':').length > 2) {
      throw FormatException('Formato de tempo inválido (intervalo detectado): $timeStr');
    }

    // Verifica se a string está no formato esperado (hh:mm)
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(timeStr)) {
      throw FormatException('Formato de tempo inválido: $timeStr');
    }

    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }


  // Verifica se dois intervalos de tempo se sobrepõem
  static bool intervalsSeSobrepoem(List<int> a, List<int> b) {
    final startA = a[0], endA = a[1];
    final startB = b[0], endB = b[1];
    return (startA < endB) && (startB < endA);
  }
}
