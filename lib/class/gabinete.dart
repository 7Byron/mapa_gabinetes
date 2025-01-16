class Gabinete {
  final String id;
  final String setor;
  final String nome;
  final List<String> especialidadesPermitidas;

  Gabinete({
    required this.id,
    required this.setor,
    required this.nome,
    required this.especialidadesPermitidas,
  });

  // Serialização para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'setor': setor,
      'nome': nome,
      'especialidades': especialidadesPermitidas.join(','), // Salva como string separada por vírgulas
    };
  }

  // Desserialização para carregar do banco de dados
  factory Gabinete.fromMap(Map<String, dynamic> map) {
    return Gabinete(
      id: map['id'] as String,
      setor: map['setor'] as String,
      nome: map['nome'] as String,
      especialidadesPermitidas: (map['especialidades'] as String).split(',').map((e) => e.trim()).toList(),
    );
  }
}
