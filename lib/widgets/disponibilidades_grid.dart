import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../class/disponibilidade.dart';

class DisponibilidadesGrid extends StatefulWidget {
  final List<Disponibilidade> disponibilidades;
  final Function(DateTime, bool) onRemoverData;

  const DisponibilidadesGrid({
    super.key,
    required this.disponibilidades,
    required this.onRemoverData,
  });

  @override
  DisponibilidadesGridState createState() => DisponibilidadesGridState();
}

class DisponibilidadesGridState extends State<DisponibilidadesGrid> {

// Determina a cor do cartão baseado na validação dos horários
  Color _determinarCorDoCartao(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) {
      return Colors.orange; // Nenhum horário definido
    }
    if (disponibilidade.horarios.length == 1) {
      return Colors.orange; // Apenas um horário definido
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

      // Validação: horário de início deve ser antes do fim
      if (inicio.hour < fim.hour ||
          (inicio.hour == fim.hour && inicio.minute < fim.minute)) {
        return Colors.lightGreen; // Válido
      } else {
        return Colors.red; // Início depois do fim
      }
    } catch (e) {
      return Colors.red; // Erro de formatação de horário
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
              'Remover apenas este dia ou toda a série desde dia em diante (${disponibilidade.tipo})?',
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
      // Única
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

  Future<void> _selecionarHorario(
      BuildContext context,
      DateTime data,
      bool isInicio,
      ) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      final horario =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      setState(() {
        // 1. Atualiza o horário só do dia selecionado
        final disponibilidade =
        widget.disponibilidades.firstWhere((d) => d.data == data);

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
            // Caso extremo: se não há nada, adiciona primeiro um placeholder
            disponibilidade.horarios = isInicio
                ? [horario]
                : ['', horario];
          }
        }

        // 2. Se for uma série (tipo != 'Única'), pergunta ao usuário
        if (disponibilidade.tipo != 'Única') {
          Future.delayed(Duration.zero, () async {
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
              // 3. Aplica a todas as disponibilidades daquele tipo
              setState(() {
                for (final disp in widget.disponibilidades.where(
                        (d) => d.tipo == disponibilidade.tipo)) {
                  if (isInicio) {
                    // Se não existir ainda, cria
                    if (disp.horarios.isEmpty) {
                      disp.horarios.add(horario);
                    } else {
                      disp.horarios[0] = horario;
                    }
                  } else {
                    // se está definindo horário fim
                    if (disp.horarios.isEmpty) {
                      // Cria placeholder pra início e fim
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

            return Card(
              elevation: 4,
              margin: const EdgeInsets.all(8),
              color: _determinarCorDoCartao(disponibilidade),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                            '${disponibilidade.data.day}'
                                '/${disponibilidade.data.month}'
                                '/${disponibilidade.data.year} '
                                '($diaSemana)',
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
            );
          },
        );
      },
    );
  }
}
