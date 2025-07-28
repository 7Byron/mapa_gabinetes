import 'package:flutter/material.dart';

// Suas telas de referência
import '../main.dart';
import '../models/unidade.dart';
import '../screens/lista_medicos.dart';
import '../screens/lista_gabinetes.dart';
import '../screens/config_clinica_screen.dart';
import '../screens/relatorios_screen.dart';
import '../screens/relatorio_especialidades_screen.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onRefresh; // Callback para recarregar dados
  final Unidade? unidade; // Unidade atual para personalizar os nomes

  const CustomDrawer({
    super.key,
    required this.onRefresh,
    this.unidade,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: MyAppTheme.azulEscuro,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 8,
                  child: Image.asset(
                    'images/icon2.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Gestão Mapa ${unidade?.nomeAlocacao ?? 'Gabinetes'}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.medical_services),
            title: Text('Gerir ${unidade?.nomeOcupantes ?? 'Ocupantes'}'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ListaMedicos(unidade: unidade)),
              ).then((_) {
                // Após retornar, chama o callback para recarregar os dados
                onRefresh();
              });
            },
          ),
          // "Gerir ${unidade?.nomeAlocacao ?? 'Gabinetes'}"
          ListTile(
            leading: const Icon(Icons.business),
            title: Text('Gerir ${unidade?.nomeAlocacao ?? 'Alocações'}'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ListaGabinetes(unidade: unidade)),
              ).then((_) => onRefresh());
            },
          ),
          // "Configurar Horários"
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurar Horários'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ConfigClinicaScreen()),
              ).then((_) => onRefresh());
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Relatórios de Ocupação'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RelatoriosScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Relatório Especialidades'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RelatorioEspecialidadesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
