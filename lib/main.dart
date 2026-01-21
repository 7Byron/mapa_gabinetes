import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'models/unidade.dart';
import 'services/unidade_service.dart';
import 'services/unidade_selecionada_service.dart';
import 'screens/login_screen.dart';
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
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isLoading = true;
  Unidade? _unidadeSelecionada;

  @override
  void initState() {
    super.initState();
    _carregarUnidadeInicial();
  }

  Future<void> _carregarUnidadeInicial() async {
    try {
      final unidadeId =
          await UnidadeSelecionadaService.carregarUnidadeSelecionada();
      if (unidadeId != null) {
        final unidade = await UnidadeService.buscarUnidadePorId(unidadeId);
        if (unidade != null && unidade.ativa) {
          setState(() {
            _unidadeSelecionada = unidade;
            _isLoading = false;
          });
          return;
        }

        await UnidadeSelecionadaService.limparUnidadeSelecionada();
      }
    } catch (_) {
      await UnidadeSelecionadaService.limparUnidadeSelecionada();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_unidadeSelecionada != null) {
      return LoginScreen(unidade: _unidadeSelecionada!);
    }

    return const SelecaoUnidadeScreen();
  }
}
