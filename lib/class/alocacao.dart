class Alocacao {
  String id;
  String medicoId;
  String gabineteId;
  DateTime data;
  String horarioInicio;
  String horarioFim;

  Alocacao({
    required this.id,
    required this.medicoId,
    required this.gabineteId,
    required this.data,
    required this.horarioInicio,
    required this.horarioFim,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicoId': medicoId,
      'gabineteId': gabineteId,
      'data': data.toIso8601String(),
      'horarioInicio': horarioInicio,
      'horarioFim': horarioFim,
    };
  }

  factory Alocacao.fromMap(Map<String, dynamic> map) {
    return Alocacao(
      id: map['id'],
      medicoId: map['medicoId'],
      gabineteId: map['gabineteId'],
      data: DateTime.parse(map['data']),
      horarioInicio: map['horarioInicio'],
      horarioFim: map['horarioFim'],
    );
  }
}