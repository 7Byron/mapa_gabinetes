import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../services/relatorios_service.dart';
import '../models/gabinete.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  // Período de datas
  DateTime dataInicio = DateTime(2025, 1, 1);
  DateTime dataFim   = DateTime(2025, 1, 31);

  // Filtros
  String setorSelecionado = '';
  String gabineteSelecionado = '';
  String especialidadeSelecionada = '';

  // Resultados dos relatórios (0..100)
  double resultadoGeral = 0.0;
  double resultadoSetor = 0.0;
  double resultadoGabinete = 0.0;
  double resultadoEspecialidade = 0.0;

  // Listas
  List<Gabinete> todosGabinetes = [];
  List<String> setores = [];
  List<String> especialidades = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  /// Carrega do DB: gabinetes, especialidades
  Future<void> _carregarDadosIniciais() async {
    setState(() {});
  }

  /// Chama o RelatoriosService para cada tipo de relatório
  Future<void> _calcularRelatorios() async {
    // Taxa geral (todos os gabinetes)
    final tGeral = await RelatoriosService.taxaOcupacaoGeral(
      inicio: dataInicio,
      fim: dataFim,
    );

    double tSetor = 0.0;
    if (setorSelecionado.isNotEmpty) {
      tSetor = await RelatoriosService.taxaOcupacaoPorSetor(
        inicio: dataInicio,
        fim: dataFim,
        setor: setorSelecionado,
      );
    }

    double tGabinete = 0.0;
    if (gabineteSelecionado.isNotEmpty) {
      tGabinete = await RelatoriosService.taxaOcupacaoPorGabinete(
        inicio: dataInicio,
        fim: dataFim,
        gabineteId: gabineteSelecionado,
      );
    }

    double tEsp = 0.0;
    if (especialidadeSelecionada.isNotEmpty) {
      tEsp = await RelatoriosService.taxaOcupacaoPorEspecialidade(
        inicio: dataInicio,
        fim: dataFim,
        especialidadeProcurada: especialidadeSelecionada,
      );
    }

    setState(() {
      resultadoGeral = tGeral;
      resultadoSetor = tSetor;
      resultadoGabinete = tGabinete;
      resultadoEspecialidade = tEsp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Relatórios de Ocupação'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Selecione o Período',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final novo = await showDatePicker(
                      context: context,
                      initialDate: dataInicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (novo != null) {
                      setState(() => dataInicio = novo);
                    }
                  },
                  child: Text(
                    'Início: ${DateFormat('dd/MM/yyyy').format(dataInicio)}',
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final novo = await showDatePicker(
                      context: context,
                      initialDate: dataFim,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (novo != null) {
                      setState(() => dataFim = novo);
                    }
                  },
                  child: Text(
                    'Fim: ${DateFormat('dd/MM/yyyy').format(dataFim)}',
                  ),
                ),
              ],
            ),
            const Divider(),

            const Text(
              'Filtrar por Piso (Setor)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildDropdownSetor(),

            const SizedBox(height: 8),
            const Text(
              'Filtrar por Gabinete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildDropdownGabinete(),

            const SizedBox(height: 8),
            const Text(
              'Filtrar por Especialidade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildDropdownEspecialidade(),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calcularRelatorios,
              child: const Text('Calcular Relatórios'),
            ),

            const SizedBox(height: 24),
            _buildGraficoTaxa(
              label: 'Taxa Geral',
              valor: resultadoGeral,
            ),
            if (setorSelecionado.isNotEmpty)
              _buildGraficoTaxa(
                label: 'Setor "$setorSelecionado"',
                valor: resultadoSetor,
              ),
            if (gabineteSelecionado.isNotEmpty)
              _buildGraficoTaxa(
                label: 'Gabinete "$gabineteSelecionado"',
                valor: resultadoGabinete,
              ),
            if (especialidadeSelecionada.isNotEmpty)
              _buildGraficoTaxa(
                label: 'Especialidade "$especialidadeSelecionada"',
                valor: resultadoEspecialidade,
              ),
          ],
        ),
      ),
    );
  }

  /// Dropdown para selecionar Setor
  Widget _buildDropdownSetor() {
    if (setores.isEmpty) {
      return const Text('Nenhum setor encontrado ou carregando...');
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('(Nenhum)'),
      ),
      for (final s in setores)
        DropdownMenuItem(
          value: s,
          child: Text(s),
        ),
    ];

    return DropdownButton<String>(
      isExpanded: true,
      value: setorSelecionado,
      items: items,
      onChanged: (value) {
        setState(() {
          setorSelecionado = value ?? '';
        });
      },
    );
  }

  /// Dropdown para selecionar Gabinete
  Widget _buildDropdownGabinete() {
    if (todosGabinetes.isEmpty) {
      return const Text('Nenhum gabinete encontrado ou carregando...');
    }
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('(Nenhum)'),
      ),
      for (final g in todosGabinetes)
        DropdownMenuItem(
          value: g.id,
          child: Text('${g.nome} (${g.setor})'),
        ),
    ];

    return DropdownButton<String>(
      isExpanded: true,
      value: gabineteSelecionado,
      items: items,
      onChanged: (value) {
        setState(() {
          gabineteSelecionado = value ?? '';
        });
      },
    );
  }

  /// Dropdown para selecionar Especialidade
  Widget _buildDropdownEspecialidade() {
    if (especialidades.isEmpty) {
      return const Text('Nenhuma especialidade cadastrada ou carregando...');
    }

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('(Nenhuma)'),
      ),
      for (final esp in especialidades)
        DropdownMenuItem(
          value: esp,
          child: Text(esp),
        ),
    ];

    return DropdownButton<String>(
      isExpanded: true,
      value: especialidadeSelecionada,
      items: items,
      onChanged: (value) {
        setState(() {
          especialidadeSelecionada = value ?? '';
        });
      },
    );
  }

  /// Widget para exibir o "gráfico de barras" + label
  Widget _buildGraficoTaxa({required String label, required double valor}) {
    final perc = valor.clamp(0.0, 100.0) / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${valor.toStringAsFixed(1)}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          child: LinearProgressIndicator(
            value: perc,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
