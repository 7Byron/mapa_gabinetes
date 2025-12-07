import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapa_gabinetes/screens/selecao_unidade_screen.dart';
import 'package:mapa_gabinetes/utils/web_gl_support.dart';
import 'package:mapa_gabinetes/utils/network_utils.dart';
import 'package:mapa_gabinetes/services/firebase_error_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
// import 'debug_firebase.dart'; // Debug temporário - DESATIVADO

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar dados de locale para português
  await initializeDateFormatting('pt_PT', null);
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ativa cache offline do Firestore (com sync entre abas no Web)
  try {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true),
    );
    print('✅ Firestore persistence habilitada.');
  } catch (e) {
    // Em alguns ambientes pode já estar ativa ou não ser suportada; apenas loga
    print('ℹ️ Não foi possível ativar persistence (ignorado): $e');
  }

  // Inicializar verificação de rede e Firebase
  await NetworkUtils.initialize();
  await FirebaseErrorHandler.initialize();

  // Verificar WebGL e logar o status
  final webglAvailable = hasWebGL();
  print('🌐 WebGL disponível: $webglAvailable');

  if (!webglAvailable) {
    print('⚠️ WebGL não disponível - aplicação em modo de compatibilidade');
  }

  // Verificar conectividade de rede (agora só detecta problemas reais)
  if (NetworkUtils.hasNetworkIssues) {
    print('⚠️ Problemas de rede detectados - aplicação em modo offline');
  }

  // Verificar Firebase (agora só detecta problemas reais)
  if (FirebaseErrorHandler.hasFirebaseIssues) {
    print('⚠️ Problemas com Firebase detectados - aplicação em modo offline');
  }

  // Debug temporário - remover depois
  // await debugFirebase(); // DESATIVADO

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlocMap',
      theme: MyAppTheme.themeData, // Aplica o tema do MyAppTheme
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        SfGlobalLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'PT'), // Português de Portugal
      ],
      locale: const Locale('pt', 'PT'),
      home: _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    final canUseWebGL = !kIsWeb || hasWebGL();
    final hasNetworkProblems = NetworkUtils.hasNetworkIssues;
    final hasFirebaseProblems = FirebaseErrorHandler.hasFirebaseIssues;

    // Se WebGL está disponível e não há problemas, usar tela normal
    if (canUseWebGL && !hasNetworkProblems && !hasFirebaseProblems) {
      return const SelecaoUnidadeScreen();
    }

    // Caso contrário, mostrar tela de fallback
    return _FallbackScreen(
      hasNetworkIssues: hasNetworkProblems,
      hasFirebaseIssues: hasFirebaseProblems,
      hasWebGLIssues: !canUseWebGL,
    );
  }
}

class _FallbackScreen extends StatelessWidget {
  const _FallbackScreen({
    required this.hasNetworkIssues,
    required this.hasFirebaseIssues,
    required this.hasWebGLIssues,
  });

  final bool hasNetworkIssues;
  final bool hasFirebaseIssues;
  final bool hasWebGLIssues;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                color: _getIconColor(),
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                _getTitle(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getIconColor(),
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                _getMessage(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Modo de Compatibilidade Ativo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A aplicação está a funcionar com funcionalidades básicas.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // No web, peça ao utilizador para recarregar manualmente a página.
                  // Em plataformas móveis, este botão não faz ação especial.
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (hasNetworkIssues) return Icons.wifi_off;
    if (hasFirebaseIssues) return Icons.cloud_off;
    if (hasWebGLIssues) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  Color _getIconColor() {
    if (hasNetworkIssues || hasFirebaseIssues) return Colors.red.shade700;
    if (hasWebGLIssues) return Colors.orange.shade700;
    return Colors.blue.shade700;
  }

  String _getTitle() {
    if (hasNetworkIssues) return 'Problemas de Rede';
    if (hasFirebaseIssues) return 'Problemas de Conectividade';
    if (hasWebGLIssues) return 'Compatibilidade Limitada';
    return 'Modo de Compatibilidade';
  }

  String _getMessage() {
    if (hasNetworkIssues) {
      return 'A aplicação está a funcionar em modo offline devido a restrições de rede corporativa. Alguns dados podem não estar atualizados.';
    }
    if (hasFirebaseIssues) {
      return 'Não foi possível conectar aos serviços em nuvem. A aplicação está a funcionar em modo local.';
    }
    if (hasWebGLIssues) {
      return 'Este navegador tem funcionalidades limitadas devido a restrições de segurança corporativa.';
    }
    return 'A aplicação está a funcionar em modo de compatibilidade.';
  }
}

class MyAppTheme {
  static const Color azulEscuro =
      Color(0xFF1565C0); // Azul Escuro; // Azul Escuro
  static const Color azulClaro = Color(0xFF42A5F5); // Azul Claro
  static const Color roxo = Color(0xFF7E57C2); // Roxo
  static Color cinzento = Colors.grey.shade200; // Roxo

  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    primaryColor: azulEscuro,
    fontFamily: 'Montserrat',
    appBarTheme: AppBarTheme(
      backgroundColor: azulEscuro,
      foregroundColor: cinzento,
      elevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: azulClaro, // Azul Claro
      secondary: roxo, // Roxo
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF7E57C2), width: 2), // Roxo
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: roxo,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: azulClaro,
        foregroundColor: cinzento,
      ),
    ),
  );
}
