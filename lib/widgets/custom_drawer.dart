import 'package:flutter/material.dart';

// Suas telas de referência
import '../main.dart';
import '../models/unidade.dart';
import '../screens/lista_medicos.dart';
import '../screens/lista_gabinetes.dart';
import '../screens/config_clinica_screen.dart';
import '../screens/relatorios_screen.dart';
import '../screens/relatorio_especialidades_screen.dart';
import '../screens/selecao_unidade_screen.dart';

class CustomDrawer extends StatelessWidget {
  final VoidCallback onRefresh; // Callback para recarregar dados
  final Unidade? unidade; // Unidade atual para personalizar os nomes
  final bool isAdmin; // Novo parâmetro para indicar se é administrador

  const CustomDrawer({
    super.key,
    required this.onRefresh,
    this.unidade,
    this.isAdmin = false, // Por defeito é utilizador normal
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

          // Informação sobre o tipo de utilizador
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isAdmin ? Colors.orange[50] : Colors.blue[50],
            child: Row(
              children: [
                Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: isAdmin ? Colors.orange[700] : Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isAdmin ? 'Administrador' : 'Utilizador',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAdmin ? Colors.orange[700] : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),

          // Opções do menu
          ListTile(
            leading: const Icon(Icons.medical_services),
            title: Text('Gerir ${unidade?.nomeOcupantes ?? 'Ocupantes'}'),
            enabled: isAdmin, // Só administradores podem gerir
            onTap: isAdmin
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ListaMedicos(unidade: unidade)),
                    ).then((_) {
                      // Após retornar, chama o callback para recarregar os dados
                      onRefresh();
                    });
                  }
                : null,
          ),

          ListTile(
            leading: const Icon(Icons.business),
            title: Text('Gerir ${unidade?.nomeAlocacao ?? 'Alocações'}'),
            enabled: isAdmin, // Só administradores podem gerir
            onTap: isAdmin
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ListaGabinetes(unidade: unidade)),
                    ).then((_) => onRefresh());
                  }
                : null,
          ),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurar Horários'),
            enabled: isAdmin, // Só administradores podem configurar
            onTap: isAdmin
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ConfigClinicaScreen(unidade: unidade)),
                    ).then((_) => onRefresh());
                  }
                : null,
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

          const Spacer(), // Empurra o botão de sair para baixo

          // Botão de sair
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const SelecaoUnidadeScreen(),
                ),
                (route) => false, // Remove todas as rotas anteriores
              );
            },
          ),
        ],
      ),
    );
  }
}
