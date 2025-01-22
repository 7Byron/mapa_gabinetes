import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../banco_dados/database_helper.dart';
import '../class/disponibilidade.dart';
import '../class/medico.dart';

// Services
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

  // Vamos manter o ID do médico numa variável interna
  late String _medicoId;

  // Disponibilidades e datas selecionadas
  List<Disponibilidade> disponibilidades = [];
  List<DateTime> diasSelecionados = [];

  // Controllers de texto
  TextEditingController especialidadeController = TextEditingController();
  TextEditingController nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Se vier "medico" no construtor, usamos o ID dele
    // Senão, geramos um novo ID
    _medicoId = widget.medico?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.medico != null) {
      // Estamos editando um médico existente
      nomeController.text = widget.medico!.nome;
      especialidadeController.text = widget.medico!.especialidade;
      // Carregamos as disponibilidades deste médico do banco
      _carregarDisponibilidadesSalvas(_medicoId);
    }
  }

  Future<void> _carregarDisponibilidadesSalvas(String medicoId) async {
    final dbDisponibilidades = await DatabaseHelper.buscarDisponibilidades(medicoId);
    setState(() {
      disponibilidades = dbDisponibilidades;
    });
    _atualizarDiasSelecionados();
  }

  void _atualizarDiasSelecionados() {
    diasSelecionados = disponibilidades.map((d) => d.data).toList();
    setState(() {});
  }

  /// Adiciona um dia no calendário, com um [tipo] (Única, Semanal, etc.).
  /// Agora passamos `medicoId: _medicoId` para criar as disponibilidades.
  void _adicionarData(DateTime date, String tipo) {
    final geradas = criarDisponibilidadesSerie(
      date,
      tipo,
      medicoId: _medicoId,       // <-- IMPORTANTE
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
  }

  void _removerData(DateTime date, {bool removeSerie = false}) {
    setState(() {
      disponibilidades = removerDisponibilidade(
        disponibilidades,
        date,
        removeSerie: removeSerie,
      );
      diasSelecionados = disponibilidades.map((d) => d.data).toList();
    });
  }

  /// Salva o médico atual (novo ou já existente).
  /// Ao salvar, passamos as disponibilidades que já possuem o `medicoId`.
  Future<void> _salvarMedico() async {
    // if (!_formKey.currentState!.validate()) return; // se quiser validar

    final medico = Medico(
      id: _medicoId, // <-- Usamos o ID definido no initState
      nome: nomeController.text,
      especialidade: especialidadeController.text,
      disponibilidades: disponibilidades,
    );

    try {
      // Salva no banco (inserindo/atualizando)
      await salvarMedicoCompleto(medico);
      if (kDebugMode) {
        print('Medico ${medico.id} salvo com sucesso!');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar o médico: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return WillPopScope(
      onWillPop: () async {
        // 1) Chama salvar antes de sair
        await _salvarMedico();
        // 2) Retorna true para concluir o pop
        return true;
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
                          especialidadeController: especialidadeController,
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
