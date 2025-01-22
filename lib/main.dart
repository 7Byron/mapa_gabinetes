import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'banco_dados/database_helper.dart';
import 'ecrans/tela_principal.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  // Define o caminho que será usado pelo DatabaseHelper
  await DatabaseHelper.database;
  // Garante que o banco de dados seja inicializado antes de rodar o app
  //await DatabaseHelper.database;
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: TelaPrincipal(),
      //home: TestCalendar() //Define a Tela Principal como a página inicial do app.
    );
  }
}
