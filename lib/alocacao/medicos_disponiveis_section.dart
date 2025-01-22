// medicos_disponiveis_section.dart
import 'package:flutter/material.dart';
import '../class/medico.dart';
import '../class/disponibilidade.dart';
import 'medico_card.dart';

class MedicosDisponiveisSection extends StatelessWidget {
  final List<Medico> medicosDisponiveis;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final Function(String) onDesalocarMedico;

  const MedicosDisponiveisSection({
    super.key,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.selectedDate,
    required this.onDesalocarMedico,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAccept: (medicoId) {
        // Permitir que qualquer médico seja solto aqui
        return true;
      },
      onAccept: (medicoId) {
        // Quando o médico é solto, ele é desalocado
        onDesalocarMedico(medicoId);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          color: candidateData.isNotEmpty ? Colors.green[50] : Colors.white,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.start,
              runSpacing: 8,
              spacing: 8,
              children: medicosDisponiveis.map((medico) {
                // Calcula os horários disponíveis
                final dispDoMedico = disponibilidades.where((d) =>
                d.medicoId == medico.id &&
                    d.data.year == selectedDate.year &&
                    d.data.month == selectedDate.month &&
                    d.data.day == selectedDate.day).toList();

                final horariosStr = dispDoMedico
                    .expand((d) => d.horarios)
                    .join(', ');

                return Draggable<String>(
                  data: medico.id, // ID do médico
                  feedback: MedicoCard.dragFeedback(medico, horariosStr),
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: MedicoCard.buildSmallMedicoCard(medico, horariosStr, Colors.grey, true),
                  ),
                  child: MedicoCard.buildSmallMedicoCard(medico, horariosStr, Colors.grey, true),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}