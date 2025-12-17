// lib/models/medico.dart

import 'disponibilidade.dart';

class Medico {
  final String id;
  String nome;
  String especialidade;
  String? observacoes;
  final List<Disponibilidade> disponibilidades;
  bool ativo; // Indica se o médico está ativo (true) ou inativo (false)

  Medico({
    required this.id,
    required this.nome,
    required this.especialidade,
    this.observacoes,
    required this.disponibilidades,
    this.ativo = true, // Por padrão, médicos são ativos
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'especialidade': especialidade,
      'observacoes': observacoes,
      'disponibilidades': disponibilidades.map((d) => d.toMap()).toList(),
      'ativo': ativo,
    };
  }

  factory Medico.fromMap(Map<String, dynamic> map) {
    // Corrige: se disponibilidades vier null, usa lista vazia
    final disponList = map['disponibilidades'];
    return Medico(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      especialidade: map['especialidade']?.toString() ?? '',
      observacoes: map['observacoes']?.toString(),
      disponibilidades: (disponList != null)
          ? (disponList as List).map((e) => Disponibilidade.fromMap(e)).toList()
          : [],
      ativo: map['ativo'] ?? true, // Por padrão, assume ativo se não especificado
    );
  }
}
