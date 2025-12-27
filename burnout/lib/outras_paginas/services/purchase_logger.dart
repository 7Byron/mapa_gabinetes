import 'package:flutter/foundation.dart';

/// Sistema de logs otimizado para In-App Purchases
/// Zero impacto em produção, logs detalhados em debug
class PurchaseLogger {
  static const String _prefix = '💳 InAppPurchase';

  /// Log informativo
  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint('$_prefix >> ℹ️ $message');
  }

  /// Log de sucesso
  static void success(String message) {
    if (!kDebugMode) return;
    debugPrint('$_prefix >> ✅ $message');
  }

  /// Log de aviso
  static void warning(String message, [Object? error]) {
    if (!kDebugMode) return;
    final errorText = error != null ? ' | Error: $error' : '';
    debugPrint('$_prefix >> ⚠️ $message$errorText');
  }

  /// Log de erro
  static void error(String message, [Object? error]) {
    if (!kDebugMode) return;
    final errorText = error != null ? ' | Error: $error' : '';
    debugPrint('$_prefix >> ❌ $message$errorText');
  }

  /// Log de transação
  static void transaction(String productId, String status, [String? details]) {
    if (!kDebugMode) return;
    final detailsText = details != null ? ' | $details' : '';
    debugPrint(
        '$_prefix >> 💰 Product: $productId | Status: $status$detailsText');
  }

  /// Log de conectividade
  static void connectivity(bool isOnline) {
    if (!kDebugMode) return;
    final status = isOnline ? 'ONLINE' : 'OFFLINE';
    final icon = isOnline ? '🌐' : '📵';
    debugPrint('$_prefix >> $icon Network: $status');
  }

  /// Log de status do usuário
  static void userStatus(String message) {
    if (!kDebugMode) return;
    debugPrint('$_prefix >> 👤 $message');
  }
}
