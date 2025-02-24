import 'package:flutter/material.dart';

// Services
import '../database/database_helper.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../services/medico_salvar_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/disponibilidade_remocao.dart';

// Widgets
import '../widgets/disponibilidades_grid.dart';
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/formulario_medico.dart';

class CadastroMedico extends StatefulWidget {
  final Medico? medico;

  const CadastroMedico({super.key, this.medico});

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

      // Carregamos as disponibilidades deste médico do banco
      _carregarDisponibilidadesSalvas(_medicoId);
    }
  }

  /// Lê as disponibilidades no banco para este médico e ordena por data
  Future<void> _carregarDisponibilidadesSalvas(String medicoId) async {
    final dbDisponibilidades =
        await DatabaseHelper.buscarDisponibilidades(medicoId);
    setState(() {
      disponibilidades = dbDisponibilidades;
      // **Ordena** por data para ficar sempre cronológico
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    });
    _atualizarDiasSelecionados();
  }

  /// Atualiza o array de [diasSelecionados] com base na lista de [disponibilidades]
  void _atualizarDiasSelecionados() {
    diasSelecionados = disponibilidades.map((d) => d.data).toList();
    setState(() {});
  }

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

    final medico = Medico(
      id: _medicoId,
      nome: nomeController.text, // Captura o nome
      especialidade: especialidadeController.text, // Captura a especialidade
      observacoes: observacoesController.text, // Captura observações
      disponibilidades: disponibilidades, // Adiciona as disponibilidades
    );

    try {
      await salvarMedicoCompleto(medico);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Médico salvo com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar médico: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return WillPopScope(
      onWillPop: () async {
        // Salva antes de sair
        await _salvarMedico();
        return true; // permite pop
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.medico == null ? 'Novo Médico' : 'Editar Médico'),
        ),
        body: Padding(
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
                              // Botão de Salvar removido, pois salvamos ao sair
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
      ),
    );
  }
}
