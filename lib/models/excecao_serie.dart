// lib/models/excecao_serie.dart

/// Representa uma exceção a uma regra de recorrência
/// Usado para cancelar ou modificar uma data específica de uma série
class ExcecaoSerie {
  String id;
  String serieId; // ID da série à qual pertence
  DateTime data; // Data específica da exceção
  bool cancelada; // true = não acontece nesta data
  List<String>? horarios; // null = usa horários da série, senão sobrescreve
  String? gabineteId; // null = usa gabinete da série, senão sobrescreve

  ExcecaoSerie({
    required this.id,
    required this.serieId,
    required this.data,
    this.cancelada = false,
    this.horarios,
    this.gabineteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serieId': serieId,
      'data': data.toIso8601String(),
      'cancelada': cancelada,
      'horarios': horarios,
      'gabineteId': gabineteId,
    };
  }

  static ExcecaoSerie fromMap(Map<String, dynamic> map) {
    final horariosRaw = map['horarios'];
    List<String>? horarios;
    if (horariosRaw != null) {
      if (horariosRaw is List) {
        horarios = (horariosRaw).cast<String>();
      } else {
        horarios = null;
      }
    }

    return ExcecaoSerie(
      id: map['id']?.toString() ?? '',
      serieId: map['serieId']?.toString() ?? '',
      data: map['data'] != null
          ? DateTime.parse(map['data'].toString())
          : DateTime.now(),
      cancelada: map['cancelada'] ?? false,
      horarios: horarios,
      gabineteId: map['gabineteId']?.toString(),
    );
  }
}

