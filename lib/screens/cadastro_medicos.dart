import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';

// Services
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/medico_salvar_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/disponibilidade_remocao.dart';

// Widgets
import '../widgets/disponibilidades_grid.dart';
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/formulario_medico.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroMedico extends StatefulWidget {
  final Medico? medico;
  final Unidade? unidade;

  const CadastroMedico({super.key, this.medico, this.unidade});

  @override
  CadastroMedicoState createState() => CadastroMedicoState();
}

class CadastroMedicoState extends State<CadastroMedico> {
  final _formKey = GlobalKey<FormState>();

  // Mantém o ID do médico numa variável interna
  late String _medicoId;

  // Disponibilidades e datas selecionadas
  List<Disponibilidade> disponibilidades = [];
  List<DateTime> diasSelecionados = [];

  // Controllers de texto
  TextEditingController especialidadeController = TextEditingController();
  TextEditingController nomeController = TextEditingController();
  TextEditingController observacoesController = TextEditingController();

  bool isLoadingDisponibilidades = false;

  @override
  void initState() {
    super.initState();

    // Se vier "medico" no construtor, usamos o ID dele; senão, criamos um novo
    _medicoId =
        widget.medico?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.medico != null) {
      // Editando um médico existente
      nomeController.text = widget.medico!.nome;
      especialidadeController.text = widget.medico!.especialidade;
      observacoesController.text = widget.medico!.observacoes ?? '';
      _carregarDisponibilidadesFirestore(widget.medico!.id);
    }
  }

  Future<void> _carregarDisponibilidadesFirestore(String medicoId) async {
    setState(() {
      isLoadingDisponibilidades = true;
    });

    CollectionReference disponibilidadesRef;
    if (widget.unidade != null) {
      // Busca disponibilidades da unidade específica
      disponibilidadesRef = FirebaseFirestore.instance
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('ocupantes')
          .doc(medicoId)
          .collection('disponibilidades');
    } else {
      // Busca da coleção antiga (fallback)
      disponibilidadesRef = FirebaseFirestore.instance
          .collection('medicos')
          .doc(medicoId)
          .collection('disponibilidades');
    }

    // Carrega disponibilidades da nova estrutura por ano
    final disponibilidades = <Disponibilidade>[];
    
    // Carrega apenas o ano atual por padrão (otimização)
    final anoAtual = DateTime.now().year.toString();
    final anoRef = disponibilidadesRef.doc(anoAtual);
    final registosRef = anoRef.collection('registos');
    
    try {
      final registosSnapshot = await registosRef.get();
      for (final doc in registosSnapshot.docs) {
        final data = doc.data();
        disponibilidades.add(Disponibilidade.fromMap(data));
      }
      print('📊 Disponibilidades carregadas para edição: ${disponibilidades.length} (ano: $anoAtual)');
    } catch (e) {
      print('⚠️ Erro ao carregar disponibilidades do ano $anoAtual: $e');
      // Fallback: tenta carregar de todos os anos
      final anosSnapshot = await disponibilidadesRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          disponibilidades.add(Disponibilidade.fromMap(data));
        }
      }
      print('📊 Disponibilidades carregadas (fallback): ${disponibilidades.length}');
    }
    
    setState(() {
      this.disponibilidades = disponibilidades;
      // Atualiza os dias selecionados baseado nas disponibilidades carregadas
      diasSelecionados = disponibilidades.map((d) => d.data).toList();
      isLoadingDisponibilidades = false;
    });
  }

  /// Lê as disponibilidades no banco para este médico e ordena por data
  // Future<void> _carregarDisponibilidadesSalvas(String medicoId) async {
  //   final dbDisponibilidades =
  //       await DatabaseHelper.buscarDisponibilidades(medicoId);
  //   setState(() {
  //     disponibilidades = dbDisponibilidades;
  //     // **Ordena** por data para ficar sempre cronológico
  //     disponibilidades.sort((a, b) => a.data.compareTo(b.data));
  //   });
  //   _atualizarDiasSelecionados();
  // }

  /// Adiciona data(s) no calendário (única, semanal, quinzenal, mensal), depois **ordena**.
  void _adicionarData(DateTime date, String tipo) {
    // Usa o serviço que gera a série
    final geradas = criarDisponibilidadesSerie(
      date,
      tipo,
      medicoId: _medicoId,
      limitarAoAno: true,
    );

    for (final novaDisp in geradas) {
      // Se esse dia ainda não estava selecionado, adicionamos
      if (!diasSelecionados.contains(novaDisp.data)) {
        setState(() {
          disponibilidades.add(novaDisp);
          diasSelecionados.add(novaDisp.data);
        });
      }
    }

    // Após inserir todas, **ordenamos** por data
    setState(() {
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    });
  }

  /// Remove data(s) do calendário, depois ordena a lista
  void _removerData(DateTime date, {bool removeSerie = false}) {
    setState(() {
      disponibilidades = removerDisponibilidade(
        disponibilidades,
        date,
        removeSerie: removeSerie,
      );
      // Re-atualiza a lista de dias
      diasSelecionados = disponibilidades.map((d) => d.data).toList();

      // **Ordena** novamente, só para garantir
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    });
  }

  Future<void> _salvarMedico() async {
    if (!_formKey.currentState!.validate()) {
      return; // Não salva se o formulário for inválido
    }

    // Verifica se o nome foi preenchido
    if (nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduza o nome do médico')),
      );
      return; // Interrompe o processo de salvar
    }

    final medico = Medico(
      id: _medicoId,
      nome: nomeController.text, // Captura o nome
      especialidade: especialidadeController.text, // Captura a especialidade
      observacoes: observacoesController.text, // Captura observações
      disponibilidades: disponibilidades, // Adiciona as disponibilidades
    );

    try {
      await salvarMedicoCompleto(medico, unidade: widget.unidade);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registo salvo com sucesso!')),
      );
      // Retorna true para indicar que foi salvo com sucesso
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar registo: $e')),
      );
    }
  }

  void _cancelar() {
    // Retorna para a tela anterior sem salvar
    Navigator.pop(context);
  }

  /// Reseta campos para criação de um novo registo
  void _criarNovo() {
    setState(() {
      _medicoId = DateTime.now().millisecondsSinceEpoch.toString();
      nomeController.clear();
      especialidadeController.clear();
      observacoesController.clear();
      disponibilidades.clear();
      diasSelecionados.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: CustomAppBar(
          title: widget.medico == null ? 'Novo Médico' : 'Editar Médico'),
      backgroundColor: MyAppTheme.cinzento,
      body: isLoadingDisponibilidades
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: isLargeScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Coluna esquerda (dados do médico + calendário)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FormularioMedico(
                                    nomeController: nomeController,
                                    especialidadeController:
                                        especialidadeController,
                                    observacoesController:
                                        observacoesController,
                                  ),
                                  const SizedBox(height: 16),
                                  CalendarioDisponibilidades(
                                    diasSelecionados: diasSelecionados,
                                    onAdicionarData: _adicionarData,
                                    onRemoverData: (date, removeSerie) {
                                      _removerData(date,
                                          removeSerie: removeSerie);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          IconButton(
                                            onPressed: () => _salvarMedico(),
                                            icon: const Icon(Icons.save,
                                                color: Colors.blue),
                                            tooltip: 'Salvar',
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              try {
                                                await _salvarMedico();
                                                _criarNovo();
                                              } catch (e) {
                                                // Não faz pop se der erro
                                                print('Erro ao salvar e adicionar novo: $e');
                                              }
                                            },
                                            icon: const Icon(Icons.add,
                                                color: Colors.green),
                                            tooltip: 'Salvar e Adicionar Novo',
                                          ),
                                          IconButton(
                                            onPressed: _cancelar,
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            tooltip: 'Cancelar',
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Coluna direita (grid das disponibilidades)
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              child: DisponibilidadesGrid(
                                disponibilidades: disponibilidades,
                                onRemoverData: (date, removeSerie) {
                                  _removerData(date, removeSerie: removeSerie);
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FormularioMedico(
                              nomeController: nomeController,
                              especialidadeController: especialidadeController,
                              observacoesController: observacoesController,
                            ),
                            const SizedBox(height: 16),
                            CalendarioDisponibilidades(
                              diasSelecionados: diasSelecionados,
                              onAdicionarData: _adicionarData,
                              onRemoverData: (date, removeSerie) {
                                _removerData(date, removeSerie: removeSerie);
                              },
                            ),
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: DisponibilidadesGrid(
                                disponibilidades: disponibilidades,
                                onRemoverData: (date, removeSerie) {
                                  _removerData(date, removeSerie: removeSerie);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Botão de Salvar removido, pois salvamos ao sair
                          ],
                        ),
                      ),
              ),
            ),
    );
  }
}
