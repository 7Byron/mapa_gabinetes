// lib/models/serie_recorrencia.dart

import 'dart:convert';

/// Representa uma regra de recorrência (série) de disponibilidades/alocações
/// Em vez de criar um cartão para cada data, armazena apenas a regra
class SerieRecorrencia {
  String id;
  String medicoId;
  DateTime dataInicio; // Data de início da série
  DateTime? dataFim; // null = série infinita
  String tipo; // "Semanal", "Quinzenal", "Mensal", "Consecutivo"
  List<String> horarios; // Horários padrão da série
  String? gabineteId; // Se já estiver alocado (null = não alocado)
  Map<String, dynamic> parametros; // Parâmetros específicos da série
  bool ativo; // Se a série está ativa

  SerieRecorrencia({
    required this.id,
    required this.medicoId,
    required this.dataInicio,
    this.dataFim,
    required this.tipo,
    required this.horarios,
    this.gabineteId,
    Map<String, dynamic>? parametros,
    this.ativo = true,
  }) : parametros = parametros ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicoId': medicoId,
      'dataInicio': dataInicio.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'tipo': tipo,
      'horarios': horarios,
      'gabineteId': gabineteId,
      'parametros': parametros,
      'ativo': ativo,
    };
  }

  static SerieRecorrencia fromMap(Map<String, dynamic> map) {
    final horariosRaw = map['horarios'];
    List<String> horarios;
    if (horariosRaw is String) {
      try {
        horarios = (jsonDecode(horariosRaw) as List).cast<String>();
      } catch (e) {
        horarios = [];
      }
    } else if (horariosRaw is List) {
      horarios = (horariosRaw).cast<String>();
    } else {
      horarios = [];
    }

    final parametrosRaw = map['parametros'];
    Map<String, dynamic> parametros;
    if (parametrosRaw is Map) {
      parametros = Map<String, dynamic>.from(parametrosRaw);
    } else {
      parametros = {};
    }

    return SerieRecorrencia(
      id: map['id']?.toString() ?? '',
      medicoId: map['medicoId']?.toString() ?? '',
      dataInicio: map['dataInicio'] != null
          ? DateTime.parse(map['dataInicio'].toString())
          : DateTime.now(),
      dataFim: map['dataFim'] != null
          ? DateTime.parse(map['dataFim'].toString())
          : null,
      tipo: map['tipo']?.toString() ?? 'Semanal',
      horarios: horarios,
      gabineteId: map['gabineteId']?.toString(),
      parametros: parametros,
      ativo: map['ativo'] ?? true,
    );
  }

  /// Verifica se a série está ativa em uma data específica
  bool estaAtivaEm(DateTime data) {
    if (!ativo) return false;
    if (data.isBefore(dataInicio)) return false;
    if (dataFim != null && data.isAfter(dataFim!)) return false;
    return true;
  }
}

