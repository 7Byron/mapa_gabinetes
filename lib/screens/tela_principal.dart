import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/screens/relatorios_screen.dart';
import 'alocacao_medicos_screen.dart';
import 'banco_dados_screen.dart';
import 'config_clinica_screen.dart';
import 'lista_gabinetes.dart';
import 'lista_medicos.dart';
import 'relatorio_especialidades_screen.dart';

class TelaPrincipal extends StatelessWidget {
  const TelaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alocação de Gabinetes'),
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
              title: Text('Alocação Gabinetes'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TelaPrincipal()),
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
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configurar Horários'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConfigClinicaScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bar_chart),
              title: Text('Relatórios de Ocupação'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RelatoriosScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Relatório Especialidades'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RelatorioEspecialidadesScreen()),
                );
              },
            ),

          ],
        ),
      ),
      body: const AlocacaoMedicos(),
    );
  }
}