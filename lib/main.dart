import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/selecao_unidade_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase inicializado com sucesso');
  } catch (e, stackTrace) {
    debugPrint('❌ Erro ao inicializar Firebase: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continuar mesmo com erro para não bloquear o app
  }

  // Inicializar dados de locale para formatação de datas
  try {
    await initializeDateFormatting('pt_PT', null);
    debugPrint('✅ Locale pt_PT inicializado com sucesso');
  } catch (e) {
    debugPrint('⚠️ Erro ao inicializar locale pt_PT: $e');
    // Continuar mesmo com erro
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa de Gabinetes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: MyAppTheme.azulEscuro,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MyAppTheme.azulEscuro,
          primary: MyAppTheme.azulEscuro,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: MyAppTheme.azulEscuro,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Montserrat',
      ),
      home: const SelecaoUnidadeScreen(),
    );
  }
}
