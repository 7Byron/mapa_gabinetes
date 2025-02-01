// lib/widgets/custom_drawer.dart

import 'package:flutter/material.dart';
import '../screens/lista_medicos.dart';
import '../screens/lista_gabinetes.dart';
import '../screens/banco_dados_screen.dart';
import '../screens/config_clinica_screen.dart';
import '../screens/relatorios_screen.dart';
import '../screens/relatorio_especialidades_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: const Text(
              'Gestão Mapa Gabinetes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medical_services),
            title: const Text('Gerir Médicos'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ListaMedicos()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Gerir Gabinetes'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ListaGabinetes()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('Base de Dados'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BancoDadosScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurar Horários'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigClinicaScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Relatórios de Ocupação'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RelatoriosScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Relatório Especialidades'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RelatorioEspecialidadesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
