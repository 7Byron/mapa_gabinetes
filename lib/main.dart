import 'package:flutter/material.dart';
import 'ecrans/tela_principal.dart';
//import 'widgets/teste.dart'; // Importa a Tela Principal que criamos.

void main() {
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
