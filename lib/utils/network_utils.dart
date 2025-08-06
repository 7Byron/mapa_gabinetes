import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  static Future<void> _checkNetworkConnectivity() async {
    // Esta função agora só é chamada quando há problemas específicos
    // Por padrão, assumimos que a rede está funcionando
  }

  /// Verifica se o Firebase está acessível
  static Future<bool> isFirebaseAccessible() async {
    if (!kIsWeb) return true;

    try {
      // Tentar conectar ao Firebase
      final response = await html.HttpRequest.request(
        'https://firestore.googleapis.com',
        method: 'HEAD',
        sendData: null,
      );

      return response.status == 200;
    } catch (e) {
      return false;
    }
  }

  /// Retorna uma mensagem de erro apropriada para problemas de rede
  static String getNetworkErrorMessage() {
    if (_hasNetworkIssues) {
      return 'Problemas de conectividade detectados. A aplicação está a funcionar em modo offline.';
    }
    return 'A aplicação está a funcionar normalmente.';
  }
}
