import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/serie_tipo_colors.dart';
import '../models/disponibilidade.dart';

class CalendarioDisponibilidades extends StatefulWidget {
  final List<DateTime> diasSelecionados;
  final List<Disponibilidade> disponibilidades;

  /// onAdicionarData recebe (DateTime date, String tipo)
  final Function(DateTime, String) onAdicionarData;

  /// onRemoverData recebe (DateTime date, bool removeSerie)
  final Function(DateTime, bool) onRemoverData;

  /// onViewChanged recebe (DateTime visibleDate) quando o usuário navega no calendário
  final Function(DateTime)? onViewChanged;

  /// dataCalendario - data atual do calendário para forçar atualização visual
  final DateTime? dataCalendario;

  /// Modo apenas seleção - se true, apenas seleciona a data sem mostrar diálogos
  final bool modoApenasSelecao;

  /// Callback opcional para quando uma data é selecionada (usado no modo apenas seleção)
  final Function(DateTime)? onDateSelected;

  const CalendarioDisponibilidades({
    super.key,
    required this.diasSelecionados,
    this.disponibilidades = const [],
    required this.onAdicionarData,
    required this.onRemoverData,
    this.onViewChanged,
    this.dataCalendario,
    this.modoApenasSelecao = false,
    this.onDateSelected,
  });

  @override
  State<CalendarioDisponibilidades> createState() =>
      _CalendarioDisponibilidadesState();
}

