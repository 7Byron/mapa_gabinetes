import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../banco_dados/database_helper.dart';
import '../class/medico.dart';
import '../class/disponibilidade.dart';

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

  const CadastroMedico({Key? key, this.medico}) : super(key: key);

  @override
  CadastroMedicoState createState() => CadastroMedicoState();
}

class CadastroMedicoState extends State<CadastroMedico> {
  final _formKey = GlobalKey<FormState>();
  List<Disponibilidade> disponibilidades = [];
  List<DateTime> diasSelecionados = [];

  TextEditingController especialidadeController = TextEditingController();
  TextEditingController nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.medico != null) {
      nomeController.text = widget.medico!.nome;
      especialidadeController.text = widget.medico!.especialidade;
      _carregarDisponibilidadesSalvas(widget.medico!.id);
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

  void _adicionarData(DateTime date, String tipo) {
    final geradas = criarDisponibilidadesSerie(
      date,
      tipo,
      limitarAoAno: true,
    );

    for (final novaDisp in geradas) {
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

  Future<void> _salvarMedico() async {
    // Remova a validação se quiser salvar mesmo com campos incompletos
    // if (!_formKey.currentState!.validate()) return;

    final medico = Medico(
      id: widget.medico?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nome: nomeController.text,
      especialidade: especialidadeController.text,
      disponibilidades: disponibilidades,
      ferias: widget.medico?.ferias ?? [],
    );

    try {
      await salvarMedicoCompleto(medico);
      if (kDebugMode) {
        print('Salvo automaticamente ao sair via WillPopScope');
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
        // 1) Chama salvar
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
