import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseInitService {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _initialized = true;
    } catch (_) {
      // Ignorar erros de inicialização (ex.: ambiente de teste sem canais nativos)
    }
  }
}
