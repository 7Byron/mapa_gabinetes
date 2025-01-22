import 'package:flutter/material.dart';
import '../class/gabinete.dart';
import '../class/alocacao.dart';
import '../class/medico.dart';
import 'medico_card.dart';
import 'conflict_utils.dart';

class GabinetesSection extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final DateTime selectedDate;
  final Function(String, String) onAlocarMedico;

  const GabinetesSection({
    super.key,
    required this.gabinetes,
    required this.alocacoes,
    required this.medicos,
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
    // Inicializa selecionando todos os pisos disponíveis
    pisosSelecionados = widget.gabinetes.map((g) => g.setor).toSet().toList();
  }

  // Filtra os gabinetes com base nos critérios
  List<Gabinete> _filtrarGabinetes() {
    return widget.gabinetes.where((gabinete) {
      // Filtro por piso
      if (!pisosSelecionados.contains(gabinete.setor)) return false;

      // Alocações do gabinete no dia selecionado
      final alocacoesDoGabinete = widget.alocacoes.where((a) =>
      a.gabineteId == gabinete.id &&
          a.data.year == widget.selectedDate.year &&
          a.data.month == widget.selectedDate.month &&
          a.data.day == widget.selectedDate.day).toList();

      // Filtro por ocupação
      if (filtroOcupacao == 'Livres' && alocacoesDoGabinete.isNotEmpty) {
        return false;
      }
      if (filtroOcupacao == 'Ocupados' && alocacoesDoGabinete.isEmpty) {
        return false;
      }

      // Filtro por conflitos
      final temConflito = ConflictUtils.temConflitoGabinete(alocacoesDoGabinete);
      if (mostrarConflitos && !temConflito) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, List<Gabinete>> _agruparPorSetor(List<Gabinete> gabinetes) {
    Map<String, List<Gabinete>> gabinetesPorSetor = {};
    for (var gabinete in gabinetes) {
      if (!gabinetesPorSetor.containsKey(gabinete.setor)) {
        gabinetesPorSetor[gabinete.setor] = [];
      }
      gabinetesPorSetor[gabinete.setor]!.add(gabinete);
    }
    return gabinetesPorSetor;
  }

  @override
  Widget build(BuildContext context) {
    // Aplica os filtros para exibir os gabinetes corretamente
    final gabinetesFiltrados = _filtrarGabinetes();

    return Row(
      children: [
        // Coluna da Esquerda: Filtros
        SizedBox(
          width: 220,
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtros',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                // Filtro: Escolher Pisos
                Text('Pisos'),
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

                // Filtro: Ocupação
                Text('Ocupação'),
                DropdownButton<String>(
                  value: filtroOcupacao,
                  items: ['Todos', 'Livres', 'Ocupados']
                      .map((opcao) => DropdownMenuItem(
                    value: opcao,
                    child: Text(opcao),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      filtroOcupacao = value!;
                    });
                  },
                ),
                const Divider(),

                // Filtro: Mostrar Conflitos
                CheckboxListTile(
                  title: Text('Mostrar Conflitos'),
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

        // Coluna da Direita: Gabinetes
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
                  // Nome do setor como cabeçalho
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

                  // Gabinetes do setor como grid
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

                      // Alocações para o dia selecionado
                      final alocacoesDoGabinete = widget.alocacoes
                          .where((a) =>
                      a.gabineteId == gabinete.id &&
                          a.data.year == widget.selectedDate.year &&
                          a.data.month == widget.selectedDate.month &&
                          a.data.day == widget.selectedDate.day)
                          .toList();

                      // Verifica se há conflitos
                      final temConflito =
                      ConflictUtils.temConflitoGabinete(alocacoesDoGabinete);

                      // Define a cor de fundo do gabinete
                      Color corFundo;
                      if (alocacoesDoGabinete.isEmpty) {
                        corFundo = Colors.grey[300]!; // Cinza para livres
                      } else if (temConflito) {
                        corFundo = Colors.red[200]!; // Vermelho para conflitos
                      } else {
                        corFundo = Colors.green[200]!; // Verde para ocupados
                      }

                      return DragTarget<String>(
                        onWillAccept: (medicoId) {
                          // Permitir que qualquer médico seja solto no gabinete
                          return true;
                        },
                        onAccept: (medicoId) {
                          // Alocar médico ao gabinete
                          widget.onAlocarMedico(medicoId, gabinete.id);
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
                                  Text(gabinete.nome),
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

                                      return Draggable<String>(
                                        data: medico.id,
                                        feedback: MedicoCard.dragFeedback(
                                          medico,
                                          a.horarioInicio,
                                        ),
                                        childWhenDragging: Opacity(
                                          opacity: 0.5,
                                          child: MedicoCard.buildSmallMedicoCard(
                                            medico,
                                            a.horarioInicio,
                                          ),
                                        ),
                                        child: MedicoCard.buildSmallMedicoCard(
                                          medico,
                                          a.horarioInicio,
                                        ),
                                      );
                                    }),
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
