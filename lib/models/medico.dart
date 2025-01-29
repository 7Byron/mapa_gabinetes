// lib/models/medico.dart

import 'disponibilidade.dart';

class Medico {
  final String id;
  String nome;
  String especialidade;
  String? observacoes;
  final List<Disponibilidade> disponibilidades;

  Medico({
    required this.id,
    required this.nome,
    required this.especialidade,
    this.observacoes,
    required this.disponibilidades,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'especialidade': especialidade,
      'observacoes': observacoes,
      'disponibilidades': disponibilidades.map((d) => d.toMap(id)).toList(),
    };
  }

  factory Medico.fromMap(Map<String, dynamic> map) {
    return Medico(
      id: map['id'],
      nome: map['nome'],
      especialidade: map['especialidade'],
      observacoes: map['observacoes'],
      disponibilidades: (map['disponibilidades'] as List)
          .map((e) => Disponibilidade.fromMap(e))
          .toList(),
    );
  }
}
