// lib/services/serie_generator.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/debug_log_file.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';

// #region agent log helper
void _writeDebugLog(
    String location, String message, Map<String, dynamic> data) {
  try {
    final logEntry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'data': data,
      'sessionId': 'debug-session',
      'runId': 'run1',
    };
    writeLogToFile(jsonEncode(logEntry));
  } catch (e) {
    // Ignorar erros de escrita de log
  }
}
// #endregion

/// Gera cartões de disponibilidade/alocação dinamicamente baseado em regras de recorrência
class SerieGenerator {
  /// Gera lista de disponibilidades para um período baseado em regras e exceções
  static List<Disponibilidade> gerarDisponibilidades({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
    required DateTime dataInicio,
    required DateTime dataFim,
  }) {
    final disponibilidades = <Disponibilidade>[];
    // Indexar exceções por sérieId e data (serieId_dataKey)
    final excecoesMap = <String, ExcecaoSerie>{};

    // Indexar exceções por sérieId e data para evitar conflitos entre séries
    for (final excecao in excecoes) {
      // CORREÇÃO CRÍTICA: Normalizar a data da exceção antes de criar a chave
      // Isso garante correspondência exata mesmo se a data tiver horas/minutos/segundos
      final dataNormalizada = DateTime(
        excecao.data.year,
        excecao.data.month,
        excecao.data.day,
      );
      final dataKey = _dataKey(dataNormalizada);
      final chave = '${excecao.serieId}_$dataKey';
      excecoesMap[chave] = excecao;

      // Debug: mostrar exceções canceladas sendo indexadas
      if (excecao.cancelada) {
        debugPrint(
            '🚫 [EXCEÇÃO CANCELADA] Indexada: série=${excecao.serieId}, data=$dataKey, chave=$chave');
        // #region agent log
        if (dataNormalizada.year == 2026 &&
            (dataNormalizada.month == 2 &&
                (dataNormalizada.day == 9 ||
                    dataNormalizada.day == 12 ||
                    dataNormalizada.day == 16))) {
          _writeDebugLog(
              'serie_generator.dart:40', 'Exceção cancelada indexada', {
            'serieId': excecao.serieId,
            'data': dataKey,
            'chave': chave,
            'cancelada': excecao.cancelada,
            'hypothesisId': 'B'
          });
        }
        // #endregion
      }
    }

    // Para cada série, gerar cartões no período
    for (final serie in series) {
      if (!serie.ativo) continue;

      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_generator.dart:76',
          'message': 'Processando série',
          'data': {
            'serieId': serie.id,
            'tipo': serie.tipo,
            'medicoId': serie.medicoId,
            'dataInicio': serie.dataInicio.toString(),
            'dataFim': serie.dataFim?.toString(),
            'hypothesisId': 'E'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

      final cartoes = _gerarCartoesDaSerie(
        serie: serie,
        dataInicio: dataInicio,
        dataFim: dataFim,
        excecoesMap: excecoesMap,
      );

      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_generator.dart:76',
          'message': 'Série processada',
          'data': {
            'serieId': serie.id,
            'numCartoes': cartoes.length,
            'hypothesisId': 'E'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

      disponibilidades.addAll(cartoes);
    }

    // #region agent log
    try {
      final logEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'location': 'serie_generator.dart:90',
        'message': 'Ordenando disponibilidades',
        'data': {
          'numDisponibilidades': disponibilidades.length,
          'hypothesisId': 'E'
        },
        'sessionId': 'debug-session',
        'runId': 'run1',
      };
      writeLogToFile(jsonEncode(logEntry));
    } catch (e) {}
    // #endregion

    // Ordenar por data
    disponibilidades.sort((a, b) => a.data.compareTo(b.data));

    // #region agent log
    try {
      final logEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'location': 'serie_generator.dart:92',
        'message': 'gerarDisponibilidades concluído',
        'data': {
          'numDisponibilidades': disponibilidades.length,
          'hypothesisId': 'E'
        },
        'sessionId': 'debug-session',
        'runId': 'run1',
      };
      writeLogToFile(jsonEncode(logEntry));
    } catch (e) {}
    // #endregion

    return disponibilidades;
  }

