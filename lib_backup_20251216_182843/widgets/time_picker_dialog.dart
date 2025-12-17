import 'package:flutter/material.dart';

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const CustomTimePickerDialog({
    super.key,
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late int selectedHour;
  late int selectedMinute;
  bool hourSelected = false;
  bool minuteSelected = false;

  @override
  void initState() {
    super.initState();
    selectedHour = widget.initialTime.hour;
    selectedMinute = widget.initialTime.minute;
  }

  void _selectHour(int hour) {
    setState(() {
      selectedHour = hour;
      hourSelected = true;
    });
  }

  void _selectMinute(int minute) {
    setState(() {
      selectedMinute = minute;
      minuteSelected = true;
    });
  }

  void _confirmSelection() {
    if (hourSelected && minuteSelected) {
      widget.onTimeSelected(TimeOfDay(hour: selectedHour, minute: selectedMinute));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Hora'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            // Horas (0-23)
            const Text(
              'Hora',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 24,
                itemBuilder: (context, index) {
                  final hour = index;
                  final isSelected = hour == selectedHour;
                  return InkWell(
                    onTap: () => _selectHour(hour),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Indicador de seleção
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hourSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: hourSelected ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hora selecionada',
                  style: TextStyle(
                    color: hourSelected ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  minuteSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: minuteSelected ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Minutos selecionados',
                  style: TextStyle(
                    color: minuteSelected ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Minutos (0, 15, 30, 45)
            const Text(
              'Minutos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [0, 15, 30, 45].map((minute) {
                final isSelected = minute == selectedMinute;
                return InkWell(
                  onTap: () => _selectMinute(minute),
                  child: Container(
                    width: 60,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        minute.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          onPressed: hourSelected && minuteSelected ? _confirmSelection : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
