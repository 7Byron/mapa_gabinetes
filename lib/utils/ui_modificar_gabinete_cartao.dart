import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/alocacao_unica_service.dart';
import '../services/alocacao_serie_service.dart';
import '../services/realocacao_unico_service.dart';
import '../services/realocacao_serie_service.dart';
import '../services/serie_service.dart';
import '../utils/series_helper.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

/// Função unificada para modificar o gabinete de um cartão de disponibilidade
/// Funciona tanto para cartões únicos quanto para séries
/// Suporta: alocar, realocar e desalocar
/// 
/// Esta função:
/// 1. Identifica se é série ou disponibilidade única
/// 2. Para séries, pergunta se quer modificar só o dia ou toda a série
/// 3. Atualiza UI otimisticamente antes de chamar serviços
/// 4. Chama os serviços apropriados
/// 5. Atualiza o estado após concluir
/// 
/// Parâmetros:
/// - [context]: Contexto do Flutter para diálogos
/// - [disponibilidade]: Disponibilidade do cartão a ser modificado
/// - [novoGabineteId]: ID do novo gabinete (null para desalocar)
/// - [gabineteOrigem]: ID do gabinete atual (opcional, usado para realocação)
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [series]: Lista de séries (para identificar série correspondente)
/// - [medicoId]: ID do médico
/// - [unidade]: Unidade para operações no Firebase
/// - [setState]: Função para atualizar estado da UI
/// - [onProgresso]: Callback para atualizar progresso (opcional)
/// - [onAlocarMedico]: Callback para alocar médico (usado para alocação única)
/// - [onAtualizarEstado]: Callback para atualizar estado após operação
/// 
/// Retorna:
/// - `true` se a operação foi bem-sucedida
/// - `false` se houve erro ou cancelamento
Future<bool> modificarGabineteCartao({
  required BuildContext context,
  required Disponibilidade disponibilidade,
  required String? novoGabineteId,
  String? gabineteOrigem,
  required List<Alocacao> alocacoes,
  required List<SerieRecorrencia> series,
  required String medicoId,
  required Unidade? unidade,
  required VoidCallback setState,
  void Function(double progresso, String mensagem)? onProgresso,
  required Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico,
  required Future<void> Function() onAtualizarEstado, // Pode ser convertido para VoidCallback se necessário
}) async {
  try {
    final dataNormalizada = DateTime(
      disponibilidade.data.year,
      disponibilidade.data.month,
      disponibilidade.data.day,
    );

    // 1. Identificar se é série ou disponibilidade única
    final isSerie = disponibilidade.id.startsWith('serie_') ||
        disponibilidade.tipo != 'Única';

    if (!isSerie) {
      // ===== CARTAO ÚNICO =====
      return await _modificarGabineteCartaoUnico(
        context: context,
        disponibilidade: disponibilidade,
        novoGabineteId: novoGabineteId,
        gabineteOrigem: gabineteOrigem,
        alocacoes: alocacoes,
        dataNormalizada: dataNormalizada,
        medicoId: medicoId,
        unidade: unidade,
        setState: setState,
        onProgresso: onProgresso,
        onAlocarMedico: onAlocarMedico,
        onAtualizarEstado: onAtualizarEstado,
      );
    } else {
      // ===== CARTAO DE SÉRIE =====
      return await _modificarGabineteCartaoSerie(
        context: context,
        disponibilidade: disponibilidade,
        novoGabineteId: novoGabineteId,
        gabineteOrigem: gabineteOrigem,
        alocacoes: alocacoes,
        series: series,
        dataNormalizada: dataNormalizada,
        medicoId: medicoId,
        unidade: unidade,
        setState: setState,
        onProgresso: onProgresso,
        onAlocarMedico: onAlocarMedico,
        onAtualizarEstado: onAtualizarEstado,
      );
    }
  } catch (e) {
    debugPrint('❌ Erro ao modificar gabinete do cartão: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao modificar gabinete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}

/// Modifica gabinete de um cartão único
Future<bool> _modificarGabineteCartaoUnico({
  required BuildContext context,
  required Disponibilidade disponibilidade,
  required String? novoGabineteId,
  String? gabineteOrigem,
  required List<Alocacao> alocacoes,
  required DateTime dataNormalizada,
  required String medicoId,
  required Unidade? unidade,
  required VoidCallback setState,
  void Function(double progresso, String mensagem)? onProgresso,
  required Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico,
  required Future<void> Function() onAtualizarEstado, // Pode ser convertido para VoidCallback se necessário
}) async {
  // Encontrar alocação atual
  final alocacaoAtual = alocacoes.firstWhere(
    (a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          aDate == dataNormalizada &&
          !a.id.startsWith('serie_');
    },
    orElse: () => Alocacao(
      id: '',
      medicoId: '',
      gabineteId: '',
      data: DateTime(1900),
      horarioInicio: '',
      horarioFim: '',
    ),
  );

  if (novoGabineteId == null) {
    // DESALOCAR cartão único
    // Nota: onProgresso não está disponível neste escopo, usar apenas no escopo principal
    
    // Atualização otimista: remover alocação
    alocacoes.removeWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          aDate == dataNormalizada &&
          !a.id.startsWith('serie_');
    });
    setState();

    // Invalidar cache
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    // Remover do Firebase - para cartões únicos simples, remover diretamente do Firestore
    if (alocacaoAtual.id.isNotEmpty && !alocacaoAtual.id.startsWith('serie_')) {
      try {
        final firestore = FirebaseFirestore.instance;
        final ano = alocacaoAtual.data.year.toString();
        final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('alocacoes')
            .doc(ano)
            .collection('registos');
        await alocacoesRef.doc(alocacaoAtual.id).delete();
        debugPrint('✅ Alocação única removida do Firebase: ${alocacaoAtual.id}');
      } catch (e) {
        debugPrint('❌ Erro ao remover alocação do Firebase: $e');
      }
    }

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Desalocado com sucesso!');
    return true;
  } else {
    // ALOCAR ou REALOCAR cartão único
    if (alocacaoAtual.id.isNotEmpty && alocacaoAtual.gabineteId == novoGabineteId) {
      // Já está no gabinete correto
      return true;
    }

    onProgresso?.call(0.1, 'A processar...');

    if (alocacaoAtual.id.isNotEmpty && alocacaoAtual.gabineteId.isNotEmpty) {
      // REALOCAR (já está alocado em outro gabinete)
      final origem = gabineteOrigem ?? alocacaoAtual.gabineteId;
      
      // Atualização otimista
      final index = alocacoes.indexWhere((a) => a.id == alocacaoAtual.id);
      if (index != -1) {
        alocacoes[index] = Alocacao(
          id: alocacaoAtual.id,
          medicoId: alocacaoAtual.medicoId,
          gabineteId: novoGabineteId,
          data: alocacaoAtual.data,
          horarioInicio: alocacaoAtual.horarioInicio,
          horarioFim: alocacaoAtual.horarioFim,
        );
      }
      setState();

      // Invalidar cache
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      // Realocar no Firebase
      await RealocacaoUnicoService.realocar(
        medicoId: medicoId,
        gabineteOrigem: origem,
        gabineteDestino: novoGabineteId,
        data: dataNormalizada,
        alocacoes: alocacoes,
        unidade: unidade,
        context: context,
        onAlocarMedico: onAlocarMedico,
        onAtualizarEstado: onAtualizarEstado,
        onProgresso: (progresso, mensagem) {
          onProgresso?.call(0.2 + progresso * 0.6, mensagem);
        },
      );
    } else {
      // ALOCAR (novo)
      // Atualização otimista: criar alocação local
      final novaAlocacao = Alocacao(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        medicoId: medicoId,
        gabineteId: novoGabineteId,
        data: dataNormalizada,
        horarioInicio: disponibilidade.horarios.isNotEmpty
            ? disponibilidade.horarios[0]
            : '08:00',
        horarioFim: disponibilidade.horarios.length > 1
            ? disponibilidade.horarios[1]
            : '15:00',
      );
      alocacoes.add(novaAlocacao);
      setState();

      // Invalidar cache
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      // Alocar no Firebase
      await AlocacaoUnicaService.alocar(
        medicoId: medicoId,
        gabineteId: novoGabineteId,
        data: dataNormalizada,
        disponibilidade: disponibilidade,
        onAlocarMedico: onAlocarMedico,
        context: context,
        unidade: unidade,
      );
    }

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Concluído!');
    return true;
  }
}

/// Modifica gabinete de um cartão de série
Future<bool> _modificarGabineteCartaoSerie({
  required BuildContext context,
  required Disponibilidade disponibilidade,
  required String? novoGabineteId,
  String? gabineteOrigem,
  required List<Alocacao> alocacoes,
  required List<SerieRecorrencia> series,
  required DateTime dataNormalizada,
  required String medicoId,
  required Unidade? unidade,
  required VoidCallback setState,
  void Function(double progresso, String mensagem)? onProgresso,
  required Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico,
  required Future<void> Function() onAtualizarEstado, // Pode ser convertido para VoidCallback se necessário
}) async {
  // Extrair ID da série
  String? serieId;
  if (disponibilidade.id.startsWith('serie_')) {
    serieId = SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id);
    // Remover prefixo 'serie_' duplo se existir
    if (serieId.startsWith('serie_serie_')) {
      serieId = serieId.substring(7); // Remove primeiro 'serie_'
    }
  }

  // Se não encontrou pelo ID, buscar na lista de séries local
  if (serieId == null || !series.any((s) => s.id == serieId)) {
    SerieRecorrencia? serieCorrespondente;
    for (final serie in series) {
      if (serie.medicoId != medicoId ||
          serie.tipo != disponibilidade.tipo) {
        continue;
      }
      if (serie.dataInicio
          .isAfter(dataNormalizada.add(const Duration(days: 1)))) {
        continue;
      }
      if (serie.dataFim != null &&
          serie.dataFim!
              .isBefore(dataNormalizada.subtract(const Duration(days: 1)))) {
        continue;
      }
      if (!SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
          dataNormalizada, serie)) {
        continue;
      }
      serieCorrespondente = serie;
      break;
    }

    if (serieCorrespondente != null) {
      serieId = serieCorrespondente.id;
    }
  }

  // CORREÇÃO CRÍTICA: Se ainda não encontrou, buscar série do Firestore
  // Similar ao que o cadastro médico faz
  if (serieId == null || serieId.isEmpty) {
    debugPrint('⚠️ Série não encontrada localmente, buscando do Firestore...');
    try {
      // Buscar séries do Firestore
      final seriesDoFirestore = await SerieService.carregarSeries(
        medicoId,
        unidade: unidade,
        dataInicio: null,
        dataFim: null,
        forcarServidor: false,
      );

      // Tentar encontrar série correspondente
      SerieRecorrencia? serieCorrespondente;
      for (final serie in seriesDoFirestore) {
        if (serie.medicoId != medicoId ||
            serie.tipo != disponibilidade.tipo) {
          continue;
        }
        if (serie.dataInicio
            .isAfter(dataNormalizada.add(const Duration(days: 1)))) {
          continue;
        }
        if (serie.dataFim != null &&
            serie.dataFim!.isBefore(
                dataNormalizada.subtract(const Duration(days: 1)))) {
          continue;
        }
        if (!SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
            dataNormalizada, serie)) {
          continue;
        }
        serieCorrespondente = serie;
        break;
      }

      if (serieCorrespondente != null) {
        serieId = serieCorrespondente.id;
        debugPrint('✅ Série encontrada no Firestore: $serieId');
        // Adicionar à lista local para futuras referências
        if (!series.any((s) => s.id == serieId)) {
          series.add(serieCorrespondente);
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar série do Firestore: $e');
    }
  }

  if (serieId == null || serieId.isEmpty) {
    debugPrint('⚠️ Não foi possível encontrar série para disponibilidade ${disponibilidade.id}');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível encontrar a série correspondente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return false;
  }

  // Encontrar série
  final serie = series.firstWhere(
    (s) => s.id == serieId,
    orElse: () => SerieRecorrencia(
      id: '',
      medicoId: '',
      dataInicio: DateTime(1900),
      tipo: '',
      horarios: [],
      gabineteId: null,
      parametros: {},
      ativo: false,
    ),
  );

  if (serie.id.isEmpty) {
    debugPrint('⚠️ Série $serieId não encontrada na lista');
    return false;
  }

  // Encontrar alocação atual
  final alocacaoAtual = alocacoes.firstWhere(
    (a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataNormalizada;
    },
    orElse: () => Alocacao(
      id: '',
      medicoId: '',
      gabineteId: '',
      data: DateTime(1900),
      horarioInicio: '',
      horarioFim: '',
    ),
  );

  // Verificar se há exceção existente
  bool temExcecao = false;
  if (alocacaoAtual.id.isNotEmpty && serieId.isNotEmpty) {
    // Verificar se a alocação atual tem ID que indica exceção
    // Exceções têm ID no formato 'serie_${serieId}_${dataKey}'
    final serieIdPrefix = 'serie_${serieId}_';
    temExcecao = alocacaoAtual.id.startsWith(serieIdPrefix);
  }

  if (novoGabineteId == null) {
    // DESALOCAR série
    return await _desalocarSerie(
      context: context,
      disponibilidade: disponibilidade,
      serieId: serieId,
      serie: serie,
      alocacaoAtual: alocacaoAtual,
      temExcecao: temExcecao,
      dataNormalizada: dataNormalizada,
      medicoId: medicoId,
      alocacoes: alocacoes,
      unidade: unidade,
      setState: setState,
      onProgresso: onProgresso,
      onAtualizarEstado: onAtualizarEstado,
    );
  } else {
    // ALOCAR ou REALOCAR série
    // Verificar se já está no gabinete correto
    final gabineteAtual = alocacaoAtual.gabineteId.isNotEmpty
        ? alocacaoAtual.gabineteId
        : (serie.gabineteId ?? '');
    
    if (gabineteAtual == novoGabineteId) {
      return true; // Já está no gabinete correto
    }

    return await _alocarOuRealocarSerie(
      context: context,
      disponibilidade: disponibilidade,
      novoGabineteId: novoGabineteId,
      gabineteOrigem: gabineteOrigem ?? gabineteAtual,
      serieId: serieId,
      serie: serie,
      alocacaoAtual: alocacaoAtual,
      temExcecao: temExcecao,
      dataNormalizada: dataNormalizada,
      medicoId: medicoId,
      alocacoes: alocacoes,
      unidade: unidade,
      setState: setState,
      onProgresso: onProgresso,
      onAlocarMedico: onAlocarMedico,
      onAtualizarEstado: onAtualizarEstado,
    );
  }
}

