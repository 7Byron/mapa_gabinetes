// lib/screens/gestao_cartoes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../services/medico_salvar_service.dart';
import '../services/gabinete_service.dart';

/// Ecrã de gestão e limpeza de cartões
/// Permite visualizar, filtrar e apagar cartões (disponibilidades e alocações)
/// Útil para limpar cartões "Desconhecidos" ou de médicos inativos
class GestaoCartoesScreen extends StatefulWidget {
  final Unidade? unidade;

  const GestaoCartoesScreen({super.key, this.unidade});

  @override
  State<GestaoCartoesScreen> createState() => _GestaoCartoesScreenState();
}

class _GestaoCartoesScreenState extends State<GestaoCartoesScreen> {
  bool isLoading = true;
  DateTime? dataFiltro;
  String? medicoFiltro;
  String? gabineteFiltro;
  String tipoFiltro = 'Todos'; // 'Todos', 'Desconhecidos', 'Inativos', 'PorAlocar', 'Alocados'
  
  List<Medico> todosMedicos = [];
  List<Gabinete> todosGabinetes = [];
  List<Disponibilidade> todasDisponibilidades = [];
  List<Alocacao> todasAlocacoes = [];
  
  // Cartões filtrados para exibição
  List<Map<String, dynamic>> cartoesFiltrados = [];
  
