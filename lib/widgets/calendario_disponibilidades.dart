import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class CalendarioDisponibilidades extends StatelessWidget {
  final List<DateTime> diasSelecionados;

  /// onAdicionarData recebe (DateTime date, String tipo)
  final Function(DateTime, String) onAdicionarData;

  /// onRemoverData recebe (DateTime date, bool removeSerie)
  final Function(DateTime, bool) onRemoverData;

  const CalendarioDisponibilidades({
    super.key,
    required this.diasSelecionados,
    required this.onAdicionarData,
    required this.onRemoverData,
  });

  Future<void> _mostrarDialogoTipoMarcacao(
      BuildContext context, DateTime date) async {
    final String? tipoMarcacao = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Escolha o tipo de marcação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Única'),
                onTap: () => Navigator.of(context).pop('Única'),
              ),
              ListTile(
                title: const Text('Semanal'),
                onTap: () => Navigator.of(context).pop('Semanal'),
              ),
              ListTile(
                title: const Text('Quinzenal'),
                onTap: () => Navigator.of(context).pop('Quinzenal'),
              ),
              ListTile(
                title: const Text('Mensal'),
                onTap: () => Navigator.of(context).pop('Mensal'),
              ),
              ListTile(
                title: const Text('Consecutivo'),
                onTap: () => Navigator.of(context).pop('Consecutivo'),
              ),
            ],
          ),
        );
      },
    );

    if (tipoMarcacao != null) {
      if (tipoMarcacao == 'Consecutivo') {
        // Se escolheu Consecutivo, perguntar quantos dias
        final int? numeroDias = await _mostrarDialogoNumeroDias(context);
        if (numeroDias != null) {
          onAdicionarData(date, 'Consecutivo:$numeroDias');
        }
      } else {
        onAdicionarData(date, tipoMarcacao);
      }
    }
  }

  Future<int?> _mostrarDialogoNumeroDias(BuildContext context) async {
    int numeroDias = 5; // Valor padrão
    
    return await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Quantos dias consecutivos?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Escolha quantos dias consecutivos deseja marcar:'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (numeroDias > 1) {
                            setState(() {
                              numeroDias--;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$numeroDias',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (numeroDias < 30) {
                            setState(() {
                              numeroDias++;
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(numeroDias),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarDialogoRemocaoSeries(
      BuildContext context, DateTime date) async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover disponibilidade'),
          content: Text(
            'Deseja remover a disponibilidade do dia '
                '${date.day}/${date.month}/${date.year}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('single'),
              child: const Text('Apenas este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('all'),
              child: const Text('Toda a série'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (escolha == 'single') {
      onRemoverData(date, false); // remove só o dia
    } else if (escolha == 'all') {
      onRemoverData(date, true); // remove toda a série
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SfCalendar(
          showNavigationArrow: true,
          view: CalendarView.month,
          onTap: (details) {
            final date = details.date;
            if (date != null) {
              final isSelected = diasSelecionados.any(
                    (d) =>
                d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day,
              );

              if (isSelected) {
                // Se já está selecionado (vermelho), pergunta se remove só esse ou toda a série
                _mostrarDialogoRemocaoSeries(context, date);
              } else {
                // Se não está selecionado, perguntar qual tipo de marcação (Única, Semanal etc.)
                _mostrarDialogoTipoMarcacao(context, date);
              }
            }
          },
          monthCellBuilder: (context, details) {
            final isSelected = diasSelecionados.any(
                  (d) =>
              d.year == details.date.year &&
                  d.month == details.date.month &&
                  d.day == details.date.day,
            );

            // Verifica se a célula pertence ao mês atual
            final isCurrentMonth =
                details.visibleDates[10].month == details.date.month;

            return Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 0.5),
                  color: isSelected ? Colors.purple : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${details.date.day}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isCurrentMonth
                        ? Colors.black
                        : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
