import 'package:flutter/foundation.dart';
import '../models/unidade.dart';
import '../services/cache_version_service.dart';
import '../services/serie_service.dart';
import 'alocacao_cache_store.dart';

class CacheSyncResult {
  final bool seriesMudou;
  final bool alocacoesMudou;
  final bool disponibilidadesMudou;
  final bool medicosMudou;
  final bool gabinetesMudou;

  const CacheSyncResult({
    required this.seriesMudou,
    required this.alocacoesMudou,
    required this.disponibilidadesMudou,
    required this.medicosMudou,
    required this.gabinetesMudou,
  });

  bool get recarregarStatic => medicosMudou || gabinetesMudou;

  bool get recarregarDinamico =>
      seriesMudou || alocacoesMudou || disponibilidadesMudou;
}

class AlocacaoCacheSync {
  static const String _unidadeFallbackId = 'fyEj6kOXvCuL65sMfCaR';

  static final Map<String, int> _versaoSeriesPorUnidade = {};
  static final Map<String, int> _versaoAlocacoesPorUnidade = {};
  static final Map<String, int> _versaoDisponibilidadesPorUnidade = {};
  static final Map<String, int> _versaoMedicosPorUnidade = {};
  static final Map<String, int> _versaoGabinetesPorUnidade = {};
  static final Map<String, bool> _forcarServidorSeriesPorUnidade = {};

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static String _unidadeKey(Unidade? unidade) =>
      unidade?.id ?? _unidadeFallbackId;

  static bool shouldForceServerForSeries(Unidade? unidade) {
    final unidadeKey = _unidadeKey(unidade);
    return _forcarServidorSeriesPorUnidade[unidadeKey] ?? false;
  }

  static void clearForceServerForSeries(Unidade? unidade) {
    final unidadeKey = _unidadeKey(unidade);
    _forcarServidorSeriesPorUnidade[unidadeKey] = false;
  }

  static bool _atualizarVersao(
    Map<String, int> mapa,
    String unidadeKey,
    int versaoRemota,
  ) {
    final versaoLocal = mapa[unidadeKey];
    mapa[unidadeKey] = versaoRemota;
    return versaoLocal != null && versaoLocal != versaoRemota;
  }

  static Future<CacheSyncResult> sincronizarVersoes({
    Unidade? unidade,
    bool forcar = false,
  }) async {
    final unidadeKey = _unidadeKey(unidade);
    final versaoSeriesLocal = _versaoSeriesPorUnidade[unidadeKey];
    final versaoAlocacoesLocal = _versaoAlocacoesPorUnidade[unidadeKey];
    final versaoDisponibilidadesLocal =
        _versaoDisponibilidadesPorUnidade[unidadeKey];
    final versaoMedicosLocal = _versaoMedicosPorUnidade[unidadeKey];
    final versaoGabinetesLocal = _versaoGabinetesPorUnidade[unidadeKey];
    final versoes =
        await CacheVersionService.fetchVersions(unidadeId: unidade?.id);

    final versaoSeriesRemota = versoes[CacheVersionService.fieldSeries] ?? 0;
    final versaoAlocacoesRemota =
        versoes[CacheVersionService.fieldAlocacoes] ?? 0;
    final versaoDisponibilidadesRemota =
        versoes[CacheVersionService.fieldDisponibilidades] ?? 0;
    final versaoMedicosRemota = versoes[CacheVersionService.fieldMedicos] ?? 0;
    final versaoGabinetesRemota =
        versoes[CacheVersionService.fieldGabinetes] ?? 0;

    final seriesMudou = _atualizarVersao(
      _versaoSeriesPorUnidade,
      unidadeKey,
      versaoSeriesRemota,
    );
    final alocacoesMudou = _atualizarVersao(
      _versaoAlocacoesPorUnidade,
      unidadeKey,
      versaoAlocacoesRemota,
    );
    final disponibilidadesMudou = _atualizarVersao(
      _versaoDisponibilidadesPorUnidade,
      unidadeKey,
      versaoDisponibilidadesRemota,
    );
    final medicosMudou = _atualizarVersao(
      _versaoMedicosPorUnidade,
      unidadeKey,
      versaoMedicosRemota,
    );
    final gabinetesMudou = _atualizarVersao(
      _versaoGabinetesPorUnidade,
      unidadeKey,
      versaoGabinetesRemota,
    );

    final result = CacheSyncResult(
      seriesMudou: seriesMudou,
      alocacoesMudou: alocacoesMudou,
      disponibilidadesMudou: disponibilidadesMudou,
      medicosMudou: medicosMudou,
      gabinetesMudou: gabinetesMudou,
    );

    _log(
        '🔎 [CACHE] Versões $unidadeKey (remotas): series=$versaoSeriesRemota, '
        'alocs=$versaoAlocacoesRemota, disps=$versaoDisponibilidadesRemota, '
        'medicos=$versaoMedicosRemota, gabs=$versaoGabinetesRemota');
    _log(
        '🔎 [CACHE] Versões $unidadeKey (locais): series=${versaoSeriesLocal ?? 'null'}, '
        'alocs=${versaoAlocacoesLocal ?? 'null'}, disps=${versaoDisponibilidadesLocal ?? 'null'}, '
        'medicos=${versaoMedicosLocal ?? 'null'}, gabs=${versaoGabinetesLocal ?? 'null'}');
    _log(
        '🔎 [CACHE] Mudanças $unidadeKey: series=$seriesMudou, alocs=$alocacoesMudou, '
        'disps=$disponibilidadesMudou, medicos=$medicosMudou, gabs=$gabinetesMudou, '
        'forcar=$forcar');

    if (result.recarregarDinamico) {
      AlocacaoCacheStore.clearAll();
    }
    if (seriesMudou) {
      SerieService.invalidateCacheSeries(unidadeKey);
      _forcarServidorSeriesPorUnidade[unidadeKey] = true;
      _log('⚠️ [CACHE] séries mudaram para $unidadeKey, forçar servidor');
    }
    if (result.recarregarDinamico || result.recarregarStatic) {
      AlocacaoCacheStore.log(
          '🧹 [CACHE] Versões alteradas, cache limpo para $unidadeKey');
    }

    return result;
  }
}
