import 'dart:convert';

class Disponibilidade {
  final String id;
  final DateTime data;
  final String tipo; // Novo campo para armazenar o tipo de marcação
  List<String> horarios;

  Disponibilidade({
    required this.id,
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
      'tipo': tipo, // Inclui o tipo no banco
    };
  }

  static Disponibilidade fromMap(Map<String, dynamic> map) {
    return Disponibilidade(
      id: map['id'],
      data: DateTime.parse(map['data']),
      horarios: (jsonDecode(map['horarios']) as List<dynamic>).cast<String>(),
      tipo: map['tipo'] ?? 'Única', // Padrão: única
    );
  }
}
