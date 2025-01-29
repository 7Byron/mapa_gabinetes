// lib/models/gabinete.dart

class Gabinete {
  final String id;
  final String setor;
  String nome;
  final List<String> especialidadesPermitidas;

  Gabinete({
    required this.id,
    required this.setor,
    required this.nome,
    required this.especialidadesPermitidas,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'setor': setor,
      'nome': nome,
      'especialidades': especialidadesPermitidas.join(','),
    };
  }

  factory Gabinete.fromMap(Map<String, dynamic> map) {
    return Gabinete(
      id: map['id'],
      setor: map['setor'],
      nome: map['nome'],
      especialidadesPermitidas:
      (map['especialidades'] as String).split(',').map((e) => e.trim()).toList(),
    );
  }
}
