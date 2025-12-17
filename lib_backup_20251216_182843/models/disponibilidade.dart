// lib/models/disponibilidade.dart

import 'dart:convert';

class Disponibilidade {
  String id;
  String medicoId;
  final DateTime data;
  final String tipo; // "Única", "Semanal", etc.
  List<String> horarios;

  Disponibilidade({
    required this.id,
    required this.medicoId,
    required this.data,
    required this.horarios,
    required this.tipo,
  });

  Map<String, dynamic> toMap([String? medicoId]) {
    return {
      'id': id,
      'medicoId': medicoId ?? this.medicoId,
      'data': data.toIso8601String(),
      'horarios': horarios,
      'tipo': tipo,
    };
  }

  static Disponibilidade fromMap(Map<String, dynamic> map) {
    final horariosRaw = map['horarios'];
    List<String> horarios;
    if (horariosRaw is String) {
      try {
        horarios = (jsonDecode(horariosRaw) as List).cast<String>();
      } catch (e) {
        horarios = [];
      }
    } else if (horariosRaw is List) {
      horarios = (horariosRaw).cast<String>();
    } else {
      horarios = [];
    }
    return Disponibilidade(
      id: map['id']?.toString() ?? '',
      medicoId: map['medicoId']?.toString() ?? '',
      data: map['data'] != null
          ? DateTime.parse(map['data'].toString())
          : DateTime.now(),
      horarios: horarios,
      tipo: map['tipo']?.toString() ?? 'Única',
    );
  }
}
