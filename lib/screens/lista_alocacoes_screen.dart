import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../services/medico_salvar_service.dart';
import '../services/gabinete_service.dart';
import '../widgets/date_picker_customizado.dart';

/// Tela para listar e gerir todas as alocações da base de dados
/// Permite filtrar por nome de médico e data, e ordenar por gabinete, médico ou data
class ListaAlocacoesScreen extends StatefulWidget {
  final Unidade? unidade;

  const ListaAlocacoesScreen({super.key, this.unidade});

  @override
  State<ListaAlocacoesScreen> createState() => _ListaAlocacoesScreenState();
}

class _ListaAlocacoesScreenState extends State<ListaAlocacoesScreen> {
  List<Alocacao> todasAlocacoes = [];
  List<Alocacao> alocacoesFiltradas = [];
  List<Medico> medicos = [];
  List<Gabinete> gabinetes = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  DateTime? _dataFiltro;
  String? _medicoFiltroId;
  String? _gabineteFiltroId;
  
  // Ordenação
  String _ordenacaoAtual = 'data'; // 'gabinete', 'medico', 'data'

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);

    try {
      // Carregar médicos
      final medicosData = await buscarMedicos(
        unidade: widget.unidade,
      );
      
      // Carregar gabinetes
      final gabinetesData = await buscarGabinetes(
        unidade: widget.unidade,
      );

      // Carregar todas as alocações do ano atual e anos próximos
      final anoAtual = DateTime.now().year;
      final anosParaCarregar = [anoAtual - 1, anoAtual, anoAtual + 1];
      
      // Carregar alocações uma vez e filtrar pelos anos
      final alocacoesCarregadas = await logic.AlocacaoMedicosLogic.carregarAlocacoesUnidade(
        widget.unidade,
      );
      final todasAlocacoesTemp = alocacoesCarregadas
          .where((a) => anosParaCarregar.contains(a.data.year))
          .toList();

      setState(() {
        medicos = medicosData;
        gabinetes = gabinetesData;
        todasAlocacoes = todasAlocacoesTemp;
        _aplicarFiltros();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      alocacoesFiltradas = todasAlocacoes.where((aloc) {
        // Filtro por data
        if (_dataFiltro != null) {
          final dataFiltro = DateTime(_dataFiltro!.year, _dataFiltro!.month, _dataFiltro!.day);
          final dataAlocacao = DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
          if (dataAlocacao != dataFiltro) return false;
        }

        // Filtro por médico
        if (_medicoFiltroId != null) {
          if (aloc.medicoId != _medicoFiltroId) return false;
        }

        // Filtro por gabinete
        if (_gabineteFiltroId != null) {
          if (aloc.gabineteId != _gabineteFiltroId) return false;
        }

        return true;
      }).toList();

      // Aplicar ordenação
      _aplicarOrdenacao();
    });
  }

  void _aplicarOrdenacao() {
    switch (_ordenacaoAtual) {
      case 'gabinete':
        alocacoesFiltradas.sort((a, b) {
          final nomeA = _getNomeGabinete(a.gabineteId);
          final nomeB = _getNomeGabinete(b.gabineteId);
          return nomeA.compareTo(nomeB);
        });
        break;
      case 'medico':
        alocacoesFiltradas.sort((a, b) {
          final nomeA = _getNomeMedico(a.medicoId);
          final nomeB = _getNomeMedico(b.medicoId);
          return nomeA.compareTo(nomeB);
        });
        break;
      case 'data':
      default:
        // Ordenar por data (mais recentes primeiro)
        alocacoesFiltradas.sort((a, b) => b.data.compareTo(a.data));
        break;
    }
  }

  Future<void> _apagarAlocacao(Alocacao alocacao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja apagar esta alocação?\n\n'
          'Gabinete: ${_getNomeGabinete(alocacao.gabineteId)}\n'
          'Data: ${DateFormat('dd/MM/yyyy').format(alocacao.data)}\n'
          'Horário: ${alocacao.horarioInicio} - ${alocacao.horarioFim}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final ano = alocacao.data.year.toString();
      
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');

      await alocacoesRef.doc(alocacao.id).delete();

      // Remover da lista local
      setState(() {
        todasAlocacoes.removeWhere((a) => a.id == alocacao.id);
        _aplicarFiltros();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alocação apagada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar alocação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getNomeMedico(String medicoId) {
    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Desconhecido',
        especialidade: '',
        disponibilidades: [],
        ativo: false,
      ),
    );
    return medico.nome;
  }

  String _getNomeGabinete(String gabineteId) {
    final gabinete = gabinetes.firstWhere(
      (g) => g.id == gabineteId,
      orElse: () => Gabinete(
        id: gabineteId,
        setor: '',
        nome: gabineteId,
        especialidadesPermitidas: [],
      ),
    );
    return gabinete.nome;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Gestão de Cartões de disponibilidade',
      ),
      body: Column(
        children: [
          // Filtros e Ordenação
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Primeira linha: Filtros
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${todasAlocacoes.length} alocações',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Primeira linha: Filtros
                Row(
                  children: [
                    // Dropdown para nome de médico
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String?>(
                          value: _medicoFiltroId,
                          isExpanded: true,
                          hint: const Text('Nome do médico'),
                          underline: const SizedBox(),
                          items: () {
                            final medicosOrdenados = List<Medico>.from(medicos)
                              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                            return [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os médicos'),
                              ),
                              ...medicosOrdenados.map((m) => DropdownMenuItem<String?>(
                                    value: m.id,
                                    child: Text('${m.nome}${!m.ativo ? ' (Inativo)' : ''}'),
                                  )),
                            ];
                          }(),
                          onChanged: (value) {
                            setState(() {
                              _medicoFiltroId = value;
                              _aplicarFiltros();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dropdown para número do gabinete
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButton<String?>(
                          value: _gabineteFiltroId,
                          isExpanded: true,
                          hint: const Text('Número do gabinete'),
                          underline: const SizedBox(),
                          items: () {
                            final gabinetesOrdenados = List<Gabinete>.from(gabinetes)
                              ..sort((a, b) => a.nome.compareTo(b.nome));
                            return [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os gabinetes'),
                              ),
                              ...gabinetesOrdenados.map((g) => DropdownMenuItem<String?>(
                                    value: g.id,
                                    child: Text(g.nome),
                                  )),
                            ];
                          }(),
                          onChanged: (value) {
                            setState(() {
                              _gabineteFiltroId = value;
                              _aplicarFiltros();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botão para selecionar data
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final data = await showDatePickerCustomizado(
                            context: context,
                            initialDate: _dataFiltro ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (data != null) {
                            setState(() {
                              _dataFiltro = data;
                              _aplicarFiltros();
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _dataFiltro != null
                              ? DateFormat('dd/MM/yyyy').format(_dataFiltro!)
                              : 'Filtrar por data',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // Botão para limpar filtros
                    if (_dataFiltro != null || _medicoFiltroId != null || _gabineteFiltroId != null)
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Limpar filtros',
                        onPressed: () {
                          setState(() {
                            _dataFiltro = null;
                            _medicoFiltroId = null;
                            _gabineteFiltroId = null;
                            _aplicarFiltros();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Segunda linha: Ordenação
                Row(
                  children: [
                    const Text(
                      'Ordenar por:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'gabinete',
                            label: Text('Gabinete'),
                            icon: Icon(Icons.business, size: 18),
                          ),
                          ButtonSegment(
                            value: 'medico',
                            label: Text('Médico'),
                            icon: Icon(Icons.person, size: 18),
                          ),
                          ButtonSegment(
                            value: 'data',
                            label: Text('Data'),
                            icon: Icon(Icons.calendar_today, size: 18),
                          ),
                        ],
                        selected: {_ordenacaoAtual},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _ordenacaoAtual = newSelection.first;
                            _aplicarOrdenacao();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Mostrar contagem de resultados filtrados
                if (_dataFiltro != null || _medicoFiltroId != null || _gabineteFiltroId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Text(
                          'Resultados: ${alocacoesFiltradas.length} de ${todasAlocacoes.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : alocacoesFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Não há alocações',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: alocacoesFiltradas.length,
                        itemBuilder: (context, index) {
                          final alocacao = alocacoesFiltradas[index];
                          final medicoNome = _getNomeMedico(alocacao.medicoId);
                          final gabineteNome = _getNomeGabinete(alocacao.gabineteId);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(
                                  Icons.calendar_today,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              title: Text(
                                gabineteNome,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Médico: $medicoNome',
                                  ),
                                  Text(
                                    '${DateFormat('dd/MM/yyyy').format(alocacao.data)} • ${alocacao.horarioInicio} - ${alocacao.horarioFim}',
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _apagarAlocacao(alocacao),
                                tooltip: 'Apagar alocação',
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
}

