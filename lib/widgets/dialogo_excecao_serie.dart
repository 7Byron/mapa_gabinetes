// lib/widgets/dialogo_excecao_serie.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/serie_recorrencia.dart';
import 'date_picker_customizado.dart';

/// Diálogo para criar exceções em séries (cancelar períodos como férias)
class DialogoExcecaoSerie extends StatefulWidget {
  final SerieRecorrencia serie;
  final Function(DateTime dataInicio, DateTime dataFim) onConfirmar;
  final Function(DateTime dataFim)? onCancelarSerie; // Novo: para cancelar a série a partir de uma data

  const DialogoExcecaoSerie({
    super.key,
    required this.serie,
    required this.onConfirmar,
    this.onCancelarSerie,
  });

  @override
  State<DialogoExcecaoSerie> createState() => _DialogoExcecaoSerieState();
}

enum TipoExcecao {
  diaUnico,
  periodo,
  cancelarSerie,
}

class _DialogoExcecaoSerieState extends State<DialogoExcecaoSerie> {
  DateTime? _dataInicio;
  DateTime? _dataFim;
  TipoExcecao _tipoExcecao = TipoExcecao.diaUnico;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Criar Exceção na Série'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Série: ${widget.serie.tipo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Início: ${DateFormat('dd/MM/yyyy').format(widget.serie.dataInicio)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (widget.serie.dataFim != null)
                      Text(
                        'Fim: ${DateFormat('dd/MM/yyyy').format(widget.serie.dataFim!)}',
                        style: const TextStyle(fontSize: 14),
                      )
                    else
                      const Text(
                        'Fim: Série infinita',
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tipo de exceção:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<TipoExcecao>(
              title: const Text('Cancelar um único dia'),
              value: TipoExcecao.diaUnico,
              groupValue: _tipoExcecao,
              onChanged: (value) {
                setState(() {
                  _tipoExcecao = value!;
                  _dataFim = null; // Limpar data fim quando não for período
                });
              },
              dense: true,
            ),
            RadioListTile<TipoExcecao>(
              title: const Text('Cancelar período (ex: férias, interrupção)'),
              value: TipoExcecao.periodo,
              groupValue: _tipoExcecao,
              onChanged: (value) {
                setState(() {
                  _tipoExcecao = value!;
                  if (_dataFim == null && _dataInicio != null) {
                    _dataFim = _dataInicio;
                  }
                });
              },
              dense: true,
            ),
            if (widget.serie.dataFim == null) // Só mostrar se a série for infinita
              RadioListTile<TipoExcecao>(
                title: const Text('Cancelar série a partir de data'),
                subtitle: const Text('Encerra a série a partir da data selecionada'),
                value: TipoExcecao.cancelarSerie,
                groupValue: _tipoExcecao,
                onChanged: (value) {
                  setState(() {
                    _tipoExcecao = value!;
                    _dataFim = null; // Limpar data fim
                  });
                },
                dense: true,
              ),
            const SizedBox(height: 16),
            if (_tipoExcecao == TipoExcecao.cancelarSerie)
              ListTile(
                title: Text(
                  _dataInicio != null
                      ? 'Cancelar série a partir de: ${DateFormat('dd/MM/yyyy').format(_dataInicio!)}'
                      : 'Selecionar data de cancelamento',
                ),
                subtitle: const Text('A série será encerrada no dia anterior à data selecionada'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final data = await showDatePickerCustomizado(
                    context: context,
                    initialDate: _dataInicio ?? DateTime.now(),
                    firstDate: widget.serie.dataInicio,
                    lastDate: DateTime(2100),
                  );
                  if (data != null) {
                    setState(() {
                      _dataInicio = data;
                    });
                  }
                },
              )
            else ...[
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
                    firstDate: widget.serie.dataInicio,
                    lastDate: widget.serie.dataFim ?? DateTime(2100),
                  );
                  if (data != null) {
                    setState(() {
                      _dataInicio = data;
                      // Se for período e não tiver data fim, definir como data fim também
                      if (_tipoExcecao == TipoExcecao.periodo && _dataFim == null) {
                        _dataFim = data;
                      }
                    });
                  }
                },
              ),
              if (_tipoExcecao == TipoExcecao.periodo)
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
                      firstDate: _dataInicio ?? widget.serie.dataInicio,
                      lastDate: widget.serie.dataFim ?? DateTime(2100),
                    );
                    if (data != null) {
                      setState(() {
                        _dataFim = data;
                      });
                    }
                  },
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _dataInicio != null
              ? () {
                  if (_tipoExcecao == TipoExcecao.cancelarSerie) {
                    // Cancelar série a partir da data
                    if (widget.onCancelarSerie != null) {
                      widget.onCancelarSerie!(_dataInicio!);
                    }
                  } else {
                    // Cancelar dia único ou período
                    final dataFim = _tipoExcecao == TipoExcecao.periodo && _dataFim != null
                        ? _dataFim!
                        : _dataInicio!;
                    widget.onConfirmar(_dataInicio!, dataFim);
                  }
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

