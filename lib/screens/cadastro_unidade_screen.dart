// lib/screens/cadastro_unidade_screen.dart
import '../utils/app_theme.dart';

import 'package:flutter/material.dart';
import '../models/unidade.dart';
import '../services/unidade_service.dart';
import '../services/password_service.dart';

class CadastroUnidadeScreen extends StatefulWidget {
  final Unidade? unidade;

  const CadastroUnidadeScreen({super.key, this.unidade});

  @override
  State<CadastroUnidadeScreen> createState() => _CadastroUnidadeScreenState();
}

class _CadastroUnidadeScreenState extends State<CadastroUnidadeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _tipoController = TextEditingController();
  final _nomeOcupantesController = TextEditingController();
  final _nomeAlocacaoController = TextEditingController();
  final _passwordProjetoController = TextEditingController();
  final _passwordAdminController = TextEditingController();

  bool _isLoading = false;
  bool _showProjectPassword = false;
  bool _showAdminPassword = false;
  List<String> _tiposExistentes = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosUnidade();

    // Valores padrão para nova unidade
    if (widget.unidade == null) {
      _nomeOcupantesController.text = 'Médicos';
      _nomeAlocacaoController.text = 'Gabinete';
    }
  }

  Future<void> _carregarTiposExistentes() async {
    try {
      final tipos = await UnidadeService.listarTiposUnidades();
      setState(() {
        _tiposExistentes = tipos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar tipos existentes: $e');
    }
  }

  Future<void> _carregarDadosUnidade() async {
    if (widget.unidade == null) return;

    try {
      debugPrint('🔄 Carregando dados da unidade: ${widget.unidade!.id}');

      // Carregar dados básicos da unidade
      _nomeController.text = widget.unidade!.nome;
      _tipoController.text = widget.unidade!.tipo;
      _enderecoController.text = widget.unidade!.endereco;
      _telefoneController.text = widget.unidade!.telefone ?? '';
      _emailController.text = widget.unidade!.email ?? '';
      _nomeOcupantesController.text = widget.unidade!.nomeOcupantes;
      _nomeAlocacaoController.text = widget.unidade!.nomeAlocacao;

      // Carregar passwords do documento da unidade
      debugPrint('🔐 Carregando passwords do documento da unidade...');
      final projectPassword = await PasswordService.getProjectPassword(
          unidadeId: widget.unidade!.id);
      final adminPassword =
          await PasswordService.getAdminPassword(unidadeId: widget.unidade!.id);

      if (projectPassword != null) {
        _passwordProjetoController.text = projectPassword;
        debugPrint(
            '✅ Password do projeto carregada: ${projectPassword.length} caracteres');
      } else {
        debugPrint('⚠️ Password do projeto não encontrada');
      }

      if (adminPassword != null) {
        _passwordAdminController.text = adminPassword;
        debugPrint(
            '✅ Password do administrador carregada: ${adminPassword.length} caracteres');
      } else {
        debugPrint('⚠️ Password do administrador não encontrada');
      }

      debugPrint('✅ Dados da unidade carregados com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados da unidade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados da unidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _tipoController.dispose();
    _nomeOcupantesController.dispose();
    _nomeAlocacaoController.dispose();
    _passwordProjetoController.dispose();
    _passwordAdminController.dispose();
    super.dispose();
  }

  Future<void> _salvarUnidade() async {
    // Validar todos os campos obrigatórios
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Validação do formulário falhou');
      return;
    }

    // Validação adicional manual para garantir que todos os campos obrigatórios estão preenchidos
    final tipo = _tipoController.text.trim();
    final nome = _nomeController.text.trim();
    final endereco = _enderecoController.text.trim();
    final passwordProjeto = _passwordProjetoController.text.trim();
    final passwordAdmin = _passwordAdminController.text.trim();
    final nomeOcupantes = _nomeOcupantesController.text.trim();
    final nomeAlocacao = _nomeAlocacaoController.text.trim();

    // Verificar se todos os campos obrigatórios estão preenchidos
    if (tipo.isEmpty ||
        nome.isEmpty ||
        endereco.isEmpty ||
        passwordProjeto.isEmpty ||
        passwordAdmin.isEmpty ||
        nomeOcupantes.isEmpty ||
        nomeAlocacao.isEmpty) {
      List<String> camposFaltantes = [];
      if (tipo.isEmpty) camposFaltantes.add('Tipo de Unidade');
      if (nome.isEmpty) camposFaltantes.add('Nome da Unidade');
      if (endereco.isEmpty) camposFaltantes.add('Endereço');
      if (passwordProjeto.isEmpty) camposFaltantes.add('Password do Projeto');
      if (passwordAdmin.isEmpty) {
        camposFaltantes.add('Password do Administrador');
      }
      if (nomeOcupantes.isEmpty) camposFaltantes.add('Nome dos Ocupantes');
      if (nomeAlocacao.isEmpty) camposFaltantes.add('Nome da Alocação');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Campos obrigatórios não preenchidos: ${camposFaltantes.join(', ')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      debugPrint(
          '❌ Campos obrigatórios não preenchidos: ${camposFaltantes.join(', ')}');
      return;
    }

    // Verificar se as passwords têm pelo menos 3 caracteres
    if (passwordProjeto.length < 3 || passwordAdmin.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('As passwords devem ter pelo menos 3 caracteres'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('❌ Passwords muito curtas');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('💾 Iniciando salvamento da unidade...');
      debugPrint('📋 Dados a salvar:');
      debugPrint('   - Tipo: $tipo');
      debugPrint('   - Nome: $nome');
      debugPrint('   - Endereço: $endereco');
      debugPrint('   - Password Projeto: ${passwordProjeto.length} caracteres');
      debugPrint('   - Password Admin: ${passwordAdmin.length} caracteres');
      debugPrint('   - Ocupantes: $nomeOcupantes');
      debugPrint('   - Alocação: $nomeAlocacao');

      final unidade = Unidade(
        id: widget.unidade?.id ?? '',
        nome: nome,
        tipo: tipo,
        endereco: endereco,
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        dataCriacao: widget.unidade?.dataCriacao ?? DateTime.now(),
        ativa: widget.unidade?.ativa ?? true,
        nomeOcupantes: nomeOcupantes,
        nomeAlocacao: nomeAlocacao,
      );

      bool sucesso;
      String? unidadeId;
      if (widget.unidade == null) {
        // Criar nova unidade
        debugPrint('🆕 Criando nova unidade...');
        unidadeId = await UnidadeService.criarUnidade(unidade);
        sucesso = unidadeId != null;

        // Se criou com sucesso, salva as passwords com o novo ID
        if (sucesso) {
          debugPrint('✅ Unidade criada com ID: $unidadeId');
          debugPrint('🔐 Salvando passwords no Firebase...');
          debugPrint('   - Unidade ID para passwords: $unidadeId');
          debugPrint(
              '   - Password projeto: ${passwordProjeto.length} caracteres');
          debugPrint('   - Password admin: ${passwordAdmin.length} caracteres');

          await PasswordService.saveProjectPassword(passwordProjeto,
              unidadeId: unidadeId);
          await PasswordService.saveAdminPassword(passwordAdmin,
              unidadeId: unidadeId);
          debugPrint('✅ Passwords salvas com o novo ID da unidade');
        }
      } else {
        // Atualizar unidade existente
        debugPrint('🔄 Atualizando unidade existente...');
        debugPrint('   - Unidade ID existente: ${widget.unidade!.id}');
        sucesso = await UnidadeService.atualizarUnidade(unidade);
        unidadeId = widget.unidade!.id;

        // Se atualizou com sucesso, salva as passwords
        if (sucesso) {
          debugPrint('✅ Unidade atualizada com sucesso');
          debugPrint('🔐 Salvando passwords no Firebase...');
          debugPrint('   - Unidade ID para passwords: $unidadeId');
          debugPrint(
              '   - Password projeto: ${passwordProjeto.length} caracteres');
          debugPrint('   - Password admin: ${passwordAdmin.length} caracteres');

          await PasswordService.saveProjectPassword(passwordProjeto,
              unidadeId: unidadeId);
          await PasswordService.saveAdminPassword(passwordAdmin,
              unidadeId: unidadeId);
          debugPrint('✅ Passwords salvas no Firebase');
        }
      }

      // Marcar que não é mais a primeira vez
      await PasswordService.markAsNotFirstTime();

      if (sucesso) {
        debugPrint('✅ Unidade salva com sucesso!');
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.unidade == null
                    ? 'Unidade criada com sucesso!'
                    : 'Unidade atualizada com sucesso!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Erro ao salvar unidade');
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar unidade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar unidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _desativarUnidade() async {
    if (widget.unidade == null) return;

    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desativação'),
        content: Text(
          'Tem certeza que deseja desativar a unidade "${widget.unidade!.nome}"?\n\n'
          'Esta ação pode ser revertida posteriormente editando a unidade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      setState(() => _isLoading = true);

      try {
        await UnidadeService.desativarUnidade(widget.unidade!.id);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Unidade "${widget.unidade!.nome}" desativada com sucesso'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao desativar unidade: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditando = widget.unidade != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditando ? 'Editar Unidade' : 'Nova Unidade'),
        backgroundColor: MyAppTheme.azulEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botão de desativar apenas quando estiver a editar
          if (isEditando && widget.unidade!.ativa)
            IconButton(
              onPressed: _isLoading ? null : _desativarUnidade,
              icon: const Icon(Icons.block, color: Colors.orange),
              tooltip: 'Desativar Unidade',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tipo de unidade
                TextFormField(
                  controller: _tipoController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Unidade *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                    hintText: 'Ex: Clínica, Hospital, Centro Médico...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o tipo de unidade';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Nome da unidade
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Unidade *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_center),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o nome da unidade';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Endereço
                TextFormField(
                  controller: _enderecoController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o endereço da unidade';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Telefone
                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone, color: Colors.grey),
                    hintText: 'Ex: 351 999999999',
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email, color: Colors.grey),
                    hintText: 'unidade@exemplo.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Digite um email válido';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Divider
                const Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),

                const SizedBox(height: 16),

                // Nome dos Ocupantes
                TextFormField(
                  controller: _nomeOcupantesController,
                  decoration: const InputDecoration(
                    labelText: 'Nome dos Ocupantes *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                    hintText: 'Ex: Médicos, Convidados, Clientes, etc...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o nome dos ocupantes';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Nome da Alocação
                TextFormField(
                  controller: _nomeAlocacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Alocação *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.room),
                    hintText: 'Ex: Gabinete, Quarto, Mesa, etc...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite o nome da alocação';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password do Projeto
                TextFormField(
                  controller: _passwordProjetoController,
                  decoration: InputDecoration(
                    labelText: 'Password do Projeto *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    hintText: 'Digite a password do projeto',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showProjectPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _showProjectPassword = !_showProjectPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showProjectPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite a password do projeto';
                    }
                    if (value.trim().length < 3) {
                      return 'A password deve ter pelo menos 3 caracteres';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password do Administrador
                TextFormField(
                  controller: _passwordAdminController,
                  decoration: InputDecoration(
                    labelText: 'Password do Administrador *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.admin_panel_settings),
                    hintText: 'Digite a password do administrador',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showAdminPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAdminPassword = !_showAdminPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showAdminPassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite a password do administrador';
                    }
                    if (value.trim().length < 3) {
                      return 'A password deve ter pelo menos 3 caracteres';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _salvarUnidade,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MyAppTheme.azulEscuro,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(isEditando ? 'Atualizar' : 'Criar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
