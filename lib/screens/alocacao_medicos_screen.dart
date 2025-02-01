// lib/screens/alocacao_medicos.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Se criou o custom_drawer.dart
import '../widgets/custom_drawer.dart';

// Widgets locais
import '../widgets/date_picker_section.dart';
import '../widgets/gabinetes_section.dart';
import '../widgets/medicos_disponiveis_section.dart';
import '../widgets/filtros_section.dart';

// Lógica separada
import '../utils/alocacao_medicos_logic.dart';

// Models, Database, etc.
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';


class AlocacaoMedicos extends StatefulWidget {
  const AlocacaoMedicos({super.key});

  @override
  State<AlocacaoMedicos> createState() => _AlocacaoMedicosState();
}

class _AlocacaoMedicosState extends State<AlocacaoMedicos> {
  bool isCarregando = true;
  DateTime selectedDate = DateTime.now();

  // Dados principais
  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Medico> medicosDisponiveis = [];

  // Filtros
  List<String> pisosSelecionados = [];
  String filtroOcupacao = 'Todos'; // 'Livres', 'Ocupados', 'Todos'
  bool mostrarConflitos = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    // Carrega do banco via logic
    await AlocacaoMedicosLogic.carregarDadosIniciais(
      gabinetes: gabinetes,
      medicos: medicos,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      onGabinetes: (g) => gabinetes = g,
      onMedicos: (m) => medicos = m,
      onDisponibilidades: (d) => disponibilidades = d,
      onAlocacoes: (a) => alocacoes = a,
    );

    // Filtra médicos do dia
    medicosDisponiveis = AlocacaoMedicosLogic.filtrarMedicosPorData(
      dataSelecionada: selectedDate,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      medicos: medicos,
    );

    // Inicializa pisos
    pisosSelecionados = gabinetes.map((g) => g.setor).toSet().toList();

    setState(() => isCarregando = false);
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
      medicosDisponiveis = AlocacaoMedicosLogic.filtrarMedicosPorData(
        dataSelecionada: newDate,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicos: medicos,
      );
    });
  }

  Future<void> _alocarMedico(
      String medicoId,
      String gabineteId, {
        DateTime? dataEspecifica,
      }) async {
    await AlocacaoMedicosLogic.alocarMedico(
      selectedDate: selectedDate,
      medicoId: medicoId,
      gabineteId: gabineteId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      onAlocacoesChanged: () {
        setState(() {
          // Se o médico foi alocado, removemos da lista de “disponíveis”
          medicosDisponiveis.removeWhere((m) => m.id == medicoId);
        });
      },
    );

    // Opcional colocar um "return;" explícito aqui
    // return;
  }


  Future<void> _desalocarMedicoDiaUnico(String medicoId) async {
    await AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
      selectedDate: selectedDate,
      medicoId: medicoId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      onAlocacoesChanged: () => setState(() {}),
    );
  }

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final disp = disponibilidades.firstWhere(
      (d) {
        final dd = DateTime(d.data.year, d.data.month, d.data.day);
        return d.medicoId == medicoId && dd == dataAlvo;
      },
      orElse: () => Disponibilidade(
        id: '',
        medicoId: '',
        data: DateTime(1900, 1, 1),
        horarios: [],
        tipo: 'Única',
      ),
    );

    // Se for única, desaloca só um dia
    if (disp.medicoId.isEmpty || disp.tipo == 'Única') {
      await _desalocarMedicoDiaUnico(medicoId);
      return;
    }

    // Pergunta ao usuário
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctxDialog) {
        return AlertDialog(
          title: const Text('Desalocar série?'),
          content: Text(
            'Esta disponibilidade é do tipo "${disp.tipo}".\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série a partir deste?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
              child: const Text('Apenas este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop('serie'),
              child: const Text('Toda a série'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctxDialog).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (escolha == '1dia') {
      await _desalocarMedicoDiaUnico(medicoId);
    } else if (escolha == 'serie') {
      await AlocacaoMedicosLogic.desalocarMedicoSerie(
        medicoId: medicoId,
        dataRef: dataAlvo,
        tipo: disp.tipo,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: () => setState(() {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCarregando) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Alocação de Gabinetes - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final gabinetesFiltrados = AlocacaoMedicosLogic.filtrarGabinetesPorUI(
      gabinetes: gabinetes,
      alocacoes: alocacoes,
      selectedDate: selectedDate,
      pisosSelecionados: pisosSelecionados,
      filtroOcupacao: filtroOcupacao,
      mostrarConflitos: mostrarConflitos,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alocação de Gabinetes - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
        ),
      ),
      drawer: const CustomDrawer(), // Se estiver usando o Drawer separado
      body: Row(
        children: [
          // COLUNA ESQUERDA: DatePicker + Filtros
          SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.all(8.0),
                    child: DatePickerSection(
                      selectedDate: selectedDate,
                      onDateChanged: _onDateChanged,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Widget de Filtros que extraímos
                  FiltrosSection(
                    todosSetores:
                        gabinetes.map((g) => g.setor).toSet().toList(),
                    pisosSelecionados: pisosSelecionados,
                    onTogglePiso: (setor, isSelected) {
                      setState(() {
                        if (isSelected) {
                          pisosSelecionados.add(setor);
                        } else {
                          pisosSelecionados.remove(setor);
                        }
                      });
                    },
                    filtroOcupacao: filtroOcupacao,
                    onFiltroOcupacaoChanged: (novo) {
                      setState(() => filtroOcupacao = novo);
                    },
                    mostrarConflitos: mostrarConflitos,
                    onMostrarConflitosChanged: (val) {
                      setState(() => mostrarConflitos = val);
                    },
                  ),
                ],
              ),
            ),
          ),

          // COLUNA DIREITA: Medicos Disponíveis (DragTarget p/ desalocar) + Gabinetes
          Expanded(
            child: Column(
              children: [
                // DragTarget para desalocar
                Container(
                  constraints: const BoxConstraints(minHeight: 85),
                  width: double.infinity,
                  child: DragTarget<String>(
                    onWillAccept: (_) => true,
                    onAccept: (medicoId) async {
                      await _desalocarMedicoComPergunta(medicoId);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          color: isHovering ? Colors.blue[50] : Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        margin: const EdgeInsets.all(8),
                        child: MedicosDisponiveisSection(
                          medicosDisponiveis: medicosDisponiveis,
                          disponibilidades: disponibilidades,
                          selectedDate: selectedDate,
                          onDesalocarMedico: (mId) =>
                              _desalocarMedicoDiaUnico(mId),
                        ),
                      );
                    },
                  ),
                ),

                // Gabinetes: DragTarget para alocar
                Expanded(
                    child: GabinetesSection(
                  gabinetes: gabinetesFiltrados,
                  alocacoes: alocacoes,
                  medicos: medicos,
                  disponibilidades: disponibilidades,
                  selectedDate: selectedDate,

                  // Troque para a mesma assinatura:
                  onAlocarMedico: (String medicoId, String gabineteId,
                      {DateTime? dataEspecifica}) async {
                    // Aqui você chama seu método de alocar
                    await _alocarMedico(medicoId, gabineteId,
                        dataEspecifica: dataEspecifica);
                  },

                  onAtualizarEstado: () {
                    setState(() {
                      // ...
                    });
                  },
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
