import 'package:flutter/material.dart';
// import 'dart:convert'; // Comentado - usado apenas na instrumentação de debug
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import 'alocacao_card.dart';
import '../utils/alocacao_card_actions.dart';
import '../utils/alocacao_card_handlers.dart';
import '../utils/series_helper.dart';
import '../services/disponibilidade_data_gestao_service.dart';
// import '../utils/debug_log_file.dart'; // Comentado - usado apenas na instrumentação de debug

class DisponibilidadesGrid extends StatefulWidget {
  final List<Disponibilidade> disponibilidades;
  final Function(DateTime, bool) onRemoverData;
  final Function(Disponibilidade)? onEditarDisponibilidade;
  final VoidCallback? onChanged; // notifica alterações (horários etc.)
  final Function(Disponibilidade, List<String>)? onAtualizarSerie; // callback para atualizar série quando horários são editados
  final List<Alocacao>? alocacoes; // Alocações para exibir número do gabinete
  final List<Gabinete>? gabinetes; // Lista de gabinetes para obter nomes
  final Unidade? unidade; // Unidade para navegação
  final Function(Disponibilidade, String?)? onGabineteChanged; // Callback quando gabinete é alterado (null = desalocar)
  final List<SerieRecorrencia>? series; // Lista de séries para validação de horários

  const DisponibilidadesGrid({
    super.key,
    required this.disponibilidades,
    required this.onRemoverData,
    this.onEditarDisponibilidade,
    this.onChanged,
    this.onAtualizarSerie,
    this.alocacoes,
    this.gabinetes,
    this.unidade,
    this.onGabineteChanged,
    this.series,
  });

  @override
  DisponibilidadesGridState createState() => DisponibilidadesGridState();
}

class DisponibilidadesGridState extends State<DisponibilidadesGrid> {
  // Contador para forçar rebuild quando alocações mudam drasticamente
  int _rebuildCounter = 0;
  List<String>? _lastAlocacoesHash;
  // Key única para forçar rebuild completo do GridView quando necessário
  Key? _gridUniqueKey;
  // Hash e contador das alocações para detectar mudanças drasticas
  int? _lastAlocacoesHashCode;
  int? _lastNumAlocacoes;

