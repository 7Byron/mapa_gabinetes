import 'package:flutter/material.dart';

import '../models/gabinete.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../utils/conflict_utils.dart';
import 'medico_card.dart';

class GabinetesSection extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final VoidCallback onAtualizarEstado;
  final Future<void> Function(String medicoId) onDesalocarMedicoComPergunta;

  /// Função que aloca UM médico em UM gabinete em UM dia específico
  final Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
  }) onAlocarMedico;

  const GabinetesSection({
    super.key,
    required this.gabinetes,
    required this.alocacoes,
    required this.medicos,
    required this.disponibilidades,
    required this.selectedDate,
    required this.onAlocarMedico,
    required this.onAtualizarEstado,
    required this.onDesalocarMedicoComPergunta,
  });

  @override
  State<GabinetesSection> createState() => _GabinetesSectionState();
}

class _GabinetesSectionState extends State<GabinetesSection> {
  int _horarioParaMinutos(String horario) {
    final partes = horario.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa gabinetes por setor
    final gabinetesPorSetor = <String, List<Gabinete>>{};
    for (var g in widget.gabinetes) {
      gabinetesPorSetor[g.setor] ??= [];
      gabinetesPorSetor[g.setor]!.add(g);
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      physics: const ClampingScrollPhysics(),
      itemCount: gabinetesPorSetor.keys.length,
      itemBuilder: (context, index) {
        final setor = gabinetesPorSetor.keys.elementAt(index);
        final listaGabinetes = gabinetesPorSetor[setor]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título do setor
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                setor,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Grid de Gabinetes
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: listaGabinetes.length,
              itemBuilder: (ctx, idx) {
                final gabinete = listaGabinetes[idx];

                // Alocações deste gabinete no dia selecionado
                final alocacoesDoGab = widget.alocacoes.where((a) {
                  return a.gabineteId == gabinete.id &&
                      a.data.year == widget.selectedDate.year &&
                      a.data.month == widget.selectedDate.month &&
                      a.data.day == widget.selectedDate.day;
                }).toList();

                final temConflito =
                    ConflictUtils.temConflitoGabinete(alocacoesDoGab);

                Color corFundo;
                if (alocacoesDoGab.isEmpty) {
                  corFundo = const Color(0xFFE4EAF2); // Azul clarinho
                } else if (temConflito) {
                  corFundo = const Color(0xFFFFCDD2); // Vermelho clarinho
                } else {
                  corFundo = const Color(0xFFC8E6C9); // Verde clarinho
                }

                return DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    final medicoId = details.data;
                    final estaAlocado = alocacoesDoGab.any((a) => a.medicoId == medicoId);
                    if (!estaAlocado) {
                      debugPrint('Médico $medicoId NÃO está alocado, ignorando desalocação.');
                      return false;
                    }
                    debugPrint('Médico $medicoId está alocado, aceitando para desalocar.');
                    return true;
                  },
                  onAcceptWithDetails: (details) async {
                    final medicoId = details.data;
                    await widget.onDesalocarMedicoComPergunta(medicoId);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final alocacoesDoGabinete = widget.alocacoes.where((a) {
                      return a.gabineteId == gabinete.id &&
                          a.data.year == widget.selectedDate.year &&
                          a.data.month == widget.selectedDate.month &&
                          a.data.day == widget.selectedDate.day;
                    }).toList()
                      ..sort((a, b) => _horarioParaMinutos(a.horarioInicio)
                          .compareTo(_horarioParaMinutos(b.horarioInicio)));

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: corFundo,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nome do gabinete
                              Text(
                                gabinete.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                gabinete.especialidadesPermitidas.join(", "),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Lista de médicos alocados
                              if (alocacoesDoGabinete.isNotEmpty)
                                ...alocacoesDoGabinete.map((a) {
                                  final medico = widget.medicos.firstWhere(
                                    (m) => m.id == a.medicoId,
                                    orElse: () => Medico(
                                      id: '',
                                      nome: 'Desconhecido',
                                      especialidade: '',
                                      disponibilidades: [],
                                    ),
                                  );

                                  final horariosAlocacao = a
                                          .horarioFim.isNotEmpty
                                      ? '${a.horarioInicio} - ${a.horarioFim}'
                                      : a.horarioInicio;

                                  return Draggable<String>(
                                    data: medico.id,
                                    feedback: MedicoCard.dragFeedback(
                                      medico,
                                      horariosAlocacao,
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.5,
                                      child: MedicoCard.buildSmallMedicoCard(
                                        medico,
                                        horariosAlocacao,
                                        Colors.white,
                                        true,
                                      ),
                                    ),
                                    child: MedicoCard.buildSmallMedicoCard(
                                      medico,
                                      horariosAlocacao,
                                      Colors.white,
                                      true,
                                    ),
                                    onDragEnd: (details) {
                                      if (details.wasAccepted == false) {
                                        debugPrint(
                                            'Cartão foi solto fora de qualquer DragTarget. Nenhuma ação será disparada.');
                                      }
                                    },
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
