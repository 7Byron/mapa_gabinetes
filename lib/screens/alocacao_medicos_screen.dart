import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';

// Se criou o custom_drawer.dart
import '../widgets/custom_drawer.dart';

// Widgets locais
import '../widgets/date_picker_section.dart';
import '../widgets/gabinetes_section.dart';
import '../widgets/medicos_disponiveis_section.dart';
import '../widgets/filtros_section.dart';

// Lógica separada
import '../utils/alocacao_medicos_logic.dart';

// Models
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';

class AlocacaoMedicos extends StatefulWidget {
  const AlocacaoMedicos({super.key});

  @override
  State<AlocacaoMedicos> createState() => AlocacaoMedicosState();
}

class AlocacaoMedicosState extends State<AlocacaoMedicos> {
  bool isCarregando = true;
  DateTime selectedDate = DateTime.now();

  // Dados principais
  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Medico> medicosDisponiveis = [];

  // Dados da clínica
  List<Map<String, dynamic>> feriados = [];
  Map<int, List<String>> horariosClinica = {};
  bool clinicaFechada = false;
  String mensagemClinicaFechada = '';

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
    try {
      // Carrega do banco via logic
      await AlocacaoMedicosLogic.carregarDadosIniciais(
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        onGabinetes: (g) => gabinetes = g,
        onMedicos: (m) => medicos = m,
        onDisponibilidades: (d) => disponibilidades = d,
        onAlocacoes: (a) {
          alocacoes = a;
          setState(() {});
        },
      );

      // TODO: Refatorar para usar Firestore diretamente.
      // Todas as referências a DatabaseHelper removidas.
      // feriados = await DatabaseHelper.buscarFeriados();

      // TODO: Refatorar para usar Firestore diretamente.
      // Todas as referências a DatabaseHelper removidas.
      // final horariosRows = await DatabaseHelper.buscarHorariosClinica();
      // for (final row in horariosRows) {
      //   final diaSemana = row['diaSemana'] as int;
      //   final horaAbertura = (row['horaAbertura'] ?? "") as String;
      //   final horaFecho = (row['horaFecho'] ?? "") as String;
      //   horariosClinica[diaSemana] = [horaAbertura, horaFecho];
      // }

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
    } catch (e) {
      debugPrint('Erro ao carregar dados do banco: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados do banco.')),
      );
    }
  }

  bool _verificarClinicaFechada(DateTime data) {
    // Verificar se é feriado
    final ehFeriado = feriados.any((feriado) {
      final dataFeriado = DateTime.parse(feriado['data']);
      return data.year == dataFeriado.year &&
          data.month == dataFeriado.month &&
          data.day == dataFeriado.day;
    });

    // Verificar horários da clínica
    final diaSemana = data.weekday; // 1 para segunda-feira, 7 para domingo
    final horarios = horariosClinica[diaSemana];
    final horarioIndisponivel =
        horarios == null || (horarios[0].isEmpty && horarios[1].isEmpty);

    return ehFeriado || horarioIndisponivel;
  }

  void _onDateChanged(DateTime newDate) {
    final clinicaEncerrada = _verificarClinicaFechada(newDate);

    setState(() {
      selectedDate = newDate;
      clinicaFechada = clinicaEncerrada;
      mensagemClinicaFechada =
          clinicaEncerrada ? 'A clínica está encerrada neste dia!' : '';

      if (!clinicaEncerrada) {
        medicosDisponiveis = AlocacaoMedicosLogic.filtrarMedicosPorData(
          dataSelecionada: newDate,
          disponibilidades: disponibilidades,
          alocacoes: alocacoes,
          medicos: medicos,
        );
      }
    });
  }

  Future<void> _alocarMedico(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
  }) async {
    await AlocacaoMedicosLogic.alocarMedico(
      selectedDate: dataEspecifica ?? selectedDate,
      medicoId: medicoId,
      gabineteId: gabineteId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      onAlocacoesChanged: () {
        setState(() {
          // Se o médico foi alocado, removemos da lista de “disponíveis”
          medicosDisponiveis.removeWhere((m) => m.id == medicoId);
          _carregarDadosIniciais();
        });
      },
    );
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
        appBar: CustomAppBar(
            title:
                'Mapa de Gabinetes - ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
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
      // AppBar já vem estilizado pelo theme
      appBar: CustomAppBar(
        title:
            'Mapa de Gabinetes - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
      ),
      drawer: CustomDrawer(
        onRefresh: _carregarDadosIniciais, // Passa o callback para o drawer
      ),
      // Corpo com cor de fundo suave e layout mais espaçoso
      body: Container(
        color: Colors.grey.shade200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coluna Esquerda: DatePicker + Filtros
            Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // DatePicker
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: DatePickerSection(
                        selectedDate: selectedDate,
                        onDateChanged: _onDateChanged,
                      ),
                    ),

                    // Filtros
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: FiltrosSection(
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
                    ),
                  ],
                ),
              ),
            ),

            // Coluna Direita: Médicos Disponíveis (dragTarget) e Gabinetes
            Expanded(
              child: clinicaFechada
                  ? Center(
                      child: Text(
                        mensagemClinicaFechada,
                        style: const TextStyle(fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 12),

                        // DragTarget: área para desalocar médico
                        Container(
                          constraints: const BoxConstraints(minHeight: 85),
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: DragTarget<String>(
                            onWillAcceptWithDetails: (details) {
                              final medicoId = details.data;
                              final estaAlocado = alocacoes.any((a) => a.medicoId == medicoId);
                              if (!estaAlocado) {
                                debugPrint('Médico $medicoId NÃO está alocado, ignorando desalocação.');
                                return false;
                              }
                              debugPrint('Médico $medicoId está alocado, aceitando para desalocar.');
                              return true;
                            },
                            onAcceptWithDetails: (details) async {
                              final medicoId = details.data;
                              await _desalocarMedicoComPergunta(medicoId);
                            },
                            builder: (context, candidateData, rejectedData) {
                              return MedicosDisponiveisSection(
                                medicosDisponiveis: medicosDisponiveis,
                                disponibilidades: disponibilidades,
                                selectedDate: selectedDate,
                                onDesalocarMedico: (mId) => _desalocarMedicoDiaUnico(mId),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Lista / Grade de Gabinetes
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: GabinetesSection(
                              gabinetes: gabinetesFiltrados,
                              alocacoes: alocacoes,
                              medicos: medicos,
                              disponibilidades: disponibilidades,
                              selectedDate: selectedDate,
                              onAlocarMedico: _alocarMedico,
                              onAtualizarEstado: _carregarDadosIniciais,
                              onDesalocarMedicoComPergunta: _desalocarMedicoComPergunta,
                            ),
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
