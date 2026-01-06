import 'package:flutter/material.dart';

import '../models/gabinete.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/conflict_utils.dart';
import '../utils/app_theme.dart';
import '../services/serie_service.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import 'medico_card.dart';
import '../services/alocacao_unica_service.dart';
import '../services/realocacao_unico_service.dart';
import '../services/realocacao_serie_service.dart';
import '../utils/ui_alocar_cartao_serie.dart';

class GabinetesSection extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final VoidCallback onAtualizarEstado;
  final Future<void> Function(String medicoId) onDesalocarMedicoComPergunta;
  final bool isAdmin; // Novo parâmetro para controlar permissões
  final Set<String>
      medicosDestacados; // IDs dos médicos destacados pela pesquisa
  final Unidade? unidade; // Unidade para buscar disponibilidades do Firebase
  final Function(Medico)? onEditarMedico; // Callback para editar médico

  /// Função que aloca UM médico em UM gabinete em UM dia específico
  final Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico;

  /// Callback opcional para atualização otimista do estado durante realocação
  /// Permite atualizar a lista de alocações imediatamente antes das operações no Firestore
  final void Function(String medicoId, String gabineteOrigem,
      String gabineteDestino, DateTime data)? onRealocacaoOtimista;

  /// Callback opcional para limpar flags de transição após realocação concluída
  /// Isso garante que o listener seja reativado e a UI volte ao normal
  final VoidCallback? onRealocacaoConcluida;

  /// Callback opcional para atualização otimista durante alocação de série
  /// Permite remover médico dos disponíveis e criar alocação temporária imediatamente
  final void Function(String medicoId, String gabineteId, DateTime data)?
      onAlocacaoSerieOtimista;

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
    this.isAdmin = false, // Por defeito é utilizador normal
    this.medicosDestacados = const {}, // Por defeito nenhum médico destacado
    this.unidade, // Unidade opcional
    this.onRealocacaoOtimista, // Callback opcional para atualização otimista
    this.onRealocacaoConcluida, // Callback opcional para limpar flags após realocação
    this.onAlocacaoSerieOtimista, // Callback opcional para atualização otimista de alocação de série
    this.onEditarMedico, // Callback opcional para editar médico
  });

  @override
  State<GabinetesSection> createState() => _GabinetesSectionState();
}

class _GabinetesSectionState extends State<GabinetesSection> {
  // Variáveis para controlar o progresso da alocação de séries
  bool _isAlocandoSerie = false;
  double _progressoAlocacao = 0.0;
  String _mensagemAlocacao = 'A iniciar...';

  // Variáveis para controlar o progresso da realocação entre gabinetes
  bool _isRealocando = false;
  double _progressoRealocacao = 0.0;
  String _mensagemRealocacao = 'A iniciar...';
  String? _medicoIdEmRealocacao; // ID do médico que está sendo realocado
  String?
      _gabineteOrigemRealocacao; // ID do gabinete de origem durante realocação

