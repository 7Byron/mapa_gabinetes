import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import 'alocacao_card_actions.dart';
import 'series_helper.dart';

/// Handlers para ações dos cartões de alocação
/// Encapsula a lógica de diálogos e interações
class AlocacaoCardHandlers {
  /// Mostra diálogo para remover cartão (único ou série)
  static Future<void> mostrarDialogoRemocao(
    BuildContext context,
    Disponibilidade disponibilidade, {
    required Function(DateTime date, bool removeSerie) onRemoverData,
  }) async {
    final isSerie = disponibilidade.tipo != 'Única';

    if (isSerie) {
      if (!context.mounted) return;
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
        onRemoverData(disponibilidade.data, false);
      } else if (escolha == 'all') {
        onRemoverData(disponibilidade.data, true);
      }
    } else {
      if (!context.mounted) return;
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
        onRemoverData(disponibilidade.data, false);
      }
    }
  }

  /// Extrai número de um texto de piso (ex: "Piso 1" -> 1, "Piso 2" -> 2)
  static int? _extrairNumeroPiso(String setor) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(setor);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Extrai número de um nome de gabinete (ex: "103" -> 103, "209" -> 209)
  static int? _extrairNumeroGabinete(String nome) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(nome);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Mostra diálogo para selecionar/desalocar gabinete
  static Future<void> mostrarDialogoSelecaoGabinete(
    BuildContext context,
    Disponibilidade disponibilidade,
    List<Gabinete>? gabinetes,
    List<Alocacao>? alocacoes, {
    required Function(Disponibilidade disponibilidade, String? novoGabineteId)
        onGabineteChanged,
  }) async {
    if (gabinetes == null || gabinetes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há gabinetes disponíveis')),
      );
      return;
    }

    // Obter gabinete atual (se houver)
    final gabineteAtual = AlocacaoCardActions.getNomeGabineteParaDisponibilidade(
      disponibilidade,
      alocacoes,
      gabinetes,
    );
    final alocacaoAtual = AlocacaoCardActions.getAlocacaoParaDisponibilidade(
      disponibilidade,
      alocacoes,
    );

    // Agrupar gabinetes por setor (piso) e ordenar
    final Map<String, List<Gabinete>> gabinetesPorSetor = {};
    for (final gabinete in gabinetes) {
      final setor = gabinete.setor;
      if (!gabinetesPorSetor.containsKey(setor)) {
        gabinetesPorSetor[setor] = [];
      }
      gabinetesPorSetor[setor]!.add(gabinete);
    }

    // Ordenar os setores (piso) e os gabinetes dentro de cada setor
    final setoresOrdenados = gabinetesPorSetor.keys.toList()
      ..sort((a, b) {
        // Extrair números de "Piso X" para ordenação numérica
        final numA = _extrairNumeroPiso(a);
        final numB = _extrairNumeroPiso(b);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        // Se não conseguir extrair números, ordena alfabeticamente
        return a.compareTo(b);
      });

    // Ordenar gabinetes numericamente dentro de cada setor
    for (final setor in setoresOrdenados) {
      gabinetesPorSetor[setor]!.sort((a, b) {
        final numA = _extrairNumeroGabinete(a.nome);
        final numB = _extrairNumeroGabinete(b.nome);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        return a.nome.compareTo(b.nome);
      });
    }

    if (!context.mounted) return;
    final gabineteEscolhido = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecione um gabinete ou desaloque:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                // Opção de desalocar
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: const Text('Desalocar (Remover gabinete)'),
                  subtitle: gabineteAtual != null
                      ? Text('Atualmente: $gabineteAtual')
                      : const Text('Nenhum gabinete atribuído'),
                  onTap: () => Navigator.of(context).pop('DESALOCAR'),
                ),
                const Divider(),
                // Lista de gabinetes agrupados por setor (piso) com ExpansionTile
                ...setoresOrdenados.map((setor) {
                  final gabinetesDoSetor = gabinetesPorSetor[setor]!;
                  return ExpansionTile(
                    leading: const Icon(Icons.folder, color: Colors.blue),
                    title: Text(
                      setor,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text('${gabinetesDoSetor.length} gabinete(s)'),
                    children: gabinetesDoSetor.map((gabinete) {
                      final isSelecionado =
                          alocacaoAtual?.gabineteId == gabinete.id;
                      final nomeCompleto = gabinete.especialidadesPermitidas.isNotEmpty
                          ? '${gabinete.nome} (${gabinete.especialidadesPermitidas.join(', ')})'
                          : gabinete.nome;
                      return ListTile(
                        leading: Icon(
                          isSelecionado
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelecionado ? Colors.green : Colors.blue,
                        ),
                        title: Text(nomeCompleto),
                        trailing: isSelecionado
                            ? const Text('Atual',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold))
                            : null,
                        onTap: () => Navigator.of(context).pop(gabinete.id),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('CANCELAR'),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    // Se o usuário cancelou, não fazer nada - apenas fechar o diálogo
    if (gabineteEscolhido == 'CANCELAR') {
      return;
    }

    // Se um gabinete foi selecionado (ou 'DESALOCAR' para desalocar), notificar o callback
    if (gabineteEscolhido != null) {
      final novoGabineteId = gabineteEscolhido == 'DESALOCAR' ? null : gabineteEscolhido;
      // Só chamar se realmente mudou
      if (novoGabineteId != alocacaoAtual?.gabineteId) {
        onGabineteChanged(disponibilidade, novoGabineteId);
      }
    }
  }

  /// Seleciona horário (início ou fim) para uma disponibilidade
  static Future<void> selecionarHorario(
    BuildContext context,
    DateTime data,
    bool isInicio,
    Disponibilidade disponibilidade,
    List<Disponibilidade> todasDisponibilidades, {
    required Function(Disponibilidade, List<String>) onAtualizarSerie,
    required VoidCallback onChanged,
    required void Function(Disponibilidade) onAtualizarLocal,
  }) async {
    if (!context.mounted) return;
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

    if (time == null || !context.mounted) return;

    final horario =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // Acha a disponibilidade do dia
    final disponibilidadeEncontrada = todasDisponibilidades.firstWhere(
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
    if (disponibilidadeEncontrada.data == DateTime(1900, 1, 1)) return;

    // Ajusta horário
    if (isInicio) {
      if (disponibilidadeEncontrada.horarios.isEmpty) {
        disponibilidadeEncontrada.horarios = [horario];
      } else {
        disponibilidadeEncontrada.horarios[0] = horario;
      }
    } else {
      if (disponibilidadeEncontrada.horarios.length == 1) {
        disponibilidadeEncontrada.horarios.add(horario);
      } else if (disponibilidadeEncontrada.horarios.length == 2) {
        disponibilidadeEncontrada.horarios[1] = horario;
      } else if (disponibilidadeEncontrada.horarios.isEmpty) {
        disponibilidadeEncontrada.horarios =
            isInicio ? [horario] : ['', horario];
      }
    }

    // Atualizar localmente
    onAtualizarLocal(disponibilidadeEncontrada);

    // Se for série, pergunta se quer aplicar em todos
    if (disponibilidadeEncontrada.tipo != 'Única') {
      if (!context.mounted) return;
      final aplicarEmTodos = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Aplicar horário a toda a série?'),
            content: Text(
              'Deseja usar este horário de '
              '${isInicio ? 'início' : 'fim'} '
              'em todos os dias da série (${disponibilidadeEncontrada.tipo})?',
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

      if (aplicarEmTodos == true && context.mounted) {
        // Construir lista completa de horários ANTES de atualizar os cartões
        final horariosCompletos = <String>[];

        // Pegar horários atuais da disponibilidade
        if (isInicio) {
          // Editando horário de início
          horariosCompletos.add(horario);
          // Manter o horário de fim se existir, senão usar o mesmo
          if (disponibilidadeEncontrada.horarios.length >= 2) {
            horariosCompletos.add(disponibilidadeEncontrada.horarios[1]);
          } else if (disponibilidadeEncontrada.horarios.length == 1) {
            horariosCompletos
                .add(disponibilidadeEncontrada.horarios[0]); // Usar o mesmo temporariamente
          } else {
            horariosCompletos.add(horario); // Se não tinha horários, usar o mesmo
          }
        } else {
          // Editando horário de fim
          // Manter o horário de início se existir
          if (disponibilidadeEncontrada.horarios.isNotEmpty) {
            horariosCompletos.add(disponibilidadeEncontrada.horarios[0]);
          } else {
            horariosCompletos.add(''); // Se não tinha início, deixar vazio
          }
          horariosCompletos.add(horario);
        }

        // CORREÇÃO: Extrair o ID da série da disponibilidade que está sendo editada
        // para atualizar apenas as disponibilidades da MESMA série específica
        final serieIdDaDisponibilidade = disponibilidadeEncontrada.id.startsWith('serie_')
            ? SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidadeEncontrada.id)
            : null;

        // Atualizar todos os cartões locais da mesma série ESPECÍFICA
        for (final disp in todasDisponibilidades) {
          // Verificar se pertence à mesma série específica
          bool pertenceMesmaSerie = false;
          
          if (serieIdDaDisponibilidade != null && disp.id.startsWith('serie_')) {
            // Se ambas são séries, comparar os IDs das séries
            final serieIdDaDisp = SeriesHelper.extrairSerieIdDeDisponibilidade(disp.id);
            pertenceMesmaSerie = serieIdDaDisp == serieIdDaDisponibilidade;
          } else if (serieIdDaDisponibilidade == null && !disp.id.startsWith('serie_')) {
            // Se nenhuma é série (ambas são "Única"), verificar apenas o tipo
            pertenceMesmaSerie = disp.tipo == disponibilidadeEncontrada.tipo;
          }
          
          if (pertenceMesmaSerie) {
            disp.horarios = List.from(horariosCompletos);
            onAtualizarLocal(disp);
          }
        }

        // Notificar para atualizar a série no Firestore
        if (horariosCompletos.length >= 2) {
          onAtualizarSerie(disponibilidadeEncontrada, horariosCompletos);
        }

        // notificar alterações em série
        onChanged();
      }
    }

    // notificar alteração deste cartão
    onChanged();
  }
}
