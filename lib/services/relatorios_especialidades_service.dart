import '../database/database_helper.dart';

class RelatoriosEspecialidadesService {
  /// Retorna um Map: {especialidade -> totalHoras}
  /// com base nas disponibilidades dos médicos no período [inicio..fim].
  static Future<Map<String, double>> horasPorEspecialidade({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final medicos = await DatabaseHelper.buscarMedicos();
    // Carrega disponibilidades de cada (ou use "buscarTodasDisponibilidades()")
    final allDisp = await DatabaseHelper.buscarTodasDisponibilidades();

    // Filtra no período
    final dispNoPeriodo = allDisp.where((d) {
      final dataD = d.data;
      return !dataD.isBefore(inicio) && !dataD.isAfter(fim);
    }).toList();

    // Mapeia "medicoId" -> especialidade do médico
    final mapMedEsp = <String, String>{};
    for (final m in medicos) {
      mapMedEsp[m.id] = m.especialidade; // se cada médico tiver 1 especialidade
    }

    // Aggregado final
    final Map<String, double> somaPorEsp = {};

    for (final disp in dispNoPeriodo) {
      final esp = mapMedEsp[disp.medicoId] ?? '(desconhecida)';
      final horas = _calcHorasDisponibilidade(disp.horarios);
      somaPorEsp[esp] = (somaPorEsp[esp] ?? 0) + horas;
    }

    return somaPorEsp;
  }

  /// Ex: disp.horarios = ["08:00","12:00"] => 4h
  /// ou ["08:00","12:00","14:00","18:00"] => 8h no total
  static double _calcHorasDisponibilidade(List<String> horarios) {
    double total = 0.0;
    for (int i = 0; i < horarios.length; i += 2) {
      if (i+1 >= horarios.length) break;
      final ini = _strToDouble(horarios[i]);
      final fim = _strToDouble(horarios[i+1]);
      final delta = fim - ini;
      if (delta > 0) total += delta;
    }
    return total;
  }

  static double _strToDouble(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    return h + (m/60.0);
  }
}