  // Seleção múltipla
  Set<String> cartoesSelecionados = {};
  bool modoSelecao = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);
    
    try {
      // Carregar médicos e gabinetes
      todosMedicos = await buscarMedicos(unidade: widget.unidade);
      todosGabinetes = await buscarGabinetes(unidade: widget.unidade);
      
      // Carregar disponibilidades e alocações
      await _carregarDisponibilidades();
      await _carregarAlocacoes();
      
      _aplicarFiltros();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _carregarDisponibilidades() async {
    todasDisponibilidades = [];
    final firestore = FirebaseFirestore.instance;
    
    if (widget.unidade == null) return;
    
    final ocupantesRef = firestore
        .collection('unidades')
        .doc(widget.unidade!.id)
        .collection('ocupantes');
    
    final ocupantesSnapshot = await ocupantesRef.get();
    
    for (final ocupanteDoc in ocupantesSnapshot.docs) {
      final disponibilidadesRef = ocupanteDoc.reference.collection('disponibilidades');
      final anosSnapshot = await disponibilidadesRef.get();
      
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          try {
            final disponibilidade = Disponibilidade.fromMap(data);
            todasDisponibilidades.add(disponibilidade);
          } catch (e) {
            debugPrint('Erro ao carregar disponibilidade: $e');
          }
        }
      }
    }
  }

  Future<void> _carregarAlocacoes() async {
    todasAlocacoes = [];
    final firestore = FirebaseFirestore.instance;
    
    if (widget.unidade == null) return;
    
    final unidadeId = widget.unidade!.id;
    final anoAtual = DateTime.now().year;
    final anosParaVerificar = [anoAtual - 1, anoAtual, anoAtual + 1];
    
    for (final ano in anosParaVerificar) {
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano.toString())
          .collection('registos');
      
      final snapshot = await alocacoesRef.get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final alocacao = Alocacao.fromMap(data);
        todasAlocacoes.add(alocacao);
      }
    }
  }

  void _aplicarFiltros() {
    cartoesFiltrados = [];
    
    // Processar disponibilidades
    for (final disp in todasDisponibilidades) {
      final medico = todosMedicos.firstWhere(
        (m) => m.id == disp.medicoId,
        orElse: () => Medico(
          id: disp.medicoId,
          nome: 'Desconhecido',
          especialidade: '',
          disponibilidades: [],
          ativo: false,
        ),
      );
      
      final dataDisp = disp.data;
      
      // Aplicar filtros
      if (dataFiltro != null) {
        final dataFiltroNormalizada = DateTime(
          dataFiltro!.year,
          dataFiltro!.month,
          dataFiltro!.day,
        );
        final dataDispNormalizada = DateTime(
          dataDisp.year,
          dataDisp.month,
          dataDisp.day,
        );
        if (dataDispNormalizada != dataFiltroNormalizada) continue;
      }
      
      if (medicoFiltro != null && medico.id != medicoFiltro) continue;
      
      // Verificar tipo de filtro
      bool incluir = false;
      if (tipoFiltro == 'Todos') {
        incluir = true;
      } else if (tipoFiltro == 'Desconhecidos' && medico.nome == 'Desconhecido') {
        incluir = true;
      } else if (tipoFiltro == 'Inativos' && !medico.ativo) {
        incluir = true;
      } else if (tipoFiltro == 'PorAlocar') {
        // Verificar se não está alocado
        final estaAlocado = todasAlocacoes.any((a) =>
            a.medicoId == disp.medicoId &&
            a.data == disp.data);
        if (!estaAlocado) incluir = true;
      }
      
      if (incluir) {
        cartoesFiltrados.add({
          'tipo': 'disponibilidade',
          'id': disp.id,
          'medicoId': disp.medicoId,
          'medicoNome': medico.nome,
          'medicoAtivo': medico.ativo,
          'data': dataDisp,
          'horarios': disp.horarios,
          'tipoDisponibilidade': disp.tipo,
          'gabineteId': null,
          'gabineteNome': null,
        });
      }
    }
    
    // Processar alocações
    for (final aloc in todasAlocacoes) {
      final medico = todosMedicos.firstWhere(
        (m) => m.id == aloc.medicoId,
        orElse: () => Medico(
          id: aloc.medicoId,
          nome: 'Desconhecido',
          especialidade: '',
          disponibilidades: [],
          ativo: false,
        ),
      );
      
      final gabinete = todosGabinetes.firstWhere(
        (g) => g.id == aloc.gabineteId,
        orElse: () => Gabinete(
          id: aloc.gabineteId,
          nome: 'Desconhecido',
          setor: '',
          especialidadesPermitidas: [],
        ),
      );
      
      final dataAloc = aloc.data;
      
      // Aplicar filtros
      if (dataFiltro != null) {
        final dataFiltroNormalizada = DateTime(
          dataFiltro!.year,
          dataFiltro!.month,
          dataFiltro!.day,
        );
        final dataAlocNormalizada = DateTime(
          dataAloc.year,
          dataAloc.month,
          dataAloc.day,
        );
        if (dataAlocNormalizada != dataFiltroNormalizada) continue;
      }
      
      if (medicoFiltro != null && medico.id != medicoFiltro) continue;
      if (gabineteFiltro != null && gabinete.id != gabineteFiltro) continue;
      
      // Verificar tipo de filtro
      bool incluir = false;
      if (tipoFiltro == 'Todos') {
        incluir = true;
      } else if (tipoFiltro == 'Desconhecidos' && 
                 (medico.nome == 'Desconhecido' || gabinete.nome == 'Desconhecido')) {
        incluir = true;
      } else if (tipoFiltro == 'Inativos' && !medico.ativo) {
        incluir = true;
      } else if (tipoFiltro == 'Alocados') {
        incluir = true;
      }
      
      if (incluir) {
        cartoesFiltrados.add({
          'tipo': 'alocacao',
          'id': aloc.id,
          'medicoId': aloc.medicoId,
          'medicoNome': medico.nome,
          'medicoAtivo': medico.ativo,
          'data': dataAloc,
          'horarios': null,
          'tipoDisponibilidade': null,
          'gabineteId': aloc.gabineteId,
          'gabineteNome': gabinete.nome,
        });
      }
    }
    
    // Ordenar alfabeticamente por nome do médico, depois por data
    cartoesFiltrados.sort((a, b) {
      final nomeA = (a['medicoNome'] as String).toLowerCase();
      final nomeB = (b['medicoNome'] as String).toLowerCase();
      final comparacaoNome = nomeA.compareTo(nomeB);
      if (comparacaoNome != 0) return comparacaoNome;
      // Se os nomes forem iguais, ordenar por data
      return (a['data'] as DateTime).compareTo(b['data'] as DateTime);
    });
    
    setState(() {});
  }

  void _selecionarTodos() {
    setState(() {
      cartoesSelecionados = cartoesFiltrados.map((c) => c['id'] as String).toSet();
    });
  }

  void _desselecionarTodos() {
    setState(() {
      cartoesSelecionados.clear();
    });
  }

  Future<void> _apagarTodosFiltrados() async {
    if (cartoesFiltrados.isEmpty) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja apagar TODOS os ${cartoesFiltrados.length} cartão(ões) filtrados?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar Todos'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    // Selecionar todos os cartões filtrados e apagar
    cartoesSelecionados = cartoesFiltrados.map((c) => c['id'] as String).toSet();
    await _apagarCartoesSelecionados();
  }

  Future<void> _apagarCartoesSelecionados() async {
    if (cartoesSelecionados.isEmpty) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja apagar ${cartoesSelecionados.length} cartão(ões)?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    final firestore = FirebaseFirestore.instance;
    int apagados = 0;
    int erros = 0;
    
    try {
      for (final cartaoId in cartoesSelecionados) {
        final cartao = cartoesFiltrados.firstWhere((c) => c['id'] == cartaoId);
        final tipo = cartao['tipo'] as String;
        
        try {
          if (tipo == 'disponibilidade') {
            // Apagar disponibilidade
            final medicoId = cartao['medicoId'] as String;
            final data = cartao['data'] as DateTime;
            
            final ocupantesRef = firestore
                .collection('unidades')
                .doc(widget.unidade!.id)
                .collection('ocupantes');
            
            final disponibilidadesRef = ocupantesRef
                .doc(medicoId)
                .collection('disponibilidades')
                .doc(data.year.toString())
                .collection('registos');
            
            final snapshot = await disponibilidadesRef
                .where('data', isEqualTo: data.toIso8601String())
                .get();
            
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
            
            // Remover da lista local
            todasDisponibilidades.removeWhere((d) => d.id == cartaoId);
          } else if (tipo == 'alocacao') {
            // Apagar alocação
            final unidadeId = widget.unidade!.id;
            final data = cartao['data'] as DateTime;
            
            final alocacoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('alocacoes')
                .doc(data.year.toString())
                .collection('registos');
            
            final snapshot = await alocacoesRef
                .where('id', isEqualTo: cartaoId)
                .get();
            
            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
            
            // Remover da lista local
            todasAlocacoes.removeWhere((a) => a.id == cartaoId);
          }
          
          apagados++;
        } catch (e) {
          erros++;
          debugPrint('Erro ao apagar cartão $cartaoId: $e');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erros > 0
                  ? '$apagados cartão(ões) apagado(s). $erros erro(s).'
                  : '$apagados cartão(ões) apagado(s) com sucesso.',
            ),
            backgroundColor: erros > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
      
      // Remover da lista filtrada e reaplicar filtros (sem recarregar do Firebase)
      cartoesSelecionados.clear();
      modoSelecao = false;
      _aplicarFiltros(); // Reaplica os filtros com as listas locais atualizadas
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar cartões: $e'),
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
        title: const Text(
          'Gestão de Cartões',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (modoSelecao)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'selecionar_todos') {
                  _selecionarTodos();
                } else if (value == 'desselecionar_todos') {
                  _desselecionarTodos();
                } else if (value == 'apagar_selecionados' && cartoesSelecionados.isNotEmpty) {
                  _apagarCartoesSelecionados();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'selecionar_todos',
                  child: Row(
                    children: [
                      Icon(Icons.select_all),
                      SizedBox(width: 8),
                      Text('Selecionar Todos'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'desselecionar_todos',
                  child: Row(
                    children: [
                      Icon(Icons.deselect),
                      SizedBox(width: 8),
                      Text('Desselecionar Todos'),
                    ],
                  ),
                ),
                if (cartoesSelecionados.isNotEmpty)
                  const PopupMenuItem(
                    value: 'apagar_selecionados',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Apagar Selecionados', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          if (!modoSelecao && cartoesFiltrados.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Apagar todos os filtrados',
              onPressed: _apagarTodosFiltrados,
            ),
          IconButton(
            icon: Icon(modoSelecao ? Icons.cancel : Icons.checklist),
            tooltip: modoSelecao ? 'Cancelar seleção' : 'Modo seleção',
            onPressed: () {
              setState(() {
                modoSelecao = !modoSelecao;
                if (!modoSelecao) cartoesSelecionados.clear();
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Image.asset(
              'images/am_icon.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtros
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      // Filtro por data
                      Row(
                        children: [
                          const Text('Data: '),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final data = await showDatePicker(
                                  context: context,
                                  initialDate: dataFiltro ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (data != null) {
                                  setState(() => dataFiltro = data);
                                  _aplicarFiltros();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dataFiltro != null
                                      ? DateFormat('dd/MM/yyyy').format(dataFiltro!)
                                      : 'Todas as datas',
                                ),
                              ),
                            ),
                          ),
                          if (dataFiltro != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => dataFiltro = null);
                                _aplicarFiltros();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filtro por tipo
                      Row(
                        children: [
                          const Text('Tipo: '),
                          Expanded(
                            child: DropdownButton<String>(
                              value: tipoFiltro,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                                DropdownMenuItem(value: 'Desconhecidos', child: Text('Desconhecidos')),
                                DropdownMenuItem(value: 'Inativos', child: Text('Médicos Inativos')),
                                DropdownMenuItem(value: 'PorAlocar', child: Text('Por Alocar')),
                                DropdownMenuItem(value: 'Alocados', child: Text('Alocados')),
                              ],
                              onChanged: (value) {
                                setState(() => tipoFiltro = value!);
                                _aplicarFiltros();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filtro por médico
                      Row(
                        children: [
                          const Text('Médico: '),
                          Expanded(
                            child: DropdownButton<String?>(
                              value: medicoFiltro,
                              isExpanded: true,
                              hint: const Text('Todos os médicos'),
                              items: () {
                                final medicosOrdenados = List<Medico>.from(todosMedicos)
                                  ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                                return [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todos os médicos'),
                                  ),
                                  ...medicosOrdenados.map((m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text('${m.nome} ${!m.ativo ? '(Inativo)' : ''}'),
                                      )),
                                ];
                              }(),
                              onChanged: (value) {
                                setState(() => medicoFiltro = value);
                                _aplicarFiltros();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Estatísticas
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEstatistica('Total', cartoesFiltrados.length),
                      _buildEstatistica(
                        'Desconhecidos',
                        cartoesFiltrados.where((c) => c['medicoNome'] == 'Desconhecido').length,
                      ),
                      _buildEstatistica(
                        'Inativos',
                        cartoesFiltrados.where((c) => !(c['medicoAtivo'] ?? true)).length,
                      ),
                    ],
                  ),
                ),
                
                // Lista de cartões
                Expanded(
                  child: cartoesFiltrados.isEmpty
                      ? const Center(child: Text('Nenhum cartão encontrado'))
                      : ListView.builder(
                          itemCount: cartoesFiltrados.length,
                          itemBuilder: (context, index) {
                            final cartao = cartoesFiltrados[index];
                            final isSelected = cartoesSelecionados.contains(cartao['id']);
                            final isDesconhecido = cartao['medicoNome'] == 'Desconhecido';
                            final isInativo = !cartao['medicoAtivo'];
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: isSelected
                                  ? Colors.blue[100]
                                  : (isDesconhecido
                                      ? Colors.red[50]
                                      : (isInativo
                                          ? Colors.orange[50]
                                          : null)),
                              child: ListTile(
                                leading: modoSelecao
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              cartoesSelecionados.add(cartao['id'] as String);
                                            } else {
                                              cartoesSelecionados.remove(cartao['id'] as String);
                                            }
                                          });
                                        },
                                      )
                                    : null,
                                title: Text(
                                  cartao['medicoNome'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDesconhecido ? Colors.red[700] : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Data: ${DateFormat('dd/MM/yyyy').format(cartao['data'])}',
                                    ),
                                    if (cartao['tipo'] == 'alocacao')
                                      Text('Gabinete: ${cartao['gabineteNome']}'),
                                    if (cartao['tipo'] == 'disponibilidade')
                                      Text('Tipo: ${cartao['tipoDisponibilidade'] as String? ?? ''}'),
                                    if (isInativo)
                                      const Text(
                                        'Médico Inativo',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                  ],
                                ),
                                trailing: modoSelecao
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          cartoesSelecionados.add(cartao['id'] as String);
                                          await _apagarCartoesSelecionados();
                                        },
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEstatistica(String label, int valor) {
    return Column(
      children: [
        Text(
          valor.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

