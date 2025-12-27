// lib/services/serie_generator.dart

import 'package:flutter/foundation.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
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
      final dataKey = _dataKey(excecao.data);
      final chave = '${excecao.serieId}_$dataKey';
      excecoesMap[chave] = excecao;
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

        // Debug para séries quinzenais e mensais
        if (serie.tipo == 'Mensal' || serie.tipo == 'Quinzenal') {
          debugPrint(
              '🔍 Buscando exceção: tipo=${serie.tipo}, série=${serie.id}, data=$dataKey, chave=$chave, encontrada=${excecao != null}');
          if (excecao != null) {
            debugPrint(
                '   ✅ Exceção encontrada: gabinete=${excecao.gabineteId}, cancelada=${excecao.cancelada}');
          } else {
            debugPrint(
                '   ❌ Exceção NÃO encontrada - usando gabinete da série: ${serie.gabineteId}');
            // Debug: mostrar todas as chaves no mapa para ajudar a identificar o problema
            debugPrint('   📋 Chaves disponíveis no mapa de exceções:');
            excecoesMap.keys
                .where((k) => k.startsWith('${serie.id}_'))
                .take(5)
                .forEach((k) => debugPrint('      - $k'));
          }
        }

        // Se cancelada, não criar alocação
        if (excecao?.cancelada ?? false) continue;

        // Usar gabinete da exceção ou da série
        final gabineteId = excecao?.gabineteId ?? serie.gabineteId!;

        // Debug para séries quinzenais e mensais
        if ((serie.tipo == 'Mensal' || serie.tipo == 'Quinzenal') &&
            excecao?.gabineteId != null) {
          debugPrint(
              '✅ Alocação gerada com exceção: tipo=${serie.tipo}, data=$dataKey, gabinete=$gabineteId (exceção: ${excecao?.gabineteId}, série: ${serie.gabineteId})');
        }

        // Usar horários da exceção ou da série
        final horarios = excecao?.horarios ?? disp.horarios;
        if (horarios.isEmpty) continue;

        final alocacao = Alocacao(
          id: 'serie_${serie.id}_${_dataKey(disp.data)}',
          medicoId: serie.medicoId,
          gabineteId: gabineteId,
          data: disp.data,
          horarioInicio: horarios[0],
          horarioFim: horarios.length > 1 ? horarios[1] : horarios[0],
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
          if (excecao?.cancelada ?? false) {
            // Cancelada, não adicionar
          } else {
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
    while (dataAtual.weekday != weekday && dataAtual.isBefore(fim)) {
      dataAtual = dataAtual.add(const Duration(days: 1));
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

    // Gerar cartões semanais
    while (dataAtual.isBefore(fim.add(const Duration(days: 1)))) {
      // Normalizar a data para garantir correspondência exata
      final dataNormalizada = DateTime(
        dataAtual.year,
        dataAtual.month,
        dataAtual.day,
      );
      final dataKey = _dataKey(dataNormalizada);
      final chave = '${serie.id}_$dataKey';
      final excecao = excecoesMap[chave];

      // Se cancelada, pular
      if (excecao?.cancelada ?? false) {
        // Debug: verificar se a exceção está sendo aplicada
        debugPrint(
            '🚫 Exceção cancelada encontrada para série ${serie.id} na data ${dataAtual.day}/${dataAtual.month}/${dataAtual.year} - pulando geração');
        dataAtual = dataAtual.add(const Duration(days: 7));
        continue;
      }

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

    // Encontrar primeira data válida no período
    DateTime dataAtual = inicio;
    while (dataAtual.isBefore(fim.add(const Duration(days: 1)))) {
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

        // Debug para verificar se a exceção está sendo encontrada
        if (excecao != null) {
          debugPrint(
              '🔍 _gerarQuinzenal: Exceção encontrada para data $dataKey, chave=$chave, gabinete=${excecao.gabineteId}');
        }

        if (!(excecao?.cancelada ?? false)) {
          cartoes.add(Disponibilidade(
            id: 'serie_${serie.id}_$dataKey',
            medicoId: serie.medicoId,
            data: dataNormalizada,
            horarios: excecao?.horarios ?? serie.horarios,
            tipo: 'Quinzenal',
          ));
        }
      }
      dataAtual = dataAtual.add(const Duration(days: 1));
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

        if (!(excecao?.cancelada ?? false)) {
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

    DateTime dataAtual = serie.dataInicio;
    while (dataAtual.isBefore(fim.add(const Duration(days: 1)))) {
      if (dataAtual.isAfter(inicio.subtract(const Duration(days: 1)))) {
        final dataKey = _dataKey(dataAtual);
        final chave = '${serie.id}_$dataKey';
        final excecao = excecoesMap[chave];

        if (!(excecao?.cancelada ?? false)) {
          cartoes.add(Disponibilidade(
            id: 'serie_${serie.id}_$dataKey',
            medicoId: serie.medicoId,
            data: dataAtual,
            horarios: excecao?.horarios ?? serie.horarios,
            tipo: 'Consecutivo',
          ));
        }
      }
      dataAtual = dataAtual.add(const Duration(days: 1));

      // Parar após número de dias consecutivos
      if (dataAtual.difference(serie.dataInicio).inDays >= numeroDias) {
        break;
      }
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
}
