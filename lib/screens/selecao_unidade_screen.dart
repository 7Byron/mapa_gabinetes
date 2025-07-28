// lib/screens/selecao_unidade_screen.dart

import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import '../models/unidade.dart';
import '../services/unidade_service.dart';
import 'cadastro_unidade_screen.dart';
import 'alocacao_medicos_screen.dart';

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
    print('🔄 Iniciando carregamento de unidades...');
    setState(() => isLoading = true);
    try {
      final unidadesCarregadas = await UnidadeService.buscarUnidades();
      print('📋 Unidades carregadas na tela: ${unidadesCarregadas.length}');
      for (final unidade in unidadesCarregadas) {
        print(
            '🏥 Unidade na tela: ${unidade.nome} (${unidade.tipo}) - Ativa: ${unidade.ativa}');
      }
      setState(() {
        unidades = unidadesCarregadas;
        isLoading = false;
      });
      print('✅ Estado atualizado com ${unidades.length} unidades');
    } catch (e) {
      print('❌ Erro ao carregar unidades na tela: $e');
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AlocacaoMedicos(unidade: unidade),
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

  void _editarUnidade(Unidade unidade) async {
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

  void _desativarUnidade(Unidade unidade) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desativação'),
        content: Text(
          'Tem certeza que deseja desativar a unidade "${unidade.nome}"?\n\n'
          'Esta ação pode ser revertida posteriormente.',
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
            ),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );

    if (confirmacao == true) {
      try {
        await UnidadeService.desativarUnidade(unidade.id);
        _carregarUnidades();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unidade "${unidade.nome}" desativada com sucesso'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desativar unidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Unidade'),
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
                  'images/icon2.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gestão Mapa Gabinetes',
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: unidadesFiltradas.length,
                        itemBuilder: (context, index) {
                          final unidade = unidadesFiltradas[index];
                          return _buildUnidadeCard(unidade);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'editar':
                          _editarUnidade(unidade);
                          break;
                        case 'desativar':
                          _desativarUnidade(unidade);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'desativar',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Desativar'),
                          ],
                        ),
                      ),
                    ],
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
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ativa',
                      style: TextStyle(
                        color: Colors.green[700],
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
