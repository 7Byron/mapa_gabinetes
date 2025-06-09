import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/disponibilidade.dart';

class DisponibilidadesGrid extends StatefulWidget {
  final List<Disponibilidade> disponibilidades;
  final Function(DateTime, bool) onRemoverData;
  final Function(Disponibilidade)? onEditarDisponibilidade;

  const DisponibilidadesGrid({
    super.key,
    required this.disponibilidades,
    required this.onRemoverData,
    this.onEditarDisponibilidade,
  });

  @override
  DisponibilidadesGridState createState() => DisponibilidadesGridState();
}

class DisponibilidadesGridState extends State<DisponibilidadesGrid> {
  // Determina cor do cartão baseado na validação dos horários
  Color _determinarCorDoCartao(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) {
      return Colors.orange.shade200; // Nenhum horário definido
    }
    if (disponibilidade.horarios.length == 1) {
      return Colors.orange.shade200; // Apenas um horário definido
    }

    try {
      final inicio = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[0].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[0].split(':')[1]),
      );
      final fim = TimeOfDay(
        hour: int.parse(disponibilidade.horarios[1].split(':')[0]),
        minute: int.parse(disponibilidade.horarios[1].split(':')[1]),
      );

      if (inicio.hour < fim.hour ||
          (inicio.hour == fim.hour && inicio.minute < fim.minute)) {
        return Colors.lightGreen.shade100; // Válido
      } else {
        return Colors.red.shade100; // Início depois do fim
      }
    } catch (e) {
      return Colors.red.shade300; // Erro de formatação
    }
  }

  Future<void> _mostrarDialogoRemocaoSeries(
      BuildContext context,
      Disponibilidade disponibilidade,
      ) async {
    final isSerie = disponibilidade.tipo != 'Única';

    if (isSerie) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Remover disponibilidade'),
            content: Text(
              'Remover apenas este dia ou toda a série desde este dia em diante (${disponibilidade.tipo})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('single'),
                child: const Text('Apenas este dia'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('all'),
                child: const Text('Toda a série'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (escolha == 'single') {
        widget.onRemoverData(disponibilidade.data, false);
      } else if (escolha == 'all') {
        widget.onRemoverData(disponibilidade.data, true);
      }
    } else {
      final confirmacao = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Remover disponibilidade'),
            content: Text(
              'Tem certeza que deseja remover o dia '
                  '${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Não'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sim'),
              ),
            ],
          );
        },
      );

      if (confirmacao == true) {
        widget.onRemoverData(disponibilidade.data, false);
      }
    }
  }

  Future<void> _selecionarHorario(BuildContext context, DateTime data, bool isInicio) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      final horario = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      setState(() {
        // Acha a disponibilidade do dia
        final disponibilidade = widget.disponibilidades.firstWhere(
              (d) => d.data == data,
          orElse: () => Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900,1,1),
            horarios: [],
            tipo: 'Única',
          ),
        );

        // Se não encontrou uma real, não faz nada
        if (disponibilidade.data == DateTime(1900,1,1)) return;

        // Ajusta horário
        if (isInicio) {
          if (disponibilidade.horarios.isEmpty) {
            disponibilidade.horarios = [horario];
          } else {
            disponibilidade.horarios[0] = horario;
          }
        } else {
          if (disponibilidade.horarios.length == 1) {
            disponibilidade.horarios.add(horario);
          } else if (disponibilidade.horarios.length == 2) {
            disponibilidade.horarios[1] = horario;
          } else if (disponibilidade.horarios.isEmpty) {
            disponibilidade.horarios = isInicio ? [horario] : ['', horario];
          }
        }

        // Se for série, pergunta se quer aplicar em todos
        if (disponibilidade.tipo != 'Única') {
          Future.delayed(Duration.zero, () async {
            if (!context.mounted) return;
            final aplicarEmTodos = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Aplicar horário a toda a série?'),
                  content: Text(
                    'Deseja usar este horário de '
                        '${isInicio ? 'início' : 'fim'} '
                        'em todos os dias da série (${disponibilidade.tipo})?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Não'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sim'),
                    ),
                  ],
                );
              },
            );

            if (aplicarEmTodos == true) {
              setState(() {
                for (final disp in widget.disponibilidades.where((d) => d.tipo == disponibilidade.tipo)) {
                  if (isInicio) {
                    if (disp.horarios.isEmpty) {
                      disp.horarios.add(horario);
                    } else {
                      disp.horarios[0] = horario;
                    }
                  } else {
                    if (disp.horarios.isEmpty) {
                      disp.horarios = ['', horario];
                    } else if (disp.horarios.length == 1) {
                      disp.horarios.add(horario);
                    } else {
                      disp.horarios[1] = horario;
                    }
                  }
                }
              });
            }
          });
        }
      });
    }
  }

  void _verDisponibilidade(Disponibilidade disponibilidade) {
    // Ao tocar no cartão, executa a mesma lógica que editar (abre o CadastroMedico)
    widget.onEditarDisponibilidade?.call(disponibilidade);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = (constraints.maxWidth / 200).floor();
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.8,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.disponibilidades.length,
          itemBuilder: (context, index) {
            final disponibilidade = widget.disponibilidades[index];
            final diaSemana =
            DateFormat.EEEE('pt_BR').format(disponibilidade.data);

            final horarioInicio = disponibilidade.horarios.isNotEmpty
                ? disponibilidade.horarios[0]
                : 'Início';
            final horarioFim = disponibilidade.horarios.length == 2
                ? disponibilidade.horarios[1]
                : 'Fim';

            return InkWell(
              onTap: () => _verDisponibilidade(disponibilidade),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.all(8),
                color: _determinarCorDoCartao(disponibilidade),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year} ($diaSemana)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _mostrarDialogoRemocaoSeries(
                                context,
                                disponibilidade,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Série: ${disponibilidade.tipo}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.black87,
                              ),
                              onPressed: () => _selecionarHorario(
                                context,
                                disponibilidade.data,
                                true,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  horarioInicio,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.black87,
                              ),
                              onPressed: () => _selecionarHorario(
                                context,
                                disponibilidade.data,
                                false,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  horarioFim,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