  /// Gera lista de alocações para um período baseado em regras e exceções
  static List<Alocacao> gerarAlocacoes({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
    required DateTime dataInicio,
    required DateTime dataFim,
  }) {
    final alocacoes = <Alocacao>[];
    // Indexar exceções por sérieId e data (serieId_dataKey)
    final excecoesMap = <String, ExcecaoSerie>{};

    // Debug: mostrar exceções recebidas
    if (excecoes.isNotEmpty) {
      final excecoesComGabinete =
          excecoes.where((e) => e.gabineteId != null).toList();
      if (excecoesComGabinete.isNotEmpty) {
        debugPrint(
            '🔍 SerieGenerator recebeu ${excecoes.length} exceções (${excecoesComGabinete.length} com gabinete)');
      }
    }

    // Indexar exceções por sérieId e data para evitar conflitos entre séries
    for (final excecao in excecoes) {
      // Normalizar a data da exceção para garantir correspondência exata
      final dataNormalizada = DateTime(
        excecao.data.year,
        excecao.data.month,
        excecao.data.day,
      );
      final dataKey = _dataKey(dataNormalizada);
      final chave = '${excecao.serieId}_$dataKey';
      excecoesMap[chave] = excecao;
      // Debug para exceções com gabineteId
      if (excecao.gabineteId != null) {
        debugPrint(
            '📋 Exceção indexada: série=${excecao.serieId}, data=$dataKey, chave=$chave, gabinete=${excecao.gabineteId}');
      }
    }

    // Para cada série com gabinete alocado, gerar alocações
    for (final serie in series) {
      if (!serie.ativo || serie.gabineteId == null) continue;

      final cartoes = _gerarCartoesDaSerie(
        serie: serie,
        dataInicio: dataInicio,
        dataFim: dataFim,
        excecoesMap: excecoesMap,
      );

      // Converter disponibilidades em alocações
      for (final disp in cartoes) {
        // Normalizar a data para garantir correspondência exata
        final dataNormalizada = DateTime(
          disp.data.year,
          disp.data.month,
          disp.data.day,
        );
        final dataKey = _dataKey(dataNormalizada);
        final chave = '${serie.id}_$dataKey';
        final excecao = excecoesMap[chave];

        // Removidos logs excessivos para melhorar performance
        // (Logs de debug apenas quando necessário para troubleshooting)

        // Se cancelada, não criar alocação
        if (excecao?.cancelada ?? false) continue;

        // CORREÇÃO: Se há exceção com gabineteId (alocação individual), gerar alocação da exceção
        // e NÃO da série. Se não há exceção, gerar alocação da série.
        final String gabineteIdFinal;
        final List<String> horariosFinal;
        final String idAlocacao;

        if (excecao?.gabineteId != null) {
          // Há exceção individual: gerar alocação da exceção (não da série)
          gabineteIdFinal = excecao!.gabineteId!;
          horariosFinal = excecao.horarios ?? disp.horarios;
          idAlocacao = 'serie_${serie.id}_${_dataKey(disp.data)}';
          debugPrint(
              '✅ Gerando alocação da exceção: data=$dataKey, gabinete=$gabineteIdFinal (exceção individual)');
        } else {
          // Não há exceção: gerar alocação normal da série
          gabineteIdFinal = serie.gabineteId!;
          horariosFinal = disp.horarios;
          idAlocacao = 'serie_${serie.id}_${_dataKey(disp.data)}';
        }

        if (horariosFinal.isEmpty) continue;

        final alocacao = Alocacao(
          id: idAlocacao,
          medicoId: serie.medicoId,
          gabineteId: gabineteIdFinal,
          data: disp.data,
          horarioInicio: horariosFinal[0],
          horarioFim:
              horariosFinal.length > 1 ? horariosFinal[1] : horariosFinal[0],
        );

        alocacoes.add(alocacao);
      }
    }

    // Ordenar por data
    alocacoes.sort((a, b) => a.data.compareTo(b.data));

    return alocacoes;
  }

