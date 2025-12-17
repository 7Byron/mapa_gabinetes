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
    // Trata campos nulos com valores padrão
    final id = map['id'] as String? ?? '';
    final setor = map['setor'] as String? ?? '';
    final nome = map['nome'] as String? ?? '';
    
    final especialidadesStr = map['especialidades'] as String? ?? '';
    final especialidades = especialidadesStr.isNotEmpty 
        ? especialidadesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
        
    return Gabinete(
      id: id,
      setor: setor,
      nome: nome,
      especialidadesPermitidas: especialidades,
    );
  }
}
