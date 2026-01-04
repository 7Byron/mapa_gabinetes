import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

// Suas telas de referência
import '../models/unidade.dart';
import '../screens/lista_medicos.dart';
import '../screens/lista_gabinetes.dart';
import '../screens/config_clinica_screen.dart';
import '../screens/dias_encerramento_screen.dart';
import '../screens/selecao_unidade_screen.dart';

/// Drawer personalizado com menu de navegação
/// Inclui opções separadas para configurar horários e dias de encerramento
/// Adapta-se ao tipo de utilizador (administrador ou utilizador normal)

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
                    'images/am_icon.png',
                    fit: BoxFit.contain,
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
            leading: const Icon(Icons.schedule),
            title: const Text('Configurar Horários'),
            enabled: isAdmin, // Só administradores podem configurar
            onTap: isAdmin
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              ConfigClinicaScreen(unidade: unidade)),
                    ).then((_) => onRefresh());
                  }
                : null,
          ),

          ListTile(
            leading: const Icon(Icons.event_busy),
            title: const Text('Dias de Encerramento'),
            enabled: isAdmin, // Só administradores podem configurar
            onTap: isAdmin
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              DiasEncerramentoScreen(unidade: unidade)),
                    ).then((_) => onRefresh());
                  }
                : null,
          ),

          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Relatórios de Ocupação'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Em construção'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Relatório Especialidades'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Em construção'),
                  duration: Duration(seconds: 2),
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
