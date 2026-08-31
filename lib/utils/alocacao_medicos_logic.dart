// import '../database/database_helper.dart';
// import 'dart:convert'; // Comentado - usado apenas na instrumentação de debug
import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../services/gabinete_service.dart';
import '../services/medico_salvar_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/cache_version_service.dart';
import '../services/alocacao_horario_service.dart';
import '../utils/alocacao_cache_store.dart';
import '../utils/alocacao_cache_sync.dart';
import '../utils/alocacao_disponibilidade_validacao_utils.dart';
import '../utils/conflict_utils.dart';
// import '../utils/debug_log_file.dart'; // Comentado - usado apenas na instrumentação de debug
import 'package:cloud_firestore/cloud_firestore.dart';

class AlocacaoMedicosLogic {
  static bool ativarCacheDaUnidade(String unidadeId) {
    return AlocacaoCacheStore.ativarUnidade(unidadeId);
  }

  static const String _unidadeFallbackId = 'fyEj6kOXvCuL65sMfCaR';
  static final Map<String, List<Gabinete>> _cacheGabinetesPorUnidade = {};
  static final Map<String, List<Medico>> _cacheMedicosPorUnidade = {};

  /// Verifica se o cache está invalidado para um dia específico
  static bool isCacheInvalidado(DateTime day) =>
      AlocacaoCacheStore.isCacheInvalidado(day);

  /// Obtém a chave do cache para um dia específico
  static String keyDia(DateTime d) => AlocacaoCacheStore.keyDia(d);

  static const int _anosFuturoCache = 1;

  static void _log(String message) {
    AlocacaoCacheStore.log(message);
  }

  static Future<void> _removerAlocacaoPersistida({
    required FirebaseFirestore firestore,
    required String unidadeId,
    required Alocacao alocacao,
  }) async {
    final ano = alocacao.data.year.toString();
    final dia = keyDia(alocacao.data);
    final unidadeRef = firestore.collection('unidades').doc(unidadeId);
    final batch = firestore.batch();

    batch.delete(
      unidadeRef
          .collection('alocacoes')
          .doc(ano)
          .collection('registos')
          .doc(alocacao.id),
    );
    // A vista diária é a primeira fonte consultada pelo mapa. Apagá-la na
    // mesma operação impede que uma cópia materializada sobreviva ao registo
    // principal enquanto a Cloud Function ainda não sincronizou.
    batch.delete(
      unidadeRef
          .collection('dias')
          .doc(dia)
          .collection('alocacoes')
          .doc(alocacao.id),
    );
    await batch.commit();
  }

  static String _cacheUnidadeKey(Unidade? unidade) =>
      unidade?.id ?? _unidadeFallbackId;

  /// Atualiza o cache do dia.
  /// Se `forcarValido` for true, marca o cache como válido mesmo se estava invalidado.
  /// Se false (padrão), preserva o estado de invalidação para evitar que dados antigos sejam marcados como válidos.
  static void updateCacheForDay({
    required DateTime day,
    List<Disponibilidade>? disponibilidades,
    List<Alocacao>? alocacoes,
    bool forcarValido =
        false, // Por padrão, não forçar validação se estava invalidado
  }) {
    AlocacaoCacheStore.updateCacheForDay(
      day: day,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      forcarValido: forcarValido,
    );
  }

  /// Remove o cache do dia específico (será recarregado do servidor na próxima consulta)
  static void invalidateCacheForDay(DateTime day) {
    AlocacaoCacheStore.invalidateCacheForDay(day);
  }

  /// Remove o cache de todos os dias a partir de uma data específica
  static void invalidateCacheFromDate(DateTime fromDate) {
    AlocacaoCacheStore.invalidateCacheFromDate(fromDate);
  }

