import 'package:flutter/material.dart';
import '../class/gabinete.dart';
import '../class/alocacao.dart';
import '../class/medico.dart';
import '../class/disponibilidade.dart';
import 'medico_card.dart';
import 'conflict_utils.dart';

class GabinetesSection extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final Function(String, String) onAlocarMedico;

  const GabinetesSection({
    super.key,
    required this.gabinetes,
    required this.alocacoes,
    required this.medicos,
    required this.disponibilidades,
    required this.selectedDate,
    required this.onAlocarMedico,
  });

  @override
  _GabinetesSectionState createState() => _GabinetesSectionState();
}

class _GabinetesSectionState extends State<GabinetesSection> {
  List<String> pisosSelecionados = [];
  String filtroOcupacao = 'Todos'; // 'Livres', 'Ocupados', 'Todos'
  bool mostrarConflitos = false;

  @override
  void initState() {
    super.initState();
    _inicializarFiltros();
    pisosSelecionados = widget.gabinetes.map((g) => g.setor).toSet().toList();
  }

  void _inicializarFiltros() {
    pisosSelecionados = widget.gabinetes.map((g) => g.setor).toSet().toList();
  }

  // Filtra os gabinetes de acordo com os filtros
  List<Gabinete> _filtrarGabinetes() {
    return widget.gabinetes.where((gabinete) {
      if (!pisosSelecionados.contains(gabinete.setor)) return false;

      final alocacoesDoGabinete = widget.alocacoes.where(
            (a) =>
        a.gabineteId == gabinete.id &&
            a.data.year == widget.selectedDate.year &&
            a.data.month == widget.selectedDate.month &&
            a.data.day == widget.selectedDate.day,
      ).toList();

      if (filtroOcupacao == 'Livres' && alocacoesDoGabinete.isNotEmpty) {
        return false;
      }
      if (filtroOcupacao == 'Ocupados' && alocacoesDoGabinete.isEmpty) {
        return false;
      }

      final temConflito = ConflictUtils.temConflitoGabinete(alocacoesDoGabinete);
      if (mostrarConflitos && !temConflito) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<Gabinete>> _agruparPorSetor(List<Gabinete> gabinetes) {
    final gabinetesPorSetor = <String, List<Gabinete>>{};
    for (var gabinete in gabinetes) {
      gabinetesPorSetor[gabinete.setor] ??= [];
      gabinetesPorSetor[gabinete.setor]!.add(gabinete);
    }
    return gabinetesPorSetor;
  }

  /// Verifica se a disponibilidade tem 2 horários válidos (início < fim).
  bool _validarDisponibilidade(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) return false;
    if (disponibilidade.horarios.length != 2) return false;

    try {
      final inicio = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[0].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[0].split(':')[1]),
      );
      final fim = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[1].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[1].split(':')[1]),
      );
      return (inicio.hour < fim.hour) ||
          (inicio.hour == fim.hour && inicio.minute < fim.minute);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gabinetesFiltrados = _filtrarGabinetes();

    return Row(
      children: [
        // -------------------------------------------------------
        // COLUNA LATERAL COM FILTROS DE PISO E OCUPAÇÃO
        // -------------------------------------------------------
        SizedBox(
          width: 220,
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Pisos'),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: widget.gabinetes
                      .map((g) => g.setor)
                      .toSet()
                      .map((setor) => FilterChip(
                    label: Text(setor),
                    selected: pisosSelecionados.contains(setor),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          pisosSelecionados.add(setor);
                        } else {
                          pisosSelecionados.remove(setor);
                        }
                      });
                    },
                  ))
                      .toList(),
                ),
                const Divider(),
                const Text('Ocupação'),
                DropdownButton<String>(
                  value: filtroOcupacao,
                  items: ['Todos', 'Livres', 'Ocupados']
                      .map(
                        (opcao) => DropdownMenuItem(
                      value: opcao,
                      child: Text(opcao),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      filtroOcupacao = value!;
                    });
                  },
                ),
                const Divider(),
                CheckboxListTile(
                  title: const Text('Mostrar Conflitos'),
                  value: mostrarConflitos,
                  onChanged: (value) {
                    setState(() {
                      mostrarConflitos = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),

        // -------------------------------------------------------
        // LISTA DE GABINETES AGRUPADOS POR SETOR
        // -------------------------------------------------------
        Expanded(
          child: ListView.builder(
            itemCount: _agruparPorSetor(gabinetesFiltrados).keys.length,
            itemBuilder: (context, setorIndex) {
              final gabinetesPorSetor = _agruparPorSetor(gabinetesFiltrados);
              final setor = gabinetesPorSetor.keys.elementAt(setorIndex);
              final gabinetesDoSetor = gabinetesPorSetor[setor]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TÍTULO DO SETOR
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

                  // GRELHA DE GABINETES
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: gabinetesDoSetor.length,
                    itemBuilder: (context, gabineteIndex) {
                      final gabinete = gabinetesDoSetor[gabineteIndex];

                      // Alocações desse gabinete no dia selecionado
                      final alocacoesDoGabinete = widget.alocacoes.where((a) {
                        return a.gabineteId == gabinete.id &&
                            a.data.year == widget.selectedDate.year &&
                            a.data.month == widget.selectedDate.month &&
                            a.data.day == widget.selectedDate.day;
                      }).toList();

                      // Se há conflito
                      final temConflito = ConflictUtils.temConflitoGabinete(
                        alocacoesDoGabinete,
                      );

                      // Cor de fundo do gabinete
                      Color corFundo;
                      if (alocacoesDoGabinete.isEmpty) {
                        corFundo = Colors.grey[300]!;
                      } else if (temConflito) {
                        corFundo = Colors.red[200]!;
                      } else {
                        corFundo = Colors.green[200]!;
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
                          if (medico.id.isEmpty) {
                            // Não encontrou um médico real
                            return false;
                          }

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
                              data: DateTime(1900,1,1),
                              horarios: [],
                              tipo: 'Única',
                            ),
                          );

                          if (disponibilidade.medicoId.isEmpty) {
                            // Não há disponibilidade “real”
                            return false;
                          }

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

                          // Se tudo ok, aceita
                          return true;
                        },
                        onAccept: (medicoId) {
                          setState(() {
                            // Chama callback que efetivamente salva a alocação
                            widget.onAlocarMedico(medicoId, gabinete.id);
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                              color: corFundo,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Nome do gabinete
                                  Text(
                                    gabinete.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

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

                                      // Monta string de horário, ex. "08:00 - 12:00"
                                      final horariosAlocacao =
                                      (a.horarioFim.isNotEmpty)
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
                                            true, // assumimos que já é válido
                                          ),
                                        ),
                                        child: MedicoCard.buildSmallMedicoCard(
                                          medico,
                                          horariosAlocacao,
                                          Colors.white,
                                          true,
                                        ),
                                      );
                                    }).toList(),
                                ],
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
          ),
        ),
      ],
    );
  }
}
