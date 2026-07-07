import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// Suas telas de referência
import '../models/unidade.dart';
import '../screens/lista_medicos.dart';
import '../screens/lista_gabinetes.dart';
import '../screens/cadastro_unidade_screen.dart';
import '../screens/config_clinica_screen.dart';
import '../screens/dias_encerramento_screen.dart';
import '../screens/selecao_unidade_screen.dart';
import '../screens/scripts_screen.dart';
import '../screens/relatorio_ocupacao_detalhe_screen.dart';
import '../screens/relatorio_horas_especialidade_screen.dart';
import '../services/unidade_selecionada_service.dart';

/// Drawer personalizado com menu de navegação
/// Inclui opções separadas para configurar horários e dias de encerramento
/// Adapta-se ao tipo de utilizador (administrador ou utilizador normal)

class CustomDrawer extends StatelessWidget {
  static const String _developerEmail = 'byronsystemdeveloper@gmail.com';

  final VoidCallback onRefresh; // Callback para recarregar dados
  final Unidade? unidade; // Unidade atual para personalizar os nomes
  final bool isAdmin; // Novo parâmetro para indicar se é administrador
  final int? onboardingStep;

  const CustomDrawer({
    super.key,
    required this.onRefresh,
    this.unidade,
    this.isAdmin = false, // Por defeito é utilizador normal
    this.onboardingStep,
  });

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey[700],
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  TextStyle _itemTextStyle() => const TextStyle(fontSize: 14);

  Widget? _buildOnboardingArrow(int passo) {
    if (onboardingStep != passo) return null;
    return Icon(
      Icons.arrow_back,
      color: Colors.red[700],
      size: 30,
    );
  }

  Widget _buildSectionDivider() {
    return const Divider(
      height: 24,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  Uri _developerMailUri() {
    return Uri(
      scheme: 'mailto',
      path: _developerEmail,
      queryParameters: {
        'subject': 'Contacto AlocMap',
      },
    );
  }

  Future<void> _abrirEmailDesenvolvedor(BuildContext context) async {
    final uri = _developerMailUri();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (abriu) return;
    } catch (_) {
      // Mostra a mensagem abaixo quando o browser/sistema não tiver mailto configurado.
    }

    if (await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o email configurado neste dispositivo.',
        ),
      ),
    );
  }

  Future<void> _copiarEmailDesenvolvedor(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _developerEmail));

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (copyDialogContext) {
        return AlertDialog(
          title: const Text('Copiado'),
          content: const Text('Endereço de e-mail copiado'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(copyDialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _contactarDesenvolvedor(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.contact_mail,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contacto',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Contacte o desenvolvedor do programa pelo e-mail',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    _abrirEmailDesenvolvedor(dialogContext),
                                child: Center(
                                  child: Text(
                                    _developerEmail,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar endereço de e-mail',
                              icon: const Icon(Icons.copy),
                              onPressed: () =>
                                  _copiarEmailDesenvolvedor(dialogContext),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _configurarUnidade(BuildContext context) async {
    final unidadeAtual = unidade;
    if (unidadeAtual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unidade não definida.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();

    final resultado = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (context) => CadastroUnidadeScreen(
          unidade: unidadeAtual,
          confirmarAoAtualizar: true,
        ),
      ),
    );

    if (resultado != true) return;

    await UnidadeSelecionadaService.limparUnidadeSelecionada();
    if (!navigator.mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const SelecaoUnidadeScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Center(
              child: Image.asset(
                'images/am_icon.png',
                fit: BoxFit.contain,
              ),
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionTitle('Médicos e Gabinete'),
                ListTile(
                  leading: const Icon(Icons.medical_services),
                  title: Text(
                    'Gerir ${unidade?.nomeOcupantes ?? 'Ocupantes'}',
                    style: _itemTextStyle(),
                  ),
                  trailing: _buildOnboardingArrow(3),
                  enabled: isAdmin, // Só administradores podem gerir
                  onTap: isAdmin
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ListaMedicos(unidade: unidade)),
                          ).then((_) {
                            // Após retornar, chama o callback para recarregar os dados
                            onRefresh();
                          });
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(
                    'Gerir ${unidade?.nomeAlocacao ?? 'Alocações'}',
                    style: _itemTextStyle(),
                  ),
                  trailing: _buildOnboardingArrow(2),
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
                _buildSectionDivider(),
                _buildSectionTitle('Relatórios'),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Ocupação de Gabinetes',
                      style: TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    if (unidade == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unidade não definida.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RelatorioOcupacaoDetalheScreen(
                          unidade: unidade!,
                          titulo: 'Ocupação de Gabinetes',
                          periodoLabel: 'esta semana',
                          inicio: DateTime.now(),
                          fim: DateTime.now(),
                          gabineteIds: const [],
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.query_stats),
                  title: const Text(
                    'Horas por Especialidade',
                    style: TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (unidade == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unidade não definida.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RelatorioHorasEspecialidadeScreen(
                            unidade: unidade!),
                      ),
                    );
                  },
                ),
                _buildSectionDivider(),
                _buildSectionTitle('Configurações'),
                ListTile(
                  leading: const Icon(Icons.settings_applications),
                  title: const Text('Configurar Unidade',
                      style: TextStyle(fontSize: 14)),
                  enabled: isAdmin,
                  onTap: isAdmin ? () => _configurarUnidade(context) : null,
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Configurar Horários',
                      style: TextStyle(fontSize: 14)),
                  trailing: _buildOnboardingArrow(1),
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
                  title: const Text('Dias de Encerramento',
                      style: TextStyle(fontSize: 14)),
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
                _buildSectionDivider(),
                _buildSectionTitle('Contactos'),
                ListTile(
                  leading: const Icon(Icons.contact_mail),
                  title: const Text(
                    'Contactar desenvolvedor',
                    style: TextStyle(fontSize: 14),
                  ),
                  onTap: () => _contactarDesenvolvedor(context),
                ),
                if (kDebugMode) ...[
                  _buildSectionDivider(),
                  ListTile(
                    leading: const Icon(Icons.code, color: Colors.orange),
                    title: const Text(
                      'Scripts...',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScriptsScreen(unidade: unidade),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // Botão de sair
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              UnidadeSelecionadaService.limparUnidadeSelecionada();
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
