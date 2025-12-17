import 'package:flutter/foundation.dart' show kDebugMode;

/// Logger de debug que só funciona em modo debug
class DebugLogger {
  static void log({
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      print('🔍 [$location] $message$dataStr');
    }
  }
}