  /// Gera cartões de disponibilidade para uma série específica
  static List<Disponibilidade> _gerarCartoesDaSerie({
    required SerieRecorrencia serie,
    required DateTime dataInicio,
    required DateTime dataFim,
    required Map<String, ExcecaoSerie> excecoesMap,
  }) {
    final cartoes = <Disponibilidade>[];

    // Ajustar dataInicio para não começar antes da série
    final inicio =
        dataInicio.isAfter(serie.dataInicio) ? dataInicio : serie.dataInicio;

    // Ajustar dataFim se a série tiver fim
    final fim = serie.dataFim != null && serie.dataFim!.isBefore(dataFim)
        ? serie.dataFim!
        : dataFim;

    switch (serie.tipo) {
      case 'Semanal':
        cartoes.addAll(_gerarSemanal(serie, inicio, fim, excecoesMap));
        break;
      case 'Quinzenal':
        cartoes.addAll(_gerarQuinzenal(serie, inicio, fim, excecoesMap));
        break;
      case 'Mensal':
        cartoes.addAll(_gerarMensal(serie, inicio, fim, excecoesMap));
        break;
      case 'Consecutivo':
        cartoes.addAll(_gerarConsecutivo(serie, inicio, fim, excecoesMap));
        break;
      default:
        // Única - criar apenas se estiver no período
        if (serie.dataInicio
                .isAfter(inicio.subtract(const Duration(days: 1))) &&
            serie.dataInicio.isBefore(fim.add(const Duration(days: 1)))) {
          final dataKey = _dataKey(serie.dataInicio);
          final chave = '${serie.id}_$dataKey';
          final excecao = excecoesMap[chave];
          // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
          // independentemente de ter gabineteId ou não
          if (!(excecao?.cancelada ?? false)) {
            cartoes.add(Disponibilidade(
              id: 'serie_${serie.id}_$dataKey',
              medicoId: serie.medicoId,
              data: serie.dataInicio,
              horarios: excecao?.horarios ?? serie.horarios,
              tipo: 'Única',
            ));
          }
        }
    }

    return cartoes;
  }

