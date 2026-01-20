import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';

class RelatoriosEspecialidadesService {
  static List<int> _anosNoIntervalo(DateTime inicio, DateTime fim) {
    final anos = <int>[];
    for (int ano = inicio.year; ano <= fim.year; ano++) {
      anos.add(ano);
    }
    return anos;
  }

  /// Retorna um Map: {especialidade -> totalHoras}
  /// com base nas disponibilidades dos médicos no período [inicio..fim].
  static Future<Map<String, double>> horasPorEspecialidade({
    required DateTime inicio,
    required DateTime fim,
    String? unidadeId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final medicosRef = unidadeId == null
        ? firestore.collection('medicos')
        : firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes');
    final medicosSnap = await medicosRef.get();
    final Map<String, String> mapMedEsp = {};
    final List<Disponibilidade> allDisp = [];
    final anos = _anosNoIntervalo(inicio, fim);
    for (final doc in medicosSnap.docs) {
      final dados = doc.data();
      final medicoId = (dados['id'] ?? doc.id).toString();
      mapMedEsp[medicoId] = (dados['especialidade'] ?? '').toString();

      // Carrega disponibilidades apenas para os anos do intervalo
      final dispRef = doc.reference.collection('disponibilidades');
      for (final ano in anos) {
        final registosRef = dispRef.doc(ano.toString()).collection('registos');
        final registosSnapshot = await registosRef.get();
        for (final dispDoc in registosSnapshot.docs) {
          final dispData = dispDoc.data();
          final medicoIdDisp =
              (dispData['medicoId'] ?? medicoId).toString();
          allDisp.add(Disponibilidade.fromMap({
            ...dispData,
            'medicoId': medicoIdDisp,
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
