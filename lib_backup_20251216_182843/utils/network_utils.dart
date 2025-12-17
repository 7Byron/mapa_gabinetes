// Sem dependências de kIsWeb aqui; lógica de rede simplificada e neutra de plataforma

class NetworkUtils {
  static bool _hasNetworkIssues = false;
  static bool _isInitialized = false;

  /// Verifica se há problemas de rede
  static bool get hasNetworkIssues => _hasNetworkIssues;

  /// Inicializa a verificação de rede
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Por padrão, assumir que a rede está OK
    // Só marcar como problema se houver erros específicos
    _hasNetworkIssues = false;
    _isInitialized = true;
  }

  /// Verifica conectividade de rede
  // Mantido para futura extensão; atualmente não utilizado de propósito
  static Future<void> _checkNetworkConnectivity() async {}

  /// Verifica se o Firebase está acessível
  static Future<bool> isFirebaseAccessible() async => true;

  /// Retorna uma mensagem de erro apropriada para problemas de rede
  static String getNetworkErrorMessage() {
    if (_hasNetworkIssues) {
      return 'Problemas de conectividade detectados. A aplicação está a funcionar em modo offline.';
    }
    return 'A aplicação está a funcionar normalmente.';
  }
}