  /// Gera cartões semanais
  static List<Disponibilidade> _gerarSemanal(
    SerieRecorrencia serie,
    DateTime inicio,
    DateTime fim,
    Map<String, ExcecaoSerie> excecoesMap,
  ) {
    final cartoes = <Disponibilidade>[];
    final weekday = serie.dataInicio.weekday;

    // Encontrar primeira data válida no período
    DateTime dataAtual = inicio;
    int tentativas = 0;
    const maxTentativas = 7; // Máximo 7 dias para encontrar o weekday correto
    while (dataAtual.weekday != weekday &&
        dataAtual.isBefore(fim) &&
        tentativas < maxTentativas) {
      dataAtual = dataAtual.add(const Duration(days: 1));
      tentativas++;
    }

    // Se não encontrou, começar na próxima semana
    if (dataAtual.isAfter(fim)) {
      return cartoes;
    }

    // Ajustar para não começar antes da série
    if (dataAtual.isBefore(serie.dataInicio)) {
      final semanas =
          (serie.dataInicio.difference(dataAtual).inDays / 7).ceil();
      dataAtual = dataAtual.add(Duration(days: semanas * 7));
    }

    // Gerar cartões semanais com limite de iterações
    int iteracoes = 0;
    const maxIteracoes = 1000; // Máximo 1000 semanas (~19 anos)
    while (dataAtual.isBefore(fim.add(const Duration(days: 1))) &&
        iteracoes < maxIteracoes) {
      iteracoes++;
      // Normalizar a data para garantir correspondência exata
      final dataNormalizada = DateTime(
        dataAtual.year,
        dataAtual.month,
        dataAtual.day,
      );
      final dataKey = _dataKey(dataNormalizada);
      final chave = '${serie.id}_$dataKey';
      final excecao = excecoesMap[chave];

      // Debug: verificar se exceção foi encontrada
      if (excecao != null) {
        debugPrint(
            '🔍 [GERAÇÃO SEMANAL] Data=$dataKey, Série=${serie.id}, Chave=$chave, Exceção encontrada: cancelada=${excecao.cancelada}, gabineteId=${serie.gabineteId}');
      } else {
        // Debug: verificar chaves disponíveis no mapa (apenas para datas problemáticas)
        if (dataNormalizada.year == 2026 &&
            (dataNormalizada.month == 2 &&
                (dataNormalizada.day == 9 ||
                    dataNormalizada.day == 12 ||
                    dataNormalizada.day == 16))) {
          debugPrint(
              '⚠️ [GERAÇÃO SEMANAL] Data=$dataKey, Série=${serie.id}, Chave=$chave, EXCEÇÃO NÃO ENCONTRADA!');
          debugPrint(
              '   Chaves disponíveis no mapa: ${excecoesMap.keys.where((k) => k.contains(dataKey)).join(", ")}');
        }
      }

      // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
      // independentemente de ter gabineteId ou não
      final excecaoCancelada = excecao?.cancelada ?? false;

      // #region agent log
      if (dataNormalizada.year == 2026 &&
          (dataNormalizada.month == 2 &&
              (dataNormalizada.day == 9 ||
                  dataNormalizada.day == 12 ||
                  dataNormalizada.day == 16))) {
        _writeDebugLog(
            'serie_generator.dart:314', 'Verificando exceção cancelada', {
          'data': dataKey,
          'serieId': serie.id,
          'excecaoCancelada': excecaoCancelada,
          'gabineteId': serie.gabineteId,
          'hypothesisId': 'A'
        });
        debugPrint(
            '🔬 [DEBUG EXCEÇÃO] Data=$dataKey, Série=${serie.id}, excecaoCancelada=$excecaoCancelada, gabineteId=${serie.gabineteId}');
      }
      // #endregion

      if (excecaoCancelada) {
        // #region agent log
        if (dataNormalizada.year == 2026 &&
            (dataNormalizada.month == 2 &&
                (dataNormalizada.day == 9 ||
                    dataNormalizada.day == 12 ||
                    dataNormalizada.day == 16))) {
          _writeDebugLog(
              'serie_generator.dart:325', 'Pulando cartão cancelado', {
            'data': dataKey,
            'serieId': serie.id,
            'excecaoCancelada': excecaoCancelada,
            'gabineteId': serie.gabineteId,
            'hypothesisId': 'C'
          });
        }
        // #endregion
        debugPrint(
            '✅ [GERAÇÃO SEMANAL] Pulando cartão cancelado: data=$dataKey, série=${serie.id}, gabineteId=${serie.gabineteId}');
        dataAtual = dataAtual.add(const Duration(days: 7));
        continue;
      }

      // #region agent log
      if (dataNormalizada.year == 2026 &&
          (dataNormalizada.month == 2 &&
              (dataNormalizada.day == 9 ||
                  dataNormalizada.day == 12 ||
                  dataNormalizada.day == 16))) {
        _writeDebugLog(
            'serie_generator.dart:350', 'Adicionando cartão à lista', {
          'data': dataKey,
          'serieId': serie.id,
          'excecaoCancelada': excecaoCancelada,
          'gabineteId': serie.gabineteId,
          'hypothesisId': 'D'
        });
        debugPrint(
            '➕ [DEBUG EXCEÇÃO] ADICIONANDO cartão: data=$dataKey, série=${serie.id}, excecaoCancelada=$excecaoCancelada, gabineteId=${serie.gabineteId}');
      }
      // #endregion

      cartoes.add(Disponibilidade(
        id: 'serie_${serie.id}_$dataKey',
        medicoId: serie.medicoId,
        data: dataNormalizada,
        horarios: excecao?.horarios ?? serie.horarios,
        tipo: 'Semanal',
      ));

      dataAtual = dataAtual.add(const Duration(days: 7));
    }

    return cartoes;
  }