/// Desaloca uma série (diálogo para escolher: só dia ou toda série)
Future<bool> _desalocarSerie({
  required BuildContext context,
  required Disponibilidade disponibilidade,
  required String serieId,
  required SerieRecorrencia serie,
  required Alocacao alocacaoAtual,
  required bool temExcecao,
  required DateTime dataNormalizada,
  required String medicoId,
  required List<Alocacao> alocacoes,
  required Unidade? unidade,
  required VoidCallback setState,
  void Function(double progresso, String mensagem)? onProgresso,
  required Future<void> Function() onAtualizarEstado, // Pode ser convertido para VoidCallback se necessário
}) async {
  // Mostrar diálogo para escolher: só dia ou toda série
  final escolha = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Desalocar gabinete'),
        content: Text(
          'Esta alocação faz parte de uma série "${disponibilidade.tipo}".\n\n'
          'Deseja desalocar apenas o dia ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year} '
          'ou deste dia para a frente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('1dia'),
            child: const Text('Apenas este dia'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('serie'),
            child: const Text('Para a frente'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );

  if (escolha == null) return false;

  onProgresso?.call(0.3, 'A desalocar...');

  if (escolha == '1dia') {
    // Desalocar apenas este dia
    alocacoes.removeWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataNormalizada;
    });
    setState();

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    await DisponibilidadeSerieService.removerGabineteDataSerie(
      serieId: serieId,
      medicoId: medicoId,
      data: dataNormalizada,
      unidade: unidade,
    );

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Desalocado com sucesso!');
    return true;
  } else {
    // Desalocar para a frente
    final gabineteOrigem = alocacaoAtual.gabineteId.isNotEmpty
        ? alocacaoAtual.gabineteId
        : (serie.gabineteId ?? '');

    if (gabineteOrigem.isEmpty) {
      return true; // Já está desalocada
    }

    // Função para verificar se data corresponde à série
    bool verificarSeDataCorrespondeSerie(DateTime data, SerieRecorrencia s) {
      final dNormalizada = DateTime(data.year, data.month, data.day);
      final inicioNormalizada = DateTime(s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
      if (dNormalizada.isBefore(inicioNormalizada)) return false;
      if (s.dataFim != null) {
        final fimNormalizada = DateTime(s.dataFim!.year, s.dataFim!.month, s.dataFim!.day);
        if (dNormalizada.isAfter(fimNormalizada)) return false;
      }

      switch (s.tipo) {
        case 'Semanal':
          return data.weekday == s.dataInicio.weekday;
        case 'Quinzenal':
          final diff = data.difference(s.dataInicio).inDays;
          return diff >= 0 && diff % 14 == 0 && data.weekday == s.dataInicio.weekday;
        case 'Mensal':
          return data.weekday == s.dataInicio.weekday;
        default:
          return true;
      }
    }

    // Remover alocações localmente para datas >= dataNormalizada
    final serieIdPrefix = 'serie_${serieId}_';
    alocacoes.removeWhere((a) {
      if (!a.id.startsWith(serieIdPrefix)) return false;
      if (a.medicoId != medicoId) return false;
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      if (aDate.isBefore(dataNormalizada)) return false;
      return verificarSeDataCorrespondeSerie(aDate, serie);
    });
    setState();

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    await DisponibilidadeSerieService.desalocarSerieAPartirDeData(
      serieId: serieId,
      medicoId: medicoId,
      dataRef: dataNormalizada,
      gabineteOrigem: gabineteOrigem,
      verificarSeDataCorrespondeSerie: verificarSeDataCorrespondeSerie,
      unidade: unidade,
    );

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Desalocado com sucesso!');
    return true;
  }
}

/// Aloca ou realoca uma série (diálogo para escolher: só dia ou toda série)
Future<bool> _alocarOuRealocarSerie({
  required BuildContext context,
  required Disponibilidade disponibilidade,
  required String novoGabineteId,
  required String gabineteOrigem,
  required String serieId,
  required SerieRecorrencia serie,
  required Alocacao alocacaoAtual,
  required bool temExcecao,
  required DateTime dataNormalizada,
  required String medicoId,
  required List<Alocacao> alocacoes,
  required Unidade? unidade,
  required VoidCallback setState,
  void Function(double progresso, String mensagem)? onProgresso,
  required Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico,
  required Future<void> Function() onAtualizarEstado, // Pode ser convertido para VoidCallback se necessário
}) async {
  // Validar horários
  if (serie.horarios.isEmpty || serie.horarios.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduza as horas de inicio e fim primeiro!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  // Mostrar diálogo
  final escolha = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(temExcecao
            ? 'Mudar gabinete do cartão?'
            : 'Mudar gabinete da série?'),
        content: Text(
          temExcecao
              ? 'Este cartão da série já foi alocado desemparelhado da série.\n\n'
                  'Deseja mudar apenas este cartão para o novo gabinete?'
              : 'Esta alocação faz parte de uma série "${disponibilidade.tipo}".\n\n'
                  'Deseja mudar apenas o dia ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year} '
                  'ou toda a série a partir deste dia para o novo gabinete?',
        ),
        actions: [
          if (!temExcecao) ...[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('1dia'),
              child: const Text('Apenas este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('serie'),
              child: const Text('Toda a série a partir deste dia'),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('1dia'),
              child: const Text('Sim, mudar cartão'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );

  if (escolha == null) return false;

  onProgresso?.call(0.3, 'A processar...');

  if (escolha == '1dia') {
    // Modificar apenas este dia
    final index = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataNormalizada;
    });

    if (index != -1) {
      alocacoes[index] = Alocacao(
        id: alocacoes[index].id,
        medicoId: alocacoes[index].medicoId,
        gabineteId: novoGabineteId,
        data: alocacoes[index].data,
        horarioInicio: alocacoes[index].horarioInicio,
        horarioFim: alocacoes[index].horarioFim,
      );
    } else {
      final dataKey = '${dataNormalizada.year}-${dataNormalizada.month}-${dataNormalizada.day}';
      alocacoes.add(Alocacao(
        id: 'serie_${serieId}_$dataKey',
        medicoId: medicoId,
        gabineteId: novoGabineteId,
        data: dataNormalizada,
        horarioInicio: disponibilidade.horarios.isNotEmpty ? disponibilidade.horarios[0] : '08:00',
        horarioFim: disponibilidade.horarios.length > 1 ? disponibilidade.horarios[1] : '15:00',
      ));
    }
    setState();

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    await DisponibilidadeSerieService.modificarGabineteDataSerie(
      serieId: serieId,
      medicoId: medicoId,
      data: dataNormalizada,
      novoGabineteId: novoGabineteId,
      unidade: unidade,
    );

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Concluído!');
    return true;
  } else {
    // Modificar toda a série
    if (gabineteOrigem.isNotEmpty && gabineteOrigem != novoGabineteId) {
      // REALOCAR série inteira
      onProgresso?.call(0.5, 'A realocar série...');

      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      // Função para verificar se data corresponde à série
      bool verificarSeDataCorrespondeSerie(DateTime data, SerieRecorrencia s) {
        final dNormalizada = DateTime(data.year, data.month, data.day);
        final inicioNormalizada = DateTime(s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
        if (dNormalizada.isBefore(inicioNormalizada)) return false;
        if (s.dataFim != null) {
          final fimNormalizada = DateTime(s.dataFim!.year, s.dataFim!.month, s.dataFim!.day);
          if (dNormalizada.isAfter(fimNormalizada)) return false;
        }

        switch (s.tipo) {
          case 'Semanal':
            return data.weekday == s.dataInicio.weekday;
          case 'Quinzenal':
            final diff = data.difference(s.dataInicio).inDays;
            return diff >= 0 && diff % 14 == 0 && data.weekday == s.dataInicio.weekday;
          case 'Mensal':
            return data.weekday == s.dataInicio.weekday;
          default:
            return true;
        }
      }

      await RealocacaoSerieService.realocar(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: novoGabineteId,
        dataRef: dataNormalizada,
        tipoSerie: disponibilidade.tipo,
        alocacoes: alocacoes,
        unidade: unidade,
        context: context,
        onRealocacaoOtimista: null, // Já feito anteriormente
        onAtualizarEstado: onAtualizarEstado, // Já é Future<void> Function()
        onProgresso: (progresso, mensagem) {
          onProgresso?.call(0.5 + progresso * 0.4, mensagem);
        },
        onRealocacaoConcluida: null,
        verificarSeDataCorrespondeSerie: verificarSeDataCorrespondeSerie,
      );
    } else {
      // ALOCAR série inteira
      onProgresso?.call(0.5, 'A alocar série...');

      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      await AlocacaoSerieService.alocar(
        medicoId: medicoId,
        gabineteId: novoGabineteId,
        data: dataNormalizada,
        disponibilidade: disponibilidade,
        unidade: unidade,
        context: context,
        onAlocacaoSerieOtimista: null,
        onAtualizarEstado: () async {
          await onAtualizarEstado();
        },
        onProgresso: (progresso, mensagem) {
          onProgresso?.call(0.5 + progresso * 0.4, mensagem);
        },
        serieIdExtraido: serieId,
      );
    }

    await onAtualizarEstado();
    onProgresso?.call(1.0, 'Concluído!');
    return true;
  }
}
