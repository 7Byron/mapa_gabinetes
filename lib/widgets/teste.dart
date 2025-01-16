import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class TestCalendar extends StatelessWidget {
  const TestCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    // Exemplo de TimeRegions para destacar
    final diasSelecionados = [
      TimeRegion(
        startTime: DateTime(2025, 1, 6, 0,0),
        endTime: DateTime(2025, 1, 7,23,59),
        color: Colors.red, // Cor sólida para teste
        enablePointerInteraction: false,
      ),
      TimeRegion(
        startTime: DateTime(2025, 1, 13,0,0),
        endTime: DateTime(2025, 1, 14,23,59),
        color: Colors.red, // Cor sólida para teste
        enablePointerInteraction: false,
      ),
    ];

    // Adicione o print detalhado aqui
    if (diasSelecionados.isNotEmpty) {
      for (var region in diasSelecionados) {
        if (kDebugMode) {
          print('TimeRegion - startTime: ${region.startTime}, '
            'endTime: ${region.endTime}, '
            'color: ${region.color}');
        }
      }
    } else {
      if (kDebugMode) {
        print('Nenhum TimeRegion encontrado.');
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Teste de Calendário')),
      body: SfCalendar(
        view: CalendarView.month,
        blackoutDates: diasSelecionados.map((region) => region.startTime).toList(),
        backgroundColor: Colors.white,
        monthCellBuilder: (BuildContext context, MonthCellDetails details) {
          // Verifica se a data atual está em blackoutDates
          bool isBlackoutDate = diasSelecionados
              .map((region) => region.startTime)
              .any((date) => date.year == details.date.year &&
              date.month == details.date.month &&
              date.day == details.date.day);

          if (isBlackoutDate) {
            return Center(
              child: Container(
                width: 30, // Largura da bola
                height: 30, // Altura da bola
                decoration: BoxDecoration(
                  color: Colors.red, // Cor da bola
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${details.date.day}', // Número do dia
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Tamanho do texto
                  ),
                ),
              ),
            );
          }

          // Renderiza as células normais
          return Center(
            child: Text(
              '${details.date.day}',
              style: TextStyle(color: Colors.black), // Cor padrão
            ),
          );
        },
      ),

    );
  }
}
