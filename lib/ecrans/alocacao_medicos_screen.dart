// alocacao_medicos_screen.dart
import 'package:flutter/material.dart';

import '../class/medico.dart';
import '../class/gabinete.dart';
import '../class/alocacao.dart';
import '../class/disponibilidade.dart';
import '../banco_dados/database_helper.dart';
import '../alocacao/date_picker_section. dart.dart';
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
    final alocadosNoDia = alocacoes.where((a) {
      return a.data.year == dataSelecionada.year &&
          a.data.month == dataSelecionada.month &&
          a.data.day == dataSelecionada.day;
    }).map((a) => a.medicoId).toSet();

    medicosDisponiveis = medicos
        .where((m) =>
    idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
        .toList();
  }

  Future<void> _alocarMedico(String medicoId, String novoGabineteId) async {
    // 1. Verificar se o médico já está alocado em algum gabinete no mesmo dia
    final indexAlocacaoAtual = alocacoes.indexWhere((a) =>
    a.medicoId == medicoId &&
        a.data.year == selectedDate.year &&
        a.data.month == selectedDate.month &&
        a.data.day == selectedDate.day);

    // 2. Se encontrado, remover a alocação antiga
    if (indexAlocacaoAtual != -1) {
      final alocacaoAntiga = alocacoes[indexAlocacaoAtual];
      alocacoes.removeAt(indexAlocacaoAtual);

      // Remover também do banco de dados
      await DatabaseHelper.deletarAlocacao(alocacaoAntiga.id);
    }

    // 3. Buscar os horários disponíveis do médico para o dia selecionado
    final disponibilidadeDoMedico = disponibilidades.where((d) =>
    d.medicoId == medicoId &&
        d.data.year == selectedDate.year &&
        d.data.month == selectedDate.month &&
        d.data.day == selectedDate.day).toList();

    final horarios = disponibilidadeDoMedico.expand((d) => d.horarios).join(', ');

    // 4. Criar a nova alocação
    final novaAlocacao = Alocacao(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicoId: medicoId,
      gabineteId: novoGabineteId,
      data: selectedDate,
      horarioInicio: horarios,
      horarioFim: '',
    );

    // 5. Salvar a nova alocação no banco de dados
    await DatabaseHelper.salvarAlocacao(novaAlocacao);

    // 6. Adicionar a nova alocação à lista local
    alocacoes.add(novaAlocacao);

    // 7. Remover o médico da lista de disponíveis, caso ainda esteja nela
    medicosDisponiveis.removeWhere((m) => m.id == medicoId);

    // Atualizar a interface
    setState(() {});
  }



  Future<void> _desalocarMedico(String medicoId) async {
    // Localiza a alocação do médico no dia selecionado
    final indexAloc = alocacoes.indexWhere((a) =>
    a.medicoId == medicoId &&
        a.data.year == selectedDate.year &&
        a.data.month == selectedDate.month &&
        a.data.day == selectedDate.day);

    // Se não encontrar nenhuma alocação, retorna sem fazer nada
    if (indexAloc == -1) return;

    // Remove a alocação localmente
    final alocRemovida = alocacoes[indexAloc];
    alocacoes.removeAt(indexAloc);

    // Atualiza o banco de dados (se necessário)
    await DatabaseHelper.deletarAlocacao(alocRemovida.id);

    // Localiza o médico correspondente ou cria um placeholder (caso não encontrado)
    final medico = medicos.firstWhere(
          (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
      ),
    );

    // Verifica se o médico ainda tem disponibilidade no dia selecionado
    final temDisponibilidade = disponibilidades.any((d) =>
    d.medicoId == medicoId &&
        d.data.year == selectedDate.year &&
        d.data.month == selectedDate.month &&
        d.data.day == selectedDate.day);

    // Se ele tiver disponibilidade, retorna para a lista de médicos disponíveis
    if (temDisponibilidade) {
      medicosDisponiveis.add(medico);
    }

    // Atualiza a interface
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
        title: Text('Alocação de Médicos'),
      ),
      body: Column(
        children: [
          // -------------------------------
          // TOPO (flex:1): calendário + médicos
          // -------------------------------
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
          // -------------------------------
          // PARTE INFERIOR (flex:2): gabinetes
          // -------------------------------
          Expanded(
            flex: 2,
            child: GabinetesSection(
              gabinetes: gabinetes,
              alocacoes: alocacoes,
              medicos: medicos,
              selectedDate: selectedDate,
              onAlocarMedico: _alocarMedico,
            ),
          ),
        ],
      ),
    );
  }
}