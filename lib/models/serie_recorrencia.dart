// lib/models/serie_recorrencia.dart

import 'dart:convert';
import 'mudanca_gabinete.dart';

/// Representa uma regra de recorrência (série) de disponibilidades/alocações
/// Em vez de criar um cartão para cada data, armazena apenas a regra
class SerieRecorrencia {
  String id;
  String medicoId;
  DateTime dataInicio; // Data de início da série
  DateTime? dataFim; // null = série infinita
  String tipo; // "Semanal", "Quinzenal", "Mensal", "Consecutivo"
  List<String> horarios; // Horários padrão da série
  String? gabineteId; // Gabinete padrão (usado antes da primeira mudança)
  List<MudancaGabinete> mudancasGabinete; // Mudanças de gabinete por período (ordenadas por dataInicio)
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
    List<MudancaGabinete>? mudancasGabinete,
    Map<String, dynamic>? parametros,
    this.ativo = true,
  }) : parametros = parametros ?? {},
       mudancasGabinete = mudancasGabinete ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicoId': medicoId,
      'dataInicio': dataInicio.toIso8601String(),
      'dataFim': dataFim?.toIso8601String(),
      'tipo': tipo,
      'horarios': horarios,
      'gabineteId': gabineteId,
      'mudancasGabinete': mudancasGabinete.map((m) => m.toMap()).toList(),
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

    // Carregar mudanças de gabinete (compatibilidade com versões antigas)
    List<MudancaGabinete> mudancasGabinete = [];
    if (map['mudancasGabinete'] != null) {
      final mudancasRaw = map['mudancasGabinete'];
      if (mudancasRaw is List) {
        mudancasGabinete = mudancasRaw
            .map((m) => MudancaGabinete.fromMap(m as Map<String, dynamic>))
            .toList();
        // Ordenar por dataInicio (mais antiga primeiro)
        mudancasGabinete.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
      }
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
      mudancasGabinete: mudancasGabinete,
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

  /// Obtém o gabineteId para uma data específica, considerando mudanças de gabinete
  /// Retorna o gabineteId da mudança mais recente que se aplica à data,
  /// ou o gabineteId padrão da série se não houver mudanças aplicáveis
  String? obterGabineteParaData(DateTime data) {
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    
    // Se não há mudanças, retornar gabinete padrão
    if (mudancasGabinete.isEmpty) {
      return gabineteId;
    }

    // Encontrar a mudança mais recente que se aplica a esta data
    // (a última mudança com dataInicio <= data)
    MudancaGabinete? mudancaAplicavel;
    for (final mudanca in mudancasGabinete) {
      final mudancaDataNormalizada = mudanca.dataInicioNormalizada;
      if (!dataNormalizada.isBefore(mudancaDataNormalizada)) {
        mudancaAplicavel = mudanca;
      } else {
        break; // Mudanças estão ordenadas, podemos parar
      }
    }

    // Se encontrou uma mudança aplicável, usar o gabineteId dela
    if (mudancaAplicavel != null) {
      return mudancaAplicavel.gabineteId;
    }

    // Caso contrário, usar o gabineteId padrão da série
    return gabineteId;
  }

  /// Adiciona ou atualiza uma mudança de gabinete a partir de uma data
  /// Remove mudanças futuras que ficam obsoletas
  void adicionarMudancaGabinete(DateTime dataInicio, String novoGabineteId) {
    final dataNormalizada = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    
    // Remover mudanças futuras que ficam obsoletas
    mudancasGabinete.removeWhere((m) => 
      m.dataInicioNormalizada.isAfter(dataNormalizada) ||
      m.dataInicioNormalizada.isAtSameMomentAs(dataNormalizada)
    );

    // Adicionar nova mudança
    mudancasGabinete.add(MudancaGabinete(
      dataInicio: dataNormalizada,
      gabineteId: novoGabineteId,
    ));

    // Ordenar por dataInicio (mais antiga primeiro)
    mudancasGabinete.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
  }
}