  int _horarioParaMinutos(String horario) {
    final partes = horario.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Verifica se uma data corresponde a uma série específica
  bool _verificarSeDataCorrespondeSerie(
    DateTime data,
    SerieRecorrencia serie,
  ) {
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final dataInicioNormalizada = DateTime(
      serie.dataInicio.year,
      serie.dataInicio.month,
      serie.dataInicio.day,
    );

    // Verificar se a data está dentro do período da série
    if (dataNormalizada.isBefore(dataInicioNormalizada)) {
      return false;
    }
    if (serie.dataFim != null) {
      final dataFimNormalizada = DateTime(
        serie.dataFim!.year,
        serie.dataFim!.month,
        serie.dataFim!.day,
      );
      if (dataNormalizada.isAfter(dataFimNormalizada)) {
        return false;
      }
    }

    // Verificar padrão da série
    final tipoNormalizado =
        serie.tipo.startsWith('Consecutivo') ? 'Consecutivo' : serie.tipo;

    if (tipoNormalizado == 'Semanal') {
      final weekdayData = dataNormalizada.weekday;
      final weekdaySerie = dataInicioNormalizada.weekday;
      final diasDiferenca =
          dataNormalizada.difference(dataInicioNormalizada).inDays;
      return weekdayData == weekdaySerie && diasDiferenca % 7 == 0;
    } else if (tipoNormalizado == 'Quinzenal') {
      final weekdayData = dataNormalizada.weekday;
      final weekdaySerie = dataInicioNormalizada.weekday;
      final diasDiferenca =
          dataNormalizada.difference(dataInicioNormalizada).inDays;
      return weekdayData == weekdaySerie && diasDiferenca % 14 == 0;
    } else if (tipoNormalizado == 'Mensal') {
      final weekdayData = dataNormalizada.weekday;
      final weekdaySerie = dataInicioNormalizada.weekday;
      if (weekdayData == weekdaySerie) {
        final ocorrenciaData = _descobrirOcorrenciaNoMes(dataNormalizada);
        final ocorrenciaSerie =
            _descobrirOcorrenciaNoMes(dataInicioNormalizada);
        return ocorrenciaData == ocorrenciaSerie;
      }
      return false;
    } else if (tipoNormalizado == 'Consecutivo') {
      final diasDiferenca =
          dataNormalizada.difference(dataInicioNormalizada).inDays;
      final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
      return diasDiferenca >= 0 && diasDiferenca < numeroDias;
    }

    return false;
  }

  /// Encontra a série correspondente para um tipo e data específicos
  Future<SerieRecorrencia?> _encontrarSerieCorrespondente({
    required String medicoId,
    required String tipo,
    required DateTime data,
  }) async {
    try {
      final series = await SerieService.carregarSeries(
        medicoId,
        unidade: widget.unidade,
      );

      final tipoNormalizado =
          tipo.startsWith('Consecutivo') ? 'Consecutivo' : tipo;
      final dataNormalizada = DateTime(data.year, data.month, data.day);

      for (final serie in series) {
        if (!serie.ativo) {
          continue;
        }

        // Verificar se a data está dentro do período da série
        if (dataNormalizada.isBefore(serie.dataInicio)) {
          continue;
        }
        if (serie.dataFim != null && dataNormalizada.isAfter(serie.dataFim!)) {
          continue;
        }

        // Verificar padrão da série
        bool corresponde = false;
        if (tipoNormalizado == 'Semanal') {
          // CORREÇÃO: Para Semanal, verificar se é o mesmo dia da semana
          // E se a diferença é múltipla de 7 dias (não apenas múltipla de 7)
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          // Deve ser o mesmo dia da semana E diferença múltipla de 7
          corresponde = weekdayData == weekdaySerie && diasDiferenca % 7 == 0;
        } else if (tipoNormalizado == 'Quinzenal') {
          // CORREÇÃO: Para Quinzenal, verificar se é o mesmo dia da semana
          // E se a diferença é múltipla de 14 dias
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          // Deve ser o mesmo dia da semana E diferença múltipla de 14
          corresponde = weekdayData == weekdaySerie && diasDiferenca % 14 == 0;
        } else if (tipoNormalizado == 'Mensal') {
          // Para mensal, verificar se é o mesmo dia do mês E a mesma ocorrência (1ª, 2ª, 3ª, etc.)
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          if (weekdayData == weekdaySerie) {
            final ocorrenciaData = _descobrirOcorrenciaNoMes(dataNormalizada);
            final ocorrenciaSerie = _descobrirOcorrenciaNoMes(serie.dataInicio);
            corresponde = ocorrenciaData == ocorrenciaSerie;
          }
        } else if (tipoNormalizado == 'Consecutivo') {
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
          corresponde = diasDiferenca >= 0 && diasDiferenca < numeroDias;
        }

        if (corresponde) {
          return serie;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Realoca um médico de um gabinete para outro
  /// Se for série, pergunta se quer realocar toda a série ou apenas o dia
  Future<void> _realocarMedicoEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataAlvo,
  }) async {
    debugPrint(
        '🔵 [REALOCAÇÃO-MÉDICO] INÍCIO: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino');

    try {
      // CORREÇÃO CRÍTICA: Verificação RÁPIDA usando apenas dados locais para mostrar diálogo IMEDIATAMENTE

      // Verificação rápida: verificar se a alocação atual é de série (usando dados locais)
      final alocacaoAtual = widget.alocacoes.firstWhere(
        (a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == medicoId &&
              a.gabineteId == gabineteOrigem &&
              aDate.year == dataAlvo.year &&
              aDate.month == dataAlvo.month &&
              aDate.day == dataAlvo.day;
        },
        orElse: () => Alocacao(
          id: '',
          medicoId: '',
          gabineteId: '',
          data: DateTime(1900, 1, 1),
          horarioInicio: '',
          horarioFim: '',
        ),
      );

      // Verificação rápida: verificar tipo da disponibilidade (dados locais)
      final disponibilidade = widget.disponibilidades.firstWhere(
        (d) =>
            d.medicoId == medicoId &&
            d.data.year == dataAlvo.year &&
            d.data.month == dataAlvo.month &&
            d.data.day == dataAlvo.day,
        orElse: () => Disponibilidade(
          id: '',
          medicoId: '',
          data: DateTime(1900, 1, 1),
          horarios: [],
          tipo: 'Única',
        ),
      );

      final bool eSerie = alocacaoAtual.id.startsWith('serie_');
      String tipoSerie = disponibilidade.tipo;
      bool podeSerSerie = eSerie || (tipoSerie != 'Única' && tipoSerie != '');

      // CORREÇÃO CRÍTICA: Se não encontrou alocação em widget.alocacoes,
      // buscar série diretamente do Firestore para verificar se é série
      // Buscar mesmo se tipoSerie for 'Única', porque pode ser que a disponibilidade
      // não esteja em widget.disponibilidades quando o cartão está nos desalocados
      if (alocacaoAtual.id.isEmpty) {

        debugPrint(
            '⚠️ [REALOCAÇÃO-MÉDICO] Alocação não encontrada em widget.alocacoes, buscando série do Firestore...');
        try {
          // Tentar buscar série com o tipo da disponibilidade primeiro
          SerieRecorrencia? serieEncontrada;
          if (tipoSerie != 'Única' && tipoSerie.isNotEmpty) {
            serieEncontrada = await _encontrarSerieCorrespondente(
              medicoId: medicoId,
              tipo: tipoSerie,
              data: dataAlvo,
            );
          }

          // Se não encontrou com o tipo da disponibilidade, tentar todos os tipos possíveis
          if (serieEncontrada == null || serieEncontrada.id.isEmpty) {
            final tiposPossiveis = ['Semanal', 'Quinzenal', 'Mensal'];
            for (final tipo in tiposPossiveis) {
              serieEncontrada = await _encontrarSerieCorrespondente(
                medicoId: medicoId,
                tipo: tipo,
                data: dataAlvo,
              );
              if (serieEncontrada != null && serieEncontrada.id.isNotEmpty) {
                break;
              }
            }
          }

          if (serieEncontrada != null && serieEncontrada.id.isNotEmpty) {

            debugPrint(
                '✅ [REALOCAÇÃO-MÉDICO] Série encontrada no Firestore: ${serieEncontrada.id}, tipo: ${serieEncontrada.tipo}');
            podeSerSerie = true;
            tipoSerie = serieEncontrada.tipo;
          } else {

            debugPrint(
                '⚠️ [REALOCAÇÃO-MÉDICO] Série não encontrada no Firestore');
          }
        } catch (e) {
          debugPrint('❌ [REALOCAÇÃO-MÉDICO] Erro ao buscar série: $e');
        }
      }

      debugPrint(
          '🔵 [REALOCAÇÃO-MÉDICO] Verificação rápida: eSerie=$eSerie, tipoSerie=$tipoSerie, podeSerSerie=$podeSerSerie');

      // CORREÇÃO: Verificar se o cartão já foi desemparelhado da série (tem exceção)
      bool temExcecao = false;
      if (eSerie && alocacaoAtual.id.isNotEmpty) {
        // Extrair ID da série
        String? serieId;
        final partes = alocacaoAtual.id.split('_');
        if (partes.length >= 4 && partes[0] == 'serie' && partes[1] == 'serie') {
          serieId = 'serie_${partes[2]}';
        } else if (partes.length >= 3 && partes[0] == 'serie') {
          serieId = partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
        }
        
        if (serieId != null) {
          // Verificar se há exceção para esta data
          try {
            final excecoes = await SerieService.carregarExcecoes(
              medicoId,
              unidade: widget.unidade,
              dataInicio: dataAlvo,
              dataFim: dataAlvo,
              serieId: serieId,
              forcarServidor: false, // Usar cache para resposta rápida
            );
            
            final excecaoExistente = excecoes.firstWhere(
              (e) =>
                  e.serieId == serieId &&
                  e.data.year == dataAlvo.year &&
                  e.data.month == dataAlvo.month &&
                  e.data.day == dataAlvo.day &&
                  !e.cancelada,
              orElse: () => ExcecaoSerie(
                id: '',
                serieId: '',
                data: DateTime(1900, 1, 1),
              ),
            );
            
            temExcecao = excecaoExistente.id.isNotEmpty;
          } catch (e) {
            debugPrint('⚠️ Erro ao verificar exceção: $e');
          }
        }
      }

      // MOSTRAR DIÁLOGO IMEDIATAMENTE se pode ser série
      if (podeSerSerie && tipoSerie != 'Única') {

        final escolha = await showDialog<String>(
          context: context,
          builder: (ctxDialog) {
            return AlertDialog(
              title: Text(temExcecao ? 'Realocar cartão?' : 'Realocar série?'),
              content: Text(
                temExcecao
                    ? 'Este cartão da série já foi alocado desemparelhado da série.\n\n'
                        'Deseja realocar apenas este cartão para o novo gabinete?'
                    : 'Esta alocação faz parte de uma série "$tipoSerie".\n\n'
                        'Deseja realocar apenas este dia (${dataAlvo.day}/${dataAlvo.month}) '
                        'ou toda a série a partir deste dia para o novo gabinete?',
              ),
              actions: [
                if (!temExcecao) ...[
                  TextButton(
                    onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
                    child: const Text('Apenas este dia'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctxDialog).pop('serie'),
                    child: const Text('Toda a série'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
                    child: const Text('Sim, realocar cartão'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(ctxDialog).pop(null),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );

        if (escolha == null) {
          // CORREÇÃO: Resetar progressbar se usuário cancelou
          if (mounted) {
            setState(() {
              _isRealocando = false;
              _progressoRealocacao = 0.0;
              _mensagemRealocacao = 'A iniciar...';
              _medicoIdEmRealocacao = null;
              _gabineteOrigemRealocacao = null;
            });
          }
          return; // Usuário cancelou
        }

        if (escolha == 'serie') {

          // CORREÇÃO: Atualização otimista PRIMEIRO - mover cartão visualmente
          debugPrint(
              '🟢 [REALOCAÇÃO-MÉDICO] Escolha: Toda a série - chamando atualização otimista PRIMEIRO');
          if (widget.onRealocacaoOtimista != null) {
            widget.onRealocacaoOtimista!(
                medicoId, gabineteOrigem, gabineteDestino, dataAlvo);
            await Future.delayed(const Duration(milliseconds: 50));
          }

          // DEPOIS iniciar progress bar (cartão já está visível no destino)
          if (mounted) {
            setState(() {
              _isRealocando = true;
              _progressoRealocacao = 0.0;
              _mensagemRealocacao = 'A iniciar realocação...';
              _medicoIdEmRealocacao = medicoId;
              _gabineteOrigemRealocacao = gabineteOrigem;
            });
          }

          // Realocar toda a série usando o serviço
          try {
            final sucesso = await RealocacaoSerieService.realocar(
              medicoId: medicoId,
              gabineteOrigem: gabineteOrigem,
              gabineteDestino: gabineteDestino,
              dataRef: dataAlvo,
              tipoSerie: tipoSerie,
              alocacoes: widget.alocacoes,
              unidade: widget.unidade,
              context: context,
              onRealocacaoOtimista: widget.onRealocacaoOtimista,
              onAtualizarEstado: widget.onAtualizarEstado,
              onProgresso: (progresso, mensagem) {
                if (mounted) {
                  setState(() {
                    _progressoRealocacao = progresso;
                    _mensagemRealocacao = mensagem;
                  });
                }
              },
              onRealocacaoConcluida: widget.onRealocacaoConcluida,
              verificarSeDataCorrespondeSerie: _verificarSeDataCorrespondeSerie,
            );

            if (!sucesso) {
              throw Exception('Falha ao realocar série');
            }
          } catch (e, stackTrace) {
            debugPrint('❌ [REALOCAÇÃO-MÉDICO] Erro ao realocar série: $e');
            debugPrint('Stack trace: $stackTrace');
            rethrow;
          }
          return; // CRÍTICO: Retornar aqui para não executar _realocarDiaUnicoEntreGabinetes
        }

        // Se escolheu "Apenas este dia", continuar para _realocarDiaUnicoEntreGabinetes
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] Escolha: Apenas este dia - continuando para realocação de dia único');

        // CORREÇÃO: Atualização otimista PRIMEIRO mesmo para "Apenas este dia"
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] Chamando atualização otimista PRIMEIRO para "Apenas este dia"');
        if (widget.onRealocacaoOtimista != null) {
          widget.onRealocacaoOtimista!(
              medicoId, gabineteOrigem, gabineteDestino, dataAlvo);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Se não é série OU usuário escolheu "Apenas este dia", fazer realocação de dia único
      // CORREÇÃO: Atualização otimista PRIMEIRO, depois progress bar
      // (só chamar se não foi chamada acima)
      if (!podeSerSerie || tipoSerie == 'Única') {
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] Não é série - chamando atualização otimista PRIMEIRO');
        if (widget.onRealocacaoOtimista != null) {
          widget.onRealocacaoOtimista!(
              medicoId, gabineteOrigem, gabineteDestino, dataAlvo);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // CORREÇÃO: Não mostrar progress bar para realocações únicas
      // A atualização otimista já move o cartão rapidamente, então o progress bar é desnecessário

      // Usar serviço de realocação único
      final sucesso = await RealocacaoUnicoService.realocar(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: gabineteDestino,
        data: dataAlvo,
        alocacoes: widget.alocacoes,
        unidade: widget.unidade,
        context: context,
        onRealocacaoOtimista: widget.onRealocacaoOtimista,
        onAlocarMedico: widget.onAlocarMedico,
        onAtualizarEstado: widget.onAtualizarEstado,
        onProgresso: (progresso, mensagem) {
          // Progress bar removido - não fazer nada
        },
      );

      if (!sucesso) {
        throw Exception('Falha ao realocar médico');
      }
    } catch (e) {
      debugPrint('❌ [REALOCAÇÃO-MÉDICO] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // CORREÇÃO CRÍTICA: SEMPRE limpar flags no finally para evitar bloqueios
      debugPrint('🔴 [REALOCAÇÃO-MÉDICO] FINALLY: Limpando flags');
      if (mounted) {
        setState(() {
          _isRealocando = false;
          _progressoRealocacao = 0.0;
          _mensagemRealocacao = 'A iniciar...';
          _medicoIdEmRealocacao = null;
          _gabineteOrigemRealocacao = null;
        });
      }

      // CORREÇÃO CRÍTICA: Limpar flags de transição após realocação concluída
      if (widget.onRealocacaoConcluida != null) {
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] FINALLY: Chamando onRealocacaoConcluida para limpar flags de transição');
        widget.onRealocacaoConcluida!();
      }
    }
  }

  bool _validarDisponibilidade(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) return false;

    for (final horario in disponibilidade.horarios) {
      if (horario.isEmpty || !horario.contains(':')) return false;

      final partes = horario.split(':');
      if (partes.length != 2) return false;

      try {
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);

        if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) return false;
      } catch (e) {
        return false;
      }
    }

    return true;
  }

  /// Extrai o número do nome do gabinete para ordenação
  /// Exemplos: "Gabinete 101" -> 101, "103" -> 103, "Sala A" -> null
  int? _extrairNumeroGabinete(String nome) {
    // Procura por sequências de dígitos no nome
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(nome);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '');
    }
    return null;
  }

  /// Ordena gabinetes por número (se disponível) ou alfabeticamente
  void _ordenarGabinetesPorNumero(List<Gabinete> gabinetes) {
    gabinetes.sort((a, b) {
      final numA = _extrairNumeroGabinete(a.nome);
      final numB = _extrairNumeroGabinete(b.nome);

      // Se ambos têm números, ordena numericamente
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }

      // Se apenas um tem número, ele vem primeiro
      if (numA != null) return -1;
      if (numB != null) return 1;

      // Se nenhum tem número, ordena alfabeticamente
      return a.nome.compareTo(b.nome);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa gabinetes por setor
    final gabinetesPorSetor = <String, List<Gabinete>>{};
    for (var g in widget.gabinetes) {
      gabinetesPorSetor[g.setor] ??= [];
      gabinetesPorSetor[g.setor]!.add(g);
    }

    // Ordena gabinetes dentro de cada setor por número
    gabinetesPorSetor.forEach((setor, lista) {
      _ordenarGabinetesPorNumero(lista);
    });

    return Stack(
      children: [
        ListView.builder(
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
                  padding: const EdgeInsets.only(
                      top: 20, bottom: 12, left: 8, right: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: MyAppTheme.azulEscuro,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        setor,
                        style: MyAppTheme.heading2.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: MyAppTheme.azulEscuro,
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid de Gabinetes
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: listaGabinetes.length,
                    itemBuilder: (ctx, idx) {
                      final gabinete = listaGabinetes[idx];
                      // Alocações deste gabinete no dia selecionado
                      final alocacoesDoGab = widget.alocacoes.where((a) {
                        // Filtrar apenas alocações do dia selecionado
                        if (a.gabineteId != gabinete.id ||
                            a.data.year != widget.selectedDate.year ||
                            a.data.month != widget.selectedDate.month ||
                            a.data.day != widget.selectedDate.day) {
                          return false;
                        }

                        // FILTRAR: Não mostrar alocações de médicos inativos
                        final medico = widget.medicos.firstWhere(
                          (m) => m.id == a.medicoId,
                          orElse: () => Medico(
                            id: a.medicoId,
                            nome: 'Desconhecido',
                            especialidade: '',
                            disponibilidades: [],
                            ativo: false,
                          ),
                        );

                        return medico.ativo;
                      }).toList();

                      // CORREÇÃO: Remover alocações otimistas quando há alocações reais correspondentes
                      // Isso previne conflitos falsos causados por alocações otimistas duplicadas
                      final alocacoesFiltradas = <Alocacao>[];
                      for (final aloc in alocacoesDoGab) {
                        if (aloc.id.startsWith('otimista_serie_')) {
                          // Verificar se há uma alocação real correspondente (mesmo médico, gabinete, dia)
                          final temAlocacaoReal = alocacoesDoGab.any((a) {
                            return a != aloc && // Não comparar com ela mesma
                                !a.id.startsWith('otimista_') &&
                                a.medicoId == aloc.medicoId &&
                                a.gabineteId == aloc.gabineteId &&
                                a.data.year == aloc.data.year &&
                                a.data.month == aloc.data.month &&
                                a.data.day == aloc.data.day;
                          });
                          // Se há alocação real, ignorar a otimista (não adicionar à lista)
                          if (temAlocacaoReal) {
                            continue;
                          }
                        }
                        alocacoesFiltradas.add(aloc);
                      }

                      final temConflito =
                          ConflictUtils.temConflitoGabinete(alocacoesFiltradas);

                      Color corFundo;
                      Color corBorda;
                      // Usar lista filtrada (sem otimistas duplicadas) para determinar cor
                      if (alocacoesFiltradas.isEmpty) {
                        corFundo = MyAppTheme.gabineteLivre;
                        corBorda = MyAppTheme.bordaGabineteLivre;
                      } else if (temConflito) {
                        corFundo = MyAppTheme.gabineteConflito;
                        corBorda = MyAppTheme.bordaGabineteConflito;
                      } else {
                        corFundo = MyAppTheme.gabineteOcupado;
                        corBorda = MyAppTheme.bordaGabineteOcupado;
                      }

                      return DragTarget<String>(
                        onWillAcceptWithDetails: (details) {
                          // Verificar se o usuário é administrador
                          if (!widget.isAdmin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Apenas administradores podem fazer alterações nas alocações.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return false;
                          }

                          final medicoId = details.data;
                          // 1) Ache o médico
                          final medico = widget.medicos.firstWhere(
                            (m) => m.id == medicoId,
                            orElse: () => Medico(
                              id: '',
                              nome: '',
                              especialidade: '',
                              disponibilidades: [],
                              ativo: false,
                            ),
                          );
                          if (medico.id.isEmpty) return false;

                          // 2) Verificar se o médico já está alocado em outro gabinete
                          final dataAlvo = DateTime(
                            widget.selectedDate.year,
                            widget.selectedDate.month,
                            widget.selectedDate.day,
                          );
                          final estaAlocadoEmOutroGabinete =
                              widget.alocacoes.any((a) {
                            final aDate =
                                DateTime(a.data.year, a.data.month, a.data.day);
                            return a.medicoId == medicoId &&
                                a.gabineteId != gabinete.id &&
                                aDate == dataAlvo;
                          });

                          // Se já está alocado em outro gabinete, não precisa validar disponibilidade
                          // (o cartão já está funcionando, apenas está sendo movido)
                          if (estaAlocadoEmOutroGabinete) {
                            return true;
                          }

                          // 3) Se não está alocado, verificar disponibilidade (vem da área de não alocados)
                          // CORREÇÃO: Para séries, a disponibilidade pode não estar na lista local
                          // porque é gerada dinamicamente. Verificar se é série primeiro.
                          final disponibilidade =
                              widget.disponibilidades.firstWhere(
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
                          
                          // CORREÇÃO: Se não encontrou disponibilidade local, pode ser série
                          // Para séries, a disponibilidade é gerada dinamicamente e pode não estar na lista local
                          // Permitir mesmo sem disponibilidade local - será validada no onAccept
                          if (disponibilidade.medicoId.isEmpty) {
                            // Permitir - pode ser série ou disponibilidade será gerada
                            // A validação completa será feita no onAccept
                            return true;
                          }

                          // 4) Verifica se horários são válidos (apenas para novos cartões)
                          // CORREÇÃO: Para séries, permitir mesmo se horários não estão configurados ainda
                          // (eles podem ser configurados depois)
                          final eTipoSerie = disponibilidade.tipo ==
                                  'Semanal' ||
                              disponibilidade.tipo == 'Quinzenal' ||
                              disponibilidade.tipo == 'Mensal' ||
                              disponibilidade.tipo.startsWith('Consecutivo');

                          if (!eTipoSerie &&
                              !_validarDisponibilidade(disponibilidade)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cartão de disponibilidade mal configurado. Configure corretamente.',
                                ),
                              ),
                            );
                            return false;
                          }

                          // Para séries, verificar se tem pelo menos algum horário ou permitir sem horários

                          return true;
                        },
                        onAcceptWithDetails: (details) async {
                          final medicoId = details.data;
                          debugPrint(
                              '🟢 [DRAG-ACCEPT] Cartão solto: médico=$medicoId, gabinete=${gabinete.id}');

                          // Verificar se o médico já está alocado neste gabinete
                          final dataAlvo = DateTime(
                            widget.selectedDate.year,
                            widget.selectedDate.month,
                            widget.selectedDate.day,
                          );
                          debugPrint('🟢 [DRAG-ACCEPT] Data alvo: $dataAlvo');

                          // 1) Localiza disponibilidade para verificar o tipo
                          final disponibilidade =
                              widget.disponibilidades.firstWhere(
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
                                  content: Text(
                                      'Disponibilidade inválida para o médico.')),
                            );
                            return;
                          }

                          final tipoDisponibilidade = disponibilidade.tipo;
                          final eTipoSerie = tipoDisponibilidade == 'Semanal' ||
                              tipoDisponibilidade == 'Quinzenal' ||
                              tipoDisponibilidade == 'Mensal' ||
                              tipoDisponibilidade.startsWith('Consecutivo');

                          // CORREÇÃO: Se a disponibilidade foi gerada de uma série (ID começa com "serie_"),
                          // extrair o ID da série diretamente do ID da disponibilidade
                          // Formato: "serie_${serieId}_${dataKey}"
                          String? serieIdExtraido;
                          if (disponibilidade.id.startsWith('serie_')) {
                            final partes = disponibilidade.id.split('_');
                            if (partes.length >= 2) {
                              serieIdExtraido = partes[1];
                            }
                          }

                          // CORREÇÃO: Para séries, verificar se a série já está alocada no gabinete
                          // Para únicas, verificar apenas o dia
                          bool jaEstaAlocadoNoMesmoGabinete = false;

                          if (eTipoSerie) {
                            // Para séries: verificar se a série está alocada no gabinete
                            final serieEncontrada =
                                await _encontrarSerieCorrespondente(
                              medicoId: medicoId,
                              tipo: tipoDisponibilidade,
                              data: dataAlvo,
                            );

                            if (serieEncontrada != null) {
                              jaEstaAlocadoNoMesmoGabinete =
                                  serieEncontrada.gabineteId == gabinete.id;
                            } else {
                              // Se não encontrou série, verificar apenas o dia (fallback)
                              jaEstaAlocadoNoMesmoGabinete =
                                  widget.alocacoes.any((a) {
                                final aDate = DateTime(
                                    a.data.year, a.data.month, a.data.day);
                                return a.medicoId == medicoId &&
                                    a.gabineteId == gabinete.id &&
                                    aDate == dataAlvo;
                              });
                            }
                          } else {
                            // Para únicas: verificar apenas o dia
                            jaEstaAlocadoNoMesmoGabinete =
                                widget.alocacoes.any((a) {
                              final aDate = DateTime(
                                  a.data.year, a.data.month, a.data.day);
                              return a.medicoId == medicoId &&
                                  a.gabineteId == gabinete.id &&
                                  aDate == dataAlvo;
                            });
                          }
                          // Se já está alocado no mesmo gabinete, desalocar (com pergunta)
                          if (jaEstaAlocadoNoMesmoGabinete) {
                            await widget.onDesalocarMedicoComPergunta(medicoId);
                            return;
                          }

                          // Verificar se o médico está alocado em OUTRO gabinete no dia selecionado
                          debugPrint(
                              '🟢 [DRAG-ACCEPT] Verificando se está alocado em outro gabinete...');

                          // CORREÇÃO CRÍTICA: Para séries, também verificar diretamente no Firestore
                          // porque a alocação pode não estar em widget.alocacoes se ainda não foi regenerada
                          Alocacao alocacaoEmOutroGabinete = Alocacao(
                            id: '',
                            medicoId: '',
                            gabineteId: '',
                            data: DateTime(1900, 1, 1),
                            horarioInicio: '',
                            horarioFim: '',
                          );

                          if (eTipoSerie) {
                            // Para séries, buscar diretamente do Firestore
                            final serieEncontrada =
                                await _encontrarSerieCorrespondente(
                              medicoId: medicoId,
                              tipo: tipoDisponibilidade,
                              data: dataAlvo,
                            );

                            // Se a série foi encontrada mas não tem gabineteId, buscar na exceção
                            String? gabineteIdSerie =
                                serieEncontrada?.gabineteId;
                            if (serieEncontrada != null &&
                                gabineteIdSerie == null) {
                              // Buscar exceção para obter o gabineteId
                              final dataNormalizada = DateTime(
                                  dataAlvo.year, dataAlvo.month, dataAlvo.day);
                              final excecoes =
                                  await SerieService.carregarExcecoes(
                                medicoId,
                                unidade: widget.unidade,
                                dataInicio: dataNormalizada,
                                dataFim: dataNormalizada,
                                serieId: serieEncontrada.id,
                                forcarServidor:
                                    true, // Forçar servidor para garantir dados atualizados
                              );

                              final excecaoParaData = excecoes.firstWhere(
                                (e) =>
                                    e.serieId == serieEncontrada.id &&
                                    e.data.year == dataNormalizada.year &&
                                    e.data.month == dataNormalizada.month &&
                                    e.data.day == dataNormalizada.day &&
                                    !e.cancelada,
                                orElse: () => ExcecaoSerie(
                                  id: '',
                                  serieId: '',
                                  data: DateTime(1900, 1, 1),
                                ),
                              );

                              if (excecaoParaData.id.isNotEmpty &&
                                  excecaoParaData.gabineteId != null) {
                                gabineteIdSerie = excecaoParaData.gabineteId;
                              }
                            }

                            if (serieEncontrada != null &&
                                gabineteIdSerie != null &&
                                gabineteIdSerie.isNotEmpty &&
                                gabineteIdSerie != gabinete.id) {
                              // Criar alocação fictícia para representar a série encontrada
                              alocacaoEmOutroGabinete = Alocacao(
                                id: 'serie_${serieEncontrada.id}_${dataAlvo.year}-${dataAlvo.month}-${dataAlvo.day}',
                                medicoId: medicoId,
                                gabineteId: gabineteIdSerie,
                                data: dataAlvo,
                                horarioInicio:
                                    serieEncontrada.horarios.isNotEmpty
                                        ? serieEncontrada.horarios.first
                                            .split('-')
                                            .first
                                        : '08:00',
                                horarioFim: serieEncontrada.horarios.isNotEmpty
                                    ? serieEncontrada.horarios.first
                                        .split('-')
                                        .last
                                    : '20:00',
                              );
                              debugPrint(
                                  '🟢 [DRAG-ACCEPT] Série encontrada em outro gabinete via Firestore: id=${serieEncontrada.id}, gabinete=$gabineteIdSerie');
                            } else {
                            }
                          }

                          // Se não encontrou via série, verificar em widget.alocacoes
                          if (alocacaoEmOutroGabinete.id.isEmpty) {
                            alocacaoEmOutroGabinete =
                                widget.alocacoes.firstWhere(
                              (a) {
                                final aDate = DateTime(
                                    a.data.year, a.data.month, a.data.day);
                                final match = a.medicoId == medicoId &&
                                    a.gabineteId != gabinete.id &&
                                    aDate.year == dataAlvo.year &&
                                    aDate.month == dataAlvo.month &&
                                    aDate.day == dataAlvo.day;
                                if (match) {
                                  debugPrint(
                                      '🟢 [DRAG-ACCEPT] Alocação encontrada em outro gabinete: id=${a.id}, gabinete=${a.gabineteId}');
                                }
                                return match;
                              },
                              orElse: () {
                                debugPrint(
                                    '🟢 [DRAG-ACCEPT] Nenhuma alocação encontrada em outro gabinete');
                                return Alocacao(
                                  id: '',
                                  medicoId: '',
                                  gabineteId: '',
                                  data: DateTime(1900, 1, 1),
                                  horarioInicio: '',
                                  horarioFim: '',
                                );
                              },
                            );
                          }

                          // Se está alocado em outro gabinete, perguntar se quer realocar
                          if (alocacaoEmOutroGabinete.id.isNotEmpty) {
                            debugPrint(
                                '🟢 [DRAG-ACCEPT] Chamando _realocarMedicoEntreGabinetes: origem=${alocacaoEmOutroGabinete.gabineteId}, destino=${gabinete.id}');

                            await _realocarMedicoEntreGabinetes(
                              medicoId: medicoId,
                              gabineteOrigem:
                                  alocacaoEmOutroGabinete.gabineteId,
                              gabineteDestino: gabinete.id,
                              dataAlvo: dataAlvo,
                            );
                            debugPrint(
                                '✅ [DRAG-ACCEPT] _realocarMedicoEntreGabinetes concluído');

                            return;
                          }

                          debugPrint(
                              '🟢 [DRAG-ACCEPT] Não está alocado em outro gabinete - prosseguindo com alocação normal');

                          // tipoDisponibilidade já foi definido acima

                          if (tipoDisponibilidade == 'Única') {
                            // Usar serviço de alocação única
                            await AlocacaoUnicaService.alocar(
                              medicoId: medicoId,
                              gabineteId: gabinete.id,
                              data: widget.selectedDate,
                              disponibilidade: disponibilidade,
                              onAlocarMedico: widget.onAlocarMedico,
                              context: context,
                              unidade: widget.unidade,
                            );
                            // onAlocarMedico já chama onAlocacoesChanged() internamente
                          } else {
                            // Usar função reutilizável para alocar cartão de série
                            // Iniciar progresso de alocação (será usado se escolher "serie")
                            if (mounted) {
                              setState(() {
                                _isAlocandoSerie = true;
                                _progressoAlocacao = 0.0;
                                _mensagemAlocacao = 'A iniciar...';
                              });
                            }

                            await alocarCartaoSerie(
                              context: context,
                              medicoId: medicoId,
                              gabineteId: gabinete.id,
                              data: widget.selectedDate,
                              disponibilidade: disponibilidade,
                              tipoDisponibilidade: tipoDisponibilidade,
                              onAlocarMedico: widget.onAlocarMedico,
                              onAtualizarEstado: widget.onAtualizarEstado,
                              onAlocacaoSerieOtimista:
                                  widget.onAlocacaoSerieOtimista,
                              onProgresso: (progresso, mensagem) {
                                if (mounted) {
                                  setState(() {
                                    _progressoAlocacao = progresso;
                                    _mensagemAlocacao = mensagem;
                                  });
                                }
                              },
                              unidade: widget.unidade,
                              serieIdExtraido: serieIdExtraido,
                            );

                            // Ocultar progresso
                            if (mounted) {
                              setState(() {
                                _isAlocandoSerie = false;
                                _progressoAlocacao = 0.0;
                                _mensagemAlocacao = 'A iniciar...';
                              });
                            }
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          final dataSelecionada = DateTime(
                              widget.selectedDate.year,
                              widget.selectedDate.month,
                              widget.selectedDate.day);

                          // Esses logs estavam causando milhares de escritas desnecessárias

                          final alocacoesDoGabinete = widget.alocacoes
                              .where((a) {
                            final aData =
                                DateTime(a.data.year, a.data.month, a.data.day);
                            final corresponde = a.gabineteId == gabinete.id &&
                                aData == dataSelecionada;
                            return corresponde;
                          }).toList()
                            ..sort((a, b) =>
                                _horarioParaMinutos(a.horarioInicio).compareTo(
                                    _horarioParaMinutos(b.horarioInicio)));

                          // CORREÇÃO CRÍTICA: Remover duplicados baseados em (medicoId, gabineteId, data)
                          // Isso previne que alocações duplicadas sejam renderizadas
                          final alocacoesUnicas = <String, Alocacao>{};
                          for (final aloc in alocacoesDoGabinete) {
                            final chave =
                                '${aloc.medicoId}_${aloc.gabineteId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
                            if (!alocacoesUnicas.containsKey(chave)) {
                              alocacoesUnicas[chave] = aloc;
                            } else {
                              // Se já existe, manter a que tem ID real (não otimista) se possível
                              final existente = alocacoesUnicas[chave]!;
                              // CORREÇÃO: Priorizar sempre alocações reais sobre otimistas
                              if (aloc.id.startsWith('otimista_serie_') &&
                                  !existente.id.startsWith('otimista_')) {
                                // Nova é otimista e existente é real - manter a existente (real)
                                continue; // Não adicionar a otimista
                              } else if (!aloc.id.startsWith('otimista_') &&
                                  existente.id.startsWith('otimista_serie_')) {
                                // Nova é real e existente é otimista - substituir pela real
                                alocacoesUnicas[chave] = aloc;
                              } else if (aloc.id.startsWith('otimista_') &&
                                  existente.id.startsWith('otimista_')) {
                                // Ambas são otimistas - manter a primeira (evitar duplicação de otimistas)
                                continue;
                              } else {
                                // Ambas são reais ou situação não prevista - manter a primeira
                                // (ou a que tem ID mais recente se necessário)
                                continue;
                              }
                            }
                          }
                          final alocacoesDoGabineteUnicas = alocacoesUnicas
                              .values
                              .toList()
                            ..sort((a, b) =>
                                _horarioParaMinutos(a.horarioInicio).compareTo(
                                    _horarioParaMinutos(b.horarioInicio)));

                          // Esses logs estavam causando milhares de escritas desnecessárias

                          // Verificar se há conflito neste gabinete
                          final temConflitoGabinete =
                              ConflictUtils.temConflitoGabinete(
                                  alocacoesDoGabineteUnicas);

                          // Efeito hover: verificar se há um cartão sendo arrastado sobre este gabinete
                          final isHovering = candidateData.isNotEmpty;
                          
                          // Aplicar cores e estilos de hover quando há um cartão sendo arrastado
                          final corBordaHover = isHovering 
                              ? MyAppTheme.azulEscuro 
                              : corBorda;
                          final larguraBordaHover = isHovering ? 3.0 : 2.0;
                          final corFundoHover = isHovering
                              ? (corFundo == MyAppTheme.gabineteLivre
                                  ? MyAppTheme.azulClaro.withOpacity(0.3)
                                  : corFundo.withOpacity(0.9))
                              : corFundo;
                          final sombraHover = isHovering
                              ? MyAppTheme.shadowCardHover
                              : MyAppTheme.shadowCard3D;

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: corBordaHover,
                                    width: larguraBordaHover,
                                  ),
                                ),
                                color: corFundoHover,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: corFundoHover,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: sombraHover,
                                  ),
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Nome do gabinete e especialidade na mesma linha com ícone de status
                                      Row(
                                        children: [
                                          // Ícone de status (ocupado/livre/conflito)
                                          Icon(
                                            alocacoesDoGabineteUnicas.isEmpty
                                                ? Icons.check_circle_outline
                                                : Icons.check_circle,
                                            size: 14,
                                            color: temConflitoGabinete
                                                ? Colors.red.shade300
                                                : alocacoesDoGabineteUnicas
                                                        .isEmpty
                                                    ? Colors.grey[400]
                                                    : MyAppTheme.azulEscuro,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${gabinete.nome} ${gabinete.especialidadesPermitidas.join(", ")}',
                                              style: MyAppTheme.bodyMedium
                                                  .copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: temConflitoGabinete
                                                    ? Colors.red.shade700
                                                    : alocacoesDoGabineteUnicas
                                                            .isEmpty
                                                        ? Colors.grey[700]
                                                        : MyAppTheme.azulEscuro,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Lista de médicos alocados
                                      // FILTRAR: Não mostrar alocações de médicos "Desconhecido" ou médicos não encontrados
                                      // CORREÇÃO: Ocultar médico que está sendo realocado da origem
                                      if (alocacoesDoGabineteUnicas.isNotEmpty)
                                        ...alocacoesDoGabineteUnicas.where((a) {
                                          // CORREÇÃO: Se o médico está sendo realocado, ocultar da origem
                                          if (_isRealocando &&
                                              _medicoIdEmRealocacao ==
                                                  a.medicoId &&
                                              _gabineteOrigemRealocacao ==
                                                  gabinete.id) {
                                            // Este é o gabinete de origem e o médico está sendo realocado
                                            // Ocultar o cartão da origem durante a realocação
                                            return false;
                                          }

                                          // Verificar se o médico existe e está ativo
                                          final medico =
                                              widget.medicos.firstWhere(
                                            (m) => m.id == a.medicoId,
                                            orElse: () => Medico(
                                              id: '',
                                              nome: 'Desconhecido',
                                              especialidade: '',
                                              disponibilidades: [],
                                              ativo: false,
                                            ),
                                          );
                                          return medico.id.isNotEmpty &&
                                              medico.ativo &&
                                              medico.nome != 'Desconhecido';
                                        }).map((a) {
                                          final medico =
                                              widget.medicos.firstWhere(
                                            (m) => m.id == a.medicoId,
                                            orElse: () {
                                              return Medico(
                                                id: '',
                                                nome: 'Desconhecido',
                                                especialidade: '',
                                                disponibilidades: [],
                                                ativo: false,
                                              );
                                            },
                                          );
                                          final horariosAlocacao = a
                                                  .horarioFim.isNotEmpty
                                              ? '${a.horarioInicio} - ${a.horarioFim}'
                                              : a.horarioInicio;

                                          // Verificar se o médico está destacado pela pesquisa
                                          final isDestacado = widget
                                              .medicosDestacados
                                              .contains(medico.id);
                                          final corDestaque = isDestacado
                                              ? Colors.orange.shade200
                                              : null;

                                          final medicoCard = widget.isAdmin
                                              ? Draggable<String>(
                                                  data: medico.id,
                                                  feedback:
                                                      MedicoCard.dragFeedback(
                                                    medico,
                                                    horariosAlocacao,
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.5,
                                                    child: MedicoCard
                                                        .buildSmallMedicoCard(
                                                      medico,
                                                      horariosAlocacao,
                                                      Colors.white,
                                                      true,
                                                      corDestaque: corDestaque,
                                                    ),
                                                  ),
                                                  child: MedicoCard
                                                      .buildSmallMedicoCard(
                                                    medico,
                                                    horariosAlocacao,
                                                    Colors.white,
                                                    true,
                                                    corDestaque: corDestaque,
                                                  ),
                                                  onDragEnd: (details) {
                                                    if (details.wasAccepted ==
                                                        false) {}
                                                  },
                                                )
                                              : MedicoCard.buildSmallMedicoCard(
                                                  medico,
                                                  horariosAlocacao,
                                                  Colors.white,
                                                  true,
                                                  corDestaque: corDestaque,
                                                );

                                          // Adicionar GestureDetector para detectar tap (editar)
                                          // Só permitir edição se for administrador
                                          return widget.isAdmin && widget.onEditarMedico != null
                                              ? GestureDetector(
                                                  // Clique único para editar (só aciona se não houver drag)
                                                  onTap: () {
                                                    widget.onEditarMedico!(medico);
                                                  },
                                                  child: medicoCard,
                                                )
                                              : medicoCard;
                                        }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        // Overlay de progresso durante alocação de séries ou realocação
        if (_isAlocandoSerie || _isRealocando)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mensagem de status
                    Text(
                      _isRealocando ? _mensagemRealocacao : _mensagemAlocacao,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Barra de progresso horizontal
                    Container(
                      width: 300,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Barra de progresso
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _isRealocando
                                  ? _progressoRealocacao
                                  : _progressoAlocacao,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Percentagem
                          Text(
                            '${((_isRealocando ? _progressoRealocacao : _progressoAlocacao) * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
  int _descobrirOcorrenciaNoMes(DateTime data) {
    final weekday = data.weekday;
    final ano = data.year;
    final mes = data.month;
    final dia = data.day;

    final weekdayDia1 = DateTime(ano, mes, 1).weekday;
    final offset = (weekday - weekdayDia1 + 7) % 7;
    final primeiroDesteMes = 1 + offset;
    final dif = dia - primeiroDesteMes;
    return 1 + (dif ~/ 7);
  }
}
