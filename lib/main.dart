import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapa_gabinetes/screens/alocacao_medicos_screen.dart';
import 'database/init_banco_dados.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  await initDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mapa de Gabinetes',
      theme: MyAppTheme.themeData, // Aplica o tema do MyAppTheme
      home: AlocacaoMedicos(),
    );
  }
}

class MyAppTheme {
  static const Color darkBlue = Color(0xFF1565C0); // Azul Escuro; // Azul Escuro
  static const Color lightBlue = Color(0xFF42A5F5); // Azul Claro
  static const Color purpleAccent = Color(0xFF7E57C2); // Roxo
  static Color cinzento = Colors.grey.shade200;// Roxo


  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    primaryColor: darkBlue,
    fontFamily: 'Montserrat',
    appBarTheme: AppBarTheme(
      backgroundColor: darkBlue,
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
      primary: lightBlue, // Azul Claro
      secondary: purpleAccent, // Roxo
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF7E57C2), width: 2), // Roxo
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: purpleAccent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightBlue,
        foregroundColor: cinzento,
      ),
    ),
  );
}
