// lib/models/unidade.dart

class Unidade {
  final String id;
  final String nome;
  final String tipo; // 'Clínica', 'Hospital', 'Hotel', 'Centro Médico', etc.
  final String endereco;
  final String? telefone;
  final String? email;
  final DateTime dataCriacao;
  final bool ativa;

  Unidade({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.endereco,
    this.telefone,
    this.email,
    required this.dataCriacao,
    this.ativa = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'endereco': endereco,
      'telefone': telefone,
      'email': email,
      'dataCriacao': dataCriacao.toIso8601String(),
      'ativa': ativa,
    };
  }

  factory Unidade.fromMap(Map<String, dynamic> map) {
    return Unidade(
      id: map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'Clínica',
      endereco: map['endereco'] as String? ?? '',
      telefone: map['telefone'] as String?,
      email: map['email'] as String?,
      dataCriacao: map['dataCriacao'] != null
          ? DateTime.parse(map['dataCriacao'] as String)
          : DateTime.now(),
      ativa: map['ativa'] as bool? ?? true,
    );
  }

  Unidade copyWith({
    String? id,
    String? nome,
    String? tipo,
    String? endereco,
    String? telefone,
    String? email,
    DateTime? dataCriacao,
    bool? ativa,
  }) {
    return Unidade(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      endereco: endereco ?? this.endereco,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      ativa: ativa ?? this.ativa,
    );
  }

  @override
  String toString() {
    return 'Unidade(id: $id, nome: $nome, tipo: $tipo, ativa: $ativa)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Unidade && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
