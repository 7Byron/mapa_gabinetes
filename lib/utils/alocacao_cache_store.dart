import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/medico.dart';

class AlocacaoCacheStore {
  static final Map<String, List<Disponibilidade>> cacheDispPorDia = {};
  static final Map<String, List<Alocacao>> cacheAlocPorDia = {};
  static final Map<String, DateTime> cacheAtualizadoEmPorDia = {};
  static final Set<String> cacheInvalidadoPorDia = {};
  static final Map<String, List<ExcecaoSerie>> cacheExcecoes = {};
  static final Map<String, List<Alocacao>> cacheAlocSeriesPorDia = {};
  static final Map<String, List<Medico>> cacheMedicosDisponiveisPorDia = {};
  static final Map<String, Set<String>> cacheExcecoesCanceladasPorDia = {};

  static int _cacheHits = 0;
  static int _cacheMisses = 0;
  static int _cacheInvalidados = 0;
  static int _cacheWrites = 0;

  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static String keyDia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool isCacheInvalidado(DateTime day) {
    final key = keyDia(day);
    return cacheInvalidadoPorDia.contains(key);
  }

  static void updateCacheForDay({
    required DateTime day,
    List<Disponibilidade>? disponibilidades,
    List<Alocacao>? alocacoes,
    bool forcarValido = false,
  }) {
    final key = keyDia(day);
    final estavaInvalidado = cacheInvalidadoPorDia.contains(key);
    if (disponibilidades != null) {
      cacheDispPorDia[key] = List<Disponibilidade>.from(disponibilidades);
      if (forcarValido || !estavaInvalidado) {
        cacheInvalidadoPorDia.remove(key);
      }
    }
    if (alocacoes != null) {
      cacheAlocPorDia[key] = List<Alocacao>.from(alocacoes);
      if (forcarValido || !estavaInvalidado) {
        cacheInvalidadoPorDia.remove(key);
      }
    }
    if (disponibilidades != null || alocacoes != null) {
      cacheAtualizadoEmPorDia[key] = DateTime.now();
      _cacheWrites++;
    }
    log(
        '💾 [CACHE] Cache atualizado para dia $key: ${disponibilidades?.length ?? 0} disps, ${alocacoes?.length ?? 0} alocs (estava invalidado: $estavaInvalidado, forçar válido: $forcarValido, agora válido: ${!cacheInvalidadoPorDia.contains(key)})');
  }

  static List<Disponibilidade>? getDisponibilidades(DateTime day) {
    final key = keyDia(day);
    if (cacheInvalidadoPorDia.contains(key)) return null;
    return cacheDispPorDia[key];
  }

  static List<Alocacao>? getAlocacoes(DateTime day) {
    final key = keyDia(day);
    if (cacheInvalidadoPorDia.contains(key)) return null;
    return cacheAlocPorDia[key];
  }

  static List<Alocacao>? getAlocacoesComSeries(DateTime day) {
    final key = keyDia(day);
    if (cacheInvalidadoPorDia.contains(key)) return null;
    return cacheAlocSeriesPorDia[key];
  }

  static void updateAlocacoesComSeries(DateTime day, List<Alocacao> alocacoes) {
    final key = keyDia(day);
    cacheAlocSeriesPorDia[key] = List<Alocacao>.from(alocacoes);
  }

  static List<Medico>? getMedicosDisponiveis(DateTime day) {
    final key = keyDia(day);
    if (cacheInvalidadoPorDia.contains(key)) return null;
    return cacheMedicosDisponiveisPorDia[key];
  }

  static void updateMedicosDisponiveis(DateTime day, List<Medico> medicos) {
    final key = keyDia(day);
    cacheMedicosDisponiveisPorDia[key] = List<Medico>.from(medicos);
  }

  static Set<String>? getExcecoesCanceladasParaDia(DateTime day) {
    final key = keyDia(day);
    if (cacheInvalidadoPorDia.contains(key)) return null;
    return cacheExcecoesCanceladasPorDia[key];
  }

  static void updateExcecoesCanceladasParaDia(
      DateTime day, Set<String> excecoes) {
    final key = keyDia(day);
    cacheExcecoesCanceladasPorDia[key] = Set<String>.from(excecoes);
  }

  static void registrarCacheHit(String key) {
    _cacheHits++;
  }

  static void registrarCacheMiss(String key, {bool invalidado = false}) {
    _cacheMisses++;
    if (invalidado) {
      _cacheInvalidados++;
    }
  }

  static void logResumo() {
    log('📊 [CACHE] Resumo diário: hits=$_cacheHits, misses=$_cacheMisses, '
        'invalidados=$_cacheInvalidados, writes=$_cacheWrites');
  }

  static void resetResumo() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _cacheInvalidados = 0;
    _cacheWrites = 0;
  }

  static void invalidateCacheForDay(DateTime day) {
    final key = keyDia(day);
    final tinhaCache =
        cacheDispPorDia.containsKey(key) || cacheAlocPorDia.containsKey(key);
    final jaInvalidado = cacheInvalidadoPorDia.contains(key);
    cacheDispPorDia.remove(key);
    cacheAlocPorDia.remove(key);
    cacheAtualizadoEmPorDia.remove(key);
    cacheAlocSeriesPorDia.remove(key);
    cacheMedicosDisponiveisPorDia.remove(key);
    cacheExcecoesCanceladasPorDia.remove(key);
    cacheInvalidadoPorDia.add(key);
    cacheExcecoes.clear();
    if (kDebugMode && tinhaCache) {
      final trace = StackTrace.current
          .toString()
          .split('\n')
          .skip(1)
          .take(5)
          .join('\n');
      log(
          '🧹 [CACHE] invalidateCacheForDay $key (jaInvalidado=$jaInvalidado)\n$trace');
    }
  }

  static void invalidateCacheFromDate(DateTime fromDate) {
    final keysToRemove = <String>{};
    final fromKey = keyDia(fromDate);
    for (final key in cacheDispPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in cacheAlocSeriesPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in cacheMedicosDisponiveisPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in cacheExcecoesCanceladasPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      cacheDispPorDia.remove(key);
      cacheAlocPorDia.remove(key);
      cacheAtualizadoEmPorDia.remove(key);
      cacheAlocSeriesPorDia.remove(key);
      cacheMedicosDisponiveisPorDia.remove(key);
      cacheExcecoesCanceladasPorDia.remove(key);
      cacheInvalidadoPorDia.add(key);
    }
    cacheExcecoes.clear();
    if (kDebugMode && keysToRemove.isNotEmpty) {
      final sample = keysToRemove.take(3).join(', ');
      final trace = StackTrace.current
          .toString()
          .split('\n')
          .skip(1)
          .take(5)
          .join('\n');
      log(
          '🧹 [CACHE] invalidateCacheFromDate $fromKey (total=${keysToRemove.length}, sample=$sample)\n$trace');
    }
  }

  static void clearAll() {
    cacheDispPorDia.clear();
    cacheAlocPorDia.clear();
    cacheAtualizadoEmPorDia.clear();
    cacheInvalidadoPorDia.clear();
    cacheExcecoes.clear();
    cacheAlocSeriesPorDia.clear();
    cacheMedicosDisponiveisPorDia.clear();
    cacheExcecoesCanceladasPorDia.clear();
  }
}
