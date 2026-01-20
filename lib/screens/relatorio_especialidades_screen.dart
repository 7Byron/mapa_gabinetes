// lib/screens/relatorio_especialidades_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/relatorios_especialidades_service.dart';
import '../widgets/custom_appbar.dart';
import '../models/unidade.dart';

class RelatorioEspecialidadesScreen extends StatefulWidget {
  final Unidade? unidade;

  const RelatorioEspecialidadesScreen({super.key, this.unidade});

  @override
  State<RelatorioEspecialidadesScreen> createState() => _RelatorioEspecialidadesScreenState();
}

class _RelatorioEspecialidadesScreenState extends State<RelatorioEspecialidadesScreen> {
  DateTime dataInicio = DateTime(2025,1,1);
  DateTime dataFim = DateTime(2025,1,31);

  Map<String, double> resultado = {}; // ex: {"Ortopedia": 12.0, "MGF": 8.0, ...}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Relatório de Especialidades'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                child: Text('Início: ${DateFormat('dd/MM/yyyy').format(dataInicio)}'),
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
                child: Text('Fim: ${DateFormat('dd/MM/yyyy').format(dataFim)}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _calcular,
            child: const Text('Calcular'),
          ),
          const Divider(),
          if (resultado.isEmpty)
            const Text('Nenhum resultado ainda...')
          else
            _buildTabelaHoras(),
        ],
      ),
    );
  }

  Future<void> _calcular() async {
    final map = await RelatoriosEspecialidadesService.horasPorEspecialidade(
      inicio: dataInicio,
      fim: dataFim,
      unidadeId: widget.unidade?.id,
    );
    setState(() {
      resultado = map;
    });
  }

  Widget _buildTabelaHoras() {
    // exibe cada "especialidade -> horas"
    // se quiser exibir "por dia da semana", aí é outra complexidade
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Horas Totais por Especialidade',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final esp in resultado.keys)
          ListTile(
            title: Text(esp),
            trailing: Text('${resultado[esp]!.toStringAsFixed(1)}h'),
          ),
      ],
    );
  }
}
