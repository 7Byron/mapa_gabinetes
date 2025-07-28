import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import '../models/unidade.dart';

class AlocacaoMedicos extends StatefulWidget {
  final Unidade unidade;

  const AlocacaoMedicos({super.key, required this.unidade});

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

      // Carregar feriados do Firestore (com tratamento de erro)
      debugPrint('Carregando feriados do Firestore...');
      try {
        final feriadosSnapshot =
            await FirebaseFirestore.instance.collection('feriados').get();
        feriados = feriadosSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'data': data['data'] as String? ?? '',
            'descricao': data['descricao'] as String? ?? '',
          };
        }).toList();
        debugPrint('Feriados carregados: ${feriados.length}');
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar feriados: $e');
        feriados = []; // Lista vazia se não conseguir carregar
      }

      // Carregar horários da clínica do Firestore (com tratamento de erro)
      debugPrint('Carregando horários da clínica do Firestore...');
      try {
        final horariosSnapshot = await FirebaseFirestore.instance
            .collection('horarios_clinica')
            .get();
        for (final doc in horariosSnapshot.docs) {
          final data = doc.data();
          final diaSemana = data['diaSemana'] as int?;
          final horaAbertura = data['horaAbertura'] as String? ?? '';
          final horaFecho = data['horaFecho'] as String? ?? '';

          if (diaSemana != null && diaSemana >= 1 && diaSemana <= 7) {
            horariosClinica[diaSemana] = [horaAbertura, horaFecho];
            debugPrint(
                'Horário carregado para dia $diaSemana: $horaAbertura - $horaFecho');
          }
        }
        debugPrint('Horários da clínica carregados: ${horariosClinica.length}');
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar horários da clínica: $e');
        // Definir horários padrão se não conseguir carregar
        horariosClinica = {
          1: ['08:00', '18:00'], // Segunda
          2: ['08:00', '18:00'], // Terça
          3: ['08:00', '18:00'], // Quarta
          4: ['08:00', '18:00'], // Quinta
          5: ['08:00', '18:00'], // Sexta
          6: ['08:00', '12:00'], // Sábado
          7: ['', ''], // Domingo - fechado
        };
      }

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
    debugPrint(
        'Verificando se clínica está fechada para: ${DateFormat('dd/MM/yyyy').format(data)}');

    // Verificar se é feriado
    final ehFeriado = feriados.any((feriado) {
      final dataFeriado = DateTime.parse(feriado['data']);
      final isFeriado = data.year == dataFeriado.year &&
          data.month == dataFeriado.month &&
          data.day == dataFeriado.day;

      if (isFeriado) {
        debugPrint(
            'Data é feriado: ${feriado['descricao'] ?? 'Sem descrição'}');
      }
      return isFeriado;
    });

    // Verificar horários da clínica
    final diaSemana = data.weekday; // 1 para segunda-feira, 7 para domingo
    final horarios = horariosClinica[diaSemana];
    debugPrint('Dia da semana: $diaSemana, Horários: $horarios');

    final horarioIndisponivel =
        horarios == null || (horarios[0].isEmpty && horarios[1].isEmpty);

    debugPrint(
        'É feriado: $ehFeriado, Horário indisponível: $horarioIndisponivel');

    final clinicaFechada = ehFeriado || horarioIndisponivel;
    debugPrint('Clínica fechada: $clinicaFechada');

    return clinicaFechada;
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

  Widget _buildEmptyStateOrContent() {
    // Se não há dados, mostrar estado vazio
    if (gabinetes.isEmpty && medicos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Bem-vindo à ${widget.unidade.nome}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta unidade ainda não tem dados configurados.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                'Configurado para: ${widget.unidade.nomeOcupantes} e ${widget.unidade.nomeAlocacao}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Use o menu lateral para configurar esta unidade',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Se há dados, mostrar o conteúdo normal
    final gabinetesFiltrados = AlocacaoMedicosLogic.filtrarGabinetesPorUI(
      gabinetes: gabinetes,
      alocacoes: alocacoes,
      selectedDate: selectedDate,
      pisosSelecionados: pisosSelecionados,
      filtroOcupacao: filtroOcupacao,
      mostrarConflitos: mostrarConflitos,
    );

    return Column(
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
              // Verifica se o médico realmente está alocado antes de aceitar o cartão
              final estaAlocado = alocacoes.any((a) => a.medicoId == medicoId);
              if (!estaAlocado) {
                debugPrint(
                    'Médico $medicoId NÃO está alocado, ignorando desalocação.');
                return false;
              }
              debugPrint(
                  'Médico $medicoId está alocado, aceitando para desalocar.');
              return true;
            },
            onAcceptWithDetails: (details) async {
              final medicoId = details.data;
              // Agora só será chamado para médicos alocados
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCarregando) {
      return Scaffold(
        appBar: CustomAppBar(
            title:
                'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // AppBar já vem estilizado pelo theme
      appBar: CustomAppBar(
        title:
            'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
      ),
      drawer: CustomDrawer(
        onRefresh: _carregarDadosIniciais, // Passa o callback para o drawer
        unidade: widget.unidade, // Passa a unidade para personalizar o drawer
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
                  : _buildEmptyStateOrContent(),
            ),
          ],
        ),
      ),
    );
  }
}