  /// Gera cartões quinzenais
  static List<Disponibilidade> _gerarQuinzenal(
    SerieRecorrencia serie,
    DateTime inicio,
    DateTime fim,
    Map<String, ExcecaoSerie> excecoesMap,
  ) {
    final cartoes = <Disponibilidade>[];
    final base = DateTime(
        serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
    final weekday = serie.dataInicio.weekday;

    // CORREÇÃO: Se a série começou muito antes do período, calcular a primeira data válida
    // mais próxima do início do período para evitar loops infinitos
    DateTime dataAtual = inicio;

    // Se a série começou antes do período, calcular a primeira data válida após o início
    if (base.isBefore(inicio)) {
      final diffInicio = inicio.difference(base).inDays;
      // Calcular quantas quinzenas (14 dias) já passaram desde o início da série
      final quinzenasPassadas = (diffInicio / 14).floor();
      // Começar da próxima quinzena válida
      final proximaQuinzena =
          base.add(Duration(days: (quinzenasPassadas + 1) * 14));

      // Ajustar para o weekday correto se necessário
      if (proximaQuinzena.weekday != weekday) {
        final diffWeekday = (weekday - proximaQuinzena.weekday + 7) % 7;
        dataAtual = proximaQuinzena.add(Duration(days: diffWeekday));
      } else {
        dataAtual = proximaQuinzena;
      }

      // Garantir que não começamos antes do período solicitado
      if (dataAtual.isBefore(inicio)) {
        dataAtual = dataAtual.add(const Duration(days: 14));
      }
    } else {
      // Série começou no período ou depois - começar do início da série
      dataAtual = base;
    }

    // Limitar iterações para evitar loops infinitos (máximo 1000 iterações = ~27 anos)
    int iteracoes = 0;
    const maxIteracoes = 1000;

    while (dataAtual.isBefore(fim.add(const Duration(days: 1))) &&
        iteracoes < maxIteracoes) {
      iteracoes++;

      final diff = dataAtual.difference(base).inDays;
      // Verificar se é o mesmo dia da semana e múltiplo de 14 dias
      if (diff >= 0 && diff % 14 == 0 && dataAtual.weekday == weekday) {
        // Normalizar a data para garantir correspondência exata
        final dataNormalizada = DateTime(
          dataAtual.year,
          dataAtual.month,
          dataAtual.day,
        );
        final dataKey = _dataKey(dataNormalizada);
        final chave = '${serie.id}_$dataKey';
        final excecao = excecoesMap[chave];

        // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
        // independentemente de ter gabineteId ou não
        if (excecao?.cancelada ?? false) {
          dataAtual = dataAtual.add(const Duration(days: 14));
          continue;
        }

        cartoes.add(Disponibilidade(
          id: 'serie_${serie.id}_$dataKey',
          medicoId: serie.medicoId,
          data: dataNormalizada,
          horarios: excecao?.horarios ?? serie.horarios,
          tipo: 'Quinzenal',
        ));

        // Avançar para a próxima quinzena
        dataAtual = dataAtual.add(const Duration(days: 14));
      } else {
        // Avançar um dia se não encontrou a data válida
        dataAtual = dataAtual.add(const Duration(days: 1));
      }
    }

    // #region agent log
    if (iteracoes >= maxIteracoes) {
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_generator.dart:467',
          'message': '⚠️ Loop Quinzenal atingiu limite de iterações',
          'data': {
            'serieId': serie.id,
            'iteracoes': iteracoes,
            'dataInicio': serie.dataInicio.toString(),
            'inicio': inicio.toString(),
            'fim': fim.toString(),
            'hypothesisId': 'G'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
    }
    // #endregion

    return cartoes;
  }

  /// Gera cartões mensais
  static List<Disponibilidade> _gerarMensal(
    SerieRecorrencia serie,
    DateTime inicio,
    DateTime fim,
    Map<String, ExcecaoSerie> excecoesMap,
  ) {
    final cartoes = <Disponibilidade>[];
    final weekday = serie.dataInicio.weekday;
    final ocorrencia = _descobrirOcorrenciaNoMes(serie.dataInicio);

    // Gerar para cada mês no período
    DateTime mesAtual = DateTime(inicio.year, inicio.month, 1);
    final fimMes = DateTime(fim.year, fim.month + 1, 0);

    // Verificar se deve usar último quando não existe 5ª ocorrência
    final usarUltimoQuandoNaoExiste5 =
        serie.parametros['usarUltimoQuandoNaoExiste5'] == true;
    // Verificar se deve usar último quando existe 5ª ocorrência mas escolheu 4ª
    final usarUltimoQuandoExiste5 =
        serie.parametros['usarUltimoQuandoExiste5'] == true;

    while (mesAtual.isBefore(fimMes.add(const Duration(days: 1)))) {
      final data = _pegarNthWeekdayDoMes(
          mesAtual.year, mesAtual.month, weekday, ocorrencia,
          usarUltimoQuandoNaoExiste5: usarUltimoQuandoNaoExiste5,
          usarUltimoQuandoExiste5: usarUltimoQuandoExiste5);

      if (data != null &&
          data.isAfter(inicio.subtract(const Duration(days: 1))) &&
          data.isBefore(fim.add(const Duration(days: 1)))) {
        // Normalizar a data para garantir correspondência exata
        final dataNormalizada = DateTime(data.year, data.month, data.day);
        final dataKey = _dataKey(dataNormalizada);
        final chave = '${serie.id}_$dataKey';
        final excecao = excecoesMap[chave];

        // Debug para verificar se a exceção está sendo encontrada
        if (excecao != null) {
          debugPrint(
              '🔍 _gerarMensal: Exceção encontrada para data $dataKey, chave=$chave, gabinete=${excecao.gabineteId}');
        }

        // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
        // independentemente de ter gabineteId ou não
        if (excecao?.cancelada ?? false) {
          continue;
        }

        cartoes.add(Disponibilidade(
          id: 'serie_${serie.id}_$dataKey',
          medicoId: serie.medicoId,
          data: dataNormalizada,
          horarios: excecao?.horarios ?? serie.horarios,
          tipo: 'Mensal',
        ));
      }

      // Próximo mês
      if (mesAtual.month == 12) {
        mesAtual = DateTime(mesAtual.year + 1, 1, 1);
      } else {
        mesAtual = DateTime(mesAtual.year, mesAtual.month + 1, 1);
      }
    }

    return cartoes;
  }

  /// Gera cartões consecutivos
  static List<Disponibilidade> _gerarConsecutivo(
    SerieRecorrencia serie,
    DateTime inicio,
    DateTime fim,
    Map<String, ExcecaoSerie> excecoesMap,
  ) {
    final cartoes = <Disponibilidade>[];
    final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;

    // CORREÇÃO CRÍTICA: Se a série começou muito antes do período solicitado,
    // começar do início do período para evitar loops infinitos
    // Mas só gerar cartões se a série ainda estiver ativa no período
    final dataFimSerie = serie.dataFim ?? DateTime(2100, 1, 1);
    if (dataFimSerie.isBefore(inicio)) {
      // Série já terminou antes do período - não gerar nada
      return cartoes;
    }

    // Começar do máximo entre início da série e início do período
    DateTime dataAtual =
        serie.dataInicio.isAfter(inicio) ? serie.dataInicio : inicio;

    // Ajustar para não ultrapassar o fim da série
    final fimReal = dataFimSerie.isBefore(fim) ? dataFimSerie : fim;

    // Limitar iterações para evitar loops infinitos (máximo 1000 dias)
    int iteracoes = 0;
    const maxIteracoes = 1000;

    while (dataAtual.isBefore(fimReal.add(const Duration(days: 1))) &&
        iteracoes < maxIteracoes) {
      iteracoes++;

      // Verificar se ainda estamos dentro do período da série
      if (dataAtual.isAfter(dataFimSerie)) {
        break;
      }

      // Verificar se ainda estamos dentro do número de dias consecutivos
      if (dataAtual.difference(serie.dataInicio).inDays >= numeroDias) {
        break;
      }

      final dataKey = _dataKey(dataAtual);
      final chave = '${serie.id}_$dataKey';
      final excecao = excecoesMap[chave];

      // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
      // independentemente de ter gabineteId ou não
      if (excecao?.cancelada ?? false) {
        dataAtual = dataAtual.add(const Duration(days: 1));
        continue;
      }

      cartoes.add(Disponibilidade(
        id: 'serie_${serie.id}_$dataKey',
        medicoId: serie.medicoId,
        data: dataAtual,
        horarios: excecao?.horarios ?? serie.horarios,
        tipo: 'Consecutivo',
      ));

      dataAtual = dataAtual.add(const Duration(days: 1));
    }

    // #region agent log
    if (iteracoes >= maxIteracoes) {
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'serie_generator.dart:578',
          'message': '⚠️ Loop Consecutivo atingiu limite de iterações',
          'data': {
            'serieId': serie.id,
            'iteracoes': iteracoes,
            'dataInicio': serie.dataInicio.toString(),
            'inicio': inicio.toString(),
            'fim': fim.toString(),
            'hypothesisId': 'F'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
    }
    // #endregion

    return cartoes;
  }

  /// Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
  static int _descobrirOcorrenciaNoMes(DateTime data) {
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

  /// Pega o n-ésimo weekday do mês
  static DateTime? _pegarNthWeekdayDoMes(
    int ano,
    int mes,
    int weekday,
    int n, {
    bool usarUltimoQuandoNaoExiste5 = false,
    bool usarUltimoQuandoExiste5 = false,
  }) {
    final weekdayDia1 = DateTime(ano, mes, 1).weekday;
    final offset = (weekday - weekdayDia1 + 7) % 7;
    final primeiroNoMes = 1 + offset;
    final dia = primeiroNoMes + 7 * (n - 1);

    final ultimoDiaMes = DateTime(ano, mes + 1, 0).day;

    // Se usarUltimoQuandoExiste5 está ativo e n==4, verificar se existe 5ª ocorrência
    if (usarUltimoQuandoExiste5 && n == 4) {
      final dia5 = primeiroNoMes + 7 * 4; // 5ª ocorrência
      if (dia5 <= ultimoDiaMes) {
        // Existe 5ª ocorrência, então retornar o último dia da semana
        for (int d = ultimoDiaMes; d >= 1; d--) {
          final dataTeste = DateTime(ano, mes, d);
          if (dataTeste.weekday == weekday) {
            return dataTeste;
          }
        }
      }
    }

    if (dia <= ultimoDiaMes) {
      return DateTime(ano, mes, dia);
    }

    // Se não existe o n-ésimo dia e a opção está ativa, retornar o último dia da semana
    if (usarUltimoQuandoNaoExiste5 && n == 5) {
      // Encontrar o último dia da semana desejada no mês
      // Começar do último dia do mês e ir retrocedendo até encontrar o weekday correto
      for (int d = ultimoDiaMes; d >= 1; d--) {
        final dataTeste = DateTime(ano, mes, d);
        if (dataTeste.weekday == weekday) {
          return dataTeste;
        }
      }
    }

    return null;
  }

  /// Gera chave de data no formato yyyy-MM-dd
  static String _dataKey(DateTime data) {
    return '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
  }
}
