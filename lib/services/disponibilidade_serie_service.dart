// lib/services/disponibilidade_serie_service.dart

// import 'dart:convert'; // Comentado - usado apenas na instrumentação de debug
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import 'serie_service.dart';
import '../utils/alocacao_medicos_logic.dart';
// import '../utils/debug_log_file.dart'; // Comentado - usado apenas na instrumentação de debug

/// Serviço para criar séries de recorrência em vez de cartões individuais
class DisponibilidadeSerieService {
  /// Cria uma série de recorrência baseada nos parâmetros
  /// Retorna a série criada e uma lista de disponibilidades geradas (para compatibilidade)
  static Future<SerieRecorrencia> criarSerie({
    required String medicoId,
    required DateTime dataInicial,
    required String tipo,
    required List<String> horarios,
    Unidade? unidade,
    DateTime? dataFim,
    String? gabineteId,
    bool usarSerie =
        true, // Se false, cria cartões individuais (compatibilidade)
    Map<String, dynamic>? parametros,
  }) async {
    // Se não deve usar série, retornar série vazia (será tratado pelo código antigo)
    if (!usarSerie) {
      throw UnimplementedError('Modo de compatibilidade não implementado aqui');
    }

    // Criar ID único para a série
    final serieId = 'serie_${DateTime.now().millisecondsSinceEpoch}';

    // Preparar parâmetros específicos
    Map<String, dynamic> parametrosFinal = parametros ?? {};
    if (tipo.startsWith('Consecutivo:')) {
      final numeroDiasStr = tipo.split(':')[1];
      final numeroDias = int.tryParse(numeroDiasStr) ?? 5;
      parametrosFinal['numeroDias'] = numeroDias;
      tipo = 'Consecutivo';
    }

    final dataInicialNormalizada =
        DateTime(dataInicial.year, dataInicial.month, dataInicial.day);
    final dataFimNormalizada = dataFim == null
        ? null
        : DateTime(dataFim.year, dataFim.month, dataFim.day);

    // Criar série
    final serie = SerieRecorrencia(
      id: serieId,
      medicoId: medicoId,
      dataInicio: dataInicialNormalizada,
      dataFim: dataFimNormalizada,
      tipo: tipo,
      horarios: horarios,
      gabineteId: gabineteId,
      parametros: parametrosFinal,
      ativo: true,
    );

    // #region agent log (COMENTADO - pode ser reativado se necessário)

//    try {
//      final logEntry = {
//        'timestamp': DateTime.now().millisecondsSinceEpoch,
//        'location': 'disponibilidade_serie_service.dart:59',
//        'message': '🔵 [HYP-A] Criando série - ANTES de salvar',
//        'data': {
//          'serieId': serie.id,
//          'medicoId': medicoId,
//          'tipo': tipo,
//          'dataInicio': dataInicial.toString(),
//          'dataFim': dataFim?.toString() ?? 'null',
//          'ativo': true,
//          'hypothesisId': 'A'
//        },
//        'sessionId': 'debug-session',
//        'runId': 'run1',
//      };
//      writeLogToFile(jsonEncode(logEntry));
//    } catch (e) {}

// #endregion

    // Salvar no Firestore
    await SerieService.salvarSerie(serie, unidade: unidade);

    // #region agent log (COMENTADO - pode ser reativado se necessário)

//    try {
//      final logEntry = {
//        'timestamp': DateTime.now().millisecondsSinceEpoch,
//        'location': 'disponibilidade_serie_service.dart:75',
//        'message': '🟢 [HYP-A] Série salva no Firestore - DEPOIS de salvar',
//        'data': {
//          'serieId': serie.id,
//          'medicoId': medicoId,
//          'tipo': tipo,
//          'dataInicio': dataInicial.toString(),
//          'hypothesisId': 'A'
//        },
//        'sessionId': 'debug-session',
//        'runId': 'run1',
//      };
//      writeLogToFile(jsonEncode(logEntry));
//    } catch (e) {}

// #endregion

    // CORREÇÃO CRÍTICA: Invalidar cache para todos os dias que esta série afeta
    // Isso garante que quando o utilizador navega para qualquer dia da série,
    // os dados serão recarregados do servidor e estarão atualizados
    AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);

