import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
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
  List<Alocacao> todasAlocacoesCarregadas = []; // Todas as alocações sem filtro de ano
  List<Medico> medicos = [];
  List<Gabinete> gabinetes = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  DateTime? _dataFiltro;
  String? _medicoFiltroId;
  String? _gabineteFiltroId;
  late int _anoFiltro; // Ano selecionado para filtro
  
  // Ordenação
  String _ordenacaoAtual = 'data'; // 'gabinete', 'medico', 'data'

  @override
  void initState() {
    super.initState();
    _anoFiltro = DateTime.now().year; // Ano corrente por default
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

      // Carregar todas as alocações de TODOS os anos disponíveis
      final alocacoesCarregadas = await _carregarTodasAlocacoesTodosAnos();

      setState(() {
        medicos = medicosData;
        gabinetes = gabinetesData;
        todasAlocacoesCarregadas = alocacoesCarregadas;
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

  /// Carrega todas as alocações de todos os anos disponíveis
  Future<List<Alocacao>> _carregarTodasAlocacoesTodosAnos() async {
    final firestore = FirebaseFirestore.instance;
    final todasAlocacoes = <Alocacao>[];

    if (widget.unidade == null) return todasAlocacoes;

    try {
      // Buscar todos os anos disponíveis na coleção de alocações
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('alocacoes');

      final anosSnapshot = await alocacoesRef.get();

      // Carregar alocações de cada ano em paralelo
      final futures = <Future<void>>[];

      for (final anoDoc in anosSnapshot.docs) {
        final ano = anoDoc.id;
        final registosRef = anoDoc.reference.collection('registos');
        
        futures.add(
          registosRef.get().then((registosSnapshot) {
            for (final doc in registosSnapshot.docs) {
              try {
                final data = doc.data();
                final alocacao = Alocacao.fromMap(data);
                todasAlocacoes.add(alocacao);
              } catch (e) {
                debugPrint('Erro ao carregar alocação do ano $ano: $e');
              }
            }
          }).catchError((e) {
            debugPrint('Erro ao carregar alocações do ano $ano: $e');
          }),
        );
      }

      // Aguardar todas as cargas em paralelo
      await Future.wait(futures);

      debugPrint('✅ Carregadas ${todasAlocacoes.length} alocações de ${anosSnapshot.docs.length} anos');
    } catch (e) {
      debugPrint('❌ Erro ao carregar todas as alocações: $e');
    }

    return todasAlocacoes;
  }

  void _aplicarFiltros() {
    setState(() {
      // Primeiro, filtrar por ano
      todasAlocacoes = todasAlocacoesCarregadas
          .where((a) => a.data.year == _anoFiltro)
          .toList();

      // Se um médico foi selecionado, resetar o filtro de gabinete se não for válido
      if (_medicoFiltroId != null && _gabineteFiltroId != null) {
        final gabinetesDisponiveis = _getGabinetesFiltrados();
        final gabineteValido = gabinetesDisponiveis.any((g) => g.id == _gabineteFiltroId);
        if (!gabineteValido) {
          _gabineteFiltroId = null;
        }
      }

      alocacoesFiltradas = todasAlocacoes.where((aloc) {
        // Filtro por médico (primeiro)
        if (_medicoFiltroId != null) {
          if (aloc.medicoId != _medicoFiltroId) return false;
        }

        // Filtro por data (depois do médico)
        if (_dataFiltro != null) {
          final dataFiltro = DateTime(_dataFiltro!.year, _dataFiltro!.month, _dataFiltro!.day);
          final dataAlocacao = DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
          if (dataAlocacao != dataFiltro) return false;
        }

        // Filtro por gabinete (por último)
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
        // Ordenar por data (crescente - mais antigas primeiro)
        alocacoesFiltradas.sort((a, b) => a.data.compareTo(b.data));
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

  // Obter gabinetes filtrados baseado no médico selecionado
  List<Gabinete> _getGabinetesFiltrados() {
    if (_medicoFiltroId == null) {
      return gabinetes;
    }
    
    // Obter todos os gabinetes únicos das alocações do médico selecionado
    final gabinetesIds = todasAlocacoes
        .where((aloc) => aloc.medicoId == _medicoFiltroId)
        .map((aloc) => aloc.gabineteId)
        .toSet();
    
    return gabinetes.where((g) => gabinetesIds.contains(g.id)).toList();
  }


  // Obter lista de anos disponíveis nas alocações
  List<int> _getAnosDisponiveis() {
    if (todasAlocacoesCarregadas.isEmpty) {
      return [DateTime.now().year]; // Retornar pelo menos o ano atual
    }
    final anos = todasAlocacoesCarregadas
        .map((a) => a.data.year)
        .toSet()
        .toList();
    anos.sort((a, b) => b.compareTo(a)); // Ordenar decrescente
    return anos;
  }

  // Widget para opção de ordenação
  Widget _buildOpcaoOrdenacao(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    final isSelected = _ordenacaoAtual == value;
    return InkWell(
      onTap: () {
        setState(() {
          _ordenacaoAtual = value;
          _aplicarOrdenacao();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected 
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            ),
            Icon(
              Icons.sort_by_alpha,
              size: 16,
              color: isSelected 
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anosDisponiveis = _getAnosDisponiveis();
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Cartões de disponibilidade',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            // Dropdown de ano
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: DropdownButton<int>(
                value: anosDisponiveis.contains(_anoFiltro) 
                    ? _anoFiltro 
                    : (anosDisponiveis.isNotEmpty ? anosDisponiveis.first : DateTime.now().year),
                underline: const SizedBox(),
                dropdownColor: Theme.of(context).primaryColor,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                items: anosDisponiveis.map((ano) {
                  return DropdownMenuItem<int>(
                    value: ano,
                    child: Text(ano.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _anoFiltro = value;
                      _aplicarFiltros();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              height: 32,
              width: 32,
              child: Image.asset(
                'images/am_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna Esquerda: Filtros e Ordenação
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filtro de Médico
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<String?>(
                        value: _medicoFiltroId,
                        isExpanded: true,
                        hint: const Text('Todos os médicos'),
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
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
                            if (value != null) {
                              _gabineteFiltroId = null;
                            }
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filtro de Gabinete
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<String?>(
                        value: _gabineteFiltroId,
                        isExpanded: true,
                        hint: const Text('Todos os gabinetes'),
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                        items: () {
                          final gabinetesParaMostrar = _getGabinetesFiltrados();
                          final gabinetesOrdenados = List<Gabinete>.from(gabinetesParaMostrar)
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
                    const SizedBox(height: 12),
                    // Filtro de Data
                    InkWell(
                      onTap: () async {
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dataFiltro != null
                                    ? DateFormat('dd/MM/yyyy').format(_dataFiltro!)
                                    : 'Filtrar por data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _dataFiltro != null 
                                      ? Colors.black 
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Botão para limpar filtros
                    if (_dataFiltro != null || _medicoFiltroId != null || _gabineteFiltroId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _dataFiltro = null;
                              _medicoFiltroId = null;
                              _gabineteFiltroId = null;
                              _aplicarFiltros();
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Limpar filtros'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Ordenação
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ordenar por',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              _buildOpcaoOrdenacao(
                                context,
                                'gabinete',
                                Icons.business,
                                'Gabinete',
                              ),
                              const SizedBox(height: 8),
                              _buildOpcaoOrdenacao(
                                context,
                                'medico',
                                Icons.person,
                                'Médico',
                              ),
                              const SizedBox(height: 8),
                              _buildOpcaoOrdenacao(
                                context,
                                'data',
                                Icons.calendar_today,
                                'Data',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Coluna Direita: Lista de Alocações
          Expanded(
            child: Column(
              children: [
                // Cards de Métricas
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${todasAlocacoes.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dataFiltro != null || _medicoFiltroId != null || _gabineteFiltroId != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filtrados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${alocacoesFiltradas.length}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: alocacoesFiltradas.length,
                              itemBuilder: (context, index) {
                                final alocacao = alocacoesFiltradas[index];
                                final medicoNome = _getNomeMedico(alocacao.medicoId);
                                final gabineteNome = _getNomeGabinete(alocacao.gabineteId);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        // Ícone
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.calendar_today,
                                            color: Colors.blue.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Informações em Row
                                        Expanded(
                                          child: Row(
                                            children: [
                                              // Gabinete
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  gabineteNome,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              // Médico
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  medicoNome,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Data e Horário
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${DateFormat('dd/MM/yyyy').format(alocacao.data)} • ${alocacao.horarioInicio} - ${alocacao.horarioFim}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Botão de deletar
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _apagarAlocacao(alocacao),
                                          tooltip: 'Apagar alocação',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

