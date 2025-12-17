import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class DatePickerSection extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const DatePickerSection({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Cabeçalho com mês/ano
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final newDate = DateTime(selectedDate.year,
                      selectedDate.month - 1, selectedDate.day);
                  if (newDate.isAfter(DateTime(2021))) {
                    onDateChanged(newDate);
                  }
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_getMonthName(selectedDate.month)} ${selectedDate.year}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final newDate = DateTime(selectedDate.year,
                      selectedDate.month + 1, selectedDate.day);
                  if (newDate.isBefore(DateTime(2031))) {
                    onDateChanged(newDate);
                  }
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendário customizado
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month - 1];
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    return Column(
      children: [
        // Cabeçalho dos dias da semana
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((day) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),

        // Grid dos dias
        ...List.generate((daysInMonth + firstWeekday - 1) ~/ 7 + 1,
            (weekIndex) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final date =
                  DateTime(selectedDate.year, selectedDate.month, dayNumber);
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    print(
                        '🔄 Dia clicado: $dayNumber/${selectedDate.month}/${selectedDate.year}');
                    onDateChanged(date);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? MyAppTheme.roxo : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? MyAppTheme.roxo : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}
