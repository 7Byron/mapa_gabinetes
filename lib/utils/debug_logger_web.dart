import 'package:flutter/foundation.dart' show kDebugMode;

/// Web-specific implementation of DebugLogger
class DebugLogger {
  static void log({
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      final dataStr = data != null ? ' | Data: $data' : '';
      // Use console.log for web
      print('🔍 [$location] $message$dataStr');
    }
  }
}