  /// CORREÇÃO CRÍTICA: Invalida o cache para todos os dias que uma série afeta
  /// Esta função calcula todos os dias que uma série pode gerar disponibilidades/alocações
  /// e invalida o cache para cada um desses dias
  /// IMPORTANTE: Esta função deve ser chamada SEMPRE que uma série é criada, alocada, desalocada ou atualizada
  static void invalidateCacheParaSerie(SerieRecorrencia serie,
      {Unidade? unidade}) {
    if (!serie.ativo) return;

    final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
    final medicoId = serie.medicoId;

    // Invalidar cache de séries primeiro
    SerieService.invalidateCacheSeries(unidadeId, medicoId);

    // Calcular período para invalidar
    final dataInicio = DateTime(
        serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
    final anoAtual = DateTime.now().year;
    final anoLimite = anoAtual + _anosFuturoCache;
    final dataFimPadrao = DateTime(anoLimite, 12, 31);
    final dataFimSerie = serie.dataFim != null
        ? DateTime(
            serie.dataFim!.year, serie.dataFim!.month, serie.dataFim!.day)
        : dataFimPadrao;
    final dataFim =
        dataFimSerie.isAfter(dataFimPadrao) ? dataFimPadrao : dataFimSerie;

    // Invalidar apenas a janela de interesse (ano atual + 1)
    final anoInicio = dataInicio.year < anoAtual ? anoAtual : dataInicio.year;
    final anoFim = dataFim.year;
    for (int ano = anoInicio; ano <= anoFim; ano++) {
      invalidateCacheFromDate(DateTime(ano, 1, 1));
    }

    // CORREÇÃO CRÍTICA: Invalidar também dias específicos baseado no tipo da série
    // Para garantir que TODOS os dias afetados sejam invalidados, não apenas o período
    final diasParaInvalidar = <DateTime>[];
    final weekday = serie.dataInicio.weekday; // Dia da semana da série
    final dataInicioCache = dataInicio.isAfter(DateTime(anoInicio, 1, 1))
        ? dataInicio
        : DateTime(anoInicio, 1, 1);

    switch (serie.tipo) {
      case 'Única':
        diasParaInvalidar.add(dataInicio);
        break;

      case 'Semanal':
        // Invalidar todas as semanas: dataInicio, dataInicio+7, dataInicio+14, etc.
        DateTime dataAtual = dataInicioCache;
        if (dataAtual.weekday != weekday) {
          final diff = (weekday - dataAtual.weekday) % 7;
          dataAtual = dataAtual.add(Duration(days: diff));
        }
        int iteracoes = 0;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1))) &&
            iteracoes < 60) {
          // Limitar a ~1 ano
          if (dataAtual.weekday == weekday) {
            diasParaInvalidar
                .add(DateTime(dataAtual.year, dataAtual.month, dataAtual.day));
          }
          dataAtual = dataAtual.add(const Duration(days: 7));
          iteracoes++;
        }
        break;

      case 'Quinzenal':
        // CORREÇÃO CRÍTICA: Invalidar todas as quinzenas: dataInicio, dataInicio+14, dataInicio+28, etc.
        // Para uma série quinzenal que começa em 9/2, invalidar: 9/2, 23/2, 9/3, 23/3, etc.
        int diasDesdeInicio = dataInicioCache.difference(dataInicio).inDays;
        if (diasDesdeInicio < 0) diasDesdeInicio = 0;
        final resto = diasDesdeInicio % 14;
        DateTime dataAtual =
            dataInicioCache.add(Duration(days: resto == 0 ? 0 : 14 - resto));
        int iteracoes = 0;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1))) &&
            iteracoes < 30) {
          // Limitar a ~1 ano
          // Verificar se é uma quinzena válida (múltiplo de 14 dias a partir do início)
          final diff = dataAtual.difference(dataInicio).inDays;
          if (diff >= 0 && diff % 14 == 0 && dataAtual.weekday == weekday) {
            diasParaInvalidar
                .add(DateTime(dataAtual.year, dataAtual.month, dataAtual.day));
          }
          dataAtual = dataAtual.add(const Duration(days: 14));
          iteracoes++;
        }
        break;

      case 'Mensal':
        // Invalidar todas as ocorrências mensais
        DateTime mesAtual =
            DateTime(dataInicioCache.year, dataInicioCache.month, 1);
        int iteracoes = 0;
        while (mesAtual.isBefore(dataFim.add(const Duration(days: 1))) &&
            iteracoes < 15) {
          // Limitar a ~1 ano
          // Calcular a data da ocorrência no mês
          final ocorrencia = _descobrirOcorrenciaNoMes(dataInicio);
          final data = _pegarNthWeekdayDoMes(
            mesAtual.year,
            mesAtual.month,
            weekday,
            ocorrencia,
            usarUltimoQuandoNaoExiste5:
                serie.parametros['usarUltimoQuandoNaoExiste5'] ?? false,
            usarUltimoQuandoExiste5:
                serie.parametros['usarUltimoQuandoExiste5'] ?? false,
          );
          if (data != null &&
              data.isAfter(dataInicio.subtract(const Duration(days: 1))) &&
              data.isBefore(dataFim.add(const Duration(days: 1)))) {
            diasParaInvalidar.add(DateTime(data.year, data.month, data.day));
          }
          // Avançar para o próximo mês
          if (mesAtual.month == 12) {
            mesAtual = DateTime(mesAtual.year + 1, 1, 1);
          } else {
            mesAtual = DateTime(mesAtual.year, mesAtual.month + 1, 1);
          }
          iteracoes++;
        }
        break;

      case 'Consecutivo':
        final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
        if (!dataInicio.isBefore(DateTime(anoInicio, 1, 1))) {
          DateTime dataAtual = dataInicio;
          for (int i = 0;
              i < numeroDias &&
                  dataAtual.isBefore(dataFim.add(const Duration(days: 1)));
              i++) {
            diasParaInvalidar
                .add(DateTime(dataAtual.year, dataAtual.month, dataAtual.day));
            dataAtual = dataAtual.add(const Duration(days: 1));
          }
        }
        break;

      default:
        // Para outros tipos, invalidar apenas o período (já feito acima)
        break;
    }

    // CORREÇÃO CRÍTICA: Invalidar cache para cada dia específico calculado
    // Além de invalidar o período inteiro, invalidar também cada dia específico
    // para garantir máxima precisão
    for (final dia in diasParaInvalidar) {
      invalidateCacheForDay(dia);
    }

    _log(
        '🗑️ [CACHE] Cache invalidado para série ${serie.id} (${serie.tipo}): ${diasParaInvalidar.length} dias específicos + período completo desde ${dataInicio.day}/${dataInicio.month}/${dataInicio.year} até ${dataFim.day}/${dataFim.month}/${dataFim.year}');
  }

  /// Helper: Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
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

  /// Helper: Pega o n-ésimo weekday do mês
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
      for (int d = ultimoDiaMes; d >= 1; d--) {
        final dataTeste = DateTime(ano, mes, d);
        if (dataTeste.weekday == weekday) {
          return dataTeste;
        }
      }
    }

    return null;
  }

  /// Obtém a source apropriada para buscar dados do Firestore
  // Flag para rastrear se o app está em foco
  static bool _appEmFoco = true;

  /// Define se o app está em foco (chamado pelo lifecycle observer)
  static void setAppEmFoco(bool emFoco) {
    if (_appEmFoco == emFoco) return;
    _appEmFoco = emFoco;
    _log('ℹ️ [CACHE] App em foco: ${_appEmFoco ? 'sim' : 'não'}');
  }

  /// Retorna Source.server se o cache foi invalidado, Source.serverAndCache caso contrário
  static Source _getSourceForDay(DateTime? day) {
    if (day == null) {
      return Source.serverAndCache;
    }
    if (isCacheInvalidado(day)) {
      return Source.server; // Cache invalidado, buscar do servidor
    }
    return Source.serverAndCache; // Usar cache do Firestore quando válido
  }

  /// Extrai datas com exceções canceladas do Firestore para um dia específico
  /// Retorna um Set com chaves no formato: medicoId_ano-mes-dia
  /// OTIMIZAÇÃO: Usa cache de exceções quando disponível para evitar chamadas redundantes
  static Future<Set<String>> extrairExcecoesCanceladasParaDia(
      String unidadeId, DateTime data) async {
    final cachePorDia = AlocacaoCacheStore.getExcecoesCanceladasParaDia(data);
    if (cachePorDia != null) {
      return Set<String>.from(cachePorDia);
    }

    final datasComExcecoesCanceladas = <String>{};
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    try {
      final firestore = FirebaseFirestore.instance;
      final ano = data.year;

      // OTIMIZAÇÃO: Tentar usar cache de exceções primeiro
      // Percorrer cache para médicos que têm exceções para este dia
      for (final entry in AlocacaoCacheStore.cacheExcecoes.entries) {
        final cacheKey = entry.key;
        final excecoes = entry.value;

        // Extrair medicoId do cacheKey (formato: medicoId_timestamp_timestamp)
        final parts = cacheKey.split('_');
        if (parts.isEmpty) continue;
        final medicoId = parts[0];

        // Verificar se há exceções canceladas para este dia
        for (final excecao in excecoes) {
          if (excecao.cancelada &&
              excecao.data.year == dataNormalizada.year &&
              excecao.data.month == dataNormalizada.month &&
              excecao.data.day == dataNormalizada.day) {
            final dataKey =
                '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
            datasComExcecoesCanceladas.add(dataKey);
          }
        }
      }

      // Uma collectionGroup por data substitui até 20 consultas por médico e,
      // ao contrário do limite antigo, não perde cancelamentos de médicos que
      // ficavam fora da amostra.
      try {
        final snapshot = await firestore
            .collectionGroup('registos')
            .where('data', isEqualTo: dataNormalizada.toIso8601String())
            .get(GetOptions(source: _getSourceForDay(data)));
        for (final doc in snapshot.docs) {
          final segmentos = doc.reference.path.split('/');
          final eExcecaoDaUnidade = segmentos.length >= 8 &&
              segmentos[0] == 'unidades' &&
              segmentos[1] == unidadeId &&
              segmentos[2] == 'ocupantes' &&
              segmentos[4] == 'excecoes' &&
              segmentos[5] == ano.toString() &&
              segmentos[6] == 'registos';
          if (!eExcecaoDaUnidade || doc.data()['cancelada'] != true) continue;

          final medicoId = segmentos[3];
          datasComExcecoesCanceladas.add(
            '${medicoId}_${data.year}-${data.month}-${data.day}',
          );
        }
      } catch (e) {
        _log('⚠️ [EXCEÇÕES-DIA] Consulta agrupada indisponível: $e');
      }
    } catch (e) {
      // Em caso de erro, retornar conjunto vazio
      debugPrint('❌ Erro ao extrair exceções canceladas: $e');
      return <String>{};
    }

    AlocacaoCacheStore.updateExcecoesCanceladasParaDia(
        dataNormalizada, datasComExcecoesCanceladas);
    return datasComExcecoesCanceladas;
  }

  static Future<void> carregarDadosIniciais({
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required Function(List<Gabinete>) onGabinetes,
    required Function(List<Medico>) onMedicos,
    required Function(List<Disponibilidade>) onDisponibilidades,
    required Function(List<Alocacao>) onAlocacoes,
    Unidade? unidade,
    DateTime? dataFiltroDia,
    bool reloadStatic =
        false, // evita recarregar gabinetes/medicos quando só muda o dia
    Set<String>? excecoesCanceladas, // Exceções já carregadas (otimização)
  }) async {
    // Guardar estado inicial para preservar em caso de erro
    final gabinetesIniciais = List<Gabinete>.from(gabinetes);
    final medicosIniciais = List<Medico>.from(medicos);
    try {
      // Sempre consultar a versão no momento da consulta (sem listeners)
      final sync = await AlocacaoCacheSync.sincronizarVersoes(
        unidade: unidade,
        forcar: reloadStatic,
      );
      final deveRecarregarStatic = reloadStatic || sync.recarregarStatic;
      final unidadeKey = _cacheUnidadeKey(unidade);
      if (deveRecarregarStatic) {
        _cacheGabinetesPorUnidade.remove(unidadeKey);
        _cacheMedicosPorUnidade.remove(unidadeKey);
      }

      // Carrega dados estáticos (gabinetes/medicos) apenas quando solicitado
      final List<Gabinete> gabs;
      final List<Medico> meds;
      final cacheGabs = _cacheGabinetesPorUnidade[unidadeKey];
      final cacheMeds = _cacheMedicosPorUnidade[unidadeKey];
      final precisaGabinetes =
          deveRecarregarStatic || (gabinetes.isEmpty && cacheGabs == null);
      final precisaMedicos =
          deveRecarregarStatic || (medicos.isEmpty && cacheMeds == null);

      if (precisaGabinetes) {
        gabs = await buscarGabinetes(
          unidade: unidade,
          forcarAtualizacao: deveRecarregarStatic,
        );
      } else {
        gabs = gabinetes.isNotEmpty ? gabinetes : (cacheGabs ?? []);
      }

      if (precisaMedicos) {
        meds = await buscarMedicos(
          unidade: unidade,
          forcarAtualizacao: deveRecarregarStatic,
        );
      } else {
        meds = medicos.isNotEmpty ? medicos : (cacheMeds ?? []);
      }

      if (gabs.isNotEmpty) {
        _cacheGabinetesPorUnidade[unidadeKey] = List<Gabinete>.from(gabs);
      }
      if (meds.isNotEmpty) {
        _cacheMedicosPorUnidade[unidadeKey] = List<Medico>.from(meds);
      }

      // Usar cache quando disponível
      List<Disponibilidade> disps;
      List<Alocacao> alocs;

      if (dataFiltroDia != null) {
        final key = keyDia(dataFiltroDia);
        // Verificar cache primeiro
        final temCacheDisp =
            AlocacaoCacheStore.cacheDispPorDia.containsKey(key);
        final temCacheAloc =
            AlocacaoCacheStore.cacheAlocPorDia.containsKey(key);
        final estaInvalidado =
            AlocacaoCacheStore.cacheInvalidadoPorDia.contains(key);
        if (temCacheDisp && temCacheAloc && !estaInvalidado) {
          AlocacaoCacheStore.registrarCacheHit(key);
          _log(
              '💾 [CACHE] Usando cache para dia $key (${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year})');
          disps = List<Disponibilidade>.from(
              AlocacaoCacheStore.cacheDispPorDia[key]!);
          alocs = List<Alocacao>.from(AlocacaoCacheStore.cacheAlocPorDia[key]!);
        } else {
          AlocacaoCacheStore.registrarCacheMiss(
            key,
            invalidado: estaInvalidado,
          );
          // Cache não disponível ou invalidado, buscar do Firestore
          // CORREÇÃO: Se app não está em foco, sempre buscar do servidor mesmo se cache existe
          _log('🔄 [CACHE] Buscando do Firestore para dia $key');
          final results = await Future.wait([
            _carregarDisponibilidadesUnidade(unidade,
                dataFiltroDia: dataFiltroDia),
            _carregarAlocacoesUnidade(unidade, dataFiltroDia: dataFiltroDia),
          ]);
          disps = results[0] as List<Disponibilidade>;
          alocs = results[1] as List<Alocacao>;
        }
      } else {
        // Sem filtro de dia, buscar do Firestore (não usar cache para múltiplos dias)
        final results = await Future.wait([
          _carregarDisponibilidadesUnidade(unidade,
              dataFiltroDia: dataFiltroDia),
          _carregarAlocacoesUnidade(unidade, dataFiltroDia: dataFiltroDia),
        ]);
        disps = results[0] as List<Disponibilidade>;
        alocs = results[1] as List<Alocacao>;
      }

      // Aplicar exceções canceladas aos dados carregados (se fornecidas e não foram aplicadas antes)
      // CORREÇÃO CRÍTICA: Sempre filtrar disponibilidades e alocações quando há exceções canceladas
      if (excecoesCanceladas != null &&
          excecoesCanceladas.isNotEmpty &&
          unidade != null &&
          dataFiltroDia != null) {
        // Filtrar disponibilidades - remover todas as disponibilidades de médicos com exceções canceladas
        final dispsAntes = disps.length;
        disps = disps.where((disp) {
          final dataKey =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
          final temExcecao = excecoesCanceladas.contains(dataKey);
          if (temExcecao) {}
          return !temExcecao;
        }).toList();
        if (dispsAntes != disps.length) {
          _log(
              '✅ [FILTRO EXCEÇÃO] Disponibilidades filtradas: $dispsAntes -> ${disps.length} (removidas ${dispsAntes - disps.length})');
        }

        // Filtrar alocações - remover todas as alocações de médicos com exceções canceladas
        final alocsAntes = alocs.length;
        alocs = alocs.where((aloc) {
          final dataKey =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          final temExcecao = excecoesCanceladas.contains(dataKey);
          if (temExcecao) {}
          return !temExcecao;
        }).toList();
        if (alocsAntes != alocs.length) {
          _log(
              '✅ [FILTRO EXCEÇÃO] Alocações filtradas: $alocsAntes -> ${alocs.length} (removidas ${alocsAntes - alocs.length})');
        }
      }

      // Reparar dados antigos criados pela edição de um cartão único: quando
      // há exatamente um cartão e uma alocação no dia, o vínculo é
      // inequívoco e o gabinete deve ser preservado enquanto as horas mudam.
      if (unidade != null) {
        final correcoes = AlocacaoDisponibilidadeValidacaoUtils
            .encontrarCorrecoesInequivocasDeCartoesUnicos(
          alocacoes: alocs,
          disponibilidades: disps,
        );
        if (correcoes.isNotEmpty) {
          try {
            final medicosComSerieAtualizada =
                await AlocacaoHorarioService.persistirCorrecoesInequivocas(
              unidadeId: unidade.id,
              correcoes: correcoes,
            );
            for (final medicoId in medicosComSerieAtualizada) {
              SerieService.invalidateCacheSeries(unidade.id, medicoId);
            }
            final atualizadasPorId = {
              for (final correcao in correcoes)
                correcao.atualizada.id: correcao.atualizada,
            };
            alocs = alocs
                .map((alocacao) => atualizadasPorId[alocacao.id] ?? alocacao)
                .toList();
            _log(
              '✅ [RECONCILIAÇÃO] ${correcoes.length} alocação(ões) '
              'mantida(s) no gabinete com o novo horário',
            );
          } catch (e) {
            _log('⚠️ [RECONCILIAÇÃO] Não foi possível persistir: $e');
          }
        }
      }

      // Uma alocação individual só é válida enquanto existir um cartão com o
      // mesmo médico, dia e intervalo. Isto elimina cópias antigas da vista
      // diária sem arriscar ocultar dados quando um médico não foi carregado.
      final totalAlocacoesAntesValidacao = alocs.length;
      alocs = AlocacaoDisponibilidadeValidacaoUtils.filtrarOrfasConfirmadas(
        alocacoes: alocs,
        disponibilidades: disps,
        onOrfaEncontrada: (alocacao) => _log(
          '⚠️ [VALIDAÇÃO] Alocação órfã ignorada: '
          '${alocacao.id} (${alocacao.medicoId}, '
          '${alocacao.horarioInicio}-${alocacao.horarioFim})',
        ),
      );
      if (totalAlocacoesAntesValidacao != alocs.length) {
        _log(
          '✅ [VALIDAÇÃO] ${totalAlocacoesAntesValidacao - alocs.length} '
          'alocação(ões) órfã(s) removida(s) do dia',
        );
      }

      // Guardar no cache apenas dados já filtrados e validados.
      if (dataFiltroDia != null) {
        updateCacheForDay(
          day: dataFiltroDia,
          disponibilidades: disps,
          alocacoes: alocs,
          forcarValido: true,
        );
      }

      // que por sua vez chama carregarDisponibilidadesDeSeries e carrega disponibilidades "Única"

      // Atualizar as listas
      onGabinetes(List<Gabinete>.from(gabs));
      onMedicos(List<Medico>.from(meds));
      onDisponibilidades(List<Disponibilidade>.from(disps));
      onAlocacoes(List<Alocacao>.from(alocs));
    } catch (e) {
      // CORREÇÃO CRÍTICA: Em caso de erro, NÃO limpar dados estáticos (gabinetes e médicos)
      // Esses dados não mudam com a data e não devem ser perdidos
      // Preservar dados estáticos existentes para evitar que sejam perdidos durante mudança de data
      debugPrint('❌ Erro ao carregar dados iniciais: $e');

      // Se estamos recarregando ou não havia dados, usar listas vazias
      if (!reloadStatic && gabinetesIniciais.isNotEmpty) {
        onGabinetes(gabinetesIniciais);
      } else {
        onGabinetes(<Gabinete>[]);
      }

      if (!reloadStatic && medicosIniciais.isNotEmpty) {
        onMedicos(medicosIniciais);
      } else {
        onMedicos(<Medico>[]);
      }

      // Para dados dinâmicos, usar listas vazias em caso de erro
      onDisponibilidades(<Disponibilidade>[]);
      onAlocacoes(<Alocacao>[]);
    }
  }

  static List<Medico> filtrarMedicosPorData({
    required DateTime dataSelecionada,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
  }) {
    final dataAlvo = DateTime(
        dataSelecionada.year, dataSelecionada.month, dataSelecionada.day);

    final dispNoDia = disponibilidades.where((disp) {
      final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return d == dataAlvo;
    }).toList();

    final idsMedicosNoDia = dispNoDia.map((d) => d.medicoId).toSet();
    final alocadosNoDia = alocacoes
        .where((a) {
          final aData = DateTime(a.data.year, a.data.month, a.data.day);
          return aData == dataAlvo;
        })
        .map((a) => a.medicoId)
        .toSet();

    return medicos
        .where((m) =>
            idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
        .toList();
  }

  static List<Gabinete> filtrarGabinetesPorUI({
    required List<Gabinete> gabinetes,
    required List<Alocacao> alocacoes,
    required DateTime selectedDate,
    required List<String> pisosSelecionados,
    required String filtroOcupacao,
    required bool mostrarConflitos,
    String? filtroEspecialidadeGabinete,
  }) {
    // Filtro por piso
    final filtradosPiso = pisosSelecionados.isEmpty
        ? gabinetes
        : gabinetes.where((g) => pisosSelecionados.contains(g.setor)).toList();

    // Filtro por especialidade do gabinete
    final filtrados = filtroEspecialidadeGabinete != null &&
            filtroEspecialidadeGabinete.isNotEmpty
        ? filtradosPiso
            .where((g) => g.especialidadesPermitidas
                .contains(filtroEspecialidadeGabinete))
            .toList()
        : filtradosPiso;

    List<Gabinete> filtradosOcupacao = [];
    for (final gab in filtrados) {
      final alocacoesDoGab = alocacoes.where((a) {
        return a.gabineteId == gab.id &&
            a.data.year == selectedDate.year &&
            a.data.month == selectedDate.month &&
            a.data.day == selectedDate.day;
      }).toList();

      final estaOcupado = alocacoesDoGab.isNotEmpty;

      if (filtroOcupacao == 'Todos') {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Livres' && !estaOcupado) {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Ocupados' && estaOcupado) {
        filtradosOcupacao.add(gab);
      }
    }

    if (mostrarConflitos) {
      return filtradosOcupacao.where((gab) {
        final alocacoesDoGab = alocacoes.where((a) {
          return a.gabineteId == gab.id &&
              a.data.year == selectedDate.year &&
              a.data.month == selectedDate.month &&
              a.data.day == selectedDate.day;
        }).toList();
        return ConflictUtils.temConflitoGabinete(alocacoesDoGab);
      }).toList();
    } else {
      return filtradosOcupacao;
    }
  }

  static Future<void> alocarMedico({
    required DateTime selectedDate,
    required String medicoId,
    required String gabineteId,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required Function() onAlocacoesChanged,
    Unidade? unidade,
    List<String>?
        horariosForcados, // Novo parâmetro opcional para forçar horários
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    String? horarioInicioForcado;
    String? horarioFimForcado;
    if (horariosForcados != null && horariosForcados.length >= 2) {
      horarioInicioForcado = horariosForcados[0];
      horarioFimForcado = horariosForcados[1];
    }

    // Validar antes de remover qualquer alocação existente. Sem isto, uma
    // falha de carregamento podia fabricar 08:00-15:00 e ainda apagar o cartão
    // correto antes de o erro ser detetado.
    if (horarioInicioForcado != null && horarioFimForcado != null) {
      final existeDisponibilidade = disponibilidades.any((disp) {
        return AlocacaoDisponibilidadeValidacaoUtils.disponibilidadeCorresponde(
          disponibilidade: disp,
          medicoId: medicoId,
          data: dataAlvo,
          horarioInicio: horarioInicioForcado!,
          horarioFim: horarioFimForcado!,
        );
      });
      if (!existeDisponibilidade) {
        throw StateError(
          'O cartão selecionado já não corresponde a uma disponibilidade válida.',
        );
      }
    } else {
      final candidatas = disponibilidades.where((disp) {
        final dia = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId &&
            dia == dataAlvo &&
            disp.horarios.length >= 2;
      }).toList();
      if (candidatas.isEmpty) {
        throw StateError(
          'Não é possível alocar o médico sem um horário válido neste dia.',
        );
      }
      if (candidatas.length > 1) {
        throw StateError(
          'Existem vários cartões neste dia; indique o horário do cartão a alocar.',
        );
      }
    }

    // Substituir apenas a alocação correspondente ao cartão/intervalo. Outras
    // sequências do mesmo médico no dia têm de permanecer independentes.
    final alocacoesAnteriores = alocacoes.where((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      // NÃO remover alocações otimistas - elas serão substituídas pela nova alocação real
      return a.medicoId == medicoId &&
          alocDate == dataAlvo &&
          (horarioInicioForcado == null ||
              (a.horarioInicio == horarioInicioForcado &&
                  a.horarioFim == horarioFimForcado)) &&
          !a.id.startsWith('otimista_');
    }).toList();

    if (alocacoesAnteriores.isNotEmpty) {
      _log(
          '🔄 Removendo ${alocacoesAnteriores.length} alocação(ões) anterior(es) do médico $medicoId no dia ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');

      // Remover da lista local
      for (final alocacaoAnterior in alocacoesAnteriores) {
        alocacoes.remove(alocacaoAnterior);
      }

      // Remover todas as alocações anteriores do Firebase
      final firestore = FirebaseFirestore.instance;
      final unidadeId = unidade?.id ??
          'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade

      for (final alocacaoAnterior in alocacoesAnteriores) {
        try {
          await _removerAlocacaoPersistida(
            firestore: firestore,
            unidadeId: unidadeId,
            alocacao: alocacaoAnterior,
          );
          _log(
              '✅ Alocação anterior removida do Firebase: ${alocacaoAnterior.id}');
        } catch (e) {
          _log(
              '⚠️ Erro ao remover alocação anterior ${alocacaoAnterior.id} do Firebase (pode já ter sido removida): $e');
          // Continuar mesmo se houver erro (pode já ter sido removida)
        }
      }
    }

    // Se horários foram forçados, usar esses. Senão, buscar das disponibilidades
    String horarioInicio;
    String horarioFim;

    final disponibilidadesDoDia = disponibilidades.where((disp) {
      return AlocacaoDisponibilidadeValidacaoUtils.disponibilidadeCorresponde(
        disponibilidade: disp,
        medicoId: medicoId,
        data: dataAlvo,
        horarioInicio: horariosForcados != null && horariosForcados.length >= 2
            ? horariosForcados[0]
            : disp.horarios.isNotEmpty
                ? disp.horarios[0]
                : '',
        horarioFim: horariosForcados != null && horariosForcados.length >= 2
            ? horariosForcados[1]
            : disp.horarios.length >= 2
                ? disp.horarios[1]
                : '',
      );
    }).toList();

    if (horariosForcados != null && horariosForcados.length >= 2) {
      if (disponibilidadesDoDia.isEmpty) {
        throw StateError(
          'Não existe uma disponibilidade válida para $medicoId em '
          '${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year} no intervalo '
          '${horariosForcados[0]}-${horariosForcados[1]}.',
        );
      }
      horarioInicio = horariosForcados[0];
      horarioFim = horariosForcados[1];
      _log('✅ Usando horários forçados: $horarioInicio - $horarioFim');
    } else {
      final dispDoDia = disponibilidades.where((disp) {
        final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId &&
            dd == dataAlvo &&
            disp.horarios.length >= 2;
      }).toList();

      if (dispDoDia.isEmpty) {
        throw StateError(
          'Não é possível alocar o médico sem um horário válido neste dia.',
        );
      }
      if (dispDoDia.length > 1) {
        throw StateError(
          'Existem vários cartões neste dia; indique o horário do cartão a alocar.',
        );
      }
      horarioInicio = dispDoDia.first.horarios[0];
      horarioFim = dispDoDia.first.horarios[1];
    }

    // Gerar ID único baseado em timestamp + microsegundos + data + médico + gabinete
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dataStr =
        '${dataAlvo.year}${dataAlvo.month.toString().padLeft(2, '0')}${dataAlvo.day.toString().padLeft(2, '0')}';
    final novaAloc = Alocacao(
      id: '${timestamp}_${medicoId}_${gabineteId}_$dataStr',
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataAlvo,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );

    // Salvar no Firebase
    try {
      final firestore = FirebaseFirestore.instance;

      // Salvar na coleção de alocações da unidade por ano
      final unidadeId = unidade?.id ??
          'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
      final ano = dataAlvo.year.toString();
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');

      await alocacoesRef.doc(novaAloc.id).set({
        'id': novaAloc.id,
        'medicoId': novaAloc.medicoId,
        'gabineteId': novaAloc.gabineteId,
        'data': novaAloc.data.toIso8601String(),
        'horarioInicio': novaAloc.horarioInicio,
        'horarioFim': novaAloc.horarioFim,
      });

      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldAlocacoes,
      );
      _log('✅ Alocação salva no Firebase: ${novaAloc.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar alocação no Firebase: $e');
      rethrow; // Re-throw para que o erro seja tratado no nível superior
    }

    // Adicionar localmente IMEDIATAMENTE para feedback visual instantâneo
    // O listener do Firestore vai atualizar depois, mas isso garante que o cartão apareça no gabinete
    final indexExistente = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          aDate == dataAlvo &&
          a.horarioInicio == horarioInicio &&
          a.horarioFim == horarioFim;
    });

    if (indexExistente != -1) {
      alocacoes[indexExistente] = novaAloc;
    } else {
      alocacoes.add(novaAloc);
    }

    // CORREÇÃO CRÍTICA: Invalidar cache do dia após salvar para garantir que será recarregado
    // quando necessário. Também invalidar cache do ano para garantir que todas as alocações sejam atualizadas
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
    invalidateCacheForDay(dataAlvoNormalizada);
    invalidateCacheFromDate(DateTime(dataAlvo.year, 1, 1));

    // CORREÇÃO: Chamar onAlocacoesChanged() que recarrega tudo do Firebase
    // Mas como já adicionamos localmente, o cartão aparece imediatamente
    // O delay aumentado ajuda a consolidar atualizações e reduzir "piscar"
  }

  static Future<void> desalocarMedicoDiaUnico({
    required DateTime selectedDate,
    required String medicoId,
    String? alocacaoId,
    String? serieId,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Function() onAlocacoesChanged,
    Unidade? unidade,
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    // CORREÇÃO CRÍTICA: Invalidar cache ANTES de desalocar
    invalidateCacheForDay(dataAlvo);

    final indexAloc = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          aDate == dataAlvo &&
          (alocacaoId == null || a.id == alocacaoId);
    });
    if (indexAloc == -1) {
      return;
    }

    final alocacaoRemovida = alocacoes[indexAloc];

    // CORREÇÃO CRÍTICA: Verificar se é alocação de série (pode ser exceção)
    // Se for série, verificar se há exceção para esta data
    final eAlocacaoDeSerie = alocacaoRemovida.id.startsWith('serie_');

    if (eAlocacaoDeSerie) {
      // Extrair ID da série
      String? serieIdAlvo = serieId;
      final partes = alocacaoRemovida.id.split('_');

      if (serieIdAlvo == null &&
          partes.length >= 4 &&
          partes[0] == 'serie' &&
          partes[1] == 'serie') {
        serieIdAlvo = 'serie_${partes[2]}';
      } else if (serieIdAlvo == null &&
          partes.length >= 3 &&
          partes[0] == 'serie') {
        serieIdAlvo =
            partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
      }

      if (serieIdAlvo != null) {
        // Verificar se há exceção para esta série e data
        final excecoes = await SerieService.carregarExcecoes(
          medicoId,
          unidade: unidade,
          dataInicio: dataAlvo,
          dataFim: dataAlvo,
          serieId: serieIdAlvo,
          forcarServidor: true,
        );

        final excecaoExistente = excecoes.firstWhere(
          (e) =>
              e.serieId == serieIdAlvo &&
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

        if (excecaoExistente.id.isNotEmpty) {
          // Já existe uma exceção - atualizar para remover o gabinete (exceção de gabinete)
          _log(
              '🔄 [DESALOCAÇÃO] Cartão é exceção de série existente, atualizando para remover gabinete: ${excecaoExistente.id}');

          // Atualizar exceção existente removendo o gabinete (exceção de gabinete com gabineteId: null)
          final excecaoAtualizada = ExcecaoSerie(
            id: excecaoExistente.id,
            serieId: excecaoExistente.serieId,
            data: excecaoExistente.data,
            cancelada:
                false, // IMPORTANTE: Não cancelada - é exceção de gabinete, não de disponibilidade
            horarios: excecaoExistente.horarios,
            gabineteId:
                null, // Remover gabinete - médico fica sem gabinete mas disponível
          );

          await SerieService.salvarExcecao(excecaoAtualizada, medicoId,
              unidade: unidade);

          // Invalidar cache após atualizar exceção
          invalidateCacheForDay(dataAlvo);
          invalidateCacheFromDate(DateTime(dataAlvo.year, 1, 1));

          // Remover da lista local (a série não vai mais regenerar este dia no gabinete)
          alocacoes.removeAt(indexAloc);

          _log(
              '✅ [DESALOCAÇÃO] Exceção de gabinete atualizada - médico sem gabinete mas disponível');

          // CORREÇÃO: Adicionar médico de volta à lista de disponíveis
          // Mesmo sem disponibilidade local, o médico deve aparecer nos desalocados
          // A disponibilidade será regenerada quando o cache for recarregado
          final medico = medicos.firstWhere(
            (m) => m.id == medicoId,
            orElse: () => Medico(
              id: medicoId,
              nome: 'Médico não identificado',
              especialidade: '',
              disponibilidades: [],
              ativo: true, // Ativo para aparecer na lista
            ),
          );
          if (!medicosDisponiveis.contains(medico)) {
            medicosDisponiveis.add(medico);
          }

          onAlocacoesChanged();
          return; // Retornar aqui - não remover do Firestore pois é alocação gerada
        } else {
          // CORREÇÃO CRÍTICA: É uma série mas NÃO existe exceção ainda
          // Precisamos criar uma EXCEÇÃO DE GABINETE (não de disponibilidade) para remover o gabinete deste dia
          // O médico fica sem gabinete neste dia mas continua disponível
          _log(
              '🔄 [DESALOCAÇÃO] Cartão é de série sem exceção - criando exceção de gabinete para ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');

          // Criar exceção de gabinete removendo o gabinete deste dia específico
          await DisponibilidadeSerieService.removerGabineteDataSerie(
            serieId: serieIdAlvo,
            medicoId: medicoId,
            data: dataAlvo,
            unidade: unidade,
          );

          // Invalidar cache após criar exceção de gabinete
          invalidateCacheForDay(dataAlvo);
          invalidateCacheFromDate(DateTime(dataAlvo.year, 1, 1));

          // Remover da lista local (a série não vai mais regenerar este dia no gabinete devido à exceção de gabinete)
          alocacoes.removeAt(indexAloc);

          _log(
              '✅ [DESALOCAÇÃO] Exceção de gabinete criada - dia ${dataAlvo.day}/${dataAlvo.month} não será mais gerado pela série (médico sem gabinete mas disponível)');

          // Adicionar médico de volta à lista de disponíveis
          final medico = medicos.firstWhere(
            (m) => m.id == medicoId,
            orElse: () => Medico(
              id: medicoId,
              nome: 'Médico não identificado',
              especialidade: '',
              disponibilidades: [],
              ativo: true,
            ),
          );
          if (!medicosDisponiveis.contains(medico)) {
            medicosDisponiveis.add(medico);
          }

          onAlocacoesChanged();
          return; // Retornar aqui - não remover do Firestore pois é alocação gerada
        }
      }
    }

    alocacoes.removeAt(indexAloc);

    // Remover do Firebase (apenas para alocações individuais, não séries)
    try {
      final firestore = FirebaseFirestore.instance;
      final ano = alocacaoRemovida.data.year.toString();
      final unidadeId = unidade?.id ??
          'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
      await _removerAlocacaoPersistida(
        firestore: firestore,
        unidadeId: unidadeId,
        alocacao: alocacaoRemovida,
      );
      await CacheVersionService.bumpVersion(
        unidadeId: unidadeId,
        field: CacheVersionService.fieldAlocacoes,
      );
      _log(
          '✅ Alocação removida do Firebase: ${alocacaoRemovida.id} (ano: $ano, unidade: $unidadeId)');

      // CORREÇÃO CRÍTICA: Invalidar cache do dia e do ano após remover alocação
      // Garantir que quando o utilizador navega para este dia, a alocação não aparecerá
      invalidateCacheForDay(dataAlvo);
      invalidateCacheFromDate(DateTime(dataAlvo.year, 1, 1));
    } catch (e) {
      debugPrint('❌ Erro ao remover alocação do Firebase: $e');
    }

    // CORREÇÃO CRÍTICA: Adicionar médico de volta à lista de disponíveis
    // Mesmo sem disponibilidade local, o médico deve aparecer nos desalocados
    // A disponibilidade será regenerada quando o cache for recarregado
    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
        ativo: true, // Ativo para aparecer na lista
      ),
    );
    // CORREÇÃO: Sempre adicionar médico de volta, mesmo sem disponibilidade local
    if (!medicosDisponiveis.contains(medico)) {
      medicosDisponiveis.add(medico);
      _log(
          '✅ [DESALOCAÇÃO] Médico adicionado de volta aos disponíveis: $medicoId');
    } else {
      _log('⚠️ [DESALOCAÇÃO] Médico já estava nos disponíveis: $medicoId');
    }

    // Chamar onAlocacoesChanged() DEPOIS de invalidar cache e atualizar lista local
    onAlocacoesChanged();
  }

  static Future<void> desalocarMedicoSerie({
    required String medicoId,
    required DateTime dataRef,
    required String tipo,
    String? serieId,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Function() onAlocacoesChanged,
    Unidade? unidade,
  }) async {
    // OTIMIZAÇÃO: Buscar a série primeiro, depois buscar apenas as alocações necessárias
    // Isso evita buscar todas as alocações do médico quando só precisamos das da série
    final tipoNormalizado =
        tipo.startsWith('Consecutivo') ? 'Consecutivo' : tipo;
    final dataRefNormalizada =
        DateTime(dataRef.year, dataRef.month, dataRef.day);

    // CORREÇÃO CRÍTICA: Invalidar cache ANTES de desalocar série
    invalidateCacheForDay(dataRefNormalizada);
    invalidateCacheFromDate(DateTime(dataRef.year, 1, 1));

    final series = await SerieService.carregarSeries(
      medicoId,
      unidade: unidade,
    );

    // Encontrar a série correspondente
    SerieRecorrencia? serieEncontrada;
    for (final serie in series) {
      if (serieId != null && serie.id != serieId) continue;
      if (!serie.ativo || serie.tipo != tipoNormalizado) continue;

      // Verificar se a data está dentro do período da série
      if (dataRefNormalizada.isBefore(serie.dataInicio)) continue;
      if (serie.dataFim != null && dataRefNormalizada.isAfter(serie.dataFim!)) {
        continue;
      }

      // Verificar padrão da série
      bool corresponde = false;
      if (tipoNormalizado == 'Semanal') {
        final diasDiferenca =
            dataRefNormalizada.difference(serie.dataInicio).inDays;
        corresponde = diasDiferenca % 7 == 0;
      } else if (tipoNormalizado == 'Quinzenal') {
        final diasDiferenca =
            dataRefNormalizada.difference(serie.dataInicio).inDays;
        corresponde = diasDiferenca % 14 == 0;
      } else if (tipoNormalizado == 'Mensal') {
        corresponde = dataRefNormalizada.day == serie.dataInicio.day;
      } else if (tipoNormalizado == 'Consecutivo') {
        final diasDiferenca =
            dataRefNormalizada.difference(serie.dataInicio).inDays;
        final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
        corresponde = diasDiferenca >= 0 && diasDiferenca < numeroDias;
      }

      if (corresponde) {
        serieEncontrada = serie;
        break;
      }
    }

    // OTIMIZAÇÃO CRÍTICA: Para séries, não existem alocações individuais no Firestore!
    // As alocações são geradas dinamicamente a partir da série quando se lê.
    // Portanto, apenas precisamos:
    // 1. Remover o gabineteId da série (já feito acima)
    // 2. Invalidar o cache (já feito acima)
    // 3. Remover da lista local apenas as alocações geradas dinamicamente

    if (serieEncontrada == null) {
      // Buscar e remover apenas este dia específico
      final alocacoesDoDia = await buscarAlocacoesMedico(
        unidade,
        medicoId,
        dataInicio: dataRefNormalizada,
        dataFim: dataRefNormalizada.add(const Duration(days: 1)),
      );
      final alocacoesParaRemover = alocacoesDoDia.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return a.medicoId == medicoId && aDateNormalizada == dataRefNormalizada;
      }).toList();

      // Remover da lista local
      for (final alocacao in alocacoesParaRemover) {
        final indexAloc = alocacoes.indexWhere((a) => a.id == alocacao.id);
        if (indexAloc != -1) {
          alocacoes.removeAt(indexAloc);
        }
      }

      // Remover do Firestore (apenas se existir alocação individual)
      if (alocacoesParaRemover.isNotEmpty) {
        try {
          final firestore = FirebaseFirestore.instance;
          final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
          final batch = firestore.batch();

          for (final alocacao in alocacoesParaRemover) {
            final ano = alocacao.data.year.toString();
            final alocacoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('alocacoes')
                .doc(ano)
                .collection('registos');
            batch.delete(alocacoesRef.doc(alocacao.id));
          }

          await batch.commit();
        } catch (e) {
          // Em caso de erro, continuar
        }
      }
    } else {
      // Para séries: remover o gabineteId da série no Firestore e da lista local
      final serie = serieEncontrada; // Já verificado que não é null no if acima

      // Remover o gabineteId da série no Firestore IMEDIATAMENTE
      try {
        await DisponibilidadeSerieService.desalocarSerie(
          serieId: serie.id,
          medicoId: medicoId,
          unidade: unidade,
        );

        // NOTA: invalidateCacheParaSerie já é chamado dentro de desalocarSerie,
        // então não precisamos chamar novamente aqui

        // Verificar se foi realmente removido buscando novamente do servidor
        final seriesVerificacao = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
        );
        seriesVerificacao.firstWhere(
          (s) => s.id == serie.id,
          orElse: () => serie,
        );
      } catch (e) {
        // Em caso de erro, continuar
      }

      // CORREÇÃO: Com a nova arquitetura, séries não criam mais alocações individuais no Firestore
      // Mas pode haver alocações antigas de versões anteriores que precisam ser removidas
      // As alocações antigas têm ID no formato: 'serie_${serie.id}_${dataKey}' onde dataKey é 'YYYY-MM-DD'
      final serieIdPrefix = 'serie_${serie.id}_';

      // Remover TODAS as alocações que têm ID começando com 'serie_${serie.id}_'
      final alocacoesRemovidas = alocacoes.where((a) {
        if (a.id.startsWith(serieIdPrefix)) {
          return true;
        }
        return false;
      }).toList();

      // Remover da lista local
      for (final alocacao in alocacoesRemovidas) {
        alocacoes.removeWhere((a) => a.id == alocacao.id);
      }

      // CORREÇÃO: Deletar alocações antigas do Firestore (se existirem)
      // Com a nova arquitetura, séries não criam mais alocações individuais
      // Mas pode haver alocações antigas de versões anteriores que precisam ser limpas
      // IMPORTANTE: Buscar TODAS as alocações da série do Firestore para limpeza
      try {
        final firestore = FirebaseFirestore.instance;
        final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
        final batch = firestore.batch();
        int totalParaDeletar = 0;

        // Buscar alocações da série em todos os anos possíveis (ano atual + próximos 2 anos)
        // porque quando aloca, cria alocações para 90 dias, mas séries infinitas podem cruzar anos
        final anoAtual = dataRef.year;
        final anoLimite = anoAtual + 2; // Buscar até 2 anos no futuro

        for (int ano = anoAtual; ano <= anoLimite; ano++) {
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('alocacoes')
              .doc(ano.toString())
              .collection('registos');

          // Buscar todas as alocações do médico neste ano
          final snapshot = await alocacoesRef
              .where('medicoId', isEqualTo: medicoId)
              .get(const GetOptions(source: Source.serverAndCache));

          // Filtrar apenas as que têm ID começando com o prefixo da série
          for (final doc in snapshot.docs) {
            final alocId = doc.id;
            if (alocId.startsWith(serieIdPrefix)) {
              batch.delete(alocacoesRef.doc(alocId));
              totalParaDeletar++;
            }
          }
        }

        if (totalParaDeletar > 0) {
          await batch.commit();
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao desalocar série (batch): $e');
      }

      // Cache já foi invalidado acima após desalocar a série
    }

    // Garantir que o médico seja adicionado de volta à lista de disponíveis
    // mesmo que não haja disponibilidade no momento (será regenerada)
    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
        ativo: true,
      ),
    );

    // Adicionar médico de volta à lista de disponíveis
    // A disponibilidade será regenerada quando o cache for recarregado
    if (!medicosDisponiveis.contains(medico)) {
      medicosDisponiveis.add(medico);
    }

    onAlocacoesChanged();

    // Cache já foi invalidado acima quando a série foi desalocada
  }

  /// Carrega todas as disponibilidades de todos os médicos de uma unidade (otimizado para ano atual)
  static Future<List<Disponibilidade>> _carregarDisponibilidadesUnidade(
      Unidade? unidade,
      {DateTime? dataFiltroDia}) async {
    // Se fornecido, filtrar por dia: pergunta apenas às coleções do ano alvo
    final alvo = dataFiltroDia ?? DateTime.now();
    final anoAlvo = alvo.year.toString();
    return _carregarDisponibilidadesUnidadePorAno(
      unidade,
      anoAlvo,
      dataFiltroDia: dataFiltroDia,
    );
  }

  /// Carrega disponibilidades de todos os médicos de uma unidade por ano específico
  /// Agora também carrega séries e gera cartões dinamicamente
  static Future<List<Disponibilidade>> _carregarDisponibilidadesUnidadePorAno(
      Unidade? unidade, String? anoEspecifico,
      {DateTime? dataFiltroDia}) async {
    // NOVO MODELO: Carregar séries e gerar cartões dinamicamente
    // As exceções já são aplicadas automaticamente na geração
    final disponibilidadesDeSeries = await carregarDisponibilidadesDeSeries(
      unidade: unidade,
      anoEspecifico: anoEspecifico,
      dataFiltroDia: dataFiltroDia,
    );

    // CORREÇÃO: Também carregar disponibilidades "Única" do Firestore
    // Elas são salvas em unidades/{unidadeId}/dias/{dayKey}/disponibilidades
    List<Disponibilidade> dispsUnicas = [];
    if (unidade != null && dataFiltroDia != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final keyDia =
            '${dataFiltroDia.year}-${dataFiltroDia.month.toString().padLeft(2, '0')}-${dataFiltroDia.day.toString().padLeft(2, '0')}';
        final diasRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('dias')
            .doc(keyDia)
            .collection('disponibilidades');

        // Usar Source apropriado (server se cache invalidado, serverAndCache caso contrário)
        final snapshot = await diasRef
            .get(GetOptions(source: _getSourceForDay(dataFiltroDia)));
        dispsUnicas = snapshot.docs
            .map((doc) => Disponibilidade.fromMap(doc.data()))
            .where((d) => d.tipo == 'Única')
            .toList();
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar disponibilidades únicas: $e');
      }
    }

    // Mesclar séries e únicas
    final todasDisps = <String, Disponibilidade>{};

    for (final disp in disponibilidadesDeSeries) {
      // CORREÇÃO: Se há filtro de dia, incluir apenas disponibilidades desse dia
      if (dataFiltroDia != null) {
        final dispData =
            DateTime(disp.data.year, disp.data.month, disp.data.day);
        final filtroData = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        if (dispData != filtroData) {
          continue; // Pular disponibilidades de outros dias
        }
      }
      final chave =
          '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.id}';
      todasDisps[chave] = disp;
    }
    for (final disp in dispsUnicas) {
      // CORREÇÃO: Se há filtro de dia, incluir apenas disponibilidades desse dia
      if (dataFiltroDia != null) {
        final dispData =
            DateTime(disp.data.year, disp.data.month, disp.data.day);
        final filtroData = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        if (dispData != filtroData) {
          continue; // Pular disponibilidades de outros dias
        }
      }
      final chave =
          '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.id}';
      todasDisps[chave] = disp;
    }

    final resultado = todasDisps.values.toList();
    return resultado;
  }

  /// Carrega séries de recorrência e gera disponibilidades dinamicamente
  static Future<List<Disponibilidade>> carregarDisponibilidadesDeSeries({
    required Unidade? unidade,
    String? anoEspecifico,
    DateTime? dataFiltroDia,
  }) async {
    if (unidade == null) return [];

    final forcarServidorSeries =
        AlocacaoCacheSync.shouldForceServerForSeries(unidade);

    // Usar Map para evitar duplicatas sem fundir séries diferentes do mesmo
    // tipo que coincidam no mesmo dia.
    final disponibilidadesMap = <String, Disponibilidade>{};
    final firestore = FirebaseFirestore.instance;

    // Variável para rastrear médicos com séries (fora do try para estar acessível)
    final medicosComSeries = <String>[];

    try {
      // Determinar período para gerar cartões
      DateTime dataInicio;

      if (dataFiltroDia != null) {
        // CORREÇÃO: Gerar para um período maior para capturar séries que começaram antes
        // Se gerarmos apenas para o dia, séries que começaram antes podem não gerar disponibilidade
        // Exemplo: série semanal que começou em dezembro não geraria disponibilidade para janeiro
        dataInicio = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        // Gerar para um período de 7 dias antes até 1 dia depois para garantir que séries semanais sejam capturadas
        dataInicio = dataInicio.subtract(const Duration(days: 7));
      } else if (anoEspecifico != null) {
        // Se há ano específico, gerar para o ano inteiro
        final ano = int.tryParse(anoEspecifico) ?? DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
      } else {
        // Gerar para o ano atual
        final ano = DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
      }

      // Carregar médicos ativos a partir do cache local quando possível
      // (evita round-trip desnecessário ao Firestore).
      final unidadeKey = _cacheUnidadeKey(unidade);
      final cachedMedicos = _cacheMedicosPorUnidade[unidadeKey];
      List<String> medicoIds = [];
      if (cachedMedicos != null && cachedMedicos.isNotEmpty) {
        medicoIds = cachedMedicos
            .where((m) => m.ativo)
            .map((m) => m.id)
            .where((id) => id.isNotEmpty)
            .toList();
      }

      if (medicoIds.isEmpty) {
        // Fallback: buscar do servidor apenas quando não há cache confiável
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('ocupantes');

        final medicosSnapshot = await medicosRef
            .where('ativo', isEqualTo: true)
            .get(const GetOptions(
                source: Source.server)); // Forçar servidor para evitar cache
        medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
      }
      if (medicoIds.isEmpty) {
        return disponibilidadesMap.values.toList();
      }

      DateTime? dataInicioSeriesEmLote;
      DateTime? dataFimSeriesEmLote;
      if (dataFiltroDia != null) {
        dataInicioSeriesEmLote = null;
        dataFimSeriesEmLote = dataFiltroDia.add(const Duration(days: 1));
      } else if (anoEspecifico != null) {
        final ano = int.tryParse(anoEspecifico) ?? DateTime.now().year;
        dataInicioSeriesEmLote = null;
        dataFimSeriesEmLote = DateTime(ano + 1, 1, 1);
      } else {
        final ano = DateTime.now().year;
        dataInicioSeriesEmLote = DateTime(ano, 1, 1);
        dataFimSeriesEmLote = DateTime(ano + 1, 1, 1);
      }
      final forcarSeriesEmLote =
          (anoEspecifico != null && dataFiltroDia == null) ||
              forcarServidorSeries;
      final seriesPorMedico = await SerieService.carregarSeriesDeMedicos(
        medicoIds,
        unidade: unidade,
        dataInicio: dataInicioSeriesEmLote,
        dataFim: dataFimSeriesEmLote,
        forcarServidor: forcarSeriesEmLote,
      );

      // Carregar séries em paralelo para médicos ativos
      final futures = <Future<List<Disponibilidade>>>[];

      for (final medicoId in medicoIds) {
        // SEMPRE carregar séries do Firestore (cache removido)
        if (dataFiltroDia == null && anoEspecifico == null) {
          continue;
        }

        // Carregar séries e exceções em paralelo
        futures.add((() async {
          try {
            // IMPORTANTE: Para séries infinitas, precisamos carregar TODAS as séries ativas
            // que começaram antes ou no período, independentemente do dataFim da série.
            // O filtro por período será feito na geração dinâmica, não no carregamento.
            // Se há filtro de dia, ainda precisamos carregar todas as séries ativas que
            // podem se aplicar a essa data (séries que começaram antes ou nessa data).
            DateTime? dataInicioParaCarregarSeries;
            DateTime? dataFimParaCarregarSeries;

            if (dataFiltroDia != null) {
              // CORREÇÃO CRÍTICA: Carregar TODAS as séries ativas (dataInicio = null)
              // Séries antigas (ex: de 2020) ainda ativas devem ser incluídas
              // O filtro de relevância será feito DEPOIS localmente
              // Não podemos usar janela de tempo aqui porque perderíamos séries antigas
              dataInicioParaCarregarSeries = null;
              // Apenas filtrar séries que começaram depois do dia (não aplicáveis)
              dataFimParaCarregarSeries =
                  dataFiltroDia.add(const Duration(days: 1));
            } else {
              // CORREÇÃO CRÍTICA: Quando anoEspecifico é fornecido (ex: filtro de médicos não alocados),
              // precisamos carregar TODAS as séries ativas, não apenas as que começam no ano
              // Porque séries que começaram antes (ex: em fevereiro) ainda geram disponibilidades no ano
              // O filtro por ano será feito na geração de disponibilidades, não no carregamento de séries
              if (anoEspecifico != null) {
                // Para filtro de ano completo, carregar TODAS as séries ativas (dataInicio = null)
                // e filtrar apenas séries que começam depois do fim do ano (não aplicáveis)
                final ano = int.tryParse(anoEspecifico) ?? DateTime.now().year;
                dataInicioParaCarregarSeries = null;
                dataFimParaCarregarSeries = DateTime(ano + 1, 1, 1);
              } else {
                final ano = DateTime.now().year;
                dataInicioParaCarregarSeries = DateTime(ano, 1, 1);
                dataFimParaCarregarSeries = DateTime(ano + 1, 1, 1);
              }
            }

            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'alocacao_medicos_logic.dart:1415',
//                'message': '🔵 [HYP-E] Carregando séries para médico - ANTES',
//                'data': {
//                  'medicoId': medicoId,
//                  'dataFiltroDia': dataFiltroDia != null ? dataFiltroDia.toString() : 'null',
//                  'dataInicioParaCarregarSeries': dataInicioParaCarregarSeries != null ? dataInicioParaCarregarSeries.toString() : 'null',
//                  'dataFimParaCarregarSeries': dataFimParaCarregarSeries.toString(),
//                  'hypothesisId': 'E'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}

// #endregion

            final series = seriesPorMedico[medicoId] ?? const [];

            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'alocacao_medicos_logic.dart:1420',
//                'message': '🟡 [HYP-E] Séries carregadas - DEPOIS',
//                'data': {
//                  'medicoId': medicoId,
//                  'totalSeries': series.length,
//                  'seriesIds': series.map((s) => s.id).toList(),
//                  'seriesTipos': series.map((s) => s.tipo).toList(),
//                  'seriesDataInicio': series.map((s) => s.dataInicio.toString()).toList(),
//                  'hypothesisId': 'E'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}

// #endregion

            if (series.isEmpty) {
              return <Disponibilidade>[];
            }

            // OTIMIZAÇÃO CRÍTICA: Filtrar séries que não podem se aplicar ao dia ANTES de carregar exceções
            // Isso evita centenas de chamadas de exceções desnecessárias para médicos sem séries relevantes
            List<SerieRecorrencia> seriesRelevantes = series;
            if (dataFiltroDia != null) {
              final dataFiltro = dataFiltroDia; // Evitar null-check repetido
              // Filtrar séries que começaram depois do dia ou terminaram antes do dia
              // CORREÇÃO CRÍTICA: Normalizar datas para comparação correta (sem hora/minutos/segundos)
              final dataFiltroNormalizada =
                  DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day);
              seriesRelevantes = series.where((serie) {
                final serieDataInicioNormalizada = DateTime(
                    serie.dataInicio.year,
                    serie.dataInicio.month,
                    serie.dataInicio.day);
                // Série começou depois do dia selecionado - não aplicável
                if (serieDataInicioNormalizada.isAfter(dataFiltroNormalizada)) {
                  // #region agent log (COMENTADO - pode ser reativado se necessário)

//                  try {
//                    final logEntry = {
//                      'timestamp': DateTime.now().millisecondsSinceEpoch,
//                      'location': 'alocacao_medicos_logic.dart:1432',
//                      'message': '🔴 [HYP-E] Série filtrada - começou depois do dia',
//                      'data': {
//                        'medicoId': medicoId,
//                        'serieId': serie.id,
//                        'serieTipo': serie.tipo,
//                        'serieDataInicio': serieDataInicioNormalizada.toString(),
//                        'dataFiltro': dataFiltroNormalizada.toString(),
//                        'serieInicioNormalizada': serieDataInicioNormalizada.toString(),
//                        'filtroNormalizada': dataFiltroNormalizada.toString(),
//                        'isQuinzenal': serie.tipo == 'Quinzenal',
//                        'hypothesisId': 'E'
//                      },
//                      'sessionId': 'debug-session',
//                      'runId': 'run1',
//                    };
//                    writeLogToFile(jsonEncode(logEntry));
//                  } catch (e) {}

// #endregion
                  return false;
                }
                // Série terminou antes do dia selecionado - não aplicável
                if (serie.dataFim != null) {
                  final serieDataFimNormalizada = DateTime(serie.dataFim!.year,
                      serie.dataFim!.month, serie.dataFim!.day);
                  if (serieDataFimNormalizada.isBefore(dataFiltroNormalizada)) {
                    // #region agent log (COMENTADO - pode ser reativado se necessário)

//                    try {
//                      final logEntry = {
//                        'timestamp': DateTime.now().millisecondsSinceEpoch,
//                        'location': 'alocacao_medicos_logic.dart:1437',
//                        'message': '🔴 [HYP-E] Série filtrada - terminou antes do dia',
//                        'data': {
//                          'medicoId': medicoId,
//                          'serieId': serie.id,
//                          'serieTipo': serie.tipo,
//                          'serieDataFim': serie.dataFim.toString(),
//                          'dataFiltro': dataFiltroNormalizada.toString(),
//                          'hypothesisId': 'E'
//                        },
//                        'sessionId': 'debug-session',
//                        'runId': 'run1',
//                      };
//                      writeLogToFile(jsonEncode(logEntry));
//                    } catch (e) {}

// #endregion
                    return false;
                  }
                }
                // #region agent log (COMENTADO - pode ser reativado se necessário)

//                try {
//                  final logEntry = {
//                    'timestamp': DateTime.now().millisecondsSinceEpoch,
//                    'location': 'alocacao_medicos_logic.dart:1440',
//                    'message': '🟢 [HYP-E] Série relevante (passou filtros)',
//                    'data': {
//                      'medicoId': medicoId,
//                      'serieId': serie.id,
//                      'serieTipo': serie.tipo,
//                      'serieDataInicio': serieDataInicioNormalizada.toString(),
//                      'serieDataFim': serie.dataFim != null ? DateTime(serie.dataFim!.year, serie.dataFim!.month, serie.dataFim!.day).toString() : 'null',
//                      'dataFiltro': dataFiltroNormalizada.toString(),
//                      'serieInicioNormalizada': serieDataInicioNormalizada.toString(),
//                      'filtroNormalizada': dataFiltroNormalizada.toString(),
//                      'isQuinzenal': serie.tipo == 'Quinzenal',
//                      'hypothesisId': 'E'
//                    },
//                    'sessionId': 'debug-session',
//                    'runId': 'run1',
//                  };
//                  writeLogToFile(jsonEncode(logEntry));
//                } catch (e) {}

// #endregion
                return true;
              }).toList();

              // #region agent log (COMENTADO - pode ser reativado se necessário)

//              try {
//                final logEntry = {
//                  'timestamp': DateTime.now().millisecondsSinceEpoch,
//                  'location': 'alocacao_medicos_logic.dart:1445',
//                  'message': '🟡 [HYP-E] Séries relevantes após filtro',
//                  'data': {
//                    'medicoId': medicoId,
//                    'totalSeries': series.length,
//                    'totalSeriesRelevantes': seriesRelevantes.length,
//                    'seriesRelevantesIds': seriesRelevantes.map((s) => s.id).toList(),
//                    'seriesRelevantesTipos': seriesRelevantes.map((s) => s.tipo).toList(),
//                    'hypothesisId': 'E'
//                  },
//                  'sessionId': 'debug-session',
//                  'runId': 'run1',
//                };
//                writeLogToFile(jsonEncode(logEntry));
//              } catch (e) {}

// #endregion

              // Se nenhuma série é relevante, não precisa carregar exceções (ECONOMIZA 1 chamada ao Firestore)
              if (seriesRelevantes.isEmpty) {
                return <Disponibilidade>[];
              }
            }
            // IMPORTANTE: Se há filtro de dia, carregar exceções APENAS para esse dia
            // Isso evita carregar exceções de todo o ano quando só precisa de um dia
            DateTime dataInicioExcecoes;
            DateTime dataFimExcecoes;
            if (dataFiltroDia != null) {
              // Para exceções, carregar apenas do dia específico
              dataInicioExcecoes = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              dataFimExcecoes = dataInicioExcecoes.add(const Duration(days: 1));
            } else {
              // Garantir que não sejam null
              final ano = anoEspecifico != null
                  ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                  : DateTime.now().year;
              dataInicioExcecoes =
                  dataInicioParaCarregarSeries ?? DateTime(ano, 1, 1);
              dataFimExcecoes = dataFimParaCarregarSeries;
            }

            // CORREÇÃO CRÍTICA: Quando anoEspecifico é fornecido (ex: filtro de médicos não alocados),
            // SEMPRE forçar servidor para garantir dados completos do ano inteiro, independentemente do cache do dia atual.
            // O cache em memória pode estar incompleto se foi carregado para um dia específico.
            final deveForcarServidorExcecoes = anoEspecifico != null
                ? true // Sempre forçar servidor quando filtro de ano completo é usado
                : false; // Usar cache do Firestore quando filtro de dia é usado

            // OTIMIZAÇÃO: Usar cache em memória APENAS quando não estamos forçando servidor
            // Chave do cache: medicoId_dataInicio_dataFim
            final cacheKey =
                '${medicoId}_${dataInicioExcecoes.millisecondsSinceEpoch}_${dataFimExcecoes.millisecondsSinceEpoch}';
            List<ExcecaoSerie> excecoes;
            if (!deveForcarServidorExcecoes &&
                AlocacaoCacheStore.cacheExcecoes.containsKey(cacheKey)) {
              // Usar exceções do cache (evita chamadas duplicadas ao Firestore)
              excecoes = AlocacaoCacheStore.cacheExcecoes[cacheKey]!;
            } else {
              excecoes = await SerieService.carregarExcecoes(
                medicoId,
                unidade: unidade,
                dataInicio: dataInicioExcecoes,
                dataFim: dataFimExcecoes,
                forcarServidor: deveForcarServidorExcecoes,
              );
              // Atualizar cache apenas se não forçou servidor
              if (!deveForcarServidorExcecoes) {
                AlocacaoCacheStore.cacheExcecoes[cacheKey] = excecoes;
              }
            }

            // OTIMIZAÇÃO: Se há filtro de dia, filtrar exceções apenas para esse dia
            // Isso reduz o processamento desnecessário
            final excecoesFiltradas = dataFiltroDia != null
                ? excecoes
                    .where((e) =>
                        e.data.year == dataFiltroDia.year &&
                        e.data.month == dataFiltroDia.month &&
                        e.data.day == dataFiltroDia.day)
                    .toList()
                : excecoes;

            // Mensagens de debug removidas para reduzir ruído no terminal
            // debugPrint('  📊 Exceções carregadas do Firestore para $medicoId: ${excecoes.length} (filtradas: ${excecoesFiltradas.length})');
            // for (final excecao in excecoesFiltradas) {
            //   debugPrint('    - Exceção: ${excecao.serieId} - ${excecao.data.day}/${excecao.data.month}/${excecao.data.year} - Cancelada: ${excecao.cancelada}');
            // }

            // Gerar disponibilidades dinamicamente
            // Determinar período para gerar disponibilidades
            // CORREÇÃO CRÍTICA: Para séries quinzenais, precisamos de um período maior
            // para capturar séries que começaram antes do dia filtrado (ex: série começa em fevereiro, navegamos em março)
            DateTime dataInicioGeracao;
            DateTime dataFimGeracao;
            if (dataFiltroDia != null) {
              dataInicioGeracao = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              // CORREÇÃO CRÍTICA: Expandir período para pelo menos 28 dias (2 quinzenas) antes
              // para garantir que séries que começaram em meses anteriores sejam capturadas
              // Exemplo: série começa em 9/2, navegamos para 15/3
              // Precisamos de período que inclua pelo menos 9/2 para calcular quinzenas válidas
              dataInicioGeracao = DateTime(dataInicioGeracao.year,
                  dataInicioGeracao.month, dataInicioGeracao.day - 28);
              dataFimGeracao = DateTime(dataFiltroDia.year, dataFiltroDia.month,
                  dataFiltroDia.day + 1);
            } else {
              final ano = anoEspecifico != null
                  ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                  : DateTime.now().year;
              dataInicioGeracao = DateTime(ano, 1, 1);
              dataFimGeracao = DateTime(ano + 1, 1, 1);
            }
            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'alocacao_medicos_logic.dart:1531',
//                'message': '🔵 [HYP-E] Gerando disponibilidades - ANTES',
//                'data': {
//                  'medicoId': medicoId,
//                  'totalSeriesRelevantes': seriesRelevantes.length,
//                  'seriesRelevantesIds': seriesRelevantes.map((s) => s.id).toList(),
//                  'seriesRelevantesTipos': seriesRelevantes.map((s) => s.tipo).toList(),
//                  'seriesRelevantesDataInicio': seriesRelevantes.map((s) => s.dataInicio.toString()).toList(),
//                  'dataInicioGeracao': dataInicioGeracao.toString(),
//                  'dataFimGeracao': dataFimGeracao.toString(),
//                  'dataFiltroDia': dataFiltroDia != null ? dataFiltroDia.toString() : 'null',
//                  'hypothesisId': 'E'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}

// #endregion

            final dispsGeradas = SerieGenerator.gerarDisponibilidades(
              series: seriesRelevantes,
              excecoes: excecoesFiltradas,
              dataInicio: dataInicioGeracao,
              dataFim: dataFimGeracao,
            );

            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'alocacao_medicos_logic.dart:1537',
//                'message': '🟡 [HYP-E] Disponibilidades geradas - DEPOIS',
//                'data': {
//                  'medicoId': medicoId,
//                  'totalDisponibilidadesGeradas': dispsGeradas.length,
//                  'datasGeradas': dispsGeradas.map((d) => d.data.toString()).toList(),
//                  'tiposGerados': dispsGeradas.map((d) => d.tipo).toList(),
//                  'dataFiltroDia': dataFiltroDia != null ? dataFiltroDia.toString() : 'null',
//                  'hypothesisId': 'E'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}

// #endregion

            // Filtrar apenas disponibilidades do dia selecionado se dataFiltroDia foi fornecido
            final dispsFiltradas = dataFiltroDia != null
                ? dispsGeradas.where((d) {
                    final dData =
                        DateTime(d.data.year, d.data.month, d.data.day);
                    final filtroData = DateTime(dataFiltroDia.year,
                        dataFiltroDia.month, dataFiltroDia.day);
                    final corresponde = dData == filtroData;

                    // #region agent log (COMENTADO - pode ser reativado se necessário)

//                    try {
//                      if (!corresponde && d.tipo == 'Quinzenal') {
//                        final logEntry = {
//                          'timestamp': DateTime.now().millisecondsSinceEpoch,
//                          'location': 'alocacao_medicos_logic.dart:1543',
//                          'message': '🔴 [HYP-E] Disponibilidade quinzenal filtrada - data não corresponde',
//                          'data': {
//                            'medicoId': medicoId,
//                            'dispData': d.data.toString(),
//                            'filtroData': filtroData.toString(),
//                            'dispId': d.id,
//                            'hypothesisId': 'E'
//                          },
//                          'sessionId': 'debug-session',
//                          'runId': 'run1',
//                        };
//                        writeLogToFile(jsonEncode(logEntry));
//                      }
//                    } catch (e) {}

// #endregion

                    return corresponde;
                  }).toList()
                : dispsGeradas;

            if (dataFiltroDia != null) {}

            // #region agent log (COMENTADO - pode ser reativado se necessário)

//            try {
//              final logEntry = {
//                'timestamp': DateTime.now().millisecondsSinceEpoch,
//                'location': 'alocacao_medicos_logic.dart:1560',
//                'message': '🟢 [HYP-E] Disponibilidades após filtro de dia',
//                'data': {
//                  'medicoId': medicoId,
//                  'totalDisponibilidadesGeradas': dispsGeradas.length,
//                  'totalDisponibilidadesFiltradas': dispsFiltradas.length,
//                  'datasFiltradas': dispsFiltradas.map((d) => d.data.toString()).toList(),
//                  'tiposFiltrados': dispsFiltradas.map((d) => d.tipo).toList(),
//                  'dataFiltroDia': dataFiltroDia != null ? dataFiltroDia.toString() : 'null',
//                  'hypothesisId': 'E'
//                },
//                'sessionId': 'debug-session',
//                'runId': 'run1',
//              };
//              writeLogToFile(jsonEncode(logEntry));
//            } catch (e) {}

// #endregion

            medicosComSeries.add(medicoId);

            final dispsMap = <String, Disponibilidade>{};
            for (final disp in dispsFiltradas) {
              final chave =
                  '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.id}';
              dispsMap[chave] = disp;
            }
            return dispsMap.values.toList();
          } catch (e) {
            return <Disponibilidade>[];
          }
        })());
      }

      // Aguardar todas as cargas em paralelo e coletar resultados
      final resultados = await Future.wait(futures);

      // Mesclar todos os resultados no Map para evitar duplicatas
      for (final resultado in resultados) {
        for (final disp in resultado) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.id}';
          disponibilidadesMap[chave] =
              disp; // Sobrescreve se já existir (evita duplicatas)
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar disponibilidades: $e');
    } finally {
      if (forcarServidorSeries) {
        AlocacaoCacheSync.clearForceServerForSeries(unidade);
      }
    }

    final disponibilidades = disponibilidadesMap.values.toList();

    return disponibilidades;
  }

  /// Carrega todas as alocações de uma unidade (otimizado para ano atual)
  /// Método público para permitir reloads focados
  static Future<List<Alocacao>> carregarAlocacoesUnidade(Unidade? unidade,
      {DateTime? dataFiltroDia}) async {
    return _carregarAlocacoesUnidade(unidade, dataFiltroDia: dataFiltroDia);
  }

  /// Carrega todas as alocações de uma unidade (otimizado para ano atual)
  static Future<List<Alocacao>> _carregarAlocacoesUnidade(Unidade? unidade,
      {DateTime? dataFiltroDia}) async {
    final alvo = dataFiltroDia ?? DateTime.now();
    final anoAlvo = alvo.year.toString();
    final result = await _carregarAlocacoesUnidadePorAno(unidade, anoAlvo,
        dataFiltroDia: dataFiltroDia); // Carrega apenas o ano alvo
    return result;
  }

  /// Carrega alocações de uma unidade por ano específico
  /// Se medicoIdFiltro for fornecido, carrega séries apenas desse médico (otimização)
  static Future<List<Alocacao>> _carregarAlocacoesUnidadePorAno(
      Unidade? unidade, String? anoEspecifico,
      {DateTime? dataFiltroDia, String? medicoIdFiltro}) async {
    final firestore = FirebaseFirestore.instance;
    final alocacoes = <Alocacao>[];

    try {
      if (unidade != null) {
        // Caminho preferencial: vista diária materializada
        if (dataFiltroDia != null) {
          final dayKey = keyDia(dataFiltroDia);
          try {
            final daySnap = await firestore
                .collection('unidades')
                .doc(unidade.id)
                .collection('dias')
                .doc(dayKey)
                .collection('alocacoes')
                .get(GetOptions(source: _getSourceForDay(dataFiltroDia)));
            final alocacoesVistaDiaria = <Alocacao>[];
            if (daySnap.docs.isNotEmpty) {
              for (final doc in daySnap.docs) {
                final aloc = Alocacao.fromMap(doc.data());
                alocacoesVistaDiaria.add(aloc);
              }
              // Adicionar alocações da vista diária à lista principal (será mesclada depois)
              alocacoes.addAll(alocacoesVistaDiaria);
              // NÃO fazer return aqui - continuar para buscar também da coleção alocacoes
              // e mesclar resultados (a vista diária pode estar incompleta)
            }
          } catch (e) {
            // Vista diária indisponível, continuar com fallback
          }
        }
        // OTIMIZAÇÃO CRÍTICA: Se a vista diária retornou resultados, usar apenas ela
        // A vista diária já contém todas as alocações do dia, não precisa buscar da coleção
        if (alocacoes.isNotEmpty) {
          _log(
              '✅ [PERF] Usando apenas vista diária (${alocacoes.length} alocações) - pulando busca da coleção para melhor performance');
        } else {
          // Carrega alocações da unidade específica por ano apenas se vista diária estiver vazia
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidade.id)
              .collection('alocacoes');

          if (anoEspecifico != null) {
            // Carrega apenas o ano específico (mais eficiente)
            final registosRef =
                alocacoesRef.doc(anoEspecifico).collection('registos');
            Query<Map<String, dynamic>> query = registosRef;
            if (dataFiltroDia != null) {
              final inicio = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              final fim = inicio.add(const Duration(days: 1));
              query = query
                  .where('data',
                      isGreaterThanOrEqualTo: inicio.toIso8601String())
                  .where('data', isLessThan: fim.toIso8601String());
            }
            // OTIMIZAÇÃO CRÍTICA: Usar cache quando disponível em vez de forçar servidor
            final registosSnapshot = await query.get(GetOptions(
                source: _getSourceForDay(dataFiltroDia ?? DateTime.now())));
            final alocacoesDaColecao = <Alocacao>[];
            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              final alocacao = Alocacao.fromMap(data);
              alocacoesDaColecao.add(alocacao);
            }
            // Mesclar alocações da coleção com as da vista diária, evitando duplicados
            final alocacoesMap = <String, Alocacao>{};
            // Primeiro adicionar alocações já carregadas (vista diária)
            for (final aloc in alocacoes) {
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
              alocacoesMap[chave] = aloc;
            }
            // Depois adicionar alocações da coleção (sobrescrevem se houver duplicado com mesma chave)
            for (final aloc in alocacoesDaColecao) {
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
              alocacoesMap[chave] = aloc;
            }
            // Atualizar lista final
            alocacoes.clear();
            alocacoes.addAll(alocacoesMap.values);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar alocações: $e');
    }

    // Gerar alocações dinamicamente a partir de séries
    try {
      // Carregar séries e exceções para gerar alocações
      // IMPORTANTE: Usar cache de médicos e séries quando disponível

      final alocacoesGeradas = <Alocacao>[];

      // OTIMIZAÇÃO CRÍTICA: Se medicoIdFiltro for fornecido, carregar séries apenas desse médico
      // Isso evita carregar séries de todos os médicos quando estamos editando apenas um
      final medicoIds = <String>[];
      if (medicoIdFiltro != null) {
        // Carregar apenas o médico específico
        medicoIds.add(medicoIdFiltro);
      } else {
        // Carregar TODOS os médicos ativos do Firestore (comportamento original)
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade!.id)
            .collection('ocupantes');
        final medicosSnapshot = await medicosRef
            .where('ativo', isEqualTo: true)
            .get(const GetOptions(source: Source.serverAndCache));
        medicoIds.addAll(medicosSnapshot.docs.map((d) => d.id).toList());
      }

      final anoSeries = anoEspecifico != null
          ? int.tryParse(anoEspecifico) ?? DateTime.now().year
          : DateTime.now().year;
      final dataInicioSeries =
          dataFiltroDia == null ? DateTime(anoSeries, 1, 1) : null;
      final dataFimSeries = dataFiltroDia != null
          ? dataFiltroDia.add(const Duration(days: 1))
          : DateTime(anoSeries + 1, 1, 1);
      final seriesPorMedico = await SerieService.carregarSeriesDeMedicos(
        medicoIds,
        unidade: unidade,
        dataInicio: dataInicioSeries,
        dataFim: dataFimSeries,
        forcarServidor:
            dataFiltroDia != null && isCacheInvalidado(dataFiltroDia),
      );

      // OTIMIZAÇÃO CRÍTICA: Processar médicos em PARALELO (não sequencialmente)
      // Isso reduz drasticamente o tempo de carregamento (de ~52s para ~5-10s)
      final futures = <Future<List<Alocacao>>>[];

      for (final medicoId in medicoIds) {
        futures.add((() async {
          List<ExcecaoSerie> excecoes;
          final series = seriesPorMedico[medicoId] ?? const [];

          // OTIMIZAÇÃO: Se não há séries relevantes para o dia, não precisa carregar exceções
          if (dataFiltroDia != null) {
            final seriesRelevantes = series.where((serie) {
              // Série começou depois do dia selecionado - não aplicável
              if (serie.dataInicio.isAfter(dataFiltroDia)) {
                return false;
              }
              // Série terminou antes do dia selecionado - não aplicável
              if (serie.dataFim != null &&
                  serie.dataFim!.isBefore(dataFiltroDia)) {
                return false;
              }
              // Série precisa ter gabineteId OU mudanças de gabinete para gerar alocações
              final hasGabinete =
                  serie.gabineteId != null && serie.gabineteId!.isNotEmpty;
              return hasGabinete || serie.mudancasGabinete.isNotEmpty;
            }).toList();

            if (seriesRelevantes.isEmpty) {
              return <Alocacao>[];
            }
          }

          // Filtrar apenas séries com gabineteId != null para gerar alocações
          final seriesComGabinete = series.where((s) {
            final hasGabinete =
                s.gabineteId != null && s.gabineteId!.isNotEmpty;
            return hasGabinete || s.mudancasGabinete.isNotEmpty;
          }).toList();

          if (seriesComGabinete.isEmpty) {
            return <Alocacao>[];
          }

          // Carregar exceções do médico no período (usar cache quando possível)
          DateTime dataInicioExcecoes;
          DateTime dataFimExcecoes;
          if (dataFiltroDia != null) {
            dataInicioExcecoes = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            dataFimExcecoes = dataInicioExcecoes.add(const Duration(days: 1));
          } else {
            final ano = anoEspecifico != null
                ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                : DateTime.now().year;
            dataInicioExcecoes = DateTime(ano, 1, 1);
            dataFimExcecoes = DateTime(ano + 1, 1, 1);
          }

          // CORREÇÃO CRÍTICA: Forçar servidor se o cache estiver invalidado para este dia
          // Isso garante que exceções recém-criadas (ex: exceção cancelada ao desalocar "apenas este dia")
          // sejam carregadas imediatamente
          final cacheInvalidado =
              dataFiltroDia != null && isCacheInvalidado(dataFiltroDia);
          excecoes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioExcecoes,
            dataFim: dataFimExcecoes,
            forcarServidor:
                cacheInvalidado, // Forçar servidor se cache invalidado
          );

          // Filtrar exceções para o dia se necessário
          if (dataFiltroDia != null) {
            excecoes = excecoes
                .where((e) =>
                    e.data.year == dataFiltroDia.year &&
                    e.data.month == dataFiltroDia.month &&
                    e.data.day == dataFiltroDia.day)
                .toList();
          }

          // Gerar alocações dinamicamente apenas de séries com gabineteId
          // CORREÇÃO CRÍTICA: Para séries quinzenais, precisamos de um período maior
          // para capturar séries que começaram antes do dia filtrado (ex: série começa em fevereiro, navegamos em março)
          DateTime dataInicioAlocacoes;
          DateTime dataFimAlocacoes;
          if (dataFiltroDia != null) {
            dataInicioAlocacoes = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            // CORREÇÃO CRÍTICA: Expandir período para pelo menos 28 dias (2 quinzenas) antes
            // para garantir que séries que começaram em meses anteriores sejam capturadas
            // Exemplo: série começa em 9/2, navegamos para 15/3
            // Precisamos de período que inclua pelo menos 9/2 para calcular quinzenas válidas
            dataInicioAlocacoes = DateTime(dataInicioAlocacoes.year,
                dataInicioAlocacoes.month, dataInicioAlocacoes.day - 28);
            dataFimAlocacoes = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day + 1);
          } else {
            final ano = anoEspecifico != null
                ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                : DateTime.now().year;
            dataInicioAlocacoes = DateTime(ano, 1, 1);
            dataFimAlocacoes = DateTime(ano + 1, 1, 1);
          }

          final alocsGeradas = SerieGenerator.gerarAlocacoes(
            series: seriesComGabinete,
            excecoes: excecoes,
            dataInicio: dataInicioAlocacoes,
            dataFim: dataFimAlocacoes,
          );

          return alocsGeradas;
        })());
      }

      // Aguardar todos os médicos processarem em paralelo
      final resultados = await Future.wait(futures);
      for (final resultado in resultados) {
        alocacoesGeradas.addAll(resultado);
      }

      // Criar mapa de datas com exceções canceladas para filtrar alocações do Firestore
      final datasComExcecoesCanceladas = <String>{};
      if (dataFiltroDia != null) {
        try {
          // Carregar exceções canceladas diretamente do Firestore (cache removido)
          if (unidade != null) {
            final datasComExcecoes =
                await AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
                    unidade.id, dataFiltroDia);
            datasComExcecoesCanceladas.addAll(datasComExcecoes);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao carregar exceções canceladas: $e');
        }
      }

      // CORREÇÃO: Simplificar mesclagem de alocações
      // Alocações de séries: geradas dinamicamente (não salvas no Firestore)
      // Alocações "Única": salvas no Firestore (ID não começa com "serie_")

      // CORREÇÃO CRÍTICA: Criar conjunto de chaves de séries para identificar quais remover
      final chavesSeriesParaRemover = <String>{};
      for (final aloc in alocacoesGeradas) {
        // Criar chave sem gabineteId para identificar todas as alocações da mesma série/data
        final chaveSemGabinete =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        chavesSeriesParaRemover.add(chaveSemGabinete);
      }

      // Criar conjunto de médicos/datas que têm exceções ativas (não canceladas) com gabineteId
      // Estas datas devem manter alocações "Única" do Firestore se existirem
      // OTIMIZAÇÃO CRÍTICA: Processar em PARALELO em vez de sequencialmente

      // Determinar período uma vez
      DateTime dataInicioExcecoes;
      DateTime dataFimExcecoes;
      if (dataFiltroDia != null) {
        dataInicioExcecoes = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        dataFimExcecoes = dataInicioExcecoes.add(const Duration(days: 1));
      } else {
        final ano = anoEspecifico != null
            ? int.tryParse(anoEspecifico) ?? DateTime.now().year
            : DateTime.now().year;
        dataInicioExcecoes = DateTime(ano, 1, 1);
        dataFimExcecoes = DateTime(ano + 1, 1, 1);
      }

      // Só médicos com uma série efetivamente gerada neste dia podem ter uma
      // exceção ativa relevante para esta mesclagem. Percorrer os 147 médicos
      // criava consultas desnecessárias, sobretudo em dias vazios.
      final medicoIdsComSerieNoDia =
          alocacoesGeradas.map((alocacao) => alocacao.medicoId).toSet();
      final futuresExcecoes = <Future<List<String>>>[];
      for (final medicoId in medicoIdsComSerieNoDia) {
        futuresExcecoes.add((() async {
          final dataKeys = <String>[];
          try {
            final excecoes = await SerieService.carregarExcecoes(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicioExcecoes,
              dataFim: dataFimExcecoes,
              forcarServidor: false,
            );
            for (final excecao in excecoes) {
              if (!excecao.cancelada && excecao.gabineteId != null) {
                final dataKey =
                    '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                dataKeys.add(dataKey);
              }
            }
          } catch (e) {
            // Ignorar erros ao carregar exceções
          }
          return dataKeys;
        })());
      }

      // Aguardar todas as exceções serem carregadas em paralelo e coletar resultados
      final resultadosExcecoes = await Future.wait(futuresExcecoes);
      final datasComExcecoesAtivas = <String>{};
      for (final dataKeys in resultadosExcecoes) {
        datasComExcecoesAtivas.addAll(dataKeys);
      }

      final alocacoesMap = <String, Alocacao>{};

      // Primeiro, adicionar apenas alocações "Única" do Firestore
      // Filtrar alocações antigas de séries que serão regeneradas
      // e alocações com exceções canceladas
      for (final aloc in alocacoes) {
        // Ignorar alocações antigas de séries que serão regeneradas
        if (aloc.id.startsWith('serie_')) {
          final chaveSemGabinete =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          if (chavesSeriesParaRemover.contains(chaveSemGabinete)) {
            // Esta alocação de série será regenerada, pular para evitar duplicação
            continue;
          }
        }

        // Verificar se esta alocação corresponde a uma data com exceção cancelada
        final dataKey =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        if (datasComExcecoesCanceladas.contains(dataKey)) {
          continue;
        }

        // CORREÇÃO: Se há série alocada para esta data (está em chavesSeriesParaRemover),
        // mas NÃO há exceção ativa, remover alocação "Única" do Firestore
        // porque será substituída pela alocação gerada da série
        if (!aloc.id.startsWith('serie_') &&
            chavesSeriesParaRemover.contains(dataKey)) {
          if (!datasComExcecoesAtivas.contains(dataKey)) {
            // Há série alocada para esta data mas não há exceção ativa,
            // então a alocação "Única" será substituída pela alocação gerada da série
            continue;
          }
        }

        // Adicionar apenas alocações "Única" (não são de séries)
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
        // Alocações "Única" do Firestore têm prioridade sobre alocações geradas (caso raro de conflito)
        alocacoesMap[chave] = aloc;
      }

      // Depois, adicionar alocações geradas de séries (dinâmicas)
      // Isso substitui qualquer alocação antiga da mesma série/data
      for (final aloc in alocacoesGeradas) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
        alocacoesMap[chave] = aloc;
      }

      alocacoes.clear();
      alocacoes.addAll(alocacoesMap.values);
    } catch (e) {
      // Em caso de erro, retornar apenas as alocações do Firestore
    }

    return alocacoes;
  }

  /// Busca todas as alocações de um médico específico do Firebase
  static Future<List<Alocacao>> buscarAlocacoesMedico(
      Unidade? unidade, String medicoId,
      {int? anoEspecifico, DateTime? dataInicio, DateTime? dataFim}) async {
    List<Alocacao> todasAlocacoes;

    // Se há dataInicio e dataFim, buscar de todos os anos necessários
    if (dataInicio != null && dataFim != null) {
      final anoInicio = dataInicio.year;
      final anoFim = dataFim.year;
      todasAlocacoes = [];

      // Buscar de todos os anos que a série cruza
      // OTIMIZAÇÃO: Passar medicoId para evitar carregar séries de todos os médicos
      for (int ano = anoInicio; ano <= anoFim; ano++) {
        final alocacoesAno = await _carregarAlocacoesUnidadePorAno(
          unidade,
          ano.toString(),
          medicoIdFiltro: medicoId, // Passar médico específico para otimizar
        );
        todasAlocacoes.addAll(alocacoesAno);
      }
    } else {
      // Buscar apenas do ano específico ou ano atual
      // OTIMIZAÇÃO: Passar medicoId para evitar carregar séries de todos os médicos
      todasAlocacoes = await _carregarAlocacoesUnidadePorAno(
        unidade,
        anoEspecifico?.toString(),
        medicoIdFiltro: medicoId, // Passar médico específico para otimizar
      );
    }

    var alocacoesMedico =
        todasAlocacoes.where((a) => a.medicoId == medicoId).toList();

    // Filtrar por período se fornecido
    if (dataInicio != null || dataFim != null) {
      alocacoesMedico = alocacoesMedico.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        if (dataInicio != null && aDate.isBefore(dataInicio)) return false;
        if (dataFim != null && aDate.isAfter(dataFim)) return false;
        return true;
      }).toList();
    }

    return alocacoesMedico;
  }
}
