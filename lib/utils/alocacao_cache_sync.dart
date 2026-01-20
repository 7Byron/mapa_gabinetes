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
  static const Duration _intervaloVerificacaoVersao = Duration(seconds: 60);

  static final Map<String, int> _versaoSeriesPorUnidade = {};
  static final Map<String, int> _versaoAlocacoesPorUnidade = {};
  static final Map<String, int> _versaoDisponibilidadesPorUnidade = {};
  static final Map<String, int> _versaoMedicosPorUnidade = {};
  static final Map<String, int> _versaoGabinetesPorUnidade = {};
  static final Map<String, DateTime> _ultimaVerificacaoVersao = {};
  static final Map<String, bool> _forcarServidorSeriesPorUnidade = {};

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
    final ultima = _ultimaVerificacaoVersao[unidadeKey];
    if (!forcar &&
        ultima != null &&
        DateTime.now().difference(ultima) < _intervaloVerificacaoVersao) {
      return const CacheSyncResult(
        seriesMudou: false,
        alocacoesMudou: false,
        disponibilidadesMudou: false,
        medicosMudou: false,
        gabinetesMudou: false,
      );
    }

    _ultimaVerificacaoVersao[unidadeKey] = DateTime.now();
    final versoes =
        await CacheVersionService.fetchVersions(unidadeId: unidade?.id);

    final seriesMudou = _atualizarVersao(
      _versaoSeriesPorUnidade,
      unidadeKey,
      versoes[CacheVersionService.fieldSeries] ?? 0,
    );
    final alocacoesMudou = _atualizarVersao(
      _versaoAlocacoesPorUnidade,
      unidadeKey,
      versoes[CacheVersionService.fieldAlocacoes] ?? 0,
    );
    final disponibilidadesMudou = _atualizarVersao(
      _versaoDisponibilidadesPorUnidade,
      unidadeKey,
      versoes[CacheVersionService.fieldDisponibilidades] ?? 0,
    );
    final medicosMudou = _atualizarVersao(
      _versaoMedicosPorUnidade,
      unidadeKey,
      versoes[CacheVersionService.fieldMedicos] ?? 0,
    );
    final gabinetesMudou = _atualizarVersao(
      _versaoGabinetesPorUnidade,
      unidadeKey,
      versoes[CacheVersionService.fieldGabinetes] ?? 0,
    );

    final result = CacheSyncResult(
      seriesMudou: seriesMudou,
      alocacoesMudou: alocacoesMudou,
      disponibilidadesMudou: disponibilidadesMudou,
      medicosMudou: medicosMudou,
      gabinetesMudou: gabinetesMudou,
    );

    if (result.recarregarDinamico) {
      AlocacaoCacheStore.clearAll();
    }
    if (seriesMudou) {
      SerieService.invalidateCacheSeries(unidadeKey);
      _forcarServidorSeriesPorUnidade[unidadeKey] = true;
    }
    if (result.recarregarDinamico || result.recarregarStatic) {
      AlocacaoCacheStore.log(
          '🧹 [CACHE] Versões alteradas, cache limpo para $unidadeKey');
    }

    return result;
  }
}
