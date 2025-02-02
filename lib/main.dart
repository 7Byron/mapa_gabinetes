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
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        fontFamily: 'Montserrat', // Fonte local configurada
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade300,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: AlocacaoMedicos(),
    );
  }
}
