import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import 'medico_card.dart';

class MedicosDisponiveisSection extends StatelessWidget {
  final List<Medico> medicosDisponiveis;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;

  /// Em geral não precisamos mais chamar onDesalocarMedico aqui,
  /// pois a desalocação está sendo tratada no `DragTarget` externo.
  /// Mas podemos manter se você usa de outra forma.
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
      // Horário de início deve ser antes do fim
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8,
          //runSpacing: 8,
          children: medicosDisponiveis.map((medico) {
            // Corrigir a query de disponibilidades
            final dispDoMedico = disponibilidades.where((d) =>
            d.medicoId == medico.id &&
                d.data.year == selectedDate.year &&
                d.data.month == selectedDate.month &&
                d.data.day == selectedDate.day
            ).toList(); // Corrigido: sintaxe do where e toList()

            // Corrigir o join e formatação dos horários
            final horariosStr = dispDoMedico
                .expand((d) => d.horarios)
                .join(', '); // Corrigido: sintaxe do expand e join

            // Validação correta
            final isValido = dispDoMedico.any((d) =>
                _validarDisponibilidade(d)
            );
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
      ),
    );
  }

  Widget _buildMedicoCardContent(Medico medico, String horarios, bool isValid) {
    return Container(
      width: 160, // Largura fixa para consistência
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isValid ? Colors.grey[200]! : Colors.red[200]!,
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
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
          ),
          // const SizedBox(height: 4),
          // Text(
          //   horarios,
          //   style: const TextStyle(fontSize: 10, color: Colors.grey),
          // ),
        ],
      ),
    );
  }
}