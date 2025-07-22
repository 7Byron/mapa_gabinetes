// lib/screens/cadastro_unidade_screen.dart

import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import '../models/unidade.dart';
import '../services/unidade_service.dart';

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
  bool _isLoading = false;
  List<String> _tiposExistentes = [];

  @override
  void initState() {
    super.initState();
    _carregarTiposExistentes();
    if (widget.unidade != null) {
      _nomeController.text = widget.unidade!.nome;
      _enderecoController.text = widget.unidade!.endereco;
      _telefoneController.text = widget.unidade!.telefone ?? '';
      _emailController.text = widget.unidade!.email ?? '';
      _tipoController.text = widget.unidade!.tipo;
    }
  }

  Future<void> _carregarTiposExistentes() async {
    try {
      final tipos = await UnidadeService.listarTiposUnidades();
      setState(() {
        _tiposExistentes = tipos;
      });
    } catch (e) {
      print('Erro ao carregar tipos existentes: $e');
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _tipoController.dispose();
    super.dispose();
  }

  Future<void> _salvarUnidade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
            final unidade = Unidade(
        id: widget.unidade?.id ?? '',
        nome: _nomeController.text.trim(),
        tipo: _tipoController.text.trim(),
        endereco: _enderecoController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty 
            ? null 
            : _telefoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        dataCriacao: widget.unidade?.dataCriacao ?? DateTime.now(),
        ativa: widget.unidade?.ativa ?? true,
      );

      bool sucesso;
      if (widget.unidade == null) {
        // Criar nova unidade
        final id = await UnidadeService.criarUnidade(unidade);
        sucesso = id != null;
      } else {
        // Atualizar unidade existente
        sucesso = await UnidadeService.atualizarUnidade(unidade);
      }

      if (sucesso) {
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

  @override
  Widget build(BuildContext context) {
    final isEditando = widget.unidade != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditando ? 'Editar Unidade' : 'Nova Unidade'),
        backgroundColor: MyAppTheme.azulEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
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

            // Sugestões de tipos existentes
            if (_tiposExistentes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Tipos existentes:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _tiposExistentes.map((tipo) {
                        return InkWell(
                          onTap: () {
                            _tipoController.text = tipo;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Text(
                              tipo,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toque em um tipo para selecioná-lo, ou digite um novo tipo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                labelText: 'Telefone (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '(11) 99999-9999',
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
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

            const SizedBox(height: 32),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(isEditando ? 'Atualizar' : 'Criar'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Informações adicionais
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Informações',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Campos marcados com * são obrigatórios\n'
                    '• A unidade será criada como ativa por padrão\n'
                    '• Você pode desativar a unidade posteriormente\n'
                    '• Todos os dados da unidade ficarão isolados',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
