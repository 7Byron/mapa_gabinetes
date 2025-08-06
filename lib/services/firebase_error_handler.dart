import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/network_utils.dart';

class FirebaseErrorHandler {
  static bool _isInitialized = false;
  static bool _hasFirebaseIssues = false;

  /// Verifica se há problemas com o Firebase
  static bool get hasFirebaseIssues => _hasFirebaseIssues;

  /// Inicializa o handler de erros do Firebase
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Por padrão, assumir que o Firebase está OK
    // Só marcar como problema se houver erros específicos durante o uso
    _hasFirebaseIssues = false;
    _isInitialized = true;
  }

  /// Executa uma operação do Firestore com tratamento de erro
  static Future<T?> executeWithErrorHandling<T>(Future<T> Function() operation,
      {String? operationName}) async {
    try {
      return await operation();
    } catch (e) {
      print('❌ Erro na operação ${operationName ?? 'Firestore'}: $e');

      // Se for erro de rede, marcar como problema de Firebase
      if (_isNetworkError(e)) {
        _hasFirebaseIssues = true;
        print('⚠️ Problema de rede detectado - Firebase em modo offline');
      }

      return null;
    }
  }

  /// Verifica se o erro é relacionado à rede
  static bool _isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'permission-denied' ||
          error.message?.contains('network') == true;
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unavailable');
  }

  /// Retorna uma mensagem de erro apropriada
  static String getErrorMessage(dynamic error) {
    if (_isNetworkError(error)) {
      return 'Problemas de conectividade. Verifique a sua ligação à internet.';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Acesso negado. Verifique as permissões.';
        case 'not-found':
          return 'Recurso não encontrado.';
        case 'already-exists':
          return 'O recurso já existe.';
        default:
          return 'Erro: ${error.message}';
      }
    }

    return 'Ocorreu um erro inesperado.';
  }

  /// Verifica se deve usar dados locais em vez do Firebase
  static bool shouldUseLocalData() {
    return _hasFirebaseIssues || NetworkUtils.hasNetworkIssues;
  }
}
