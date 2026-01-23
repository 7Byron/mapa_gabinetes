// lib/models/mudanca_gabinete.dart

/// Representa uma mudança de gabinete a partir de uma data específica
/// Usado para armazenar apenas as mudanças de gabinete por período,
/// evitando criar exceções para cada dia individual
class MudancaGabinete {
  DateTime dataInicio; // Data a partir da qual o gabinete muda
  String gabineteId; // Novo gabineteId a partir desta data

  MudancaGabinete({
    required this.dataInicio,
    required this.gabineteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'dataInicio': dataInicio.toIso8601String(),
      'gabineteId': gabineteId,
    };
  }

  static MudancaGabinete fromMap(Map<String, dynamic> map) {
    final dataRaw = map['dataInicio'] != null
        ? DateTime.parse(map['dataInicio'].toString())
        : DateTime.now();
    final dataNormalizada =
        DateTime(dataRaw.year, dataRaw.month, dataRaw.day);
    return MudancaGabinete(
      dataInicio: dataNormalizada,
      gabineteId: map['gabineteId']?.toString() ?? '',
    );
  }

  /// Normaliza a data para comparação (apenas ano, mês, dia)
  DateTime get dataInicioNormalizada {
    return DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
  }
}
