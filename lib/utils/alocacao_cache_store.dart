import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';

class AlocacaoCacheStore {
  static final Map<String, List<Disponibilidade>> cacheDispPorDia = {};
  static final Map<String, List<Alocacao>> cacheAlocPorDia = {};
  static final Map<String, DateTime> cacheAtualizadoEmPorDia = {};
  static final Set<String> cacheInvalidadoPorDia = {};
  static final Map<String, List<ExcecaoSerie>> cacheExcecoes = {};

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
    cacheDispPorDia.remove(key);
    cacheAlocPorDia.remove(key);
    cacheAtualizadoEmPorDia.remove(key);
    cacheInvalidadoPorDia.add(key);
    cacheExcecoes.clear();
  }

  static void invalidateCacheFromDate(DateTime fromDate) {
    final keysToRemove = <String>[];
    final fromKey = keyDia(fromDate);
    for (final key in cacheDispPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      cacheDispPorDia.remove(key);
      cacheAlocPorDia.remove(key);
      cacheAtualizadoEmPorDia.remove(key);
      cacheInvalidadoPorDia.add(key);
    }
    cacheExcecoes.clear();
  }

  static void clearAll() {
    cacheDispPorDia.clear();
    cacheAlocPorDia.clear();
    cacheAtualizadoEmPorDia.clear();
    cacheInvalidadoPorDia.clear();
    cacheExcecoes.clear();
  }
}
