// lib/widgets/dialogo_excecao_periodo.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'date_picker_customizado.dart';

/// Diálogo para criar exceções de período (remove todos os cartões no período, independente das séries)
class DialogoExcecaoPeriodo extends StatefulWidget {
  final DateTime? dataInicialMinima;
  final DateTime? dataFinalMaxima;
  final Function(DateTime dataInicio, DateTime dataFim) onConfirmar;

  const DialogoExcecaoPeriodo({
    super.key,
    this.dataInicialMinima,
    this.dataFinalMaxima,
    required this.onConfirmar,
  });

  @override
  State<DialogoExcecaoPeriodo> createState() => _DialogoExcecaoPeriodoState();
}

class _DialogoExcecaoPeriodoState extends State<DialogoExcecaoPeriodo> {
  DateTime? _dataInicio;
  DateTime? _dataFim;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Criar Exceção de Período'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta exceção removerá TODOS os cartões no período selecionado, independentemente das séries.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Exemplo: Se o médico vai a um congresso de 4 a 7 de dezembro, todos os cartões nesse período serão removidos.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                _dataInicio != null
                    ? 'Data inicial: ${DateFormat('dd/MM/yyyy').format(_dataInicio!)}'
                    : 'Selecionar data inicial',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final data = await showDatePickerCustomizado(
                  context: context,
                  initialDate: _dataInicio ?? DateTime.now(),
                  firstDate: widget.dataInicialMinima ?? DateTime(2020),
                  lastDate: widget.dataFinalMaxima ?? DateTime(2100),
                );
                if (data != null) {
                  setState(() {
                    _dataInicio = data;
                    // Se não tiver data fim, definir como data fim também
                    if (_dataFim == null || _dataFim!.isBefore(data)) {
                      _dataFim = data;
                    }
                  });
                }
              },
            ),
            ListTile(
              title: Text(
                _dataFim != null
                    ? 'Data final: ${DateFormat('dd/MM/yyyy').format(_dataFim!)}'
                    : 'Selecionar data final',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final data = await showDatePickerCustomizado(
                  context: context,
                  initialDate: _dataFim ?? _dataInicio ?? DateTime.now(),
                  firstDate: _dataInicio ?? widget.dataInicialMinima ?? DateTime(2020),
                  lastDate: widget.dataFinalMaxima ?? DateTime(2100),
                );
                if (data != null) {
                  setState(() {
                    _dataFim = data;
                  });
                }
              },
            ),
            if (_dataInicio != null && _dataFim != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_dataInicio!)} a ${DateFormat('dd/MM/yyyy').format(_dataFim!)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _dataInicio != null && _dataFim != null
              ? () {
                  widget.onConfirmar(_dataInicio!, _dataFim!);
                  Navigator.of(context).pop();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