class _CalendarioDisponibilidadesState
    extends State<CalendarioDisponibilidades> {
  late CalendarController _calendarController;
  bool _isInitialBuild = true;
  DateTime? _lastProgrammaticDate; // Data que foi definida programaticamente

  Future<void> _mostrarDialogoTipoMarcacao(
      BuildContext context, DateTime date) async {
    const tiposMarcacao = [
      'Única',
      'Semanal',
      'Quinzenal',
      'Mensal',
      'Consecutivo',
    ];
    final String? tipoMarcacao = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Escolha o tipo de marcação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: tiposMarcacao.map((tipo) {
              final cor = SerieTipoColors.para(tipo);
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(
                  tipo,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(tipo),
              );
            }).toList(),
          ),
        );
      },
    );
    if (!context.mounted) return;

    if (tipoMarcacao != null) {
      if (tipoMarcacao == 'Consecutivo') {
        // Se escolheu Consecutivo, perguntar quantos dias
        final int? numeroDias = await _mostrarDialogoNumeroDias(context);
        if (numeroDias != null) {
          widget.onAdicionarData(date, 'Consecutivo:$numeroDias');
        }
      } else {
        widget.onAdicionarData(date, tipoMarcacao);
      }
    }
  }

  Future<int?> _mostrarDialogoNumeroDias(BuildContext context) async {
    int numeroDias = 5; // Valor padrão

    return await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Quantos dias consecutivos?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Escolha quantos dias consecutivos deseja marcar:'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (numeroDias > 1) {
                            setState(() {
                              numeroDias--;
                            });
                          }
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$numeroDias',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (numeroDias < 30) {
                            setState(() {
                              numeroDias++;
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(numeroDias),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarNovaSerie(BuildContext context, DateTime date) async {
    final criarNova = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Criar nova série?'),
          content: Text(
            'Já existe uma disponibilidade em '
            '${date.day}/${date.month}/${date.year}. '
            'Deseja criar uma nova série para este dia?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Criar nova série'),
            ),
          ],
        );
      },
    );

    if (criarNova == true && context.mounted) {
      await _mostrarDialogoTipoMarcacao(context, date);
    }
  }

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    // Se dataCalendario foi fornecida, navegar para ela após o build
    if (widget.dataCalendario != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calendarController.displayDate = widget.dataCalendario!;
        }
      });
    }
  }

  @override
  void didUpdateWidget(CalendarioDisponibilidades oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se a data do calendário mudou, atualizar a visualização
    if (widget.dataCalendario != null &&
        (oldWidget.dataCalendario == null ||
            oldWidget.dataCalendario!.year != widget.dataCalendario!.year ||
            oldWidget.dataCalendario!.month != widget.dataCalendario!.month ||
            oldWidget.dataCalendario!.day != widget.dataCalendario!.day)) {
      // Marcar que estamos atualizando programaticamente ANTES de atualizar o displayDate
      _lastProgrammaticDate = widget.dataCalendario!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calendarController.displayDate = widget.dataCalendario!;
        }
      });
    }
  }

  /// Capitaliza a primeira letra de uma string
  String _capitalizarPrimeiraLetra(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obter a data atual do calendário (usar o displayDate do controller ou a data do widget)
    final displayDate = _calendarController.displayDate ??
        widget.dataCalendario ??
        DateTime.now();

    // Capitalizar primeira letra do mês em português
    final mes = _capitalizarPrimeiraLetra(
        DateFormat('MMMM', 'pt_PT').format(displayDate));
    final ano = displayDate.year.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MyAppTheme.shadowCard3D,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header customizado com mês em português e ano destacado
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ano no topo (centralizado)
                  DropdownButton<int>(
                    value: int.parse(ano),
                    underline: Container(), // Remove a linha padrão
                    isDense: true,
                    items: List.generate(10, (index) {
                      final anoOpcao = DateTime.now().year -
                          2 +
                          index; // 2 anos atrás até 7 anos à frente
                      return DropdownMenuItem<int>(
                        value: anoOpcao,
                        child: Text(
                          anoOpcao.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? novoAno) {
                      if (novoAno != null) {
                        // CORREÇÃO: Manter o mesmo mês e dia ao mudar apenas o ano
                        final diaAtual = displayDate.day;
                        final mesAtual = displayDate.month;
                        // Garantir que o dia existe no novo mês/ano (ex: 29/02 em ano não bissexto)
                        final ultimoDiaDoMes =
                            DateTime(novoAno, mesAtual + 1, 0).day;
                        final diaFinal = diaAtual <= ultimoDiaDoMes
                            ? diaAtual
                            : ultimoDiaDoMes;
                        final novaData = DateTime(novoAno, mesAtual, diaFinal);

                        // Marcar como atualização programática para evitar conflitos
                        _lastProgrammaticDate = novaData;

                        setState(() {});
                        _calendarController.displayDate = novaData;
                        // CORREÇÃO: Não chamar forward!() pois isso avança o mês
                        // Apenas atualizar o displayDate é suficiente

                        // Notificar mudança
                        if (widget.onViewChanged != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              widget.onViewChanged!(novaData);
                            }
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  // Mês com setas de navegação: < Mês > (setas nas margens)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final novaData = DateTime(
                              displayDate.year, displayDate.month - 1, 1);
                          setState(() {});
                          _calendarController.displayDate = novaData;
                          _calendarController.backward!();
                        },
                      ),
                      // Dropdown para selecionar o mês (no centro)
                      Expanded(
                        child: Center(
                          child: DropdownButton<String>(
                            value: mes,
                            underline: Container(), // Remove a linha padrão
                            isDense: true,
                            items: [
                              'Janeiro',
                              'Fevereiro',
                              'Março',
                              'Abril',
                              'Maio',
                              'Junho',
                              'Julho',
                              'Agosto',
                              'Setembro',
                              'Outubro',
                              'Novembro',
                              'Dezembro'
                            ].map((String m) {
                              return DropdownMenuItem<String>(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? novoMes) {
                              if (novoMes != null) {
                                final meses = [
                                  'Janeiro',
                                  'Fevereiro',
                                  'Março',
                                  'Abril',
                                  'Maio',
                                  'Junho',
                                  'Julho',
                                  'Agosto',
                                  'Setembro',
                                  'Outubro',
                                  'Novembro',
                                  'Dezembro'
                                ];
                                final indiceMes = meses.indexOf(novoMes) + 1;
                                final novaData =
                                    DateTime(displayDate.year, indiceMes, 1);

                                // Marcar como atualização programática para evitar conflitos
                                _lastProgrammaticDate = novaData;

                                setState(() {});
                                _calendarController.displayDate = novaData;
                                // CORREÇÃO: Não chamar forward!() pois isso avança apenas um mês
                                // Apenas atualizar o displayDate é suficiente

                                // Notificar mudança
                                if (widget.onViewChanged != null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) {
                                      widget.onViewChanged!(novaData);
                                    }
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final novaData = DateTime(
                              displayDate.year, displayDate.month + 1, 1);
                          setState(() {});
                          _calendarController.displayDate = novaData;
                          _calendarController.forward!();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Header customizado para os dias da semana em português
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  // Sábado (índice 5) e Domingo (índice 6) em azul
                  final isWeekend = index == 5 || index == 6;
                  return Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isWeekend ? Colors.blue : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              height: 260, // Altura ajustada (300 - 40 do header dos dias)
              child: SfCalendar(
                controller: _calendarController,
                showNavigationArrow:
                    false, // Desabilitar navegação padrão, usar a customizada
                view: CalendarView.month,
                initialDisplayDate: widget.dataCalendario,
                headerHeight: 0, // Ocultar header padrão do mês/ano
                firstDayOfWeek: 1, // Começar na segunda-feira (1 = Monday)
                monthViewSettings: const MonthViewSettings(
                  dayFormat:
                      ' ', // Espaço vazio para ocultar os dias da semana padrão
                  showAgenda: false,
                ),
                onViewChanged: (ViewChangedDetails details) {
                  // Ignorar o callback durante o build inicial (apenas na primeira vez)
                  if (_isInitialBuild) {
                    _isInitialBuild = false;
                    return;
                  }

                  // Atualizar data de exibição quando o calendário navega
                  if (details.visibleDates.isNotEmpty) {
                    final visibleDate =
                        details.visibleDates[details.visibleDates.length ~/ 2];

                    // Se estamos atualizando programaticamente, verificar se a visibleDate está próxima da data programática
                    // Se sim, ignorar este callback para evitar sobrescrever a data selecionada
                    if (_lastProgrammaticDate != null) {
                      final programmaticDateNormalized = DateTime(
                          _lastProgrammaticDate!.year,
                          _lastProgrammaticDate!.month,
                          _lastProgrammaticDate!.day);
                      final visibleDateNormalized = DateTime(
                          visibleDate.year, visibleDate.month, visibleDate.day);
                      final diff = (visibleDateNormalized
                              .difference(programmaticDateNormalized)
                              .inDays)
                          .abs();

                      // Se a diferença for pequena (dentro de 14 dias) e no mesmo mês/ano, provavelmente é resultado da atualização programática
                      // Aumentado para 14 dias para cobrir casos onde o calendário mostra semanas diferentes
                      if (diff <= 14 &&
                          visibleDate.year == _lastProgrammaticDate!.year &&
                          visibleDate.month == _lastProgrammaticDate!.month) {
                        _lastProgrammaticDate = null; // Limpar flag após usar
                        return;
                      }
                      _lastProgrammaticDate =
                          null; // Limpar flag se não for programático
                    }

                    // Quando o usuário navega no calendário, notificar a mudança
                    if (widget.onViewChanged != null) {
                      debugPrint(
                          '📅 Calendário navegou para: ${visibleDate.day}/${visibleDate.month}/${visibleDate.year}');

                      // Atualizar o displayDate do controller imediatamente para sincronizar
                      _calendarController.displayDate = visibleDate;

                      // Usar WidgetsBinding para garantir que é executado após o build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(
                              () {}); // Forçar rebuild para atualizar header
                          widget.onViewChanged!(visibleDate);
                        }
                      });
                    }
                  }
                },
                onTap: (details) {
                  final date = details.date;
                  if (date != null) {
                    // Se está no modo apenas seleção, apenas chamar o callback
                    if (widget.modoApenasSelecao) {
                      if (widget.onDateSelected != null) {
                        widget.onDateSelected!(date);
                      }
                      return;
                    }

                    final isSelected = widget.diasSelecionados.any(
                      (d) =>
                          d.year == date.year &&
                          d.month == date.month &&
                          d.day == date.day,
                    );

                    if (isSelected) {
                      // A remoção é feita no cartão. No calendário, um segundo
                      // clique permite adicionar outra série no mesmo dia.
                      _confirmarNovaSerie(context, date);
                    } else {
                      // Se não está selecionado, perguntar qual tipo de marcação (Única, Semanal etc.)
                      _mostrarDialogoTipoMarcacao(context, date);
                    }
                  }
                },
                monthCellBuilder: (context, details) {
                  final isSelected = widget.diasSelecionados.any(
                    (d) =>
                        d.year == details.date.year &&
                        d.month == details.date.month &&
                        d.day == details.date.day,
                  );

                  // Verifica se a célula pertence ao mês atual
                  final isCurrentMonth =
                      details.visibleDates[10].month == details.date.month;
                  final coresDoDia = widget.disponibilidades
                      .where((d) =>
                          d.data.year == details.date.year &&
                          d.data.month == details.date.month &&
                          d.data.day == details.date.day)
                      .map((d) => SerieTipoColors.para(d.tipo))
                      .toSet()
                      .toList();
                  if (isSelected && coresDoDia.isEmpty) {
                    coresDoDia.add(Colors.purple);
                  }

                  return Center(
                    child: CustomPaint(
                      painter: isSelected
                          ? _CoresSeriesDiaPainter(coresDoDia)
                          : null,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${details.date.day}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isCurrentMonth
                                    ? Colors.black
                                    : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoresSeriesDiaPainter extends CustomPainter {
  final List<Color> cores;

  const _CoresSeriesDiaPainter(this.cores);

  @override
  void paint(Canvas canvas, Size size) {
    if (cores.isEmpty) return;
    final rect = Offset.zero & size;
    if (cores.length == 1) {
      canvas.drawOval(rect, Paint()..color = cores.first);
      return;
    }

    final sweep = 2 * 3.141592653589793 / cores.length;
    var inicio = -3.141592653589793 / 2;
    for (final cor in cores) {
      canvas.drawArc(
        rect,
        inicio,
        sweep,
        true,
        Paint()..color = cor,
      );
      inicio += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CoresSeriesDiaPainter oldDelegate) {
    if (oldDelegate.cores.length != cores.length) return true;
    for (var i = 0; i < cores.length; i++) {
      if (oldDelegate.cores[i] != cores[i]) return true;
    }
    return false;
  }
}
