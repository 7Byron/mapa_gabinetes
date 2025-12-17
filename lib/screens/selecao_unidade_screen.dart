// lib/screens/selecao_unidade_screen.dart
import '../utils/app_theme.dart';

import 'package:flutter/material.dart';
import '../models/unidade.dart';
import '../services/unidade_service.dart';
import '../services/password_service.dart';
import 'cadastro_unidade_screen.dart';
import 'login_screen.dart';

class SelecaoUnidadeScreen extends StatefulWidget {
  const SelecaoUnidadeScreen({super.key});

  @override
  State<SelecaoUnidadeScreen> createState() => _SelecaoUnidadeScreenState();
}

class _SelecaoUnidadeScreenState extends State<SelecaoUnidadeScreen> {
  List<Unidade> unidades = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
  }

  Future<void> _carregarUnidades() async {
    debugPrint('🔄 Iniciando carregamento de unidades...');
    setState(() => isLoading = true);
    try {
      final unidadesCarregadas = await UnidadeService.buscarUnidades();
      debugPrint(
          '📋 Unidades carregadas na tela: ${unidadesCarregadas.length}');
      for (final unidade in unidadesCarregadas) {
        debugPrint(
            '🏥 Unidade na tela: ${unidade.nome} (${unidade.tipo}) - Ativa: ${unidade.ativa}');
      }
      setState(() {
        unidades = unidadesCarregadas;
        isLoading = false;
      });
      debugPrint('✅ Estado atualizado com ${unidades.length} unidades');
    } catch (e) {
      debugPrint('❌ Erro ao carregar unidades na tela: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar unidades: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Unidade> get unidadesFiltradas {
    return unidades;
  }

  void _selecionarUnidade(Unidade unidade) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(unidade: unidade),
      ),
    );
  }

  void _criarNovaUnidade() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CadastroUnidadeScreen(),
      ),
    );

    if (resultado == true) {
      _carregarUnidades();
    }
  }

  Future<void> _editarUnidade(Unidade unidade) async {
    // Verificar se há passwords configuradas no Firebase
    final hasPasswords =
        await PasswordService.hasPasswordsConfigured(unidadeId: unidade.id);

    if (hasPasswords) {
      // Se há passwords configuradas, pede a password do administrador
      final password = await _solicitarPasswordAdmin();
      if (password == null) return; // Usuário cancelou

      // Verificar se a password está correta
      final isValid = await PasswordService.verifyAdminPassword(password,
          unidadeId: unidade.id);
      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password do administrador incorreta'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Se não há passwords configuradas, permite editar sem verificação
      debugPrint(
          '⚠️ Nenhuma password configurada no Firebase - permitindo edição temporária');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Acesso temporário permitido - configure as passwords após a edição'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    // Password correta ou sem passwords configuradas, abrir tela de edição
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroUnidadeScreen(unidade: unidade),
      ),
    );

    if (resultado == true) {
      _carregarUnidades();
    }
  }

  Future<String?> _solicitarPasswordAdmin() async {
    final passwordController = TextEditingController();
    bool showPassword = false;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Password do Administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite a password do administrador para editar a unidade:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    showPassword = !showPassword;
                    // Forçar rebuild do dialog
                    (context as Element).markNeedsBuild();
                  },
                ),
              ),
              obscureText: !showPassword,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite a password';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (passwordController.text.trim().isNotEmpty) {
                  Navigator.pop(context, passwordController.text.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.trim().isNotEmpty) {
                Navigator.pop(context, passwordController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MyAppTheme.azulEscuro,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('AlocMap'),
        backgroundColor: MyAppTheme.azulEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header com informações
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: MyAppTheme.azulEscuro,
            ),
            child: Column(
              children: [
                Image.asset(
                  'images/am_icon.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'AlocMap',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecione ou crie uma unidade para continuar',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Botão Nova Unidade
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _criarNovaUnidade,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova Unidade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyAppTheme.azulEscuro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de unidades
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : unidadesFiltradas.isEmpty
                    ? _buildEmptyState()
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: unidadesFiltradas.length,
                            itemBuilder: (context, index) {
                              final unidade = unidadesFiltradas[index];
                              return _buildUnidadeCard(unidade);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma unidade encontrada',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em "Nova Unidade" para criar a primeira unidade',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _criarNovaUnidade,
              icon: const Icon(Icons.add),
              label: const Text('Criar Primeira Unidade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyAppTheme.azulEscuro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnidadeCard(Unidade unidade) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _selecionarUnidade(unidade),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTipoColor(unidade.tipo),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      unidade.tipo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Ícone de edição
                  InkWell(
                    onTap: () => _editarUnidade(unidade),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                unidade.nome,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unidade.endereco,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (unidade.telefone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unidade.telefone!,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Criada em ${_formatarData(unidade.dataCriacao)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          unidade.ativa ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unidade.ativa ? 'Ativa' : 'Inativa',
                      style: TextStyle(
                        color:
                            unidade.ativa ? Colors.green[700] : Colors.red[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTipoColor(String tipo) {
    // Usar hash do tipo para gerar uma cor consistente
    final hash = tipo.hashCode;
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}
