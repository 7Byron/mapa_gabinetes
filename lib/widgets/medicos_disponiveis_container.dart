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
  final Set<String> cartoesEmAlocacao;
  final DateTime selectedDate;
  final Future<void> Function(String medicoId, {String? alocacaoId})
      onDesalocarMedicoComPergunta;
  final Function(String) onDesalocarMedico;
  final Function(Medico)? onEditarMedico;
  final VoidCallback onMostrarMedicosNaoAlocadosAno;
  final VoidCallback onMostrarConflitosAno;

  const MedicosDisponiveisContainer({
    super.key,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.alocacoes,
    required this.cartoesEmAlocacao,
    required this.selectedDate,
    required this.onDesalocarMedicoComPergunta,
    required this.onDesalocarMedico,
    this.onEditarMedico,
    required this.onMostrarMedicosNaoAlocadosAno,
    required this.onMostrarConflitosAno,
  });

  bool _podeDesalocar(String dados) {
    final medicoId = dados.split('|||').first;
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return alocacoes.any((a) {
      final data = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId.isNotEmpty &&
          data == dataAlvo;
    });
  }

  Future<void> _desalocar(String dados) async {
    final partes = dados.split('|||');
    final medicoId = partes.first;
    final identificador = partes.length > 1 ? partes[1] : '';
    final alocacaoId = identificador.startsWith('alocacao:')
        ? identificador.substring('alocacao:'.length)
        : null;
    await onDesalocarMedicoComPergunta(
      medicoId,
      alocacaoId: alocacaoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedicos = medicosDisponiveis.isNotEmpty;
    final idsDisponiveis = medicosDisponiveis.map((m) => m.id).toSet();
    final dataSelecionada =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final totalCartoes = disponibilidades.where((d) {
      final data = DateTime(d.data.year, d.data.month, d.data.day);
      return data == dataSelecionada && idsDisponiveis.contains(d.medicoId);
    }).length;
    final containerHeight =
        MedicosDisponiveisLayoutUtils.calcularAlturaContainer(
      totalMedicos: totalCartoes,
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _podeDesalocar(details.data),
      onAcceptWithDetails: (details) => _desalocar(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: hasMedicos
              ? BoxConstraints(
                  minHeight: containerHeight,
                  maxHeight: containerHeight,
                )
              : null,
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          decoration: BoxDecoration(
            color: isHovering ? Colors.blue.shade50 : MyAppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: isHovering
                ? Border.all(color: MyAppTheme.azulEscuro, width: 3)
                : null,
            boxShadow: MyAppTheme.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MyAppTheme.azulEscuro.withValues(alpha: 0.1),
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
                              color:
                                  MyAppTheme.azulEscuro.withValues(alpha: 0.1),
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
                              color: Colors.red.withValues(alpha: 0.1),
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
                ),
              ),
              if (hasMedicos)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: RepaintBoundary(
                      child: MedicosDisponiveisSection(
                        medicosDisponiveis: medicosDisponiveis,
                        disponibilidades: disponibilidades,
                        alocacoes: alocacoes,
                        cartoesEmAlocacao: cartoesEmAlocacao,
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
      },
    );
  }
}
