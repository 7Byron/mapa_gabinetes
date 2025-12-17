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
  final String nomeOcupantes; // 'Médicos', 'Convidados', 'Clientes', etc.
  final String nomeAlocacao; // 'Gabinete', 'Quarto', 'Mesa', etc.

  Unidade({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.endereco,
    this.telefone,
    this.email,
    required this.dataCriacao,
    this.ativa = true,
    required this.nomeOcupantes,
    required this.nomeAlocacao,
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
      'nomeOcupantes': nomeOcupantes,
      'nomeAlocacao': nomeAlocacao,
    };
  }

  factory Unidade.fromMap(Map<String, dynamic> map) {
    return Unidade(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'Unidade', // Valor padrão mais genérico
      endereco: map['endereco']?.toString() ?? '',
      telefone: map['telefone']?.toString(),
      email: map['email']?.toString(),
      dataCriacao: map['dataCriacao'] != null
          ? DateTime.parse(map['dataCriacao'].toString())
          : DateTime.now(),
      ativa: map['ativa'] as bool? ?? true,
      nomeOcupantes:
          map['nomeOcupantes']?.toString() ?? 'Médicos', // Valor padrão
      nomeAlocacao:
          map['nomeAlocacao']?.toString() ?? 'Gabinete', // Valor padrão
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
    String? nomeOcupantes,
    String? nomeAlocacao,
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
      nomeOcupantes: nomeOcupantes ?? this.nomeOcupantes,
      nomeAlocacao: nomeAlocacao ?? this.nomeAlocacao,
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
