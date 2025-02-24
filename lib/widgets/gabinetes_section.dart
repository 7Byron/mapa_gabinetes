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
  });

  @override
  State<GabinetesSection> createState() => _GabinetesSectionState();
}

class _GabinetesSectionState extends State<GabinetesSection> {
  bool _validarDisponibilidade(Disponibilidade d) {
    if (d.horarios.length != 2) return false;
    try {
      final inicioParts = d.horarios[0].split(':');
      final fimParts = d.horarios[1].split(':');
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
    } catch (_) {
      return false;
    }
  }

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

                final temConflito = ConflictUtils.temConflitoGabinete(alocacoesDoGab);

                Color corFundo;
                if (alocacoesDoGab.isEmpty) {
                  corFundo = const Color(0xFFE4EAF2); // Azul clarinho
                } else if (temConflito) {
                  corFundo = const Color(0xFFFFCDD2); // Vermelho clarinho
                } else {
                  corFundo = const Color(0xFFC8E6C9); // Verde clarinho
                }

                return DragTarget<String>(
                  onWillAccept: (medicoId) {
                    // 1) Ache o médico
                    final medico = widget.medicos.firstWhere(
                          (m) => m.id == medicoId,
                      orElse: () => Medico(
                        id: '',
                        nome: '',
                        especialidade: '',
                        disponibilidades: [],
                      ),
                    );
                    if (medico.id.isEmpty) return false;

                    // 2) Disponibilidade do médico no dia
                    final disponibilidade = widget.disponibilidades.firstWhere(
                          (d) =>
                      d.medicoId == medico.id &&
                          d.data.year == widget.selectedDate.year &&
                          d.data.month == widget.selectedDate.month &&
                          d.data.day == widget.selectedDate.day,
                      orElse: () => Disponibilidade(
                        id: '',
                        medicoId: '',
                        data: DateTime(1900, 1, 1),
                        horarios: [],
                        tipo: 'Única',
                      ),
                    );
                    if (disponibilidade.medicoId.isEmpty) return false;

                    // 3) Verifica se horários são válidos
                    if (!_validarDisponibilidade(disponibilidade)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cartão de disponibilidade mal configurado. Configure corretamente.',
                          ),
                        ),
                      );
                      return false;
                    }

                    return true;
                  },
                  onAccept: (medicoId) async {
                    // 1) Localiza disponibilidade
                    final disponibilidade = widget.disponibilidades.firstWhere(
                          (d) =>
                      d.medicoId == medicoId &&
                          d.data.year == widget.selectedDate.year &&
                          d.data.month == widget.selectedDate.month &&
                          d.data.day == widget.selectedDate.day,
                      orElse: () => Disponibilidade(
                        id: '',
                        medicoId: '',
                        data: DateTime(1900, 1, 1),
                        horarios: [],
                        tipo: '',
                      ),
                    );

                    if (disponibilidade.medicoId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Disponibilidade inválida para o médico.')),
                      );
                      return;
                    }

                    final tipoDisponibilidade = disponibilidade.tipo;

                    if (tipoDisponibilidade == 'Única') {
                      await widget.onAlocarMedico(
                        medicoId,
                        gabinete.id,
                        dataEspecifica: widget.selectedDate,
                      );
                    } else {
                      // Pergunta se alocar série
                      final escolha = await showDialog<String>(
                        context: context,
                        builder: (ctxDialog) {
                          return AlertDialog(
                            title: const Text('Alocar série?'),
                            content: Text(
                              'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
                                  'Deseja alocar apenas este dia (${widget.selectedDate.day}/${widget.selectedDate.month}) '
                                  'ou todos os dias da série a partir deste?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
                                child: const Text('Apenas este dia'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctxDialog).pop('serie'),
                                child: const Text('Toda a série'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctxDialog).pop(null),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          );
                        },
                      );

                      if (escolha == '1dia') {
                        await widget.onAlocarMedico(
                          medicoId,
                          gabinete.id,
                          dataEspecifica: widget.selectedDate,
                        );
                      } else if (escolha == 'serie') {
                        final dataRef = widget.selectedDate;
                        final listaMesmaSerie = widget.disponibilidades.where((d2) {
                          return d2.medicoId == medicoId &&
                              d2.tipo == tipoDisponibilidade &&
                              !d2.data.isBefore(dataRef);
                        }).toList();

                        for (final d2 in listaMesmaSerie) {
                          if (_validarDisponibilidade(d2)) {
                            await widget.onAlocarMedico(
                              medicoId,
                              gabinete.id,
                              dataEspecifica: d2.data,
                            );
                          }
                        }
                      }
                    }

                    // Atualiza localmente
                    setState(() {
                      widget.alocacoes.removeWhere((a) => a.medicoId == medicoId);
                      widget.alocacoes.add(
                        Alocacao(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          medicoId: medicoId,
                          gabineteId: gabinete.id,
                          data: widget.selectedDate,
                          horarioInicio: disponibilidade.horarios.isNotEmpty
                              ? disponibilidade.horarios.first
                              : '',
                          horarioFim: disponibilidade.horarios.length > 1
                              ? disponibilidade.horarios.last
                              : '',
                        ),
                      );
                    });
                    widget.onAtualizarEstado();
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

                                  final horariosAlocacao =
                                  a.horarioFim.isNotEmpty
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
