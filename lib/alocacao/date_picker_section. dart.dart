import 'package:flutter/material.dart';

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
    return CalendarDatePicker(
      initialDate: selectedDate,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
      onDateChanged: onDateChanged,
    );
  }
}