    debugPrint(
        '✅ Série criada: $tipo para médico $medicoId a partir de ${dataInicial.day}/${dataInicial.month}/${dataInicial.year}');

    return serie;
  }

  /// Converte uma disponibilidade antiga em uma série (migração)
  static Future<SerieRecorrencia?> converterDisponibilidadeParaSerie(
    Disponibilidade disponibilidade, {
    Unidade? unidade,
  }) async {
    // Se já é única, não precisa converter
    if (disponibilidade.tipo == 'Única') {
      return null;
    }

    try {
      final serie = await criarSerie(
        medicoId: disponibilidade.medicoId,
        dataInicial: disponibilidade.data,
        tipo: disponibilidade.tipo,
        horarios: disponibilidade.horarios,
        unidade: unidade,
      );

      return serie;
    } catch (e) {
      debugPrint('❌ Erro ao converter disponibilidade para série: $e');
      return null;
    }
  }

  /// Cria uma exceção para cancelar uma data específica de uma série
  static Future<List<ExcecaoSerie>> cancelarDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    Unidade? unidade,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final excecoesExistentes = await SerieService.carregarExcecoes(
      medicoId,
      unidade: unidade,
      dataInicio: dataNormalizada,
      dataFim: dataNormalizada,
      serieId: serieId,
      forcarServidor: true,
    );

    final excecoesParaData = excecoesExistentes
        .where(
          (e) =>
              e.serieId == serieId &&
              e.data.year == dataNormalizada.year &&
              e.data.month == dataNormalizada.month &&
              e.data.day == dataNormalizada.day,
        )
        .toList();

    final excecoesCanceladas = <ExcecaoSerie>[];
    var gravouAlteracao = false;

    if (excecoesParaData.isEmpty) {
      final excecao = ExcecaoSerie(
        id: 'excecao_${serieId}_${dataNormalizada.millisecondsSinceEpoch}',
        serieId: serieId,
        data: dataNormalizada,
        cancelada: true,
      );

      await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
      excecoesCanceladas.add(excecao);
      gravouAlteracao = true;
    } else {
      for (final excecaoExistente in excecoesParaData) {
        final excecaoCancelada = ExcecaoSerie(
          id: excecaoExistente.id,
          serieId: excecaoExistente.serieId,
          data: dataNormalizada,
          cancelada: true,
        );

        excecoesCanceladas.add(excecaoCancelada);

        if (!excecaoExistente.cancelada ||
            excecaoExistente.gabineteId != null ||
            excecaoExistente.horarios != null) {
          await SerieService.salvarExcecao(
            excecaoCancelada,
            medicoId,
            unidade: unidade,
          );
          gravouAlteracao = true;
        }
      }
    }

    // CORREÇÃO CRÍTICA: Invalidar cache para o dia específico e do ano
    // SerieService.salvarExcecao já invalida, mas garantimos aqui também
    AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

    // Invalidar também cache de séries para garantir que exceções sejam carregadas
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    SerieService.invalidateCacheSeries(unidadeId, medicoId);

    if (!gravouAlteracao) {
      debugPrint(
          'ℹ️ Exceção cancelada já existia: data ${data.day}/${data.month}/${data.year} para série $serieId');
      return excecoesCanceladas;
    }

    debugPrint(
        '✅ Exceção criada: data ${data.day}/${data.month}/${data.year} cancelada para série $serieId');

    return excecoesCanceladas;
  }

  /// Cria uma exceção para modificar horários de uma data específica
  static Future<void> modificarHorariosDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required List<String> horarios,
    Unidade? unidade,
  }) async {
    final excecaoId = 'excecao_${data.millisecondsSinceEpoch}';

    final excecao = ExcecaoSerie(
      id: excecaoId,
      serieId: serieId,
      data: data,
      cancelada: false,
      horarios: horarios,
    );

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);

    // CORREÇÃO CRÍTICA: Invalidar cache para o dia específico e do ano
    // SerieService.salvarExcecao já invalida, mas garantimos aqui também
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

    // Invalidar também cache de séries para garantir que exceções sejam carregadas
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    SerieService.invalidateCacheSeries(unidadeId, medicoId);

    debugPrint(
        '✅ Exceção criada: horários modificados para data ${data.day}/${data.month}/${data.year}');
  }

  /// Remove o gabinete de uma data específica de uma série (exceção de gabinete)
  /// O médico fica sem gabinete neste dia mas continua disponível
  static Future<void> removerGabineteDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    Unidade? unidade,
  }) async {
    // Normalizar a data para garantir correspondência exata
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // Verificar se já existe uma exceção para esta série e data
    final excecoesExistentes = await SerieService.carregarExcecoes(
      medicoId,
      unidade: unidade,
      dataInicio: dataNormalizada,
      dataFim: dataNormalizada,
      serieId: serieId,
      forcarServidor: true,
    );

    ExcecaoSerie excecao;

    // Encontrar TODAS as exceções para esta data (incluindo canceladas, pois podemos reativá-las)
    final excecoesParaData = excecoesExistentes
        .where(
          (e) =>
              e.serieId == serieId &&
              e.data.year == dataNormalizada.year &&
              e.data.month == dataNormalizada.month &&
              e.data.day == dataNormalizada.day,
        )
        .toList();

    // Separar exceções canceladas e não canceladas
    final excecoesNaoCanceladas =
        excecoesParaData.where((e) => !e.cancelada).toList();
    final excecoesCanceladas =
        excecoesParaData.where((e) => e.cancelada).toList();

    if (excecoesNaoCanceladas.isNotEmpty) {
      // Se há múltiplas exceções não canceladas, cancelar todas exceto a primeira
      if (excecoesNaoCanceladas.length > 1) {
        debugPrint(
            '⚠️ [DUPLICAÇÃO] Encontradas ${excecoesNaoCanceladas.length} exceções não canceladas para a mesma data! Cancelando duplicatas...');

        for (int i = 1; i < excecoesNaoCanceladas.length; i++) {
          final excecaoDuplicada = ExcecaoSerie(
            id: excecoesNaoCanceladas[i].id,
            serieId: excecoesNaoCanceladas[i].serieId,
            data: excecoesNaoCanceladas[i].data,
            cancelada: true,
            horarios: excecoesNaoCanceladas[i].horarios,
            gabineteId: excecoesNaoCanceladas[i].gabineteId,
          );
          await SerieService.salvarExcecao(excecaoDuplicada, medicoId,
              unidade: unidade);
        }
      }

      // Atualizar exceção existente removendo o gabinete (gabineteId: null)
      final excecaoExistente = excecoesNaoCanceladas[0];
      excecao = ExcecaoSerie(
        id: excecaoExistente.id,
        serieId: excecaoExistente.serieId,
        data: excecaoExistente.data,
        cancelada:
            false, // IMPORTANTE: Não cancelada - é exceção de gabinete, não de disponibilidade
        horarios: excecaoExistente.horarios,
        gabineteId:
            null, // Remover gabinete - médico fica sem gabinete mas disponível
      );
      debugPrint(
          '🔄 Atualizando exceção existente para remover gabinete: ${excecao.id}');
    } else if (excecoesCanceladas.isNotEmpty) {
      // Se há exceção cancelada, reativá-la como exceção de gabinete (não cancelada, sem gabinete)
      final excecaoCancelada = excecoesCanceladas[0];
      excecao = ExcecaoSerie(
        id: excecaoCancelada.id,
        serieId: excecaoCancelada.serieId,
        data: excecaoCancelada.data,
        cancelada: false, // Reativar como exceção de gabinete (não cancelada)
        horarios: excecaoCancelada.horarios,
        gabineteId:
            null, // Sem gabinete - médico fica disponível mas sem gabinete
      );
      debugPrint(
          '🔄 Reativando exceção cancelada como exceção de gabinete: ${excecao.id}');
    } else {
      // Criar nova exceção de gabinete (sem gabinete)
      final excecaoId =
          'excecao_${serieId}_${dataNormalizada.millisecondsSinceEpoch}';
      excecao = ExcecaoSerie(
        id: excecaoId,
        serieId: serieId,
        data: dataNormalizada,
        cancelada: false, // IMPORTANTE: Não cancelada - é exceção de gabinete
        gabineteId:
            null, // Sem gabinete - médico fica disponível mas sem gabinete
      );
      debugPrint(
          '➕ Criando nova exceção de gabinete (sem gabinete): ${excecao.id}');
    }

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);

    // Invalidar cache
    AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(dataNormalizada.year, 1, 1));

    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    SerieService.invalidateCacheSeries(unidadeId, medicoId);

    debugPrint(
        '✅ Exceção de gabinete salva: ID=${excecao.id}, série=$serieId, data=${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, gabinete=null (removido)');
  }

  /// Cria uma exceção para modificar o gabinete de uma data específica de uma série
  static Future<void> modificarGabineteDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required String novoGabineteId,
    Unidade? unidade,
  }) async {
    // Normalizar a data para garantir correspondência exata
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // Verificar se já existe uma exceção para esta série e data
    // CORREÇÃO: Forçar servidor para garantir que exceções recém-criadas sejam encontradas
    final excecoesExistentes = await SerieService.carregarExcecoes(
      medicoId,
      unidade: unidade,
      dataInicio: dataNormalizada,
      dataFim: dataNormalizada,
      serieId: serieId,
      forcarServidor: true, // Forçar servidor para garantir dados atualizados
    );

    ExcecaoSerie excecao;

    // CORREÇÃO CRÍTICA: Encontrar TODAS as exceções para esta data (não apenas a primeira)
    // Isso evita duplicação quando há múltiplas exceções
    final excecoesParaData = excecoesExistentes
        .where(
          (e) =>
              e.serieId == serieId &&
              e.data.year == dataNormalizada.year &&
              e.data.month == dataNormalizada.month &&
              e.data.day == dataNormalizada.day &&
              !e.cancelada,
        )
        .toList();

    if (excecoesParaData.isNotEmpty) {
      // CORREÇÃO CRÍTICA: Se há múltiplas exceções, cancelar todas exceto a primeira
      // Depois atualizar a primeira com o novo gabinete
      if (excecoesParaData.length > 1) {
        debugPrint(
            '⚠️ [DUPLICAÇÃO] Encontradas ${excecoesParaData.length} exceções para a mesma data! Cancelando duplicatas...');

        // Cancelar todas as exceções exceto a primeira
        for (int i = 1; i < excecoesParaData.length; i++) {
          final excecaoDuplicada = ExcecaoSerie(
            id: excecoesParaData[i].id,
            serieId: excecoesParaData[i].serieId,
            data: excecoesParaData[i].data,
            cancelada: true,
            horarios: excecoesParaData[i].horarios,
            gabineteId: excecoesParaData[i].gabineteId,
          );
          await SerieService.salvarExcecao(excecaoDuplicada, medicoId,
              unidade: unidade);
          debugPrint(
              '🗑️ Exceção duplicada cancelada: ${excecoesParaData[i].id}');
        }
      }

      // Usar a primeira exceção e atualizar com o novo gabinete
      final excecaoExistente = excecoesParaData[0];
      excecao = ExcecaoSerie(
        id: excecaoExistente.id,
        serieId: excecaoExistente.serieId,
        data: excecaoExistente.data,
        cancelada: false, // Garantir que não está cancelada
        horarios:
            excecaoExistente.horarios, // Manter horários existentes se houver
        gabineteId: novoGabineteId, // Atualizar o gabinete
      );
      debugPrint('🔄 Atualizando exceção existente: ${excecao.id}');
    } else {
      // Criar nova exceção
      final excecaoId =
          'excecao_${serieId}_${dataNormalizada.millisecondsSinceEpoch}';
      excecao = ExcecaoSerie(
        id: excecaoId,
        serieId: serieId,
        data: dataNormalizada,
        cancelada: false,
        gabineteId: novoGabineteId,
      );
      debugPrint('➕ Criando nova exceção: ${excecao.id}');
    }

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);

    // CORREÇÃO CRÍTICA: Invalidar cache do dia específico para garantir que mudanças apareçam imediatamente
    // Isso é especialmente importante quando um administrador faz alterações
    AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    // Também invalidar cache do ano para garantir que todas as alocações sejam atualizadas
    AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(dataNormalizada.year, 1, 1));

    // Invalidar cache de séries para garantir que exceções sejam carregadas corretamente
    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    SerieService.invalidateCacheSeries(unidadeId, medicoId);

    debugPrint(
        '✅ Exceção salva: ID=${excecao.id}, série=$serieId, data=${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, gabinete=$novoGabineteId');
    debugPrint(
        '   📋 Detalhes: dataKey=${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}, chaveEsperada=${serieId}_${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}');
  }

  /// Aloca uma série inteira a um gabinete
  static Future<void> alocarSerie({
    required String serieId,
    required String medicoId,
    required String gabineteId,
    Unidade? unidade,
  }) async {
    try {
      // CORREÇÃO CRÍTICA: Invalidar cache ANTES de carregar para garantir dados atualizados
      // Isso é especialmente importante após desalocar uma série, para garantir que
      // quando tentamos alocar novamente, carregamos a série atualizada (gabineteId: null)
      final unidadeIdTemp = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      SerieService.invalidateCacheSeries(unidadeIdTemp, medicoId);

      // Aguardar um pouco para garantir que o cache foi invalidado
      await Future.delayed(const Duration(milliseconds: 100));

      // CORREÇÃO CRÍTICA: Forçar carregamento do servidor para garantir que temos
      // a versão mais recente da série antes de atualizar
      final series = await SerieService.carregarSeries(medicoId,
          unidade: unidade, forcarServidor: true);

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      try {
//        final serieEncontradaLog = series.where((s) => s.id == serieId).isNotEmpty
//            ? series.firstWhere((s) => s.id == serieId).gabineteId
//            : null;
//        final logEntry = {
//          'timestamp': DateTime.now().millisecondsSinceEpoch,
//          'location': 'disponibilidade_serie_service.dart:alocarSerie',
//          'message': 'Série carregada do servidor ANTES de alocar',
//          'data': {
//            'serieId': serieId,
//            'medicoId': medicoId,
//            'totalSeries': series.length,
//            'serieEncontrada': series.any((s) => s.id == serieId),
//            'gabineteIdAtual': serieEncontradaLog,
//            'novoGabineteId': gabineteId,
//            'hypothesisId': 'A'
//          },
//          'sessionId': 'debug-session',
//          'runId': 'run1',
//        };
//        debugPrint('📝 [DEBUG] ${logEntry['message']}: serieId=$serieId, gabineteIdAtual=$serieEncontradaLog');
//      } catch (e) {}

// #endregion

      final serie = series.firstWhere(
        (s) => s.id == serieId,
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

      // CORREÇÃO: Se não encontrou a série, tentar buscar diretamente do Firestore
      if (serie.id.isEmpty) {
        debugPrint(
            '⚠️ Série não encontrada no cache, buscando diretamente do Firestore...');
        final firestore = FirebaseFirestore.instance;
        final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
        final serieDoc = await firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .doc(medicoId)
            .collection('series')
            .doc(serieId)
            .get(const GetOptions(source: Source.server));

        if (!serieDoc.exists) {
          throw Exception('Série $serieId não encontrada no Firestore');
        }

        final serieData = serieDoc.data();
        if (serieData == null) {
          throw Exception('Dados da série $serieId estão vazios');
        }

        final serieCarregada =
            SerieRecorrencia.fromMap({...serieData, 'id': serieDoc.id});

        // Atualizar série com gabinete
        final serieAtualizada = SerieRecorrencia(
          id: serieCarregada.id,
          medicoId: serieCarregada.medicoId,
          dataInicio: serieCarregada.dataInicio,
          dataFim: serieCarregada.dataFim,
          tipo: serieCarregada.tipo,
          horarios: serieCarregada.horarios,
          gabineteId: gabineteId,
          parametros: serieCarregada.parametros,
          ativo: serieCarregada.ativo,
        );

        await SerieService.salvarSerie(serieAtualizada, unidade: unidade);
        debugPrint(
            '✅ Série atualizada diretamente do Firestore: ${serieAtualizada.id}');
        return;
      }

      // Atualizar série com gabinete
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: gabineteId,
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      try {
//        final logEntry = {
//          'timestamp': DateTime.now().millisecondsSinceEpoch,
//          'location': 'disponibilidade_serie_service.dart:alocarSerie-salva',
//          'message': 'Série salva no Firestore',
//          'data': {
//            'serieId': serieId,
//            'medicoId': medicoId,
//            'gabineteIdAnterior': serie.gabineteId,
//            'gabineteIdNovo': gabineteId,
//            'hypothesisId': 'A'
//          },
//          'sessionId': 'debug-session',
//          'runId': 'run1',
//        };
//        debugPrint('📝 [DEBUG] ${logEntry['message']}: serieId=$serieId, gabineteIdAnterior=${serie.gabineteId}, gabineteIdNovo=$gabineteId');
//        writeLogToFile(jsonEncode(logEntry));
//      } catch (e) {}

// #endregion

      // CORREÇÃO CRÍTICA: Aguardar após salvar para garantir que a escrita foi persistida
      await Future.delayed(const Duration(milliseconds: 500));

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      try {
//        final logEntry = {
//          'timestamp': DateTime.now().millisecondsSinceEpoch,
//          'location': 'disponibilidade_serie_service.dart:alocarSerie-apos-delay',
//          'message': 'Depois de aguardar 500ms após salvar',
//          'data': {
//            'serieId': serieId,
//            'medicoId': medicoId,
//            'gabineteIdNovo': gabineteId,
//            'hypothesisId': 'A'
//          },
//          'sessionId': 'debug-session',
//          'runId': 'run1',
//        };
//        writeLogToFile(jsonEncode(logEntry));
//      } catch (e) {}

// #endregion

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      // Isso garante que quando o utilizador navega para qualquer dia da série,
      // as alocações geradas estarão visíveis imediatamente
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada,
          unidade: unidade);

      debugPrint('✅ Série alocada ao gabinete $gabineteId');
    } catch (e) {
      debugPrint('❌ Erro ao alocar série: $e');
      rethrow;
    }
  }

  /// Desaloca uma série (remove o gabineteId)
  static Future<void> desalocarSerie({
    required String serieId,
    required String medicoId,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series =
          await SerieService.carregarSeries(medicoId, unidade: unidade);
      final serie = series.firstWhere((s) => s.id == serieId);

      // Atualizar série removendo o gabineteId (definindo como null)
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: null, // Remove a alocação
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);

      // CORREÇÃO CRÍTICA: Invalidar cache de séries para forçar recarregamento
      // Isso garante que quando tentamos alocar novamente, o sistema recarrega do servidor
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      SerieService.invalidateCacheSeries(unidadeId, medicoId);

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      // Isso garante que quando o utilizador navega para qualquer dia da série,
      // as alocações serão removidas imediatamente
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada,
          unidade: unidade);

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      try {
//        final logEntry = {
//          'timestamp': DateTime.now().millisecondsSinceEpoch,
//          'location': 'disponibilidade_serie_service.dart:desalocarSerie',
//          'message': 'Série desalocada - gabineteId removido',
//          'data': {
//            'serieId': serieId,
//            'medicoId': medicoId,
//            'gabineteIdAntes': serie.gabineteId,
//            'gabineteIdDepois': null,
//            'hypothesisId': 'B'
//          },
//          'sessionId': 'debug-session',
//          'runId': 'run1',
//        };
//        debugPrint('📝 [DEBUG] ${logEntry['message']}: serieId=$serieId');
//      } catch (e) {}

// #endregion

      debugPrint('✅ Série desalocada (gabinete removido)');
    } catch (e) {
      debugPrint('❌ Erro ao desalocar série: $e');
      rethrow;
    }
  }

  /// Desaloca uma série a partir de uma data específica (mantém gabinete nas datas anteriores)
  static Future<void> desalocarSerieAPartirDeData({
    required String serieId,
    required String medicoId,
    required DateTime dataRef,
    required String gabineteOrigem,
    required bool Function(DateTime data, SerieRecorrencia serie)
        verificarSeDataCorrespondeSerie,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series = await SerieService.carregarSeries(medicoId,
          unidade: unidade, forcarServidor: true);
      final serie = series.firstWhere((s) => s.id == serieId);

      final dataRefNormalizada =
          DateTime(dataRef.year, dataRef.month, dataRef.day);
      final dataInicioSerie = DateTime(
        serie.dataInicio.year,
        serie.dataInicio.month,
        serie.dataInicio.day,
      );

      // CORREÇÃO: Ao desalocar a partir de uma data, simplesmente remover o gabineteId da série
      // e criar exceções apenas para manter gabinete nas datas anteriores (se necessário)
      // NÃO criar exceções para datas futuras - isso é desnecessário e ineficiente

      final dataFimSerie = serie.dataFim ?? DateTime(dataRef.year + 1, 12, 31);
      final dataFimProcessamento =
          DateTime(dataFimSerie.year, dataFimSerie.month, dataFimSerie.day);

      // Carregar todas as exceções existentes de uma vez (mais eficiente)
      final excecoesExistentes = await SerieService.carregarExcecoes(
        medicoId,
        unidade: unidade,
        dataInicio: dataInicioSerie,
        dataFim: dataFimProcessamento,
        serieId: serieId,
        forcarServidor: true,
      );

      // Criar mapa de exceções por data para busca rápida
      final excecoesPorData = <String, ExcecaoSerie>{};
      for (final excecao in excecoesExistentes) {
        if (excecao.serieId == serieId && !excecao.cancelada) {
          final dataKey =
              '${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
          excecoesPorData[dataKey] = excecao;
        }
      }

      // Passo 1: Criar exceções para manter o gabinete original nas datas anteriores
      if (dataRefNormalizada.isAfter(dataInicioSerie)) {
        DateTime dataAtual = dataInicioSerie;
        while (dataAtual.isBefore(dataRefNormalizada)) {
          if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
            final dataKey =
                '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
            final excecaoExistente = excecoesPorData[dataKey];

            // CORREÇÃO: Sempre criar/atualizar exceção para manter o gabinete original nas datas anteriores
            // Mesmo que já exista exceção com gabineteId == null, precisamos substituí-la para manter o gabinete
            // quando desalocamos apenas "a partir de uma data"
            if (excecaoExistente == null) {
              // Não há exceção - criar exceção para manter o gabinete original
              await modificarGabineteDataSerie(
                serieId: serieId,
                medicoId: medicoId,
                data: dataAtual,
                novoGabineteId:
                    gabineteOrigem, // Manter gabinete original nas datas anteriores
                unidade: unidade,
              );
            } else if (excecaoExistente.gabineteId != gabineteOrigem) {
              // Há exceção mas com gabinete diferente ou null - atualizar para manter gabinete original
              await modificarGabineteDataSerie(
                serieId: serieId,
                medicoId: medicoId,
                data: dataAtual,
                novoGabineteId:
                    gabineteOrigem, // Manter gabinete original nas datas anteriores
                unidade: unidade,
              );
            }
            // Se excecaoExistente.gabineteId == gabineteOrigem, já está correto, não precisa fazer nada
          }
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // Passo 2: Criar exceções com gabineteId: null para datas >= dataRef (desalocar apenas para a frente)
      // NÃO remover o gabineteId da série - isso faria com que buscarAlocacoesMedico não gerasse alocações
      // Em vez disso, criar exceções com gabineteId: null apenas para datas >= dataRef
      // Isso mantém o gabineteId da série, mas as exceções sobrepõem-se para datas futuras
      DateTime dataAtual = dataRefNormalizada;
      while (!dataAtual.isAfter(dataFimSerie)) {
        if (verificarSeDataCorrespondeSerie(dataAtual, serie)) {
          final dataKey =
              '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
          final excecaoExistente = excecoesPorData[dataKey];

          if (excecaoExistente == null) {
            // Criar exceção sem gabinete para esta data (apenas datas >= dataRef)
            await removerGabineteDataSerie(
              serieId: serieId,
              medicoId: medicoId,
              data: dataAtual,
              unidade: unidade,
            );
          } else if (excecaoExistente.gabineteId != null) {
            // Atualizar exceção existente para remover gabinete (apenas datas >= dataRef)
            await removerGabineteDataSerie(
              serieId: serieId,
              medicoId: medicoId,
              data: dataAtual,
              unidade: unidade,
            );
          }
          // Se excecaoExistente.gabineteId == null, já está correto, não precisa fazer nada
        }
        dataAtual = dataAtual.add(const Duration(days: 1));
      }

      // NÃO remover o gabineteId da série - mantê-lo para que buscarAlocacoesMedico possa gerar alocações
      // As exceções criadas acima sobrepõem-se para datas futuras

      // Invalidar cache da série completa
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      SerieService.invalidateCacheSeries(unidadeId, medicoId);
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);

      debugPrint(
          '✅ Série desalocada a partir de ${dataRef.day}/${dataRef.month}/${dataRef.year} (exceções criadas para manter gabinete nas datas anteriores e desalocar datas >= dataRef)');
    } catch (e) {
      debugPrint('❌ Erro ao desalocar série a partir de data: $e');
      rethrow;
    }
  }
}
