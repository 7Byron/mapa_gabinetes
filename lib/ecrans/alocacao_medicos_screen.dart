import 'package:flutter/material.dart';

import '../alocacao/date_picker_section. dart.dart';
import '../class/medico.dart';
import '../class/gabinete.dart';
import '../class/alocacao.dart';
import '../class/disponibilidade.dart';
import '../banco_dados/database_helper.dart'; // Ajuste para seu caminho real
import '../alocacao/gabinetes_section.dart';
import '../alocacao/medicos_disponiveis_section.dart';

class AlocacaoMedicos extends StatefulWidget {
  @override
  _AlocacaoMedicosState createState() => _AlocacaoMedicosState();
}

class _AlocacaoMedicosState extends State<AlocacaoMedicos> {
  DateTime selectedDate = DateTime.now();

  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Medico> medicosDisponiveis = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];

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
    setState(() {});
  }

  void _filtrarMedicosPorData(DateTime dataSelecionada) {
    final dispNoDia = disponibilidades.where((disp) {
      return disp.data.year == dataSelecionada.year &&
          disp.data.month == dataSelecionada.month &&
          disp.data.day == dataSelecionada.day;
    }).toList();

    final idsMedicosNoDia = dispNoDia.map((d) => d.medicoId).toSet();
    final alocadosNoDia = alocacoes
        .where((a) =>
    a.data.year == dataSelecionada.year &&
        a.data.month == dataSelecionada.month &&
        a.data.day == dataSelecionada.day)
        .map((a) => a.medicoId)
        .toSet();

    // Médicos que têm disponibilidade no dia e não estão alocados
    medicosDisponiveis = medicos
        .where((m) => idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
        .toList();
  }

  Future<void> _alocarMedico(String medicoId, String novoGabineteId) async {
    // 1) Verifica se o médico já está alocado no mesmo dia
    final indexAlocacaoAtual = alocacoes.indexWhere((a) =>
    a.medicoId == medicoId &&
        a.data.year == selectedDate.year &&
        a.data.month == selectedDate.month &&
        a.data.day == selectedDate.day);

    // 2) Se já estava, remove do local antigo
    if (indexAlocacaoAtual != -1) {
      final alocacaoAntiga = alocacoes[indexAlocacaoAtual];
      alocacoes.removeAt(indexAlocacaoAtual);

      // Remover também do banco (se for o caso)
      await DatabaseHelper.deletarAlocacao(alocacaoAntiga.id);
    }

    // 3) Pega horários disponíveis do médico
    final disponibilidadeDoMedico = disponibilidades.where((d) =>
    d.medicoId == medicoId &&
        d.data.year == selectedDate.year &&
        d.data.month == selectedDate.month &&
        d.data.day == selectedDate.day).toList();

    final horarios = disponibilidadeDoMedico
        .expand((d) => d.horarios)
        .join(', ');

    // 4) Cria a nova alocação
    final novaAlocacao = Alocacao(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicoId: medicoId,
      gabineteId: novoGabineteId,
      data: selectedDate,
      horarioInicio: horarios, // ex.: "08:00, 12:00"
      horarioFim: '',          // pode definir como quiser
    );

    // 5) Salva no banco
    await DatabaseHelper.salvarAlocacao(novaAlocacao);

    // 6) Adiciona localmente
    alocacoes.add(novaAlocacao);

    // 7) Remove da lista de disponíveis
    medicosDisponiveis.removeWhere((m) => m.id == medicoId);

    // Atualiza interface
    setState(() {});
  }

  Future<void> _desalocarMedico(String medicoId) async {
    // Encontra a alocação para esse dia
    final indexAloc = alocacoes.indexWhere((a) =>
    a.medicoId == medicoId &&
        a.data.year == selectedDate.year &&
        a.data.month == selectedDate.month &&
        a.data.day == selectedDate.day);
    if (indexAloc == -1) return;

    final alocRemovida = alocacoes[indexAloc];
    alocacoes.removeAt(indexAloc);

    // Remove do banco também
    await DatabaseHelper.deletarAlocacao(alocRemovida.id);

    // Acha o médico
    final medico = medicos.firstWhere(
          (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
      ),
    );

    // Se ele ainda tem disponibilidade no dia, volta para a lista de disponíveis
    final temDisponibilidade = disponibilidades.any((d) =>
    d.medicoId == medicoId &&
        d.data.year == selectedDate.year &&
        d.data.month == selectedDate.month &&
        d.data.day == selectedDate.day);

    if (temDisponibilidade) {
      medicosDisponiveis.add(medico);
    }

    setState(() {});
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
    });
    _filtrarMedicosPorData(newDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alocação de Médicos'),
      ),
      body: Column(
        children: [
          // -----------------------------------------
          // TOPO: calendário + médicos disponíveis
          // -----------------------------------------
          Expanded(
            flex: 1,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Container(
                    color: Colors.grey[200],
                    child: DatePickerSection(
                      selectedDate: selectedDate,
                      onDateChanged: _onDateChanged,
                    ),
                  ),
                ),
                Expanded(
                  child: MedicosDisponiveisSection(
                    medicosDisponiveis: medicosDisponiveis,
                    disponibilidades: disponibilidades,
                    selectedDate: selectedDate,
                    onDesalocarMedico: _desalocarMedico,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Colors.black),

          // -----------------------------------------
          // PARTE DE BAIXO: gabinetes
          // -----------------------------------------
          Expanded(
            flex: 2,
            child: GabinetesSection(
              gabinetes: gabinetes,
              alocacoes: alocacoes,
              medicos: medicos,
              disponibilidades: disponibilidades,
              selectedDate: selectedDate,
              onAlocarMedico: _alocarMedico,
            ),
          ),
        ],
      ),
    );
  }
}
