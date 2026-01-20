import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../utils/app_theme.dart';
import '../utils/medicos_disponiveis_layout_utils.dart';
import '../widgets/medicos_disponiveis_section.dart';

class MedicosDisponiveisContainer extends StatelessWidget {
  final List<Medico> medicosDisponiveis;
  final List<Disponibilidade> disponibilidades;
  final List<Alocacao> alocacoes;
  final DateTime selectedDate;
  final Future<void> Function(String medicoId) onDesalocarMedicoComPergunta;
  final Function(String) onDesalocarMedico;
  final Function(Medico)? onEditarMedico;
  final VoidCallback onMostrarMedicosNaoAlocadosAno;
  final VoidCallback onMostrarConflitosAno;

  const MedicosDisponiveisContainer({
    super.key,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.alocacoes,
    required this.selectedDate,
    required this.onDesalocarMedicoComPergunta,
    required this.onDesalocarMedico,
    this.onEditarMedico,
    required this.onMostrarMedicosNaoAlocadosAno,
    required this.onMostrarConflitosAno,
  });

  @override
  Widget build(BuildContext context) {
    final minHeight = MedicosDisponiveisLayoutUtils.calcularAlturaMinima(
      context: context,
      totalMedicos: medicosDisponiveis.length,
    );

    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight,
        maxHeight: 300,
      ),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MyAppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                final medicoId = details.data;
                final dataAlvo = DateTime(
                    selectedDate.year, selectedDate.month, selectedDate.day);
                final estaAlocado = alocacoes.any((a) {
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                  return a.medicoId == medicoId && aDate == dataAlvo;
                });

                if (!estaAlocado) {
                  debugPrint(
                      '❌ Médico $medicoId NÃO está alocado no dia ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}, ignorando desalocação.');
                  return false;
                }

                final estaAlocadoEmAlgumGabinete = alocacoes.any((a) {
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                  return a.medicoId == medicoId &&
                      a.gabineteId.isNotEmpty &&
                      aDate == dataAlvo;
                });

                if (estaAlocadoEmAlgumGabinete) {
                  debugPrint(
                      '⚠️ Médico $medicoId está alocado em um gabinete - não aceitar para desalocar (deve ser realocação)');
                  return false;
                }

                debugPrint(
                    '✅ Médico $medicoId está alocado no dia ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}, aceitando para desalocar.');
                return true;
              },
              onAcceptWithDetails: (details) async {
                final medicoId = details.data;
                debugPrint(
                    '🔄 onAcceptWithDetails chamado para desalocar médico $medicoId');
                await onDesalocarMedicoComPergunta(medicoId);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: isHovering
                        ? Colors.blue.shade50
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isHovering
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MyAppTheme.azulEscuro.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 18,
                          color: MyAppTheme.azulEscuro,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Médicos por Alocar',
                        style: MyAppTheme.heading2.copyWith(
                          fontSize: 17,
                          color: MyAppTheme.azulEscuro,
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Médicos não alocados no ano',
                        child: InkWell(
                          onTap: onMostrarMedicosNaoAlocadosAno,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: MyAppTheme.azulEscuro.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.list_alt,
                              size: 18,
                              color: MyAppTheme.azulEscuro,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Conflitos de gabinete no ano',
                        child: InkWell(
                          onTap: onMostrarConflitosAno,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RepaintBoundary(
                child: MedicosDisponiveisSection(
                  medicosDisponiveis: medicosDisponiveis,
                  disponibilidades: disponibilidades,
                  selectedDate: selectedDate,
                  onDesalocarMedico: onDesalocarMedico,
                  onEditarMedico: onEditarMedico,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
