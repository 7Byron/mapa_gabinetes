import 'package:flutter/foundation.dart';

/// Sistema de log otimizado para anúncios
/// Só executa logs em modo debug para melhor performance em produção
class AdLogger {
  static const String _prefix = '🎯 AdMob';
  static const bool _enableDetailedLogs = kDebugMode;

  /// Log de sucesso (verde)
  static void success(String tag, String message) {
    if (_enableDetailedLogs) {
      debugPrint('$_prefix ✅ [$tag] $message');
    }
  }

  /// Log de erro (vermelho)
  static void error(String tag, String message) {
    if (_enableDetailedLogs) {
      debugPrint('$_prefix ❌ [$tag] $message');
    }
  }

  /// Log de aviso (amarelo)
  static void warning(String tag, String message) {
    if (_enableDetailedLogs) {
      debugPrint('$_prefix ⚠️ [$tag] $message');
    }
  }

  /// Log de informação (azul)
  static void info(String tag, String message) {
    if (_enableDetailedLogs) {
      debugPrint('$_prefix ℹ️ [$tag] $message');
    }
  }

  /// Log de carregamento (loading)
  static void loading(String service, String message) {
    if (kDebugMode) {
      debugPrint('$_prefix ⏳ [$service] $message');
    }
  }

  /// Log específico para banner
  static void banner(String message, {bool isError = false}) {
    if (isError) {
      error('Banner', message);
    } else {
      success('Banner', message);
    }
  }

  /// Log específico para interstitial
  static void interstitial(String message, {bool isError = false}) {
    if (isError) {
      error('Interstitial', message);
    } else {
      success('Interstitial', message);
    }
  }

  /// Log específico para rewarded
  static void rewarded(String message, {bool isError = false}) {
    if (isError) {
      error('Rewarded', message);
    } else {
      success('Rewarded', message);
    }
  }

  /// Log específico para native
  static void native(String message, {bool isError = false}) {
    if (isError) {
      error('Native', message);
    } else {
      success('Native', message);
    }
  }

  /// Log específico para app open
  static void appOpen(String message, {bool isError = false}) {
    if (isError) {
      error('AppOpen', message);
    } else {
      success('AppOpen', message);
    }
  }

  /// Log de receita paga (onPaidEvent)
  static void paid({
    required String adType,
    required String currencyCode,
    required int valueMicros,
    String? precision,
  }) {
    if (_enableDetailedLogs) {
      final double value = valueMicros / 1000000.0;
      debugPrint('$_prefix 💰 [$adType] $value $currencyCode'
          '${precision != null ? ' (precision: $precision)' : ''}');
    }
  }
}

/// Extension para facilitar uso nos widgets
extension AdLoggerExtension on String {
  void logBannerSuccess() => AdLogger.banner(this);
  void logBannerError() => AdLogger.banner(this, isError: true);
  void logInterstitialSuccess() => AdLogger.interstitial(this);
  void logInterstitialError() => AdLogger.interstitial(this, isError: true);
  void logRewardedSuccess() => AdLogger.rewarded(this);
  void logRewardedError() => AdLogger.rewarded(this, isError: true);
}
