import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/ecrans/alocacao_medicos_screen.dart';
import 'banco_dados_screen.dart';
import 'lista_gabinetes.dart';
import 'lista_medicos.dart';

class TelaPrincipal extends StatelessWidget {
  const TelaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão de Clínica Médica'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Gestão Mapa Gabinetes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text('Gerir Alocações'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AlocacaoMedicos()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.medical_services),
              title: Text('Gerir Médicos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaMedicos()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.business),
              title: Text('Gerir Gabinetes'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaGabinetes()),
                );
              },
            ),
            // New ListTile for Settings
            ListTile(
              leading: Icon(Icons.dataset_outlined), // Icon for settings
              title: Text('Base de Dados'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          BancoDadosScreen()), // Navigate to the settings screen
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Bem-vindo ao Mapa de Gabinetes',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}