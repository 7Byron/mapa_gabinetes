import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';

class RelatoriosEspecialidadesService {
  /// Retorna um Map: {especialidade -> totalHoras}
  /// com base nas disponibilidades dos médicos no período [inicio..fim].
  static Future<Map<String, double>> horasPorEspecialidade({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final medicosSnap = await firestore.collection('medicos').get();
    final Map<String, String> mapMedEsp = {};
    final List<Disponibilidade> allDisp = [];
    for (final doc in medicosSnap.docs) {
      final dados = doc.data();
      mapMedEsp[dados['id']] = dados['especialidade'];
      // Carrega disponibilidades da nova estrutura por ano
      final dispRef = doc.reference.collection('disponibilidades');
      
      // Para relatórios, carrega todos os anos para ter dados completos
      final anosSnapshot = await dispRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        for (final dispDoc in registosSnapshot.docs) {
          final dispData = dispDoc.data();
          allDisp.add(Disponibilidade.fromMap({
            ...dispData,
            'horarios': dispData['horarios'] is List ? dispData['horarios'] : [],
          }));
        }
      }
    }
    // Filtra no período
    final dispNoPeriodo = allDisp.where((d) {
      final dataD = d.data;
      return !dataD.isBefore(inicio) && !dataD.isAfter(fim);
    }).toList();
    // Aggregado final
    final Map<String, double> somaPorEsp = {};
    for (final disp in dispNoPeriodo) {
      final esp = mapMedEsp[disp.medicoId] ?? '(desconhecida)';
      final horas = _calcHorasDisponibilidade(disp.horarios);
      somaPorEsp[esp] = (somaPorEsp[esp] ?? 0) + horas;
    }
    return somaPorEsp;
  }

  static double _calcHorasDisponibilidade(List<String> horarios) {
    double total = 0.0;
    for (int i = 0; i < horarios.length; i += 2) {
      if (i + 1 >= horarios.length) break;
      final ini = _strHoraParaDouble(horarios[i]);
      final fim = _strHoraParaDouble(horarios[i + 1]);
      final delta = fim - ini;
      if (delta > 0) total += delta;
    }
    return total;
  }

  static double _strHoraParaDouble(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0.0;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    return h + (m / 60.0);
  }
}
