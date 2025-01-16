import 'disponibilidade.dart'; // Importa a classe Disponibilidade

class Medico {
  final String id; // Identificador único
  final String nome; // Nome do médico
  final String especialidade; // Ex: 'Cardiologia'
  final List<Disponibilidade> disponibilidades; // Lista de disponibilidades
  final List<PeriodoIndisponibilidade> ferias; // Ex: férias ou indisponibilidade

  Medico({
    required this.id,
    required this.nome,
    required this.especialidade,
    required this.disponibilidades,
    required this.ferias,
  });

  /// Cria um objeto [Medico] a partir de um Map
  factory Medico.fromMap(Map<String, dynamic> map) {
    return Medico(
      id: map['id'],
      nome: map['nome'],
      especialidade: map['especialidade'],
      disponibilidades: (map['disponibilidades'] as List)
          .map((d) => Disponibilidade.fromMap(d))
          .toList(),
      ferias: (map['ferias'] as List)
          .map((f) => PeriodoIndisponibilidade.fromMap(f))
          .toList(),
    );
  }

  /// Converte o objeto [Medico] em um Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'especialidade': especialidade,
      'disponibilidades': disponibilidades.map((d) => d.toMap(id)).toList(),
      'ferias': ferias.map((f) => f.toMap()).toList(),
    };
  }
}

/// Classe que representa períodos de férias ou indisponibilidade
class PeriodoIndisponibilidade {
  final DateTime inicio; // Data de início da indisponibilidade
  final DateTime fim; // Data de término da indisponibilidade

  PeriodoIndisponibilidade({
    required this.inicio,
    required this.fim,
  });

  /// Valida se o período é válido (início antes do fim)
  bool validar() {
    if (inicio.isAfter(fim)) {
      throw Exception('A data de início deve ser anterior à data de fim.');
    }
    return true;
  }

  /// Cria um objeto [PeriodoIndisponibilidade] a partir de um Map
  factory PeriodoIndisponibilidade.fromMap(Map<String, dynamic> map) {
    return PeriodoIndisponibilidade(
      inicio: DateTime.parse(map['inicio']),
      fim: DateTime.parse(map['fim']),
    );
  }

  /// Converte o objeto [PeriodoIndisponibilidade] em um Map
  Map<String, dynamic> toMap() {
    return {
      'inicio': inicio.toIso8601String(),
      'fim': fim.toIso8601String(),
    };
  }
}
