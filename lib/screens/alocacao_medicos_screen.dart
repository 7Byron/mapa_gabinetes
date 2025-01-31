import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Adicione esta linha
import 'package:mapa_gabinetes/screens/relatorio_especialidades_screen.dart';
import 'package:mapa_gabinetes/screens/relatorios_screen.dart';

// Imports locais
import '../widgets/date_picker_section.dart';
import '../widgets/gabinetes_section.dart';
import '../widgets/medicos_disponiveis_section.dart';
import '../utils/conflict_utils.dart';

import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';

import '../database/database_helper.dart';
import 'banco_dados_screen.dart';
import 'config_clinica_screen.dart';
import 'lista_gabinetes.dart';
import 'lista_medicos.dart';
// Importa a classe separada


/// ================================================
///                 AlocacaoMedicos
/// ================================================
class AlocacaoMedicos extends StatefulWidget {
  const AlocacaoMedicos({super.key});

  @override
  AlocacaoMedicosState createState() => AlocacaoMedicosState();
}

class AlocacaoMedicosState extends State<AlocacaoMedicos> {
  bool isCarregando = true;
  DateTime selectedDate = DateTime.now();

  // --- Dados principais ---
  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Medico> medicosDisponiveis = [];

  // --- Filtros ---
  List<String> pisosSelecionados = [];
  String filtroOcupacao = 'Todos'; // 'Livres', 'Ocupados', 'Todos'
  bool mostrarConflitos = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    gabinetes = await DatabaseHelper.buscarGabinetes();
    medicos = await DatabaseHelper.buscarMedicos();
    disponibilidades = await DatabaseHelper.buscarTodasDisponibilidades();
    alocacoes = await DatabaseHelper.buscarAlocacoes();

    _filtrarMedicosPorData(selectedDate);

    // Inicializa filtros de piso
    pisosSelecionados = gabinetes.map((g) => g.setor).toSet().toList();

