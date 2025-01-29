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
    // Aqui não somos mais um DragTarget
    // Apenas exibimos os médicos disponíveis em "chips" ou "cards" arrastáveis
    return Container(
      padding: const EdgeInsets.all(8),
      // Podemos dar um fundo, mas agora esse fundo é gerenciado no drag do pai
      color: Colors.white,
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.start,
          runSpacing: 8,
          spacing: 8,
          children: medicosDisponiveis.map((medico) {
            // Descobre as disponibilidades desse médico no dia
            final dispDoMedico = disponibilidades.where((d) {
              return d.medicoId == medico.id &&
                  d.data.year == selectedDate.year &&
                  d.data.month == selectedDate.month &&
                  d.data.day == selectedDate.day;
            }).toList();

            // Junta todos os horários numa string
            final horariosStr = dispDoMedico
                .expand((d) => d.horarios)
                .join(', ');

            // Se ao menos uma disponibilidade for válida -> isValido = true
            final bool isValido =
            dispDoMedico.any((d) => _validarDisponibilidade(d));
            final Color corFundo =
            isValido ? Colors.grey[200]! : Colors.red[200]!;

            return Draggable<String>(
              data: medico.id,
              feedback: MedicoCard.dragFeedback(medico, horariosStr),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: MedicoCard.buildSmallMedicoCard(
                  medico,
                  horariosStr,
                  corFundo,
                  isValido,
                ),
              ),
              child: MedicoCard.buildSmallMedicoCard(
                medico,
                horariosStr,
                corFundo,
                isValido,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
