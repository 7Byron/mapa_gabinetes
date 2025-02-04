import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';

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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: MyAppTheme.roxo, // Cor principal (seleção e destaque)
          onPrimary: Colors.white, // Cor do texto sobre a seleção
          surface: MyAppTheme.roxo, // Fundo dos dias selecionáveis
        ),
      ),
      child: CalendarDatePicker(
        initialDate: selectedDate,
        firstDate: DateTime(2022),
        lastDate: DateTime(2030),
        onDateChanged: onDateChanged,
      ),
    );
  }
}
