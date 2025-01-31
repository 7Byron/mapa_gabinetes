// lib/utils/time_utils.dart

class TimeUtils {
  /// Converte uma string de horário no formato "HH:mm" para minutos desde a meia-noite.
  /// Exemplo: "08:30" → 510 minutos.
  static int parseTimeToMinutes(String timeStr) {
    // Validação básica do formato
    if (!timeStr.contains(':') || timeStr.split(':').length != 2) {
      throw FormatException('Formato inválido. Use "HH:mm".', timeStr);
    }

    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);

    // Validação dos valores
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      throw FormatException('Horário inválido: $timeStr');
    }

    return hours * 60 + minutes;
  }

  /// Verifica se dois intervalos de tempo (em minutos) se sobrepõem
  static bool intervalsSeSobrepoem(int inicioA, int fimA, int inicioB, int fimB) {
    return (inicioA < fimB) && (inicioB < fimA);
  }
}