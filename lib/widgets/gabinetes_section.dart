import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gabinete.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/conflict_utils.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import 'medico_card.dart';

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
    
    // CORREÇÃO: Iniciar progressbar imediatamente ao começar a realocação
    if (mounted) {
      setState(() {
        _isRealocando = true;
        _progressoRealocacao = 0.0;
        _mensagemRealocacao = 'A iniciar realocação...';
        _medicoIdEmRealocacao = medicoId;
        _gabineteOrigemRealocacao = gabineteOrigem;
      });
    }
    try {
      // CORREÇÃO CRÍTICA: Verificar PRIMEIRO nas alocações locais (inclui séries geradas)
      // Alocações de séries não estão no Firestore, então precisamos verificar localmente
      final dataAlvoNormalizada =
          DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
      
      // Verificar se a alocação atual é de série (ID começa com "serie_")
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
      
      debugPrint(
          '🔵 [REALOCAÇÃO-MÉDICO] Alocação atual encontrada: id=${alocacaoAtual.id}, é série=${alocacaoAtual.id.startsWith("serie_")}');
      
      // Se é alocação de série, verificar se há outras alocações da mesma série
      bool eSerie = alocacaoAtual.id.startsWith('serie_');
      String? serieId;
      if (eSerie) {
        // Extrair ID da série do ID da alocação
        // Formato pode ser: "serie_serie_${timestamp}_${dataKey}" ou "serie_${serieId}_${dataKey}"
        final partes = alocacaoAtual.id.split('_');
        if (partes.length >= 4 &&
            partes[0] == 'serie' &&
            partes[1] == 'serie') {
          // Formato: serie_serie_1765823155633_2025-12-10
          serieId = 'serie_${partes[2]}';
          debugPrint(
              '🔵 [REALOCAÇÃO-MÉDICO] Série detectada (formato 4 partes): serieId=$serieId');
        } else if (partes.length >= 3 && partes[0] == 'serie') {
          // Formato alternativo: serie_${serieId}_${dataKey}
          serieId =
              partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
          debugPrint(
              '🔵 [REALOCAÇÃO-MÉDICO] Série detectada (formato 3 partes): serieId=$serieId');
        }
      }
      
      // Buscar todas as alocações do médico do Firebase para verificar se é série
      final todasAlocacoesMedico =
          await AlocacaoMedicosLogic.buscarAlocacoesMedico(
        widget.unidade,
        medicoId,
        anoEspecifico: dataAlvo.year,
      );
      
      // CORREÇÃO: Combinar alocações do Firestore com alocações locais (séries)
      final todasAlocacoes = <Alocacao>[];
      todasAlocacoes.addAll(todasAlocacoesMedico);
      
      // Adicionar alocações locais que são de séries (não estão no Firestore)
      if (eSerie && serieId != null) {
        final prefixoSerie = 'serie_${serieId}_';
        final alocacoesSerie = widget.alocacoes.where((a) {
          return a.id.startsWith(prefixoSerie) && a.medicoId == medicoId;
        }).toList();
        todasAlocacoes.addAll(alocacoesSerie);
        debugPrint(
            '🔵 [REALOCAÇÃO-MÉDICO] Adicionadas ${alocacoesSerie.length} alocações de série locais');
      }

      // Verificar se há outras alocações do mesmo médico em datas futuras
      final alocacoesFuturas = todasAlocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return aDateNormalizada.isAfter(dataAlvoNormalizada) &&
            a.gabineteId == gabineteOrigem; // Apenas do gabinete de origem
      }).toList();

      // Verificar se há outras alocações passadas do mesmo gabinete
      final alocacoesPassadas = todasAlocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return aDateNormalizada.isBefore(dataAlvoNormalizada) &&
            a.gabineteId == gabineteOrigem; // Apenas do gabinete de origem
      }).toList();

      debugPrint(
          '🔵 [REALOCAÇÃO-MÉDICO] Alocações futuras: ${alocacoesFuturas.length}, passadas: ${alocacoesPassadas.length}');
      
      // CORREÇÃO: Se é série (ID começa com "serie_"), sempre considerar como série
      bool podeSerSerie =
          eSerie || alocacoesFuturas.isNotEmpty || alocacoesPassadas.isNotEmpty;
      
      debugPrint(
          '🔵 [REALOCAÇÃO-MÉDICO] podeSerSerie=$podeSerSerie, eSerie=$eSerie');

      // Tentar inferir o tipo da série
      String tipoSerie = 'Única';
      if (podeSerSerie) {
        // Buscar disponibilidade para verificar o tipo
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

        tipoSerie = disponibilidade.tipo;

        // Se não encontrou disponibilidade ou é "Única", tentar inferir
        if (tipoSerie == 'Única' && alocacoesFuturas.isNotEmpty) {
          final primeiraFutura = alocacoesFuturas.first;
          final primeiraFuturaDate = DateTime(
            primeiraFutura.data.year,
            primeiraFutura.data.month,
            primeiraFutura.data.day,
          );
          final diasDiferenca =
              primeiraFuturaDate.difference(dataAlvoNormalizada).inDays;

          if (diasDiferenca == 7 || diasDiferenca % 7 == 0) {
            tipoSerie = 'Semanal';
          } else if (diasDiferenca == 14 || diasDiferenca % 14 == 0) {
            tipoSerie = 'Quinzenal';
          } else if (primeiraFuturaDate.day == dataAlvoNormalizada.day) {
            tipoSerie = 'Mensal';
          }
        }
      }

      // Se é série, perguntar se quer realocar toda a série ou apenas o dia
      if (podeSerSerie && tipoSerie != 'Única') {
        final escolha = await showDialog<String>(
          context: context,
          builder: (ctxDialog) {
            return AlertDialog(
              title: const Text('Realocar série?'),
              content: Text(
                'Esta alocação faz parte de uma série "$tipoSerie".\n\n'
                'Deseja realocar apenas este dia (${dataAlvo.day}/${dataAlvo.month}) '
                'ou toda a série a partir deste dia para o novo gabinete?',
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
          // CORREÇÃO: Adicionar atualização otimista ANTES de realocar série toda
          // Isso faz o cartão aparecer no destino imediatamente
          debugPrint(
              '🟢 [REALOCAÇÃO-MÉDICO] Escolha: Toda a série - chamando atualização otimista');
          if (widget.onRealocacaoOtimista != null) {
            widget.onRealocacaoOtimista!(
                medicoId, gabineteOrigem, gabineteDestino, dataAlvo);
            await Future.delayed(const Duration(milliseconds: 50));
          }
          // Realocar toda a série
          await _realocarSerieEntreGabinetes(
            medicoId: medicoId,
            gabineteOrigem: gabineteOrigem,
            gabineteDestino: gabineteDestino,
            dataRef: dataAlvo,
            tipoSerie: tipoSerie,
          );
          return;
        }
        
        // Se escolheu "Apenas este dia", continuar para _realocarDiaUnicoEntreGabinetes
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] Escolha: Apenas este dia - continuando para realocação de dia único');
      }

      // Realocar apenas o dia (ou se não for série)
      // CORREÇÃO: Passar skipFlagCheck=true porque já definimos a flag acima
      await _realocarDiaUnicoEntreGabinetes(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: gabineteDestino,
        dataAlvo: dataAlvo,
        skipFlagCheck:
            true, // Já definimos a flag em _realocarMedicoEntreGabinetes
      );
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
      // Isso garante que mesmo em caso de erro, o app não fica bloqueado
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
      // Isso garante que o listener seja reativado e a UI volte ao normal
      if (widget.onRealocacaoConcluida != null) {
        debugPrint(
            '🟢 [REALOCAÇÃO-MÉDICO] FINALLY: Chamando onRealocacaoConcluida para limpar flags de transição');
        widget.onRealocacaoConcluida!();
      }
    }
  }

  /// Realoca apenas um dia entre gabinetes
  Future<void> _realocarDiaUnicoEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataAlvo,
    bool skipFlagCheck =
        false, // Se true, pula verificação de flag (já foi definida pelo chamador)
  }) async {
    debugPrint(
        '🔵 [REALOCAÇÃO] INÍCIO: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino, skipFlagCheck=$skipFlagCheck');
    
    // CORREÇÃO CRÍTICA: Só verificar flag se não foi pedido para pular
    if (!skipFlagCheck) {
      // Verificar se já está realocando para evitar bloqueios
      if (_isRealocando && _medicoIdEmRealocacao == medicoId) {
        debugPrint(
            '⚠️ [REALOCAÇÃO] JÁ EM ANDAMENTO: médico $medicoId, ignorando chamada duplicada');
        return;
      }
      
      // Se a flag está presa de uma operação anterior (médico diferente), limpar
      if (_isRealocando && _medicoIdEmRealocacao != medicoId) {
        debugPrint(
            '🔓 [REALOCAÇÃO] LIMPANDO FLAG PRESA: médico anterior=$_medicoIdEmRealocacao, novo=$medicoId');
        if (mounted) {
          setState(() {
            _isRealocando = false;
            _medicoIdEmRealocacao = null;
            _gabineteOrigemRealocacao = null;
          });
        }
      }
      
      // Iniciar progresso visual imediatamente (só se não foi pedido para pular)
      if (mounted) {
        setState(() {
          _isRealocando = true;
          _progressoRealocacao = 0.0;
          _mensagemRealocacao = 'A iniciar realocação...';
          _medicoIdEmRealocacao = medicoId;
          _gabineteOrigemRealocacao = gabineteOrigem;
        });
      }
    }

    try {
      // NOVO: Atualização otimista - atualizar estado local IMEDIATAMENTE
      // Isso faz o cartão aparecer no destino e desaparecer da origem instantaneamente
      debugPrint(
          '🟢 [REALOCAÇÃO] Chamando atualização otimista: onRealocacaoOtimista=${widget.onRealocacaoOtimista != null}');
      if (widget.onRealocacaoOtimista != null) {
        debugPrint('🟢 [REALOCAÇÃO] Executando atualização otimista...');
        widget.onRealocacaoOtimista!(
            medicoId, gabineteOrigem, gabineteDestino, dataAlvo);
        debugPrint('✅ [REALOCAÇÃO] Atualização otimista executada');
        // Pequeno delay para garantir que a UI foi atualizada
        await Future.delayed(const Duration(milliseconds: 50));
      } else {
        debugPrint('⚠️ [REALOCAÇÃO] onRealocacaoOtimista é null!');
      }
      
      // CORREÇÃO CRÍTICA: Após atualização otimista, a alocação já está no gabineteDestino
      // Então devemos procurar primeiro no destino, e se não encontrar, procurar na origem
      final dataAlvoNormalizada =
          DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
      debugPrint(
          '🔵 [REALOCAÇÃO] Procurando alocação: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino, data=$dataAlvoNormalizada');
      debugPrint(
          '🔵 [REALOCAÇÃO] Total de alocações disponíveis: ${widget.alocacoes.length}');
      
      // Listar todas as alocações do médico para debug
      final alocacoesDoMedico =
          widget.alocacoes.where((a) => a.medicoId == medicoId).toList();
      debugPrint(
          '🔵 [REALOCAÇÃO] Alocações do médico: ${alocacoesDoMedico.length}');
      for (final a in alocacoesDoMedico) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        debugPrint('   - id=${a.id}, gabinete=${a.gabineteId}, data=$aDate');
      }
      
      // CORREÇÃO: Procurar primeiro no destino (onde está após atualização otimista)
      // Se não encontrar, procurar na origem (caso a atualização otimista não tenha funcionado)
      Alocacao? alocacaoOrigem;
      
      // Tentar encontrar no destino primeiro
      try {
        alocacaoOrigem = widget.alocacoes.firstWhere(
          (a) {
            final aDate = DateTime(a.data.year, a.data.month, a.data.day);
            final aDateNormalizada =
                DateTime(aDate.year, aDate.month, aDate.day);
            return a.medicoId == medicoId &&
                a.gabineteId == gabineteDestino &&
                aDateNormalizada.year == dataAlvoNormalizada.year &&
                aDateNormalizada.month == dataAlvoNormalizada.month &&
                aDateNormalizada.day == dataAlvoNormalizada.day;
          },
        );
        debugPrint(
            '✅ [REALOCAÇÃO] Alocação encontrada no destino (após atualização otimista): id=${alocacaoOrigem.id}, gabinete=${alocacaoOrigem.gabineteId}');
      } catch (e) {
        // Se não encontrar no destino, procurar na origem
        debugPrint(
            '⚠️ [REALOCAÇÃO] Alocação não encontrada no destino, procurando na origem...');
        try {
          alocacaoOrigem = widget.alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              final aDateNormalizada =
                  DateTime(aDate.year, aDate.month, aDate.day);
              return a.medicoId == medicoId &&
                  a.gabineteId == gabineteOrigem &&
                  aDateNormalizada.year == dataAlvoNormalizada.year &&
                  aDateNormalizada.month == dataAlvoNormalizada.month &&
                  aDateNormalizada.day == dataAlvoNormalizada.day;
            },
          );
          debugPrint(
              '✅ [REALOCAÇÃO] Alocação encontrada na origem: id=${alocacaoOrigem.id}, gabinete=${alocacaoOrigem.gabineteId}');
        } catch (e2) {
          debugPrint(
              '❌ [REALOCAÇÃO] Alocação não encontrada nem no destino nem na origem');
          alocacaoOrigem = Alocacao(
            id: '',
            medicoId: '',
            gabineteId: '',
            data: DateTime(1900, 1, 1),
            horarioInicio: '',
            horarioFim: '',
          );
        }
      }

      if (alocacaoOrigem.id.isEmpty) {
        // CORREÇÃO CRÍTICA: Limpar flags ANTES de retornar para evitar bloqueio permanente
        if (mounted) {
          setState(() {
            _isRealocando = false;
            _progressoRealocacao = 0.0;
            _mensagemRealocacao = 'A iniciar...';
            _medicoIdEmRealocacao = null;
            _gabineteOrigemRealocacao = null;
          });
        }
        await widget.onAlocarMedico(
          medicoId,
          gabineteDestino,
          dataEspecifica: dataAlvo,
        );
        return;
      }

      // CORREÇÃO CRÍTICA: Verificar se a alocação faz parte de uma série
      // Se o ID começa com "serie_", é uma alocação gerada de uma série
      final eAlocacaoDeSerie = alocacaoOrigem.id.startsWith('serie_');

      if (eAlocacaoDeSerie) {
        // Extrair o ID da série do ID da alocação
        // Formato: "serie_${serieId}_${dataKey}"
        // O serieId sempre começa com "serie_" (ex: "serie_1765699306607")
        // Então o ID completo é "serie_serie_1765699306607_2025-12-31"
        String? serieId;
        final partes = alocacaoOrigem.id.split('_');

        debugPrint(
            '🔍 Extraindo ID da série do ID da alocação: ${alocacaoOrigem.id}, partes: ${partes.length}');

        if (partes.length >= 4 &&
            partes[0] == 'serie' &&
            partes[1] == 'serie') {
          // Formato: "serie_serie_${timestamp}_${dataKey}"
          serieId = 'serie_${partes[2]}';
          debugPrint('   ✅ ID extraído (formato 4 partes): $serieId');
        } else if (partes.length >= 3 && partes[0] == 'serie') {
          // Formato alternativo: "serie_${serieId}_${dataKey}" (caso o serieId não comece com "serie_")
          serieId =
              partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
          debugPrint('   ✅ ID extraído (formato 3 partes): $serieId');
        } else {
          debugPrint('   ❌ Não foi possível extrair o ID da série. Partes: $partes');
        }

        if (serieId != null) {
          // Criar exceção para modificar o gabinete deste dia específico
          try {
            // Normalizar a data para garantir correspondência exata (sem horas/minutos/segundos)
            final dataNormalizada = DateTime(
              dataAlvo.year,
              dataAlvo.month,
              dataAlvo.day,
            );

            debugPrint(
                '🔧 Criando exceção para série $serieId, data ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, novo gabinete: $gabineteDestino');

            // CORREÇÃO: Remover setState() desnecessários para reduzir "piscar"
            await DisponibilidadeSerieService.modificarGabineteDataSerie(
              serieId: serieId,
              medicoId: medicoId,
              data: dataNormalizada,
              novoGabineteId: gabineteDestino,
              unidade: widget.unidade,
            );

            debugPrint(
                '✅ Exceção criada para série $serieId, data ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, novo gabinete: $gabineteDestino');

            // CORREÇÃO: Verificar se a exceção foi realmente salva e está disponível no Firestore
            // antes de invalidar cache e regenerar. Isso garante que a exceção estará disponível
            // quando as alocações forem regeneradas
            debugPrint(
                '🔍 Verificando se a exceção está disponível no Firestore...');
            bool excecaoEncontrada = false;
            int tentativas = 0;
            const maxTentativas = 5;
            const delayEntreTentativas = Duration(milliseconds: 800);

            while (!excecaoEncontrada && tentativas < maxTentativas) {
              await Future.delayed(delayEntreTentativas);
              tentativas++;

              // CORREÇÃO: Remover setState() desnecessário para reduzir "piscar"

              try {
                final excecoesVerificacao = await SerieService.carregarExcecoes(
                  medicoId,
                  unidade: widget.unidade,
                  dataInicio: dataNormalizada,
                  dataFim: dataNormalizada.add(const Duration(days: 1)),
                  serieId: serieId,
                  forcarServidor: true, // Sempre forçar servidor para verificar
                );

                final excecaoComGabineteCorreto =
                    excecoesVerificacao.firstWhere(
                  (e) =>
                      e.serieId == serieId &&
                      e.data.year == dataNormalizada.year &&
                      e.data.month == dataNormalizada.month &&
                      e.data.day == dataNormalizada.day &&
                      e.gabineteId == gabineteDestino &&
                      !e.cancelada,
                  orElse: () => ExcecaoSerie(
                    id: '',
                    serieId: '',
                    data: DateTime(1900, 1, 1),
                  ),
                );

                if (excecaoComGabineteCorreto.id.isNotEmpty) {
                  excecaoEncontrada = true;
                  debugPrint(
                      '✅ Exceção confirmada no Firestore após ${tentativas * 800}ms (ID: ${excecaoComGabineteCorreto.id})');
                } else {
                  debugPrint(
                      '⏳ Tentativa $tentativas/$maxTentativas: Exceção ainda não encontrada, aguardando...');
                }
              } catch (e) {
                debugPrint(
                    '⚠️ Erro ao verificar exceção (tentativa $tentativas): $e');
              }
            }

            if (!excecaoEncontrada) {
              debugPrint(
                  '⚠️ AVISO: Exceção não foi confirmada após ${maxTentativas * 800}ms, mas continuando...');
            }

            // CORREÇÃO: Remover setState() desnecessário para reduzir "piscar"

            // Invalidar cache para forçar regeneração das alocações
            AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvo);
            AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(medicoId, null);

            debugPrint(
                '🔄 Cache invalidado para médico $medicoId e data ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');

            // CORREÇÃO: Aguardar um pouco mais para garantir que a invalidação do cache seja processada
            await Future.delayed(const Duration(milliseconds: 300));

            // CORREÇÃO: Remover setState() desnecessários para reduzir "piscar"
            // Aguardar tempo suficiente para que a exceção esteja disponível no servidor
            // antes de recarregar, evitando múltiplas atualizações desnecessárias
            // Reduzido para 500ms para reduzir "piscar" e melhorar responsividade
            debugPrint('⏳ Aguardando propagação completa da exceção (500ms)...');
            await Future.delayed(const Duration(milliseconds: 500));

            // SOLUÇÃO MELHORADA: Ocultar progressbar e limpar flags de transição
            // A atualização otimista já foi feita, então só precisamos sincronizar com o servidor
            // CORREÇÃO CRÍTICA: Limpar flags ANTES de chamar onAtualizarEstado para evitar bloqueios
            debugPrint(
                '🟢 [REALOCAÇÃO] Limpando flags ANTES de sincronizar (caminho série)');
            if (mounted) {
              setState(() {
                _isRealocando = false;
                _progressoRealocacao = 0.0;
                _mensagemRealocacao = 'A iniciar...';
                _medicoIdEmRealocacao = null;
                _gabineteOrigemRealocacao = null;
              });
              debugPrint(
                  '✅ [REALOCAÇÃO] Flags limpas: _isRealocando=false, _medicoIdEmRealocacao=null');
              // Atualizar UI DEPOIS de ocultar progressbar - só uma vez
              // Isso sincroniza com o servidor mas a UI já está atualizada otimisticamente
              debugPrint('🔄 Sincronizando estado com servidor...');
              widget.onAtualizarEstado();
              
              // CORREÇÃO CRÍTICA: Limpar flags de transição após sincronizar
              if (widget.onRealocacaoConcluida != null) {
                debugPrint(
                    '🟢 [REALOCAÇÃO] Chamando onRealocacaoConcluida para limpar flags de transição');
                widget.onRealocacaoConcluida!();
              }
            }

            // Mostrar mensagem de sucesso
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Médico realocado com sucesso'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return;
          } catch (e) {
            // Em caso de erro, continuar com o método normal
            debugPrint('❌ Erro ao criar exceção para mudança de gabinete: $e');
          }
        }
      }

      // Se não é de série ou não conseguiu extrair o ID, usar método normal
      // CORREÇÃO: Remover setState() desnecessário para reduzir "piscar"

      final firestore = FirebaseFirestore.instance;
      final ano = dataAlvo.year.toString();
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      // Encontrar TODAS as alocações do médico no dia do gabinete de origem
      final alocacoesParaRemover = widget.alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            aDate == dataAlvo;
      }).toList();

      // Remover TODAS as alocações do médico no dia do gabinete de origem
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');

      for (final alocacaoParaRemover in alocacoesParaRemover) {
        try {
          await alocacoesRef.doc(alocacaoParaRemover.id).delete();
        } catch (e) {
          // Erro ao remover alocação - continuar com as outras
        }
      }

      // CORREÇÃO: Remover setState() desnecessário para reduzir "piscar"

      // Invalidar cache
      AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvo);

      // Atualizar progresso: 60% - Alocando no novo gabinete
      if (mounted) {
        setState(() {
          _progressoRealocacao = 0.6;
          _mensagemRealocacao = 'A alocar no novo gabinete...';
        });
      }

      // CORREÇÃO: Aguardar um pouco antes de alocar para garantir que a remoção foi processada
      // Reduzido para 300ms para melhorar responsividade
      await Future.delayed(const Duration(milliseconds: 300));

      // SOLUÇÃO DEFINITIVA: Usar widget.onAlocarMedico que já gerencia _isProcessandoAlocacao
      // Isso previne que os listeners do Firestore atualizem a UI durante a operação
      // O onAlocarMedico já chama _carregarDadosIniciais() no final, então só precisamos
      // ocultar o progressbar DEPOIS que tudo terminar
      // NOTA: onAlocarMedico já verifica se a alocação existe no destino e não cria duplicado
      debugPrint(
          '🟢 [REALOCAÇÃO-DIA] Chamando onAlocarMedico após atualização otimista');
      await widget.onAlocarMedico(
        medicoId,
        gabineteDestino,
        dataEspecifica: dataAlvo,
      );

      // CORREÇÃO CRÍTICA: Aguardar que _carregarDadosIniciais() dentro de onAlocarMedico termine
      // e que a UI seja completamente renderizada
      // A atualização otimista já foi feita, então só precisamos garantir sincronização
      // Reduzido para 200ms para melhorar responsividade
      await Future.delayed(const Duration(milliseconds: 200));

      // SOLUÇÃO MELHORADA: Ocultar progressbar
      // A atualização otimista já moveu o cartão visualmente, então só precisamos
      // garantir que está sincronizado com o servidor
      debugPrint(
          '🟢 [REALOCAÇÃO] Limpando flags após onAlocarMedico (caminho normal)');
      if (mounted) {
        setState(() {
          _isRealocando = false;
          _progressoRealocacao = 0.0;
          _mensagemRealocacao = 'A iniciar...';
          _medicoIdEmRealocacao = null;
          _gabineteOrigemRealocacao = null;
        });
        debugPrint(
            '✅ [REALOCAÇÃO] Flags limpas: _isRealocando=false, _medicoIdEmRealocacao=null');
      }

      // Mostrar mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Médico realocado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Ocultar progresso em caso de erro
      if (mounted) {
        setState(() {
          _isRealocando = false;
          _progressoRealocacao = 0.0;
          _mensagemRealocacao = 'A iniciar...';
          _medicoIdEmRealocacao = null;
          _gabineteOrigemRealocacao = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // CORREÇÃO CRÍTICA: SEMPRE limpar flags no finally para evitar bloqueios
      // Isso garante que mesmo em caso de erro ou exceção não capturada, o app não fica bloqueado
      debugPrint('🔴 [REALOCAÇÃO] FINALLY: Limpando flags (garantia absoluta)');
      debugPrint(
          '🔴 [REALOCAÇÃO] Estado antes de limpar: _isRealocando=$_isRealocando, _medicoIdEmRealocacao=$_medicoIdEmRealocacao');
      if (mounted) {
        setState(() {
          _isRealocando = false;
          _progressoRealocacao = 0.0;
          _mensagemRealocacao = 'A iniciar...';
          _medicoIdEmRealocacao = null;
          _gabineteOrigemRealocacao = null;
        });
      }
      debugPrint(
          '✅ [REALOCAÇÃO] FINALLY: Flags limpas: _isRealocando=false, _medicoIdEmRealocacao=null');
    }
  }

  /// Realoca toda a série entre gabinetes
  Future<void> _realocarSerieEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataRef,
    required String tipoSerie,
  }) async {
    // CORREÇÃO: Não iniciar progressbar aqui se já foi iniciado em _realocarMedicoEntreGabinetes
    // Apenas atualizar mensagem se necessário
    if (mounted && !_isRealocando) {
      setState(() {
        _isRealocando = true;
        _progressoRealocacao = 0.0;
        _mensagemRealocacao = 'A iniciar realocação de série...';
        _medicoIdEmRealocacao = medicoId;
        _gabineteOrigemRealocacao = gabineteOrigem;
      });
    } else if (mounted) {
      // Já está iniciado, apenas atualizar mensagem
      setState(() {
        _mensagemRealocacao = 'A iniciar realocação de série...';
      });
    }

    try {
      // Encontrar a alocação atual no gabinete de origem
      // CORREÇÃO CRÍTICA: Após atualização otimista, a alocação pode estar no destino
      // Procurar primeiro no destino, depois na origem
      Alocacao? alocacaoAtual;

      // Tentar encontrar no destino primeiro (onde está após atualização otimista)
      try {
        alocacaoAtual = widget.alocacoes.firstWhere(
          (a) {
            final aDate = DateTime(a.data.year, a.data.month, a.data.day);
            final dataRefNormalizada =
                DateTime(dataRef.year, dataRef.month, dataRef.day);
            return a.medicoId == medicoId &&
                a.gabineteId == gabineteDestino &&
                aDate == dataRefNormalizada;
          },
        );
        debugPrint(
            '✅ [REALOCAÇÃO-DIA] Alocação encontrada no destino (após atualização otimista)');
      } catch (e) {
        // Se não encontrar no destino, procurar na origem
        debugPrint(
            '⚠️ [REALOCAÇÃO-DIA] Alocação não encontrada no destino, procurando na origem...');
        try {
          alocacaoAtual = widget.alocacoes.firstWhere(
        (a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          final dataRefNormalizada =
              DateTime(dataRef.year, dataRef.month, dataRef.day);
          return a.medicoId == medicoId &&
              a.gabineteId == gabineteOrigem &&
              aDate == dataRefNormalizada;
        },
          );
          debugPrint('✅ [REALOCAÇÃO-DIA] Alocação encontrada na origem');
        } catch (e2) {
          alocacaoAtual = Alocacao(
          id: '',
          medicoId: '',
          gabineteId: '',
          data: DateTime(1900, 1, 1),
          horarioInicio: '',
          horarioFim: '',
      );
        }
      }

      if (alocacaoAtual.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma alocação encontrada na data selecionada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Verificar se é uma alocação de série
      if (!alocacaoAtual.id.startsWith('serie_')) {
        await _realocarDiaUnicoEntreGabinetes(
          medicoId: medicoId,
          gabineteOrigem: gabineteOrigem,
          gabineteDestino: gabineteDestino,
          dataAlvo: dataRef,
        );
        return;
      }

      // Extrair o ID da série do ID da alocação
      // Formato: "serie_${serieId}_${dataKey}"
      String? serieId;
      final partes = alocacaoAtual.id.split('_');

      if (partes.length >= 4 && partes[0] == 'serie' && partes[1] == 'serie') {
        // Formato: "serie_serie_${timestamp}_${dataKey}"
        serieId = 'serie_${partes[2]}';
      } else if (partes.length >= 3 && partes[0] == 'serie') {
        // Formato alternativo: "serie_${serieId}_${dataKey}"
        serieId =
            partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
      }

      if (serieId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao identificar a série'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Buscar a série do serviço
      final series = await SerieService.carregarSeries(
        medicoId,
        unidade: widget.unidade,
      );

      final serie = series.firstWhere(
        (s) => s.id == serieId && s.ativo,
        orElse: () => SerieRecorrencia(
          id: '',
          medicoId: '',
          dataInicio: DateTime.now(),
          tipo: '',
          horarios: [],
        ),
      );

      if (serie.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Série não encontrada'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Gerar todas as datas futuras da série a partir da data de referência
      final dataRefNormalizada =
          DateTime(dataRef.year, dataRef.month, dataRef.day);
      final dataFim = serie.dataFim ??
          DateTime(
              dataRef.year + 1, 12, 31); // Limite de 1 ano se não houver fim

      final datasFuturas = _gerarDatasFuturasSerie(
        serie: serie,
        dataInicio: dataRefNormalizada,
        dataFim: dataFim,
      );

      if (datasFuturas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma data futura encontrada para a série'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Atualizar o gabineteId da série para o novo gabinete
      // Isso fará com que todas as datas futuras sejam geradas com o novo gabinete
      try {
        // Atualizar progresso: 10% - Iniciando atualização
        if (mounted) {
          setState(() {
            _progressoRealocacao = 0.1;
            _mensagemRealocacao = 'A atualizar série...';
          });
        }

        debugPrint(
            '🔄 Atualizando série $serieId para gabinete $gabineteDestino a partir de ${dataRefNormalizada.day}/${dataRefNormalizada.month}/${dataRefNormalizada.year}');

        // Atualizar o gabinete da série
        await DisponibilidadeSerieService.alocarSerie(
          serieId: serieId,
          medicoId: medicoId,
          gabineteId: gabineteDestino,
          unidade: widget.unidade,
        );

        // Atualizar progresso: 30% - Série atualizada
        if (mounted) {
          setState(() {
            _progressoRealocacao = 0.3;
            _mensagemRealocacao = 'A criar exceções...';
          });
        }

        // Criar exceções para as datas anteriores à data de referência
        // para manter o gabinete antigo nessas datas
        final dataInicioSerie = DateTime(
          serie.dataInicio.year,
          serie.dataInicio.month,
          serie.dataInicio.day,
        );

        // Se a data de referência é posterior ao início da série,
        // criar exceções para manter o gabinete antigo nas datas anteriores
        if (dataRefNormalizada.isAfter(dataInicioSerie)) {
          DateTime dataAtual = dataInicioSerie;
          int totalDatas = 0;
          int datasProcessadas = 0;

          // Contar quantas datas precisam ser processadas
          while (dataAtual.isBefore(dataRefNormalizada)) {
            final corresponde = _verificarSeDataCorrespondeSerie(
              dataAtual,
              serie,
            );
            if (corresponde) {
              totalDatas++;
            }
            dataAtual = dataAtual.add(const Duration(days: 1));
          }

          // Processar cada data
          dataAtual = dataInicioSerie;
          while (dataAtual.isBefore(dataRefNormalizada)) {
            // Verificar se esta data corresponde à série
            final corresponde = _verificarSeDataCorrespondeSerie(
              dataAtual,
              serie,
            );

            if (corresponde) {
              // Criar exceção para manter o gabinete antigo nesta data
              await DisponibilidadeSerieService.modificarGabineteDataSerie(
                serieId: serieId,
                medicoId: medicoId,
                data: dataAtual,
                novoGabineteId: gabineteOrigem,
                unidade: widget.unidade,
              );

              datasProcessadas++;
              // Atualizar progresso: 30% + (40% * progresso das exceções)
              if (mounted && totalDatas > 0) {
                final progressoExcecoes = datasProcessadas / totalDatas;
                setState(() {
                  _progressoRealocacao = 0.3 + (0.4 * progressoExcecoes);
                  _mensagemRealocacao =
                      'A criar exceções... ($datasProcessadas/$totalDatas)';
                });
              }
            }

            dataAtual = dataAtual.add(const Duration(days: 1));
          }
        }

        // Atualizar progresso: 70% - Invalidando cache
        if (mounted) {
          setState(() {
            _progressoRealocacao = 0.7;
            _mensagemRealocacao = 'A invalidar cache...';
          });
        }

        // Invalidar cache para forçar regeneração das alocações
        for (final data in datasFuturas) {
          AlocacaoMedicosLogic.invalidateCacheForDay(data);
        }
        AlocacaoMedicosLogic.invalidateCacheForDay(dataRef);
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(medicoId, null);

        // Atualizar progresso: 80% - Aguardando sincronização
        if (mounted) {
          setState(() {
            _progressoRealocacao = 0.8;
            _mensagemRealocacao = 'A sincronizar...';
          });
        }

        // Aguardar um pouco para garantir que as mudanças sejam salvas
        await Future.delayed(const Duration(milliseconds: 800));

        // Atualizar progresso: 90% - Atualizando estado
        if (mounted) {
          setState(() {
            _progressoRealocacao = 0.9;
            _mensagemRealocacao = 'A atualizar interface...';
          });
        }

        // CORREÇÃO CRÍTICA: Aguardar tempo suficiente para garantir que TODAS as operações no Firestore terminaram
        await Future.delayed(const Duration(milliseconds: 1500));

        // SOLUÇÃO ORIGINAL: Ocultar progressbar PRIMEIRO, depois atualizar UI
        // Como as operações no Firestore já foram feitas diretamente acima,
        // agora só precisamos atualizar a UI UMA VEZ, após ocultar o progressbar
        // Isso garante que o cartão aparece exatamente quando o progressbar desaparece
        if (mounted) {
          setState(() {
            _isRealocando = false;
            _progressoRealocacao = 0.0;
            _mensagemRealocacao = 'A iniciar...';
            _medicoIdEmRealocacao = null;
            _gabineteOrigemRealocacao = null;
          });
          // Atualizar UI DEPOIS de ocultar progressbar - só uma vez
          widget.onAtualizarEstado();
          
          // CORREÇÃO CRÍTICA: Limpar flags de transição após sincronizar
          if (widget.onRealocacaoConcluida != null) {
            debugPrint(
                '🟢 [REALOCAÇÃO-SÉRIE] Chamando onRealocacaoConcluida para limpar flags de transição');
            widget.onRealocacaoConcluida!();
          }
        }

        // Mostrar mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Série realocada com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Erro ao atualizar série: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar série: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Resetar progressbar em caso de erro
        if (mounted) {
          setState(() {
            _isRealocando = false;
            _progressoRealocacao = 0.0;
            _mensagemRealocacao = 'A iniciar...';
            _medicoIdEmRealocacao = null;
            _gabineteOrigemRealocacao = null;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar série: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Gera todas as datas futuras de uma série a partir de uma data de referência
  List<DateTime> _gerarDatasFuturasSerie({
    required SerieRecorrencia serie,
    required DateTime dataInicio,
    required DateTime dataFim,
  }) {
    final datas = <DateTime>[];
    final dataInicioNormalizada =
        DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    final dataFimNormalizada =
        DateTime(dataFim.year, dataFim.month, dataFim.day);

    switch (serie.tipo) {
      case 'Semanal':
        // Encontrar o próximo dia da semana correspondente
        final weekday = serie.dataInicio.weekday;
        DateTime dataAtual = dataInicioNormalizada;

        // Se a data de início já é o dia correto, usar ela
        // Caso contrário, encontrar o próximo dia da semana correto
        if (dataAtual.weekday != weekday) {
          // Calcular quantos dias faltam para o próximo dia da semana
          int diasParaProximo = (weekday - dataAtual.weekday + 7) % 7;
          if (diasParaProximo == 0) {
            diasParaProximo = 7; // Se for o mesmo dia, avançar uma semana
          }
          dataAtual = dataAtual.add(Duration(days: diasParaProximo));
        }

        // Se não encontrou dentro do período, retornar vazio
        if (dataAtual.isAfter(dataFimNormalizada)) {
          return datas;
        }

        // Gerar todas as datas semanais (incluindo a data de referência se for o dia correto)
        while (dataAtual
            .isBefore(dataFimNormalizada.add(const Duration(days: 1)))) {
          datas.add(dataAtual);
          dataAtual = dataAtual.add(const Duration(days: 7));
        }
        break;

      case 'Quinzenal':
        // Para quinzenal, garantir o mesmo dia da semana a cada 14 dias
        final base = DateTime(
          serie.dataInicio.year,
          serie.dataInicio.month,
          serie.dataInicio.day,
        );
        final weekday = serie.dataInicio.weekday;
        final diffDias = dataInicioNormalizada.difference(base).inDays;

        // Encontrar a próxima data quinzenal válida
        // Calcular quantas semanas de 14 dias se passaram
        int semanasDesdeInicio = (diffDias / 14).floor();
        DateTime dataAtual = base.add(Duration(days: semanasDesdeInicio * 14));

        // Se a data calculada é antes da data de início ou não é o dia correto,
        // avançar para a próxima ocorrência
        while (dataAtual.isBefore(dataInicioNormalizada) ||
            dataAtual.weekday != weekday) {
          dataAtual = dataAtual.add(const Duration(days: 14));
        }

        // Gerar todas as datas quinzenais
        while (dataAtual
            .isBefore(dataFimNormalizada.add(const Duration(days: 1)))) {
          // Verificar se é o mesmo dia da semana (garantia adicional)
          if (dataAtual.weekday == weekday) {
            datas.add(dataAtual);
          }
          dataAtual = dataAtual.add(const Duration(days: 14));
        }
        break;

      case 'Mensal':
        // Para séries mensais, usar a mesma lógica do serie_generator
        // que considera o dia da semana e a ocorrência (1ª, 2ª, 3ª, etc.)
        final weekday = serie.dataInicio.weekday;
        final ocorrencia = _descobrirOcorrenciaNoMes(serie.dataInicio);

        // Gerar para cada mês no período
        DateTime mesAtual = DateTime(
          dataInicioNormalizada.year,
          dataInicioNormalizada.month,
          1,
        );
        final fimMes = DateTime(
          dataFimNormalizada.year,
          dataFimNormalizada.month + 1,
          0,
        );

        while (mesAtual.isBefore(fimMes.add(const Duration(days: 1)))) {
          final data = _pegarNthWeekdayDoMes(
            mesAtual.year,
            mesAtual.month,
            weekday,
            ocorrencia,
          );

          if (data != null &&
              data.isAfter(
                  dataInicioNormalizada.subtract(const Duration(days: 1))) &&
              data.isBefore(dataFimNormalizada.add(const Duration(days: 1)))) {
            datas.add(data);
          }

          // Próximo mês
          if (mesAtual.month == 12) {
            mesAtual = DateTime(mesAtual.year + 1, 1, 1);
          } else {
            mesAtual = DateTime(mesAtual.year, mesAtual.month + 1, 1);
          }
        }
        break;

      case 'Consecutivo':
        final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
        DateTime dataAtual = dataInicioNormalizada;

        // Gerar datas consecutivas
        for (int i = 0;
            i < numeroDias &&
                dataAtual
                    .isBefore(dataFimNormalizada.add(const Duration(days: 1)));
            i++) {
          datas.add(dataAtual);
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
        break;

      default:
        // Para "Única", apenas a data de referência se for a data de início
        if (dataInicioNormalizada ==
            DateTime(serie.dataInicio.year, serie.dataInicio.month,
                serie.dataInicio.day)) {
          datas.add(dataInicioNormalizada);
        }
        break;
    }

    return datas;
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

                      // Só mostrar se o médico estiver ativo
                      return medico.ativo;
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
                        if (disponibilidade.medicoId.isEmpty) return false;

                        // 4) Verifica se horários são válidos (apenas para novos cartões)
                        // CORREÇÃO: Para séries, permitir mesmo se horários não estão configurados ainda
                        // (eles podem ser configurados depois)
                        final eTipoSerie = disponibilidade.tipo == 'Semanal' ||
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
                            final aDate =
                                DateTime(a.data.year, a.data.month, a.data.day);
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
                        final alocacaoEmOutroGabinete =
                            widget.alocacoes.firstWhere(
                          (a) {
                            final aDate =
                                DateTime(a.data.year, a.data.month, a.data.day);
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

                        // Se está alocado em outro gabinete, perguntar se quer realocar
                        if (alocacaoEmOutroGabinete.id.isNotEmpty) {
                          debugPrint(
                              '🟢 [DRAG-ACCEPT] Chamando _realocarMedicoEntreGabinetes: origem=${alocacaoEmOutroGabinete.gabineteId}, destino=${gabinete.id}');
                          await _realocarMedicoEntreGabinetes(
medicoId: medicoId,
                            gabineteOrigem: alocacaoEmOutroGabinete.gabineteId,
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
                          await widget.onAlocarMedico(
                            medicoId,
                            gabinete.id,
                            dataEspecifica: widget.selectedDate,
                          );
                          // Não precisa chamar onAtualizarEstado() aqui porque
                          // onAlocarMedico já chama onAlocacoesChanged() internamente
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
                                    onPressed: () =>
                                        Navigator.of(ctxDialog).pop('1dia'),
                                    child: const Text('Apenas este dia'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctxDialog).pop('serie'),
                                    child: const Text('Toda a série'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctxDialog).pop(null),
                                    child: const Text('Cancelar'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (escolha == '1dia') {
                            // CORREÇÃO: Não chamar onAtualizarEstado() durante a operação
                            // A atualização será feita no final pelo próprio onAlocarMedico
                            // Isso evita múltiplas atualizações que causam "piscar"
                            await widget.onAlocarMedico(
                              medicoId,
                              gabinete.id,
                              dataEspecifica: widget.selectedDate,
                            );
                          } else if (escolha == 'serie') {
                            try {
                              // Iniciar progresso de alocação
                              if (mounted) {
                                setState(() {
                                  _isAlocandoSerie = true;
                                  _progressoAlocacao = 0.0;
                                  _mensagemAlocacao = 'A iniciar alocação...';
                                });
                              }

                              final dataRef = widget.selectedDate;
                              // CORREÇÃO: Definir dataRefNormalizada no início para estar disponível em todo o escopo
                              final dataRefNormalizada = DateTime(
                                  dataRef.year, dataRef.month, dataRef.day);

                              // Atualizar progresso: 10% - Iniciado
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.1;
                                  _mensagemAlocacao = 'A verificar série...';
                                });
                              }
                              if (widget.unidade == null) {
                                if (mounted) {
                                  setState(() {
                                    _isAlocandoSerie = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Erro: Unidade não definida'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }

                              // Atualizar progresso: 20% - Unidade verificada
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.2;
                                  _mensagemAlocacao = 'A localizar série...';
                                });
                              }

                              // Normalizar o tipo da série
                              final tipoNormalizado =
                                  tipoDisponibilidade.startsWith('Consecutivo')
                                      ? 'Consecutivo'
                                      : tipoDisponibilidade;

                              // Extrair número de dias para séries consecutivas
                              int? numeroDiasConsecutivo;
                              if (tipoNormalizado == 'Consecutivo') {
                                final match = RegExp(r'Consecutivo:(\d+)')
                                    .firstMatch(tipoDisponibilidade);
                                numeroDiasConsecutivo = match != null
                                    ? int.tryParse(match.group(1) ?? '') ?? 5
                                    : 5;
                              }

                              // Usar horários da disponibilidade
                              final horariosRef =
                                  disponibilidade.horarios.isNotEmpty
                                      ? disponibilidade.horarios
                                      : ['08:00', '15:00']; // Fallback

                              // CORREÇÃO: Se temos o ID da série extraído do ID da disponibilidade,
                              // usar diretamente em vez de procurar pela data/tipo
                              SerieRecorrencia? serieEncontrada;

                              if (serieIdExtraido != null) {
                                try {
                                  final series =
                                      await SerieService.carregarSeries(
                                    medicoId,
                                    unidade: widget.unidade,
                                  );
                                  serieEncontrada = series.firstWhere(
                                    (s) => s.id == serieIdExtraido,
                                    orElse: () => SerieRecorrencia(
                                      id: '',
                                      medicoId: '',
                                      dataInicio: DateTime(1900, 1, 1),
                                      tipo: '',
                                      horarios: [],
                                      parametros: {},
                                      ativo: false,
                                    ),
                                  );
                                  if (serieEncontrada.id.isEmpty) {
                                    serieEncontrada = null;
                                  }
                                } catch (e) {
                                  serieEncontrada = null;
                                }
                              }

                              // Se não encontrou pelo ID, tentar encontrar pela data/tipo
                              if (serieEncontrada == null ||
                                  serieEncontrada.id.isEmpty) {
                                serieEncontrada =
                                    await _encontrarSerieCorrespondente(
                                  medicoId: medicoId,
                                  tipo: tipoDisponibilidade,
                                  data: dataRefNormalizada,
                                );
                              }

                              // Para séries consecutivas, verificar se o número de dias corresponde
                              if (serieEncontrada != null &&
                                  tipoNormalizado == 'Consecutivo' &&
                                  numeroDiasConsecutivo != null) {
                                final numeroDiasSerie = serieEncontrada
                                        .parametros['numeroDias'] as int? ??
                                    5;
                                if (numeroDiasSerie != numeroDiasConsecutivo) {
                                  serieEncontrada = null; // Não corresponde
                                }
                              }

                              // Atualizar progresso: 40% - Série encontrada/criada
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.4;
                                  _mensagemAlocacao = serieEncontrada == null
                                      ? 'A criar série...'
                                      : 'Série encontrada';
                                });
                              }

                              // Se não encontrou série, criar uma nova
                              if (serieEncontrada == null ||
                                  serieEncontrada.id.isEmpty) {
                                serieEncontrada =
                                    await DisponibilidadeSerieService
                                        .criarSerie(
                                  medicoId: medicoId,
                                  dataInicial: dataRefNormalizada,
                                  tipo: tipoDisponibilidade,
                                  horarios: horariosRef,
                                  unidade: widget.unidade,
                                );
                              }

                              // Atualizar progresso: 50% - Série pronta
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.5;
                                  _mensagemAlocacao = 'A alocar série...';
                                });
                              }

                              // Verificar se a série já está alocada neste gabinete
                              if (serieEncontrada.gabineteId == gabinete.id) {
                                if (mounted) {
                                  setState(() {
                                    _isAlocandoSerie = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'A série já está alocada neste gabinete.'),
                                      backgroundColor: Colors.blue,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                                widget.onAtualizarEstado();
                                return;
                              }

                              // Verificar se a série está alocada em outro gabinete
                              if (serieEncontrada.gabineteId != null &&
                                  serieEncontrada.gabineteId != gabinete.id) {
                                if (mounted) {
                                  final confirmacao = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Série já alocada'),
                                      content: Text(
                                        'Esta série já está alocada em outro gabinete.\n\n'
                                        'Deseja realocar a série para este gabinete?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Realocar'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmacao == false) {
                                    return;
                                  }
                                }
                              }

                              // Atualizar progresso: 30% - A atualizar série
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.6;
                                  _mensagemAlocacao = 'A atualizar série...';
                                });
                              }

                              // Atualizar o gabineteId da série

                              await DisponibilidadeSerieService.alocarSerie(
                                serieId: serieEncontrada.id,
                                medicoId: medicoId,
                                gabineteId: gabinete.id,
                                unidade: widget.unidade,
                              );

                              // Atualizar progresso: 70% - Série alocada
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.7;
                                  _mensagemAlocacao = 'A invalidar cache...';
                                });
                              }

                              // CORREÇÃO CRÍTICA: Aguardar um pouco para garantir que o Firestore salvou a série
                              // antes de invalidar cache e regenerar - aumentado para reduzir "piscar"
                              await Future.delayed(
                                  const Duration(milliseconds: 800));

                              // CORREÇÃO: Não salvar alocações individuais de séries
                              // As alocações serão geradas dinamicamente a partir da série com gabineteId
                              // Isso evita duplicação e permite séries infinitas funcionarem corretamente

                              // CORREÇÃO: Invalidar cache do dia atual e cache de séries
                              // Isso garante que as séries sejam recarregadas do servidor com o novo gabineteId
                              AlocacaoMedicosLogic.invalidateCacheForDay(
                                  dataRefNormalizada);

                              // CORREÇÃO CRÍTICA: Invalidar cache de séries para TODOS os anos do médico
                              // Isso garante que séries apareçam em todos os dias relevantes
                              AlocacaoMedicosLogic
                                  .invalidateSeriesCacheForMedico(medicoId,
                                      null); // null = invalidar todos os anos

                              // CORREÇÃO ADICIONAL: Invalidar cache de séries para o ano atual também
                              // para garantir que seja recarregado imediatamente
                              final anoSerie = dataRefNormalizada.year;
                              AlocacaoMedicosLogic.invalidateCacheFromDate(
                                  DateTime(anoSerie, 1, 1));

                              // CORREÇÃO CRÍTICA: Aguardar um pouco para garantir que o Firestore salvou a série
                              // antes de invalidar cache e regenerar - aumentado para reduzir "piscar"
                              await Future.delayed(
                                  const Duration(milliseconds: 800));

                              // CORREÇÃO: Invalidar cache ANTES de chamar onAtualizarEstado
                              // Isso garante que os dados sejam recarregados do servidor e não do cache antigo
                              final anoSerieParaCache = dataRefNormalizada.year;
                              AlocacaoMedicosLogic.invalidateCacheFromDate(
                                  DateTime(anoSerieParaCache, 1, 1));

                              // Atualizar progresso: 80% - A sincronizar
                              if (mounted) {
                                setState(() {
                                  _progressoAlocacao = 0.8;
                                  _mensagemAlocacao = 'A sincronizar...';
                                });
                              }

                              // CORREÇÃO: Aguardar tempo suficiente antes de atualizar estado
                              // Isso reduz "piscar" causado por atualizações prematuras
                              await Future.delayed(
                                  const Duration(milliseconds: 1000));

                              // CORREÇÃO CRÍTICA: Ocultar progressbar ANTES de atualizar estado
                              // Isso garante que quando a UI for atualizada, o progressbar já está oculto
                              // evitando o "piscar" do cartão
                              if (mounted) {
                                setState(() {
                                  _isAlocandoSerie = false;
                                  _progressoAlocacao = 0.0;
                                  _mensagemAlocacao = 'A iniciar...';
                                });
                              }

                              // CORREÇÃO: Aguardar tempo suficiente para garantir que o progressbar foi completamente ocultado
                              // e que a UI terminou de renderizar antes de atualizar estado
                              await Future.delayed(
                                  const Duration(milliseconds: 300));

                              // CORREÇÃO: Atualizar estado UMA ÚNICA VEZ após ocultar progressbar e aguardar renderização
                              // Isso evita o "piscar" do cartão porque o progressbar já está oculto há tempo suficiente
                              widget.onAtualizarEstado();

                              // Mostrar mensagem de sucesso
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Série alocada com sucesso'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              // Ocultar progresso em caso de erro
                              if (mounted) {
                                setState(() {
                                  _isAlocandoSerie = false;
                                  _progressoAlocacao = 0.0;
                                  _mensagemAlocacao = 'A iniciar...';
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erro ao alocar série: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        final dataSelecionada = DateTime(
                            widget.selectedDate.year,
                            widget.selectedDate.month,
                            widget.selectedDate.day);

                        final alocacoesDoGabinete = widget.alocacoes.where((a) {
                          final aData =
                              DateTime(a.data.year, a.data.month, a.data.day);
                          final corresponde = a.gabineteId == gabinete.id &&
                              aData == dataSelecionada;
                          return corresponde;
                        }).toList()
                          ..sort((a, b) => _horarioParaMinutos(a.horarioInicio)
                              .compareTo(_horarioParaMinutos(b.horarioInicio)));

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
                            if (aloc.id.startsWith('otimista_') &&
                                !existente.id.startsWith('otimista_')) {
                              // Manter a existente (real)
                            } else if (!aloc.id.startsWith('otimista_') &&
                                existente.id.startsWith('otimista_')) {
                              // Substituir pela real
                              alocacoesUnicas[chave] = aloc;
                            } else {
                              // Manter a primeira (ou a que tem ID mais recente)
                              if (aloc.id.compareTo(existente.id) > 0) {
                                alocacoesUnicas[chave] = aloc;
                              }
                            }
                          }
                        }
                        final alocacoesDoGabineteUnicas = alocacoesUnicas.values
                            .toList()
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
                                    gabinete.especialidadesPermitidas
                                        .join(", "),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Lista de médicos alocados
                                  // FILTRAR: Não mostrar alocações de médicos "Desconhecido" ou médicos não encontrados
                                  // CORREÇÃO: Ocultar médico que está sendo realocado da origem
                                  if (alocacoesDoGabineteUnicas.isNotEmpty)
                                    ...alocacoesDoGabineteUnicas.where((a) {
                                      // CORREÇÃO: Se o médico está sendo realocado, ocultar da origem
                                      if (_isRealocando &&
                                          _medicoIdEmRealocacao == a.medicoId &&
                                          _gabineteOrigemRealocacao ==
                                              gabinete.id) {
                                        // Este é o gabinete de origem e o médico está sendo realocado
                                        // Ocultar o cartão da origem durante a realocação
                                        return false;
                                      }

                                      // Verificar se o médico existe e está ativo
                                      final medico = widget.medicos.firstWhere(
                                        (m) => m.id == a.medicoId,
                                        orElse: () => Medico(
                                          id: '',
                                          nome: 'Desconhecido',
                                          especialidade: '',
                                          disponibilidades: [],
                                          ativo: false,
                                        ),
                                      );
                                      // Só mostrar se o médico foi encontrado (não é "Desconhecido") e está ativo
                                      return medico.id.isNotEmpty &&
                                          medico.ativo &&
                                          medico.nome != 'Desconhecido';
                                    }).map((a) {
                                      final medico = widget.medicos.firstWhere(
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

                                      return widget.isAdmin
                                          ? Draggable<String>(
                                              data: medico.id,
                                              feedback: MedicoCard.dragFeedback(
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

  /// Pega o n-ésimo weekday do mês (ex: 1ª terça-feira, 2ª terça-feira)
  DateTime? _pegarNthWeekdayDoMes(int ano, int mes, int weekday, int n) {
    final weekdayDia1 = DateTime(ano, mes, 1).weekday;
    final offset = (weekday - weekdayDia1 + 7) % 7;
    final primeiroNoMes = 1 + offset;
    final dia = primeiroNoMes + 7 * (n - 1);

    final ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
    if (dia <= ultimoDiaMes) {
      return DateTime(ano, mes, dia);
    }
    return null;
  }
}
