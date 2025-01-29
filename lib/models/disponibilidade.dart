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

  Map<String, dynamic> toMap(String medicoId) {
    return {
      'id': id,
      'medicoId': medicoId,
      'data': data.toIso8601String(),
      'horarios': jsonEncode(horarios),
      'tipo': tipo,
    };
  }

  static Disponibilidade fromMap(Map<String, dynamic> map) {
    return Disponibilidade(
      id: map['id'],
      medicoId: map['medicoId'],
      data: DateTime.parse(map['data']),
      horarios: (jsonDecode(map['horarios']) as List).cast<String>(),
      tipo: map['tipo'] ?? 'Única',
    );
  }
}
