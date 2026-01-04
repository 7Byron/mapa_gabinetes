import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../utils/app_theme.dart';
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
    // Ordenar médicos disponíveis alfabeticamente por nome
    final medicosOrdenados = List<Medico>.from(medicosDisponiveis)
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se não há médicos, retornar container vazio mínimo para permitir drop
          if (medicosOrdenados.isEmpty) {
            return const SizedBox(
              height: 0,
            );
          }
          
          // Calcular altura baseada no número de linhas necessárias
          final larguraDisponivel = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : 400.0; // Fallback
          const larguraCartao = 180.0;
          const spacing = 6.0;
          final cartoesPorLinha = (larguraDisponivel / (larguraCartao + spacing)).floor();
          final numLinhas = (medicosOrdenados.length / (cartoesPorLinha > 0 ? cartoesPorLinha : 1)).ceil();
          
          // Altura do cartão (~100px) + runSpacing (6px) por linha
          const alturaCartao = 100.0;
          final alturaNecessaria = (alturaCartao * numLinhas) + (6 * (numLinhas - 1));
          
          // Se tem 2 ou mais linhas, garantir altura mínima para 2 linhas
          final minHeight = numLinhas >= 2 
              ? (alturaCartao * 2) + 6 
              : alturaNecessaria;
          
          // Remover SingleChildScrollView para permitir que DragTarget capture gestos
          // Usar apenas Wrap com ConstrainedBox
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
            ),
            child: Wrap(
                spacing: 6, // Espaçamento horizontal reduzido
                runSpacing: 6, // Espaçamento vertical reduzido
                children: medicosOrdenados.map((medico) {
          final dispDoMedico = disponibilidades.where((d) {
            final dd = DateTime(d.data.year, d.data.month, d.data.day);
            return d.medicoId == medico.id &&
                dd ==
                    DateTime(selectedDate.year, selectedDate.month,
                        selectedDate.day);
          }).toList();

          // Formatar horários no formato "12:00 - 17:00" em vez de "12:00, 17:00"
          final horariosList = dispDoMedico.expand((d) => d.horarios).toList();
          final horariosStr = horariosList.length >= 2
              ? "${horariosList[0]} - ${horariosList[1]}"
              : horariosList.join(', ');

          final isValido = dispDoMedico.any((d) => _validarDisponibilidade(d));

          return MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Card(
              elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
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
            ),
          );
        }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicoCardContent(Medico medico, String horarios, bool isValid) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isValid 
            ? MyAppTheme.medicoDisponivelCard
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid 
              ? MyAppTheme.azulClaro.withValues(alpha: 0.4)
              : Colors.red.shade300,
          width: isValid ? 1.5 : 1,
        ),
        boxShadow: MyAppTheme.shadowMedicoCard,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nome do médico
          Row(
            children: [
              Expanded(
                child: Text(
            medico.nome,
                  style: MyAppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Horários com ícone
          if (horarios.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    horarios,
                    style: MyAppTheme.bodySmall.copyWith(
                      color: Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
          ),
          const SizedBox(height: 4),
          ],
          // Especialidade com ícone
          if (medico.especialidade.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    medico.especialidade,
                    style: MyAppTheme.bodySmall.copyWith(
                      color: Colors.grey[700],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
          ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
