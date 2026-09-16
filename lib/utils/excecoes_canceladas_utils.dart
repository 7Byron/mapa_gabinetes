import 'dart:convert';

import 'series_helper.dart';

/// Um cancelamento pertence a uma série, nunca ao dia inteiro do médico.
class ExcecoesCanceladasUtils {
  static String chave(String medicoId, String serieId, DateTime data) {
    return jsonEncode([
      medicoId,
      SeriesHelper.extrairSerieIdDeDisponibilidade(serieId),
      data.year,
      data.month,
      data.day,
    ]);
  }

  static bool contem(Set<String> cancelamentos, String medicoId,
      String cartaoId, DateTime data) {
    // Cartões únicos não pertencem à série cancelada.
    if (!cartaoId.startsWith('serie_')) return false;
    return cancelamentos.contains(chave(medicoId, cartaoId, data));
  }
}
