import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:mapa_gabinetes/screens/selecao_unidade_screen.dart';
import 'debug_firebase.dart'; // Debug temporário

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug temporário - remover depois
  await debugFirebase();

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
      home: const SelecaoUnidadeScreen(),
    );
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
