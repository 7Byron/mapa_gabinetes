import '../models/serie_recorrencia.dart';

/// Numeração estável de séries do mesmo tipo.
class SerieNumeracaoUtils {
  SerieNumeracaoUtils._();

  /// Atribui números apenas às séries que ainda não os possuem.
  ///
  /// Séries antigas são ordenadas pelo timestamp do ID de criação. IDs antigos
  /// sem timestamp usam data de início e ID como desempate. Os números já
  /// persistidos nunca são alterados.
  static List<SerieRecorrencia> numerarSeriesSemNumero(
    List<SerieRecorrencia> series,
  ) {
    final alteradas = <SerieRecorrencia>[];
    final porTipo = <String, List<SerieRecorrencia>>{};

    for (final serie in series.where((s) => s.ativo)) {
      porTipo.putIfAbsent(serie.tipo, () => []).add(serie);
    }

    for (final grupo in porTipo.values) {
      grupo.sort(_compararPorCriacao);
      final numerosUsados = grupo
          .map((s) => s.numeroNoTipo)
          .whereType<int>()
          .where((numero) => numero > 0)
          .toSet();
      var proximoNumero = numerosUsados.isEmpty
          ? 1
          : numerosUsados.reduce((a, b) => a > b ? a : b) + 1;

      for (final serie in grupo) {
        if (serie.numeroNoTipo != null) continue;
        while (numerosUsados.contains(proximoNumero)) {
          proximoNumero++;
        }
        serie.numeroNoTipo = proximoNumero;
        numerosUsados.add(proximoNumero);
        alteradas.add(serie);
        proximoNumero++;
      }
    }

    return alteradas;
  }

  /// Próximo número que pode ser usado por uma nova série deste tipo.
  static int proximoNumero(
    String tipo,
    Iterable<SerieRecorrencia> series,
  ) {
    final numeros = series
        .where((s) => s.ativo && s.tipo == tipo)
        .map((s) => s.numeroNoTipo)
        .whereType<int>()
        .where((numero) => numero > 0);
    if (numeros.isEmpty) return 1;
    return numeros.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Rótulo apresentado ao utilizador. O numeral só aparece quando existem
  /// várias séries do mesmo tipo para o médico.
  static String rotulo(
    SerieRecorrencia serie,
    Iterable<SerieRecorrencia> todasSeries,
  ) {
    final quantidadeMesmoTipo =
        todasSeries.where((s) => s.ativo && s.tipo == serie.tipo).length;
    if (quantidadeMesmoTipo <= 1) return serie.tipo;

    final numero = serie.numeroNoTipo ??
        _numeroCalculadoSemPersistencia(serie, todasSeries);
    return '${serie.tipo} ${paraRomano(numero)}';
  }

  static int _numeroCalculadoSemPersistencia(
    SerieRecorrencia serie,
    Iterable<SerieRecorrencia> todasSeries,
  ) {
    final grupo = todasSeries
        .where((s) => s.ativo && s.tipo == serie.tipo)
        .toList()
      ..sort(_compararPorCriacao);
    final index = grupo.indexWhere((s) => s.id == serie.id);
    return index < 0 ? 1 : index + 1;
  }

  static int _compararPorCriacao(
    SerieRecorrencia a,
    SerieRecorrencia b,
  ) {
    final timestampA = _timestampDoId(a.id);
    final timestampB = _timestampDoId(b.id);
    if (timestampA != null && timestampB != null) {
      final comparacaoTimestamp = timestampA.compareTo(timestampB);
      if (comparacaoTimestamp != 0) return comparacaoTimestamp;
    } else if (timestampA != null) {
      return -1;
    } else if (timestampB != null) {
      return 1;
    }

    final comparacaoData = a.dataInicio.compareTo(b.dataInicio);
    if (comparacaoData != 0) return comparacaoData;
    return a.id.compareTo(b.id);
  }

  static int? _timestampDoId(String id) {
    final match = RegExp(r'^serie_(\d+)$').firstMatch(id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String paraRomano(int numero) {
    if (numero <= 0) return numero.toString();
    const valores = <int, String>{
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    var restante = numero;
    final resultado = StringBuffer();
    for (final entrada in valores.entries) {
      while (restante >= entrada.key) {
        resultado.write(entrada.value);
        restante -= entrada.key;
      }
    }
    return resultado.toString();
  }
}