    setState(() {
      isCarregando = false;
    });
  }

  /// Filtra médicos disponíveis no dia (com base em `disponibilidades` e `alocacoes` existentes)
  void _filtrarMedicosPorData(DateTime dataSelecionada) {
    final dataAlvo = DateTime(dataSelecionada.year, dataSelecionada.month, dataSelecionada.day);

    final dispNoDia = disponibilidades.where((disp) {
      final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return d == dataAlvo;
    }).toList();

    final idsMedicosNoDia = dispNoDia.map((d) => d.medicoId).toSet();
    final alocadosNoDia = alocacoes.where((a) {
      final aData = DateTime(a.data.year, a.data.month, a.data.day);
      return aData == dataAlvo;
    }).map((a) => a.medicoId).toSet();

    medicosDisponiveis = medicos
        .where((m) => idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
        .toList();
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
    });
    _filtrarMedicosPorData(newDate);
  }

  Future<void> _alocarMedico(
      String medicoId,
      String gabineteId, {
        DateTime? dataEspecifica,
      }) async {
    final d = dataEspecifica ?? selectedDate;
    final dataAlvo = DateTime(d.year, d.month, d.day);

    // Remove alocação prévia desse médico nesse dia (se existir)
    final indexAloc = alocacoes.indexWhere((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && alocDate == dataAlvo;
    });
    if (indexAloc != -1) {
      final alocAntiga = alocacoes[indexAloc];
      alocacoes.removeAt(indexAloc);
      await DatabaseHelper.deletarAlocacao(alocAntiga.id);
    }

    // Descobre horários (concatenados) que o médico tem nesse dia
    final dispDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataAlvo;
    }).toList();
    final horarioInicio = dispDoDia.isNotEmpty ? dispDoDia.first.horarios[0] : '00:00';
    final horarioFim = dispDoDia.isNotEmpty ? dispDoDia.first.horarios[1] : '00:00';

    final novaAloc = Alocacao(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataAlvo,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );
    // Persiste no banco
    await DatabaseHelper.salvarAlocacao(novaAloc);
    // Atualiza lista local
    alocacoes.add(novaAloc);

    // Se for a data “visível” (selectedDate), remove da lista de disponíveis
    final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    if (dataAlvo == sel) {
      medicosDisponiveis.removeWhere((m) => m.id == medicoId);
    }

    setState(() {});
  }

  /// Remove a alocação do médico *apenas para UM dia* (o selectedDate ou dataEspecifica).
  Future<void> _desalocarMedicoDiaUnico(String medicoId, {DateTime? dataEspecifica}) async {
    final d = dataEspecifica ?? selectedDate;
    final dataAlvo = DateTime(d.year, d.month, d.day);

    final indexAloc = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });
    if (indexAloc == -1) return; // nada a remover

    final alocRemovida = alocacoes[indexAloc];
    alocacoes.removeAt(indexAloc);
    await DatabaseHelper.deletarAlocacao(alocRemovida.id);

    // Se ele ainda tem disponibilidade nesse dia, volta para "medicosDisponiveis"
    final temDisp = disponibilidades.any((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataAlvo;
    });
    if (temDisp) {
      final medico = medicos.firstWhere(
            (m) => m.id == medicoId,
        orElse: () => Medico(
          id: medicoId,
          nome: 'Médico não identificado',
          especialidade: '',
          disponibilidades: [],
        ),
      );
      if (!medicosDisponiveis.contains(medico)) {
        medicosDisponiveis.add(medico);
      }
    }

    setState(() {});
  }

  /// Remove a alocação do médico para **todos os dias** da série a partir de `dataRef`.
  Future<void> _desalocarMedicoSerie(String medicoId, DateTime dataRef, String tipo) async {
    // Filtra as disponibilidades do mesmo médico e tipo, a partir de dataRef
    final listaMesmaSerie = disponibilidades.where((d2) {
      if (d2.medicoId != medicoId) return false;
      if (d2.tipo != tipo) return false;
      // d2.data >= dataRef
      return !d2.data.isBefore(dataRef);
    }).toList();

    // Para cada disponibilidade na série, remove a alocação se existir.
    for (final disp in listaMesmaSerie) {
      // Normaliza a data
      final dataAlvo = DateTime(disp.data.year, disp.data.month, disp.data.day);

      final indexAloc = alocacoes.indexWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate == dataAlvo;
      });

      if (indexAloc != -1) {
        final alocRemovida = alocacoes[indexAloc];
        alocacoes.removeAt(indexAloc);
        await DatabaseHelper.deletarAlocacao(alocRemovida.id);
      }

      // Se ainda tem disponibilidade nesse dia, reintroduz na lista de médicosDisponiveis
      final temDisp = disponibilidades.any((disp2) {
        final dd = DateTime(disp2.data.year, disp2.data.month, disp2.data.day);
        return disp2.medicoId == medicoId && dd == dataAlvo;
      });
      if (temDisp) {
        final medico = medicos.firstWhere(
              (m) => m.id == medicoId,
          orElse: () => Medico(
            id: medicoId,
            nome: 'Médico não identificado',
            especialidade: '',
            disponibilidades: [],
          ),
        );
        if (!medicosDisponiveis.contains(medico)) {
          medicosDisponiveis.add(medico);
        }
      }
    }

    setState(() {});
  }

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    final dataAlvo = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

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

    if (disp.medicoId.isEmpty || disp.tipo == 'Única') {
      // Se for disponibilidade única ou não encontrada, desaloca só um dia
      await _desalocarMedicoDiaUnico(medicoId, dataEspecifica: dataAlvo);
    } else {
      // Pergunta ao usuário se quer desalocar só este dia ou toda a série
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
        await _desalocarMedicoDiaUnico(medicoId, dataEspecifica: dataAlvo);
      } else if (escolha == 'serie') {
        await _desalocarMedicoSerie(medicoId, dataAlvo, disp.tipo);
      }
    }
  }

  // ==========================================================================
  //                 Filtros (coluna da esquerda)
  // ==========================================================================
  List<Gabinete> _filtrarGabinetesPorUI() {
    final filtrados = gabinetes.where((g) => pisosSelecionados.contains(g.setor)).toList();

    List<Gabinete> filtradosOcupacao = [];
    for (final gab in filtrados) {
      final alocacoesDoGab = alocacoes.where((a) {
        return a.gabineteId == gab.id &&
            a.data.year == selectedDate.year &&
            a.data.month == selectedDate.month &&
            a.data.day == selectedDate.day;
      }).toList();

      final estaOcupado = alocacoesDoGab.isNotEmpty;

      if (filtroOcupacao == 'Todos') {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Livres' && !estaOcupado) {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Ocupados' && estaOcupado) {
        filtradosOcupacao.add(gab);
      }
    }

    if (mostrarConflitos) {
      return filtradosOcupacao.where((gab) {
        final alocacoesDoGab = alocacoes.where((a) {
          return a.gabineteId == gab.id &&
              a.data.year == selectedDate.year &&
              a.data.month == selectedDate.month &&
              a.data.day == selectedDate.day;
        }).toList();
        return ConflictUtils.temConflitoGabinete(alocacoesDoGab);
      }).toList();
    } else {
      return filtradosOcupacao;
    }
  }

  Widget _buildFiltrosWidget() {
    final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 30),

          const Text('Pisos:'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: todosSetores.map((setor) {
              return FilterChip(
                label: Text(setor),
                selected: pisosSelecionados.contains(setor),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      pisosSelecionados.add(setor);
                    } else {
                      pisosSelecionados.remove(setor);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          const Text('Ocupação:'),
          DropdownButton<String>(
            value: filtroOcupacao,
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Livres', child: Text('Livres')),
              DropdownMenuItem(value: 'Ocupados', child: Text('Ocupados')),
            ],
            onChanged: (value) {
              setState(() => filtroOcupacao = value ?? 'Todos');
            },
          ),
          const SizedBox(height: 10),

          CheckboxListTile(
            title: const Text('Mostrar Conflitos'),
            controlAffinity: ListTileControlAffinity.leading,
            value: mostrarConflitos,
            onChanged: (bool? val) {
              setState(() => mostrarConflitos = val ?? false);
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  //                           LAYOUT PRINCIPAL
  // ==========================================================================
  @override
  @override
  Widget build(BuildContext context) {
    if (isCarregando) {
      return Scaffold(
        appBar: AppBar( // Mantenha o AppBar mesmo durante o carregamento
          title: Text(
            'Alocação de Gabinetes do dia ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final gabinetesFiltrados = _filtrarGabinetesPorUI();

    return Scaffold(
      appBar: AppBar( // AppBar com a data dinâmica
        title: Text(
          'Alocação de Gabinetes do dia ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Gestão Mapa Gabinetes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // ListTile(
            //   leading: Icon(Icons.calendar_month),
            //   title: Text('Alocação Gabinetes'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => TelaPrincipal()),
            //     );
            //   },
            // ),
            ListTile(
              leading: Icon(Icons.medical_services),
              title: Text('Gerir Médicos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaMedicos()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.business),
              title: Text('Gerir Gabinetes'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaGabinetes()),
                );
              },
            ),
            // New ListTile for Settings
            ListTile(
              leading: Icon(Icons.dataset_outlined), // Icon for settings
              title: Text('Base de Dados'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          BancoDadosScreen()), // Navigate to the settings screen
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configurar Horários'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConfigClinicaScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.bar_chart),
              title: Text('Relatórios de Ocupação'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RelatoriosScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Relatório Especialidades'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RelatorioEspecialidadesScreen()),
                );
              },
            ),

          ],
        ),
      ),
      body: Row(
        children: [
          // ----------------------------------------------------------
          // COLUNA DA ESQUERDA: DatePicker (em cima) + Filtros (embaixo)
          // ----------------------------------------------------------
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
                  _buildFiltrosWidget(),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------------
          // COLUNA DA DIREITA: (1) Médicos livres (top) + DragTarget para desalocar
          //                    (2) GabinetesSection (grid de gabinetes)
          // ----------------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // DragTarget para “desalocar”
                Container(
                  constraints: const BoxConstraints(minHeight: 85),
                  width: double.infinity,
                  child: DragTarget<String>(
                    onWillAccept: (_) => true,
                    onAccept: (medicoId) async {
                      // Pergunta se quer desalocar toda a série ou só esse dia
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
                        margin: EdgeInsets.all(8), // Margem externa
                        child: MedicosDisponiveisSection(
                          medicosDisponiveis: medicosDisponiveis,
                          disponibilidades: disponibilidades,
                          selectedDate: selectedDate,
                          onDesalocarMedico: (mId) =>
                              _desalocarMedicoDiaUnico(mId, dataEspecifica: selectedDate),
                        ),
                      );
                    },
                  ),
                ),

                // Gabinetes com DragTarget para “alocar”
                Expanded(
                  child: GabinetesSection(
                    gabinetes: gabinetesFiltrados,
                    alocacoes: alocacoes,
                    medicos: medicos,
                    disponibilidades: disponibilidades,
                    selectedDate: selectedDate,
                    onAlocarMedico: _alocarMedico,
                    onAtualizarEstado: () {
                      setState(() {
                        // Remova os médicos alocados da lista de médicos disponíveis
                        medicosDisponiveis.removeWhere((m) =>
                            alocacoes.any((a) => a.medicoId == m.id && a.data == selectedDate));
                      });
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
