/// Stub implementation of DebugLogger for platforms that don't support it
class DebugLogger {
  static void log({
    required String location,
    required String message,
    Map<String, dynamic>? data,
  }) {
    // No-op in stub implementation
  }
}
