import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
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

  bool _validarDisponibilidade(Disponibilidade disp) {
    if (disp.horarios.length != 2) return false;
    try {
      final inicioParts = disp.horarios[0].split(':');
      final fimParts = disp.horarios[1].split(':');
      final inicio = TimeOfDay(
        hour: int.parse(inicioParts[0]),
        minute: int.parse(inicioParts[1]),
      );
      final fim = TimeOfDay(
        hour: int.parse(fimParts[0]),
        minute: int.parse(fimParts[1]),
      );
      if (inicio.hour < fim.hour) return true;
      if (inicio.hour == fim.hour && inicio.minute < fim.minute) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8, // Espaçamento horizontal entre os cartões
        runSpacing: 8, // Espaçamento vertical entre as linhas
        children: medicosDisponiveis.map((medico) {
          final dispDoMedico = disponibilidades.where((d) {
            final dd = DateTime(d.data.year, d.data.month, d.data.day);
            return d.medicoId == medico.id &&
                dd == DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          }).toList();

          final horariosStr = dispDoMedico
              .expand((d) => d.horarios)
              .join(', ');

          final isValido = dispDoMedico.any((d) => _validarDisponibilidade(d));

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Draggable<String>(
              data: medico.id,
              feedback: MedicoCard.dragFeedback(medico, horariosStr),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _buildMedicoCardContent(medico, horariosStr, isValido),
              ),
              child: _buildMedicoCardContent(medico, horariosStr, isValido),
            ),
          );
        }).toList(),
      ),
    );
  }



  Widget _buildMedicoCardContent(Medico medico, String horarios, bool isValid) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isValid ? Colors.grey[200] : Colors.red[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medico.nome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "$horarios ${medico.especialidade}",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
