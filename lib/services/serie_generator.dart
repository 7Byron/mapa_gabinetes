// lib/services/serie_generator.dart

import 'package:flutter/foundation.dart';

import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/mudanca_gabinete.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';

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
      }
    }

    // Para cada série, gerar cartões no período
    for (final serie in series) {
      if (!serie.ativo) continue;

      final cartoes = _gerarCartoesDaSerie(
        serie: serie,
        dataInicio: dataInicio,
        dataFim: dataFim,
        excecoesMap: excecoesMap,
      );

      disponibilidades.addAll(cartoes);
    }

    // Ordenar por data
    disponibilidades.sort((a, b) => a.data.compareTo(b.data));

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
      // Verificar se série tem gabinete (padrão ou em mudanças)
      final temGabinete =
          serie.gabineteId != null || serie.mudancasGabinete.isNotEmpty;
      if (!serie.ativo || !temGabinete) continue;

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

        // Se cancelada, não criar alocação (exceção de disponibilidade)
        if (excecao?.cancelada ?? false) continue;

        // CORREÇÃO CRÍTICA: Se há exceção de gabinete com gabineteId null, não criar alocação
        // O médico fica sem gabinete neste dia mas continua disponível (exceção de gabinete)
        if (excecao != null && excecao.gabineteId == null) {
          // Exceção de gabinete: médico sem gabinete neste dia
          continue;
        }

        // NOVA LÓGICA: Priorizar exceções individuais, depois usar mudanças de gabinete da série
        // 1. Se há exceção individual para esta data → usar exceção (modificação pontual)
        // 2. Se não há exceção → usar obterGabineteParaData (considera mudanças de gabinete por período)
        final String gabineteIdFinal;
        final List<String> horariosFinal;
        final String idAlocacao;

        if (excecao?.gabineteId != null) {
          // Há exceção individual: gerar alocação da exceção (não da série)
          // Isso permite modificar um dia específico sem criar mudança de período
          gabineteIdFinal = excecao!.gabineteId!;
          horariosFinal = excecao.horarios ?? disp.horarios;
          idAlocacao = 'serie_${serie.id}_${_dataKey(disp.data)}';
          debugPrint(
              '✅ Gerando alocação da exceção: data=$dataKey, gabinete=$gabineteIdFinal (exceção individual)');
        } else {
          // Não há exceção individual: usar mudanças de gabinete da série
          // obterGabineteParaData retorna o gabineteId correto considerando mudanças por período
          gabineteIdFinal =
              serie.obterGabineteParaData(disp.data) ?? serie.gabineteId ?? '';
          horariosFinal = disp.horarios;
          idAlocacao = 'serie_${serie.id}_${_dataKey(disp.data)}';

          // Log apenas se houver mudanças de gabinete
          if (serie.mudancasGabinete.isNotEmpty) {
            final dataNormalizada =
                DateTime(disp.data.year, disp.data.month, disp.data.day);
            MudancaGabinete? mudancaAplicavel;
            for (final mudanca in serie.mudancasGabinete.reversed) {
              if (!dataNormalizada.isBefore(mudanca.dataInicioNormalizada)) {
                mudancaAplicavel = mudanca;
                break;
              }
            }
            if (mudancaAplicavel != null &&
                mudancaAplicavel.gabineteId.isNotEmpty) {
              debugPrint(
                  '📅 Gerando alocação com mudança de gabinete: data=$dataKey, gabinete=$gabineteIdFinal (mudança desde ${mudancaAplicavel.dataInicio.day}/${mudancaAplicavel.dataInicio.month})');
            }
          }
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
        if (serie.dataInicio.isAfter(_addDias(inicio, -1)) &&
            serie.dataInicio.isBefore(_addDias(fim, 1))) {
          final dataKey = _dataKey(serie.dataInicio);
          final chave = '${serie.id}_$dataKey';
          final excecao = excecoesMap[chave];
          // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
          // independentemente de ter gabineteId ou não (exceção de disponibilidade)
          // IMPORTANTE: Se há exceção de gabinete com gabineteId null, AINDA CRIAMOS A DISPONIBILIDADE
          // A disponibilidade será criada, mas a alocação não será criada em gerarAlocacoes
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
      dataAtual = _addDias(dataAtual, 1);
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
      dataAtual = _addDias(dataAtual, semanas * 7);
    }

    // Gerar cartões semanais com limite de iterações
    int iteracoes = 0;
    const maxIteracoes = 1000; // Máximo 1000 semanas (~19 anos)
    while (dataAtual.isBefore(_addDias(fim, 1)) && iteracoes < maxIteracoes) {
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

      // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
      // independentemente de ter gabineteId ou não (exceção de disponibilidade)
      final excecaoCancelada = excecao?.cancelada ?? false;

      if (excecaoCancelada) {
        dataAtual = _addDias(dataAtual, 7);
        continue;
      }

      // IMPORTANTE: Se há exceção de gabinete com gabineteId null, AINDA CRIAMOS A DISPONIBILIDADE
      // A disponibilidade será criada, mas a alocação não será criada em gerarAlocacoes
      // Isso permite que o médico apareça em "médicos por alocar"

      cartoes.add(Disponibilidade(
        id: 'serie_${serie.id}_$dataKey',
        medicoId: serie.medicoId,
        data: dataNormalizada,
        horarios: excecao?.horarios ?? serie.horarios,
        tipo: 'Semanal',
      ));

      dataAtual = _addDias(dataAtual, 7);
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

    // CORREÇÃO CRÍTICA: Normalizar inicio e fim para comparação correta
    final inicioNormalizado = DateTime(inicio.year, inicio.month, inicio.day);
    final fimNormalizado = DateTime(fim.year, fim.month, fim.day);

    // CORREÇÃO CRÍTICA: Cálculo simplificado da primeira data válida
    // Ao avançar de 14 em 14 dias a partir de 'base', sempre mantemos o mesmo weekday
    // Então basta calcular a primeira quinzena válida que seja >= inicio

    DateTime dataAtual;

    // Se a série começou antes ou no início do período solicitado
    if (base.isBefore(inicioNormalizado) ||
        base.isAtSameMomentAs(inicioNormalizado)) {
      final diffInicio = _diasCalendarioEntre(inicioNormalizado, base);

      // CORREÇÃO CRÍTICA: Primeiro verificar se 'inicio' é uma quinzena válida
      // Se sim, usar inicio; caso contrário, calcular a próxima quinzena >= inicio
      if (diffInicio >= 0 && diffInicio % 14 == 0) {
        // O próprio inicio é uma quinzena válida da série
        if (inicioNormalizado.weekday == weekday) {
          // Inicio é uma quinzena válida com o weekday correto - usar inicio
          dataAtual = inicioNormalizado;
        } else {
          // Inicio é múltiplo de 14 dias, mas weekday errado - avançar para próxima quinzena
          final quinzenasParaAvancar = (diffInicio / 14).ceil() + 1;
          dataAtual = _addDias(base, quinzenasParaAvancar * 14);
        }
      } else {
        // Inicio não é uma quinzena válida - calcular a próxima quinzena >= inicio
        // Usar ceil para arredondar para cima e garantir que estamos >= inicio
        final quinzenasParaAvancar = (diffInicio / 14).ceil();
        dataAtual = _addDias(base, quinzenasParaAvancar * 14);

        // CORREÇÃO CRÍTICA: Se dataAtual calculada é menor que inicio, garantir que seja >= inicio
        // Isso pode acontecer quando diffInicio é negativo mas arredondado para 0
        if (dataAtual.isBefore(inicioNormalizado)) {
          dataAtual = inicioNormalizado;
          // Se inicio não é uma quinzena válida, avançar para a próxima
          final diffDesdeBase = _diasCalendarioEntre(dataAtual, base);
          if (diffDesdeBase % 14 != 0 || dataAtual.weekday != weekday) {
            // Avançar para a próxima quinzena válida
            final quinzenasAteInicio = (diffInicio / 14).floor();
            dataAtual = _addDias(base, (quinzenasAteInicio + 1) * 14);
          }
        }
      }
    } else {
      // Série começou depois do início do período solicitado
      // Verificar se base está dentro do período (entre inicio e fim, inclusive)
      // Se sim, começar do início da série; caso contrário, não gerar nada
      final baseNormalizado = DateTime(base.year, base.month, base.day);

      // Verificar se base está dentro do período: base >= inicio && base <= fim
      final baseDentroDoPeriodo = (baseNormalizado.isAfter(inicioNormalizado) ||
              (baseNormalizado.year == inicioNormalizado.year &&
                  baseNormalizado.month == inicioNormalizado.month &&
                  baseNormalizado.day == inicioNormalizado.day)) &&
          (baseNormalizado.isBefore(_addDias(fimNormalizado, 1)) ||
              (baseNormalizado.year == fimNormalizado.year &&
                  baseNormalizado.month == fimNormalizado.month &&
                  baseNormalizado.day == fimNormalizado.day));

      if (baseDentroDoPeriodo) {
        // Base está dentro do período - começar do início da série
        dataAtual = base;
      } else {
        // Série começa fora do período - não gerar nada
        return [];
      }
    }

    // Limitar iterações para evitar loops infinitos (máximo 1000 iterações = ~27 anos)
    int iteracoes = 0;
    const maxIteracoes = 1000;

    // CORREÇÃO: Simplificar o loop - avançar sempre de 14 em 14 dias
    // e verificar apenas se está no período e se é uma quinzena válida
    while (dataAtual.isBefore(_addDias(fimNormalizado, 1)) &&
        iteracoes < maxIteracoes) {
      iteracoes++;

      // Verificar se está no período solicitado
      if (!dataAtual.isBefore(inicioNormalizado) &&
          dataAtual.isBefore(_addDias(fimNormalizado, 1))) {
        final diff = _diasCalendarioEntre(dataAtual, base);

        // Verificar se é múltiplo de 14 dias e tem o weekday correto
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
          // independentemente de ter gabineteId ou não (exceção de disponibilidade)
          if (excecao?.cancelada ?? false) {
            dataAtual = _addDias(dataAtual, 14);
            continue;
          }

          // IMPORTANTE: Se há exceção de gabinete com gabineteId null, AINDA CRIAMOS A DISPONIBILIDADE
          // A disponibilidade será criada, mas a alocação não será criada em gerarAlocacoes
          // Isso permite que o médico apareça em "médicos por alocar"

          cartoes.add(Disponibilidade(
            id: 'serie_${serie.id}_$dataKey',
            medicoId: serie.medicoId,
            data: dataNormalizada,
            horarios: excecao?.horarios ?? serie.horarios,
            tipo: 'Quinzenal',
          ));
        }
      }

      // Avançar sempre para a próxima quinzena (14 dias)
      dataAtual = _addDias(dataAtual, 14);
    }

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

    // CORREÇÃO CRÍTICA: Limitar o período de geração para evitar loops infinitos
    // Se a série tem dataFim, usar o mínimo entre fim do período e dataFim da série
    // Se a série é infinita (dataFim == null), limitar a um período razoável (ex: 10 anos)
    DateTime fimLimite = fim;
    if (serie.dataFim != null) {
      // Se a série tem dataFim, usar o mínimo entre fim do período e dataFim da série
      fimLimite = fim.isBefore(serie.dataFim!) ? fim : serie.dataFim!;
    } else {
      // Se a série é infinita, limitar a 10 anos a partir do início para evitar loops infinitos
      final fimMaximo = _addDias(inicio, 365 * 10);
      fimLimite = fim.isBefore(fimMaximo) ? fim : fimMaximo;
    }

    // Gerar para cada mês no período limitado
    DateTime mesAtual = DateTime(inicio.year, inicio.month, 1);

    // Verificar se deve usar último quando não existe 5ª ocorrência
    final usarUltimoQuandoNaoExiste5 =
        serie.parametros['usarUltimoQuandoNaoExiste5'] == true;
    // Verificar se deve usar último quando existe 5ª ocorrência mas escolheu 4ª
    final usarUltimoQuandoExiste5 =
        serie.parametros['usarUltimoQuandoExiste5'] == true;

    // CORREÇÃO CRÍTICA: Adicionar proteção contra loops infinitos
    int iteracoesMensal = 0;
    const maxIteracoesMensal = 1000; // Máximo de ~83 anos

    // CORREÇÃO: Usar fimLimite em vez de fim para comparação
    while (mesAtual.isBefore(_addDias(fimLimite, 1)) &&
        iteracoesMensal < maxIteracoesMensal) {
      iteracoesMensal++;

      final data = _pegarNthWeekdayDoMes(
          mesAtual.year, mesAtual.month, weekday, ocorrencia,
          usarUltimoQuandoNaoExiste5: usarUltimoQuandoNaoExiste5,
          usarUltimoQuandoExiste5: usarUltimoQuandoExiste5);

      if (data != null &&
          data.isAfter(_addDias(inicio, -1)) &&
          data.isBefore(_addDias(fimLimite, 1))) {
        // Normalizar a data para garantir correspondência exata
        final dataNormalizada = DateTime(data.year, data.month, data.day);
        final dataKey = _dataKey(dataNormalizada);
        final chave = '${serie.id}_$dataKey';
        final excecao = excecoesMap[chave];

        // CORREÇÃO: Limitar logs repetidos - só logar uma vez por data
        // Debug para verificar se a exceção está sendo encontrada
        if (excecao != null && iteracoesMensal <= 12) {
          debugPrint(
              '🔍 _gerarMensal: Exceção encontrada para data $dataKey, chave=$chave, gabinete=${excecao.gabineteId}');
        }

        // CORREÇÃO CRÍTICA: Se exceção está cancelada, SEMPRE pular o cartão
        // independentemente de ter gabineteId ou não (exceção de disponibilidade)
        final excecaoCancelada = excecao?.cancelada ?? false;

        // IMPORTANTE: Se há exceção de gabinete com gabineteId null, AINDA CRIAMOS A DISPONIBILIDADE
        // A disponibilidade será criada, mas a alocação não será criada em gerarAlocacoes
        // Isso permite que o médico apareça em "médicos por alocar"
        if (!excecaoCancelada) {
          cartoes.add(Disponibilidade(
            id: 'serie_${serie.id}_$dataKey',
            medicoId: serie.medicoId,
            data: dataNormalizada,
            horarios: excecao?.horarios ?? serie.horarios,
            tipo: 'Mensal',
          ));
        }
      }

      // Próximo mês
      if (mesAtual.month == 12) {
        mesAtual = DateTime(mesAtual.year + 1, 1, 1);
      } else {
        mesAtual = DateTime(mesAtual.year, mesAtual.month + 1, 1);
      }
    }

    // CORREÇÃO: Avisar se atingiu limite de iterações
    if (iteracoesMensal >= maxIteracoesMensal) {
      debugPrint(
          '⚠️ [PROTEÇÃO] _gerarMensal atingiu limite de iterações ($maxIteracoesMensal) para série ${serie.id}');
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

    while (
        dataAtual.isBefore(_addDias(fimReal, 1)) && iteracoes < maxIteracoes) {
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
      // independentemente de ter gabineteId ou não (exceção de disponibilidade)
      if (excecao?.cancelada ?? false) {
        dataAtual = _addDias(dataAtual, 1);
        continue;
      }

      // IMPORTANTE: Se há exceção de gabinete com gabineteId null, AINDA CRIAMOS A DISPONIBILIDADE
      // A disponibilidade será criada, mas a alocação não será criada em gerarAlocacoes
      // Isso permite que o médico apareça em "médicos por alocar"

      cartoes.add(Disponibilidade(
        id: 'serie_${serie.id}_$dataKey',
        medicoId: serie.medicoId,
        data: dataAtual,
        horarios: excecao?.horarios ?? serie.horarios,
        tipo: 'Consecutivo',
      ));

      dataAtual = _addDias(dataAtual, 1);
    }

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

  /// Conta dias de calendário sem a hora perdida/ganha na mudança de horário.
  static int _diasCalendarioEntre(DateTime data, DateTime base) {
    return DateTime.utc(data.year, data.month, data.day)
        .difference(DateTime.utc(base.year, base.month, base.day))
        .inDays;
  }

  /// Soma dias preservando o dia local (evita drift por DST).
  static DateTime _addDias(DateTime data, int dias) {
    return DateTime(data.year, data.month, data.day + dias);
  }
}
