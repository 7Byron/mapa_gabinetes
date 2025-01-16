class Reserva {
  final String id;
  final String gabineteId;
  final String medicoId;
  final DateTime data;
  final String horario;

  Reserva({
    required this.id,
    required this.gabineteId,
    required this.medicoId,
    required this.data,
    required this.horario,
  });

  // Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gabineteId': gabineteId,
      'medicoId': medicoId,
      'data': data.toIso8601String(),
      'horario': horario,
    };
  }

  // Criar a partir de JSON
  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: json['id'] as String,
      gabineteId: json['gabineteId'] as String,
      medicoId: json['medicoId'] as String,
      data: DateTime.parse(json['data'] as String),
      horario: json['horario'] as String,
    );
  }
}
