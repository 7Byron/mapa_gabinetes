class Gabinete {
  final String id;
  final String setor;
  late final String nome;
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

  // Para agrupar a lista por sectores
  Map<String, List<Gabinete>> agruparPorSetor(List<Gabinete> gabinetes) {
    Map<String, List<Gabinete>> gabinetesPorSetor = {};
    for (var gabinete in gabinetes) {
      if (!gabinetesPorSetor.containsKey(gabinete.setor)) {
        gabinetesPorSetor[gabinete.setor] = [];
      }
      gabinetesPorSetor[gabinete.setor]!.add(gabinete);
    }
    return gabinetesPorSetor;
  }



}