  @override
  void didUpdateWidget(DisponibilidadesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // #region agent log (COMENTADO - pode ser reativado se necessário)

//    try {
//      final logEntry = {
//        'timestamp': DateTime.now().millisecondsSinceEpoch,
//        'location': 'disponibilidades_grid.dart:didUpdateWidget',
//        'message': 'didUpdateWidget chamado',
//        'data': {
//          'alocacoesAntes': oldWidget.alocacoes?.length ?? 0,
//          'alocacoesDepois': widget.alocacoes?.length ?? 0,
//          'hypothesisId': 'P1'
//        },
//        'sessionId': 'debug-session',
//        'runId': 'run1',
//      };
//      writeLogToFile(jsonEncode(logEntry));
//    } catch (e) {}
    
// #endregion
    
    // CORREÇÃO: Detectar mudanças significativas nas alocações e forçar rebuild
    final currentHashList = widget.alocacoes?.map((a) => '${a.id}_${a.gabineteId}').toList();
    final numAlocacoesAtual = widget.alocacoes?.length ?? 0;
    final numAlocacoesAntigo = oldWidget.alocacoes?.length ?? 0;
    
    if (currentHashList != null) {
      currentHashList.sort();
      if (_lastAlocacoesHash != null) {
        final hashChanged = currentHashList.join('|') != _lastAlocacoesHash!.join('|');
        // CORREÇÃO CRÍTICA: Se o número de alocações diminuiu significativamente (desalocação de série),
        // forçar rebuild completo do GridView com UniqueKey
        final desalocacaoSignificativa = numAlocacoesAtual < numAlocacoesAntigo - 5;
        
        if (hashChanged || desalocacaoSignificativa) {
          // #region agent log (COMENTADO - pode ser reativado se necessário)

//          try {
//            final logEntry = {
//              'timestamp': DateTime.now().millisecondsSinceEpoch,
//              'location': 'disponibilidades_grid.dart:didUpdateWidget',
//              'message': 'Alocações mudaram - forçando rebuild',
//              'data': {
//                'alocacoesAntes': _lastAlocacoesHash!.length,
//                'alocacoesDepois': currentHashList.length,
//                'numAlocacoesAntigo': numAlocacoesAntigo,
//                'numAlocacoesAtual': numAlocacoesAtual,
//                'desalocacaoSignificativa': desalocacaoSignificativa,
//                'rebuildCounter': _rebuildCounter + 1,
//                'hypothesisId': 'P1'
//              },
//              'sessionId': 'debug-session',
//              'runId': 'run1',
//            };
//            writeLogToFile(jsonEncode(logEntry));
//          } catch (e) {}
          
// #endregion
          _rebuildCounter++;
          _lastAlocacoesHash = currentHashList;
          // CORREÇÃO CRÍTICA: Sempre criar nova UniqueKey quando há desalocação significativa
          // Isso força o Flutter a descartar completamente o GridView e criar um novo
          if (desalocacaoSignificativa || hashChanged) {
            _gridUniqueKey = UniqueKey();
            _lastAlocacoesHashCode = null; // Resetar para forçar recálculo no build()
            _lastNumAlocacoes = null;
          }
          // Forçar rebuild
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        _lastAlocacoesHash = currentHashList;
      }
    }
    
    // Atualizar contadores
    _lastNumAlocacoes = numAlocacoesAtual;
  }

  @override
  void initState() {
    super.initState();
    final initialHash = widget.alocacoes?.map((a) => '${a.id}_${a.gabineteId}').toList();
    if (initialHash != null) {
      initialHash.sort();
      _lastAlocacoesHash = initialHash;
    }
  }

  // Métodos auxiliares mantidos para compatibilidade (agora usam helpers)
  Future<void> _mostrarDialogoRemocaoSeries(
    BuildContext context,
    Disponibilidade disponibilidade,
  ) async {
    await AlocacaoCardHandlers.mostrarDialogoRemocao(
      context,
      disponibilidade,
      onRemoverData: widget.onRemoverData,
    );
  }

  Future<void> _selecionarHorario(
      BuildContext context, DateTime data, bool isInicio) async {
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
      final horario =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      setState(() {
        // Acha a disponibilidade do dia
        final disponibilidade = widget.disponibilidades.firstWhere(
          (d) => d.data == data,
          orElse: () => Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: 'Única',
          ),
        );

        // Se não encontrou uma real, não faz nada
        if (disponibilidade.data == DateTime(1900, 1, 1)) return;

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
              // Construir lista completa de horários ANTES de atualizar os cartões
              final horariosCompletos = <String>[];
              
              // Pegar horários atuais da disponibilidade
              if (isInicio) {
                // Editando horário de início
                horariosCompletos.add(horario);
                // Manter o horário de fim se existir, senão usar o mesmo
                if (disponibilidade.horarios.length >= 2) {
                  horariosCompletos.add(disponibilidade.horarios[1]);
                } else if (disponibilidade.horarios.length == 1) {
                  horariosCompletos.add(disponibilidade.horarios[0]); // Usar o mesmo temporariamente
                } else {
                  horariosCompletos.add(horario); // Se não tinha horários, usar o mesmo
                }
              } else {
                // Editando horário de fim
                // Manter o horário de início se existir
                if (disponibilidade.horarios.isNotEmpty) {
                  horariosCompletos.add(disponibilidade.horarios[0]);
                } else {
                  horariosCompletos.add(''); // Se não tinha início, deixar vazio
                }
                horariosCompletos.add(horario);
              }
              
              // CORREÇÃO: Extrair o ID da série da disponibilidade que está sendo editada
              // para atualizar apenas as disponibilidades da MESMA série específica
              final serieIdDaDisponibilidade = disponibilidade.id.startsWith('serie_')
                  ? SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id)
                  : null;

              // Atualizar todos os cartões locais da mesma série ESPECÍFICA
              setState(() {
                for (final disp in widget.disponibilidades) {
                  // Verificar se pertence à mesma série específica
                  bool pertenceMesmaSerie = false;
                  
                  if (serieIdDaDisponibilidade != null && disp.id.startsWith('serie_')) {
                    // Se ambas são séries, comparar os IDs das séries
                    final serieIdDaDisp = SeriesHelper.extrairSerieIdDeDisponibilidade(disp.id);
                    pertenceMesmaSerie = serieIdDaDisp == serieIdDaDisponibilidade;
                  } else if (serieIdDaDisponibilidade == null && !disp.id.startsWith('serie_')) {
                    // Se nenhuma é série (ambas são "Única"), verificar apenas o tipo
                    pertenceMesmaSerie = disp.tipo == disponibilidade.tipo;
                  }
                  
                  if (pertenceMesmaSerie) {
                    disp.horarios = List.from(horariosCompletos);
                  }
                }
              });
              
              // Notificar para atualizar a série no Firestore
              if (horariosCompletos.length >= 2 && widget.onAtualizarSerie != null) {
                widget.onAtualizarSerie!(disponibilidade, horariosCompletos);
              }
              
              // notificar alterações em série
              widget.onChanged?.call();
            }
          });
        }
      });

      // notificar alteração deste cartão
      widget.onChanged?.call();
    }
  }


  void _verDisponibilidade(Disponibilidade disponibilidade) {
    // CORREÇÃO: Validar horários ANTES de abrir o diálogo
    // Se é uma série, verificar se tem horários configurados
    if (disponibilidade.tipo != 'Única' && widget.series != null) {
      // Encontrar a série correspondente
      final serieEncontrada = DisponibilidadeDataGestaoService.encontrarSeriePorDisponibilidade(
        disponibilidade,
        widget.series!,
        disponibilidade.data,
      );
      
      // Se encontrou a série e não tem horários configurados, mostrar erro
      if (serieEncontrada != null && 
          serieEncontrada.id.isNotEmpty &&
          (serieEncontrada.horarios.isEmpty || serieEncontrada.horarios.length < 2)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Introduza as horas de inicio e fim primeiro!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return; // Não abrir o diálogo
      }
    }
    
    // Ao clicar no cartão, mostrar diálogo para selecionar/desalocar gabinete
    AlocacaoCardHandlers.mostrarDialogoSelecaoGabinete(
      context,
      disponibilidade,
      widget.gabinetes,
      widget.alocacoes,
      onGabineteChanged: (disp, novoGabineteId) {
        widget.onGabineteChanged?.call(disp, novoGabineteId);
      },
    );
  }

  /// Navega para a tela de alocação no dia correspondente ao cartão
  void _navegarParaMapa(BuildContext context, DateTime data) {
    AlocacaoCardActions.navegarParaMapa(
      context,
      data,
      widget.unidade,
      onVoltar: widget.onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log (COMENTADO - pode ser reativado se necessário)

//    try {
//      final logEntry = {
//        'timestamp': DateTime.now().millisecondsSinceEpoch,
//        'location': 'disponibilidades_grid.dart:build',
//        'message': 'DisponibilidadesGrid.build chamado',
//        'data': {
//          'totalAlocacoes': widget.alocacoes?.length ?? 0,
//          'totalDisponibilidades': widget.disponibilidades.length,
//          'rebuildCounter': _rebuildCounter,
//          'hypothesisId': 'P1'
//        },
//        'sessionId': 'debug-session',
//        'runId': 'run1',
//      };
//      writeLogToFile(jsonEncode(logEntry));
//    } catch (e) {}
    
// #endregion
    
    // CORREÇÃO CRÍTICA: Forçar rebuild completo quando as alocações mudam drasticamente
    // Calcular hash das alocações ANTES do LayoutBuilder para garantir detecção precisa
    final numAlocacoes = widget.alocacoes?.length ?? 0;
    final alocacoesParaHash = widget.alocacoes != null
        ? (widget.alocacoes!.map((a) => '${a.id}_${a.gabineteId}_${a.data.toString().substring(0, 10)}').toList()..sort())
        : <String>[];
    final alocacoesHashCode = alocacoesParaHash.join('|').hashCode;
    final alocacoesComGabinete = widget.alocacoes?.where((a) => a.gabineteId.isNotEmpty).length ?? 0;
    final alocacoesSemGabinete = (widget.alocacoes?.length ?? 0) - alocacoesComGabinete;
    
    // CORREÇÃO CRÍTICA: Se o hash das alocações mudou, sempre criar nova UniqueKey
    // Isso força o Flutter a descartar completamente o GridView e criar um novo
    if (_lastAlocacoesHashCode != null && _lastAlocacoesHashCode != alocacoesHashCode) {
      // Sempre criar nova UniqueKey quando o hash muda (indica mudança nas alocações)
      _gridUniqueKey = UniqueKey();
      _rebuildCounter++;
    }
    // Atualizar hash apenas se for diferente (para evitar criar UniqueKey desnecessariamente)
    if (_lastAlocacoesHashCode != alocacoesHashCode) {
      _lastAlocacoesHashCode = alocacoesHashCode;
      _lastNumAlocacoes = numAlocacoes;
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = (constraints.maxWidth / 200).floor();
        // Ordena por data para garantir ordem cronológica na grelha
        widget.disponibilidades.sort((a, b) => a.data.compareTo(b.data));
        // CORREÇÃO CRÍTICA: Usar UniqueKey quando disponível, senão usar ValueKey baseado em hash
        // Isso força rebuild completo do GridView quando as alocações mudam drasticamente
        final gridKey = _gridUniqueKey ?? ValueKey('grid_${widget.disponibilidades.length}_${numAlocacoes}_${alocacoesComGabinete}_${alocacoesSemGabinete}_$alocacoesHashCode$_rebuildCounter');
        return GridView.builder(
          key: gridKey,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1.65, // Ajustado para dar mais altura aos cartões e evitar overflow
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.disponibilidades.length,
          itemBuilder: (context, index) {
            final disponibilidade = widget.disponibilidades[index];
            // CORREÇÃO: Criar key baseada no gabineteId da alocação correspondente
            // para forçar reconstrução do cartão quando o gabinete muda ou é removido
            // Usar gabineteId diretamente da alocação em vez de nomeGabinete para garantir mudança
            String gabineteKey = 'sem_gabinete';
            final alocacoesDoDia = <Alocacao>[];
            if (widget.alocacoes != null && widget.alocacoes!.isNotEmpty) {
              alocacoesDoDia.addAll(widget.alocacoes!.where((a) {
                final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                final dDate = DateTime(disponibilidade.data.year, disponibilidade.data.month, disponibilidade.data.day);
                return a.medicoId == disponibilidade.medicoId && aDate == dDate;
              }));
              if (alocacoesDoDia.isNotEmpty) {
                final alocacaoParaDia = alocacoesDoDia.first;
                if (alocacaoParaDia.gabineteId.isNotEmpty) {
                  gabineteKey = alocacaoParaDia.gabineteId;
                }
              }
            }
            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'disponibilidades_grid.dart:itemBuilder',
//                'message': 'Construindo cartão',
//                'data': {
//                  'index': index,
//                  'disponibilidadeId': disponibilidade.id,
//                  'data': disponibilidade.data.toString().substring(0, 10),
//                  'gabineteKey': gabineteKey,
//                  'totalAlocacoes': widget.alocacoes?.length ?? 0,
//                  'alocacoesParaEsteDia': alocacoesDoDia.length,
//                  'hypothesisId': 'P1'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}
            
// #endregion
            // CORREÇÃO CRÍTICA: Incluir data na key para garantir que cada cartão tem uma key única
            // mesmo quando não há alocação (gabineteKey = 'sem_gabinete' para todos)
            // Isso força o Flutter a reconstruir todos os cartões quando as alocações mudam
            final dataKey = '${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}';
            return AlocacaoCard(
              key: ValueKey('card_${disponibilidade.id}_${dataKey}_$gabineteKey'),
              disponibilidade: disponibilidade,
              alocacoes: widget.alocacoes,
              gabinetes: widget.gabinetes,
              unidade: widget.unidade,
              onChanged: widget.onChanged,
              onTap: () => _verDisponibilidade(disponibilidade),
              onRemover: () => _mostrarDialogoRemocaoSeries(
                context,
                disponibilidade,
              ),
              onNavegarParaMapa: () => _navegarParaMapa(
                context,
                disponibilidade.data,
              ),
              onSelecionarHorarioInicio: () => _selecionarHorario(
                context,
                disponibilidade.data,
                true,
              ),
              onSelecionarHorarioFim: () => _selecionarHorario(
                context,
                disponibilidade.data,
                false,
              ),
            );
          },
        );
      },
    );
  }
}
