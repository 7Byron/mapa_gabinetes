import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date picker customizado com seleção rápida de mês e ano
class DatePickerCustomizado extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Function(DateTime) onDateSelected;

  const DatePickerCustomizado({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<DatePickerCustomizado> createState() => _DatePickerCustomizadoState();
}

class _DatePickerCustomizadoState extends State<DatePickerCustomizado> {
  late DateTime _selectedDate;
  late DateTime _displayDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _displayDate = _selectedDate;
  }

  String _capitalizarPrimeiraLetra(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final mes = _capitalizarPrimeiraLetra(DateFormat('MMMM', 'pt_PT').format(_displayDate));
    final ano = _displayDate.year.toString();
    
    final diasNoMes = DateTime(_displayDate.year, _displayDate.month + 1, 0).day;
    final primeiroDiaSemana = DateTime(_displayDate.year, _displayDate.month, 1).weekday;
    // Ajustar para segunda-feira = 0, domingo = 6 (conforme cabeçalho ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
    final primeiroDiaAjustado = primeiroDiaSemana == 7 ? 6 : primeiroDiaSemana - 1;

    return Dialog(
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com mês e ano (dropdowns)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1);
                    });
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dropdown do mês
                    DropdownButton<String>(
                      value: mes,
                      underline: Container(),
                      items: [
                        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
                        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
                      ].map((String m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? novoMes) {
                        if (novoMes != null) {
                          final meses = [
                            'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
                            'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
                          ];
                          final indiceMes = meses.indexOf(novoMes) + 1;
                          setState(() {
                            _displayDate = DateTime(_displayDate.year, indiceMes, 1);
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Dropdown do ano
                    DropdownButton<int>(
                      value: int.parse(ano),
                      underline: Container(),
                      items: List.generate(20, (index) {
                        final anoBase = (widget.firstDate?.year ?? DateTime.now().year - 5);
                        final anoOpcao = anoBase + index;
                        return DropdownMenuItem<int>(
                          value: anoOpcao,
                          child: Text(
                            anoOpcao.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (int? novoAno) {
                        if (novoAno != null) {
                          setState(() {
                            _displayDate = DateTime(novoAno, _displayDate.month, 1);
                          });
                        }
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _displayDate = DateTime(_displayDate.year, _displayDate.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
            // Header dos dias da semana
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      final isWeekend = index == 5 || index == 6;
                      return Expanded(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isWeekend ? Colors.blue : null,
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            // Grid de dias
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42, // 6 semanas * 7 dias
              itemBuilder: (context, index) {
                final dia = index - primeiroDiaAjustado + 1;
                final isDiaValido = dia >= 1 && dia <= diasNoMes;
                final isDiaSelecionado = isDiaValido &&
                    _selectedDate.year == _displayDate.year &&
                    _selectedDate.month == _displayDate.month &&
                    _selectedDate.day == dia;
                
                DateTime? dataDia;
                bool isDiaValidoParaSelecao = false;
                
                if (isDiaValido) {
                  dataDia = DateTime(_displayDate.year, _displayDate.month, dia);
                  isDiaValidoParaSelecao = 
                      (widget.firstDate == null || dataDia.isAfter(widget.firstDate!.subtract(const Duration(days: 1)))) &&
                      (widget.lastDate == null || dataDia.isBefore(widget.lastDate!.add(const Duration(days: 1))));
                }

                return GestureDetector(
                  onTap: isDiaValidoParaSelecao
                      ? () {
                          setState(() {
                            _selectedDate = dataDia!;
                          });
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDiaSelecionado
                          ? Colors.blue
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isDiaValido ? '$dia' : '',
                        style: TextStyle(
                          color: isDiaSelecionado
                              ? Colors.white
                              : isDiaValidoParaSelecao
                                  ? Colors.black
                                  : Colors.grey.shade400,
                          fontWeight: isDiaSelecionado ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onDateSelected(_selectedDate);
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Função helper para mostrar o date picker customizado
Future<DateTime?> showDatePickerCustomizado({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  DateTime? dataSelecionada;
  
  await showDialog(
    context: context,
    builder: (context) => DatePickerCustomizado(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateSelected: (data) {
        dataSelecionada = data;
      },
    ),
  );
  
  return dataSelecionada;
}

