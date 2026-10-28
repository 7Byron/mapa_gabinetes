import '../utils/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';

import '../widgets/medicos_disponiveis_section.dart';

class MedicosDisponiveisContainer extends StatelessWidget {
  final Widget resumo;
  final List<Medico> medicosDisponiveis;
  final List<Disponibilidade> disponibilidades;
  final List<Alocacao> alocacoes;
  final Set<String> cartoesEmAlocacao;
  final DateTime selectedDate;
  final Future<void> Function(String medicoId, {String? alocacaoId})
      onDesalocarMedicoComPergunta;
  final Function(Medico)? onEditarMedico;
  final VoidCallback onMostrarMedicosNaoAlocadosAno;
  final VoidCallback onMostrarConflitosAno;

  const MedicosDisponiveisContainer({
    super.key,
    required this.resumo,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.alocacoes,
    required this.cartoesEmAlocacao,
    required this.selectedDate,
    required this.onDesalocarMedicoComPergunta,
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

  Widget _acoes() => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Médicos não alocados no ano',
          onPressed: onMostrarMedicosNaoAlocadosAno,
          icon: const Icon(Icons.list_alt, size: 18, color: AppColors.acao),
        ),
        IconButton(
          tooltip: 'Conflitos de gabinete no ano',
          onPressed: onMostrarConflitosAno,
          icon: const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.textoConflito),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final hasMedicos = medicosDisponiveis.isNotEmpty;
    final escala = MediaQuery.textScalerOf(context).scale(13) / 13;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _podeDesalocar(details.data),
      onAcceptWithDetails: (details) => _desalocar(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        // Manter a zona de desalocação visível, mesmo sem médicos pendentes.
        return Container(
          decoration: BoxDecoration(
            color: isHovering ? AppColors.selecao : Colors.transparent,
            border: isHovering ? Border.all(color: AppColors.acao) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            resumo,
            Container(
              key: const ValueKey('faixa_medicos_por_alocar'),
              height: hasMedicos
                  ? (escala > 1 ? 60 * escala + 16 : 76)
                  : (escala > 1 ? 32 * escala + 16 : 48),
              margin: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isHovering ? AppColors.selecao : AppColors.superficie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isHovering ? AppColors.acao : AppColors.borda),
              ),
              child: LayoutBuilder(
                  builder: (context, constraints) => Row(children: [
                        if (hasMedicos && constraints.maxWidth > 600) ...[
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('Por alocar',
                                  style: TextStyle(
                                      color: AppColors.texto,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
                        ],
                        if (!hasMedicos)
                          const Expanded(
                              child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Arraste um médico para desalocar',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.secundario)),
                          ))
                        else
                          Expanded(
                              child: RepaintBoundary(
                                  child: MedicosDisponiveisSection(
                            medicosDisponiveis: medicosDisponiveis,
                            disponibilidades: disponibilidades,
                            alocacoes: alocacoes,
                            cartoesEmAlocacao: cartoesEmAlocacao,
                            selectedDate: selectedDate,
                            onEditarMedico: onEditarMedico,
                          ))),
                        _acoes(),
                      ])),
            ),
          ]),
        );
      },
    );
  }
}
