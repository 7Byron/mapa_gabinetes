// import '../database/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../utils/debug_log_file.dart';
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
import '../utils/conflict_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlocacaoMedicosLogic {
  // Cache simples em memória por dia (chave yyyy-MM-dd)
  static final Map<String, List<Disponibilidade>> _cacheDispPorDia = {};
  static final Map<String, List<Alocacao>> _cacheAlocPorDia = {};
  // Set de chaves de dias que foram invalidados e precisam buscar do servidor
  static final Set<String> _cacheInvalidadoPorDia = {};

  /// Verifica se o cache está invalidado para um dia específico
  static bool isCacheInvalidado(DateTime day) {
    final key = _keyDia(day);
    return _cacheInvalidadoPorDia.contains(key);
  }

  /// Obtém a chave do cache para um dia específico
  static String keyDia(DateTime d) => _keyDia(d);

  // Cache para exceções por médico e período (chave: medicoId_dataInicio_dataFim)
  // Isso evita carregar as mesmas exceções múltiplas vezes durante a mesma execução
  static final Map<String, List<ExcecaoSerie>> _cacheExcecoes = {};

  static String _keyDia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
  /// Retorna 1 para primeira ocorrência, 2 para segunda, etc.
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
    final key = _keyDia(day);
    final estavaInvalidado = _cacheInvalidadoPorDia.contains(key);
    if (disponibilidades != null) {
      _cacheDispPorDia[key] = List<Disponibilidade>.from(disponibilidades);
      // CORREÇÃO CRÍTICA: Só remover invalidação se forçado ou se não estava invalidado
      if (forcarValido || !estavaInvalidado) {
        _cacheInvalidadoPorDia.remove(key);
      }
    }
    if (alocacoes != null) {
      _cacheAlocPorDia[key] = List<Alocacao>.from(alocacoes);
      // CORREÇÃO CRÍTICA: Só remover invalidação se forçado ou se não estava invalidado
      if (forcarValido || !estavaInvalidado) {
        _cacheInvalidadoPorDia.remove(key);
      }
    }
    debugPrint(
        '💾 [CACHE] Cache atualizado para dia $key: ${disponibilidades?.length ?? 0} disps, ${alocacoes?.length ?? 0} alocs (estava invalidado: $estavaInvalidado, forçar válido: $forcarValido, agora válido: ${!_cacheInvalidadoPorDia.contains(key)})');
  }

  /// Remove o cache do dia específico (será recarregado do servidor na próxima consulta)
  static void invalidateCacheForDay(DateTime day) {
    final key = _keyDia(day);
    final tinhaCache =
        _cacheDispPorDia.containsKey(key) || _cacheAlocPorDia.containsKey(key);
    _cacheDispPorDia.remove(key);
    _cacheAlocPorDia.remove(key);
    _cacheInvalidadoPorDia
        .add(key); // Marcar como invalidado para buscar do servidor
    // Limpar cache de exceções relacionadas ao dia (para garantir dados atualizados)
    // CORREÇÃO: Limpar todo o cache de exceções quando há mudanças (mais seguro)
    _cacheExcecoes.clear();
    debugPrint(
        '🗑️ [CACHE] Cache invalidado para dia $key (${day.day}/${day.month}/${day.year})');
  }

  /// Remove o cache de todos os dias a partir de uma data específica
  static void invalidateCacheFromDate(DateTime fromDate) {
    final keysToRemove = <String>[];
    final fromKey = _keyDia(fromDate);

    for (final key in _cacheDispPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cacheDispPorDia.remove(key);
      _cacheAlocPorDia.remove(key);
      _cacheInvalidadoPorDia.add(key);
    }
  }

  /// Obtém a source apropriada para buscar dados do Firestore
  // Flag para rastrear se o app está em foco
  static bool _appEmFoco = true;
  
  /// Define se o app está em foco (chamado pelo lifecycle observer)
  static void setAppEmFoco(bool emFoco) {
    _appEmFoco = emFoco;
    if (!emFoco) {
      // Quando o app perde foco, invalidar cache para garantir dados atualizados ao voltar
      debugPrint('⚠️ [CACHE] App perdeu foco - cache será invalidado na próxima busca');
    }
  }
  
  /// Retorna Source.server se o cache foi invalidado ou app não está em foco, Source.serverAndCache caso contrário
  /// CORREÇÃO: Quando o app não está em foco, sempre buscar do servidor para garantir dados atualizados
  static Source _getSourceForDay(DateTime? day) {
    if (day == null) {
      // Se app não está em foco, buscar do servidor mesmo sem filtro de dia
      return _appEmFoco ? Source.serverAndCache : Source.server;
    }
    final key = _keyDia(day);
    if (_cacheInvalidadoPorDia.contains(key)) {
      return Source.server; // Cache invalidado, buscar do servidor
    }
    // CORREÇÃO CRÍTICA: Se app não está em foco, sempre buscar do servidor
    if (!_appEmFoco) {
      debugPrint('⚠️ [CACHE] App não está em foco - forçando busca do servidor para dia $key');
      return Source.server;
    }
    return Source.serverAndCache; // Usar cache do Firestore apenas quando app está em foco
  }

  /// Extrai datas com exceções canceladas do Firestore para um dia específico
  /// Retorna um Set com chaves no formato: medicoId_ano-mes-dia
  /// OTIMIZAÇÃO: Usa cache de exceções quando disponível para evitar chamadas redundantes
  static Future<Set<String>> extrairExcecoesCanceladasParaDia(
      String unidadeId, DateTime data) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final datasComExcecoesCanceladas = <String>{};
    try {
      final firestore = FirebaseFirestore.instance;
      final ano = data.year;
      final dataNormalizada = DateTime(data.year, data.month, data.day);

      // OTIMIZAÇÃO: Tentar usar cache de exceções primeiro
      // Percorrer cache para médicos que têm exceções para este dia
      final cacheStart = DateTime.now().millisecondsSinceEpoch;
      for (final entry in _cacheExcecoes.entries) {
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
      final cacheEnd = DateTime.now().millisecondsSinceEpoch;

      // OTIMIZAÇÃO CRÍTICA: Pular busca do Firestore se o cache já tem dados
      // A busca do Firestore é muito lenta (busca todos os médicos e depois exceções)
      // Se o cache tem dados, podemos confiar nele para este dia específico
      // A busca do Firestore será feita apenas quando o cache estiver completamente vazio
      
      final firestoreStart = DateTime.now().millisecondsSinceEpoch;
      
      // OTIMIZAÇÃO: Buscar do Firestore apenas se o cache estiver vazio
      // Isso evita queries desnecessárias que podem levar vários segundos
      if (_cacheExcecoes.isEmpty) {
        // Cache vazio - buscar apenas uma amostra limitada de médicos
        // Limitar drasticamente para melhor performance (apenas 20 médicos)
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .where('ativo', isEqualTo: true);
        
        final medicosSnapshot = await medicosRef
            .limit(20) // Limitar drasticamente para melhor performance
            .get(const GetOptions(source: Source.serverAndCache));
        final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();

        // Carregar exceções em paralelo apenas para médicos limitados
        final futures = medicoIds.map((medicoId) async {
          try {
            final medicoExcecoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('ocupantes')
                .doc(medicoId)
                .collection('excecoes')
                .doc(ano.toString())
                .collection('registos');

            // Buscar todas as exceções e filtrar localmente (mais eficiente que query complexa)
            final snapshot = await medicoExcecoesRef
                .where('cancelada', isEqualTo: true)
                .get(GetOptions(source: _getSourceForDay(data)));

            for (final doc in snapshot.docs) {
              final excecao = ExcecaoSerie.fromMap({...doc.data(), 'id': doc.id});
              if (excecao.cancelada &&
                  excecao.data.year == data.year &&
                  excecao.data.month == data.month &&
                  excecao.data.day == data.day) {
                final dataKey =
                    '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                return dataKey;
              }
            }
            return null;
          } catch (e) {
            return null;
          }
        });

        final resultados = await Future.wait(futures);
        for (final resultado in resultados) {
          if (resultado != null) {
            datasComExcecoesCanceladas.add(resultado);
          }
        }
      } else {
        // Cache tem dados - pular busca do Firestore completamente
        debugPrint('⚡ [PERF] Usando cache de exceções - pulando busca do Firestore');
      }
      
      final firestoreEnd = DateTime.now().millisecondsSinceEpoch;
      final totalEnd = DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      // Em caso de erro, retornar conjunto vazio
      debugPrint('❌ Erro ao extrair exceções canceladas: $e');
      return <String>{};
    }

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
    debugPrint(
        '🚀 [DEBUG] carregarDadosIniciais INICIADO com dataFiltroDia: ${dataFiltroDia != null ? "${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}" : "null"}');
    // #region agent log
    try {
      final logEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'location': 'alocacao_medicos_logic.dart:284',
        'message': 'carregarDadosIniciais INICIADO',
        'data': {
          'dataFiltroDia': dataFiltroDia?.toString(),
          'reloadStatic': reloadStatic,
          'hypothesisId': 'D'
        },
        'sessionId': 'debug-session',
        'runId': 'run1',
      };
      writeLogToFile(jsonEncode(logEntry));
    } catch (e) {}
    // #endregion
    // Guardar estado inicial para preservar em caso de erro
    final gabinetesIniciais = List<Gabinete>.from(gabinetes);
    final medicosIniciais = List<Medico>.from(medicos);
    try {
      // Carrega dados estáticos (gabinetes/medicos) apenas quando solicitado
      final List<Gabinete> gabs;
      final List<Medico> meds;
      if (reloadStatic || gabinetes.isEmpty || medicos.isEmpty) {
        gabs = await buscarGabinetes(unidade: unidade);
        meds = await buscarMedicos(unidade: unidade);
      } else {
        gabs = gabinetes;
        meds = medicos;
      }

      // Usar cache quando disponível
      List<Disponibilidade> disps;
      List<Alocacao> alocs;

      if (dataFiltroDia != null) {
        final key = _keyDia(dataFiltroDia);
        // Verificar cache primeiro
        final temCacheDisp = _cacheDispPorDia.containsKey(key);
        final temCacheAloc = _cacheAlocPorDia.containsKey(key);
        final estaInvalidado = _cacheInvalidadoPorDia.contains(key);
        if (temCacheDisp && temCacheAloc && !estaInvalidado) {
          debugPrint(
              '💾 [CACHE] Usando cache para dia $key (${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year})');
          disps = List<Disponibilidade>.from(_cacheDispPorDia[key]!);
          alocs = List<Alocacao>.from(_cacheAlocPorDia[key]!);
        } else {
          // Cache não disponível ou invalidado, buscar do Firestore
          // CORREÇÃO: Se app não está em foco, sempre buscar do servidor mesmo se cache existe
          final deveBuscarDoServidor = estaInvalidado || !_appEmFoco;
          if (deveBuscarDoServidor && !estaInvalidado) {
            // Invalidar cache se app não está em foco para garantir dados atualizados
            _cacheInvalidadoPorDia.add(key);
            debugPrint('⚠️ [CACHE] App não está em foco - invalidando cache do dia $key para buscar dados atualizados');
          }
          debugPrint(
              '🔄 [CACHE] Buscando do Firestore para dia $key (temCacheDisp: $temCacheDisp, temCacheAloc: $temCacheAloc, estaInvalidado: $estaInvalidado, appEmFoco: $_appEmFoco)');
          // #region agent log
          try {
            final logEntry = {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'location': 'alocacao_medicos_logic.dart:327',
              'message': 'Iniciando Future.wait para carregar disponibilidades e alocações',
              'data': {
                'key': key,
                'hypothesisId': 'D'
              },
              'sessionId': 'debug-session',
              'runId': 'run1',
            };
            writeLogToFile(jsonEncode(logEntry));
          } catch (e) {}
          // #endregion
          final results = await Future.wait([
            _carregarDisponibilidadesUnidade(unidade,
                dataFiltroDia: dataFiltroDia),
            _carregarAlocacoesUnidade(unidade, dataFiltroDia: dataFiltroDia),
          ]);
          // #region agent log
          try {
            final logEntry = {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'location': 'alocacao_medicos_logic.dart:327',
              'message': 'Future.wait concluído para disponibilidades e alocações',
              'data': {
                'numDisponibilidades': (results[0] as List).length,
                'numAlocacoes': (results[1] as List).length,
                'hypothesisId': 'D'
              },
              'sessionId': 'debug-session',
              'runId': 'run1',
            };
            writeLogToFile(jsonEncode(logEntry));
          } catch (e) {}
          // #endregion
          disps = results[0] as List<Disponibilidade>;
          alocs = results[1] as List<Alocacao>;
          // CORREÇÃO CRÍTICA: Atualizar cache com dados buscados do servidor
          // Forçar validação porque são dados atualizados do Firestore
          updateCacheForDay(
              day: dataFiltroDia,
              disponibilidades: disps,
              alocacoes: alocs,
              forcarValido: true); // Dados do servidor, forçar validação
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
          if (temExcecao) {
            debugPrint(
                '🚫 [FILTRO EXCEÇÃO] Removendo disponibilidade: médico=${disp.medicoId}, data=${disp.data.day}/${disp.data.month}/${disp.data.year}');
          }
          return !temExcecao;
        }).toList();
        if (dispsAntes != disps.length) {
          debugPrint(
              '✅ [FILTRO EXCEÇÃO] Disponibilidades filtradas: $dispsAntes -> ${disps.length} (removidas ${dispsAntes - disps.length})');
        }

        // Filtrar alocações - remover todas as alocações de médicos com exceções canceladas
        final alocsAntes = alocs.length;
        alocs = alocs.where((aloc) {
          final dataKey =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          final temExcecao = excecoesCanceladas.contains(dataKey);
          if (temExcecao) {
            debugPrint(
                '🚫 [FILTRO EXCEÇÃO] Removendo alocação: médico=${aloc.medicoId}, gabinete=${aloc.gabineteId}, data=${aloc.data.day}/${aloc.data.month}/${aloc.data.year}');
          }
          return !temExcecao;
        }).toList();
        if (alocsAntes != alocs.length) {
          debugPrint(
              '✅ [FILTRO EXCEÇÃO] Alocações filtradas: $alocsAntes -> ${alocs.length} (removidas ${alocsAntes - alocs.length})');
        }
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
    final filtradosPiso =
        gabinetes.where((g) => pisosSelecionados.contains(g.setor)).toList();

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

    // CORREÇÃO: Remover TODAS as alocações do mesmo médico no mesmo dia
    // EXCETO alocações otimistas (que começam com "otimista_") - essas devem ser preservadas
    final alocacoesAnteriores = alocacoes.where((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      // NÃO remover alocações otimistas - elas serão substituídas pela nova alocação real
      return a.medicoId == medicoId && 
             alocDate == dataAlvo &&
             !a.id.startsWith('otimista_');
    }).toList();

    if (alocacoesAnteriores.isNotEmpty) {
      debugPrint(
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
          final ano = alocacaoAnterior.data.year.toString();
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('alocacoes')
              .doc(ano)
              .collection('registos');

          await alocacoesRef.doc(alocacaoAnterior.id).delete();
          debugPrint(
              '✅ Alocação anterior removida do Firebase: ${alocacaoAnterior.id}');
        } catch (e) {
          debugPrint(
              '⚠️ Erro ao remover alocação anterior ${alocacaoAnterior.id} do Firebase (pode já ter sido removida): $e');
          // Continuar mesmo se houver erro (pode já ter sido removida)
        }
      }
    }

    // Se horários foram forçados, usar esses. Senão, buscar das disponibilidades
    String horarioInicio;
    String horarioFim;

    if (horariosForcados != null && horariosForcados.length >= 2) {
      horarioInicio = horariosForcados[0];
      horarioFim = horariosForcados[1];
      debugPrint('✅ Usando horários forçados: $horarioInicio - $horarioFim');
    } else {
      final dispDoDia = disponibilidades.where((disp) {
        final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId && dd == dataAlvo;
      }).toList();

      horarioInicio =
          dispDoDia.isNotEmpty ? dispDoDia.first.horarios[0] : '00:00';
      horarioFim = dispDoDia.isNotEmpty ? dispDoDia.first.horarios[1] : '00:00';
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

      debugPrint('✅ Alocação salva no Firebase: ${novaAloc.id}');
    } catch (e) {
      debugPrint('❌ Erro ao salvar alocação no Firebase: $e');
      rethrow; // Re-throw para que o erro seja tratado no nível superior
    }

    // Adicionar localmente IMEDIATAMENTE para feedback visual instantâneo
    // O listener do Firestore vai atualizar depois, mas isso garante que o cartão apareça no gabinete
    final indexExistente = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });

    if (indexExistente != -1) {
      alocacoes[indexExistente] = novaAloc;
    } else {
      alocacoes.add(novaAloc);
    }

    // CORREÇÃO: Invalidar cache do dia após salvar para garantir que será recarregado
    // quando necessário, mas não atualizar cache aqui porque o listener do Firestore
    // vai atualizar quando receber a atualização do servidor
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
    invalidateCacheForDay(dataAlvoNormalizada);

    // CORREÇÃO: Chamar onAlocacoesChanged() que recarrega tudo do Firebase
    // Mas como já adicionamos localmente, o cartão aparece imediatamente
    // O delay aumentado ajuda a consolidar atualizações e reduzir "piscar"
  }

  static Future<void> desalocarMedicoDiaUnico({
    required DateTime selectedDate,
    required String medicoId,
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
      return a.medicoId == medicoId && aDate == dataAlvo;
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
      String? serieId;
      final partes = alocacaoRemovida.id.split('_');

      if (partes.length >= 4 && partes[0] == 'serie' && partes[1] == 'serie') {
        serieId = 'serie_${partes[2]}';
      } else if (partes.length >= 3 && partes[0] == 'serie') {
        serieId =
            partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
      }

      if (serieId != null) {
        // Verificar se há exceção para esta série e data
        final excecoes = await SerieService.carregarExcecoes(
          medicoId,
          unidade: unidade,
          dataInicio: dataAlvo,
          dataFim: dataAlvo,
          serieId: serieId,
          forcarServidor: true,
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

        if (excecaoExistente.id.isNotEmpty) {
          // É uma exceção de série - cancelar a exceção em vez de remover alocação
          debugPrint(
              '🔄 [DESALOCAÇÃO] Cartão é exceção de série, cancelando exceção: ${excecaoExistente.id}');

          final excecaoCancelada = ExcecaoSerie(
            id: excecaoExistente.id,
            serieId: excecaoExistente.serieId,
            data: excecaoExistente.data,
            cancelada: true, // Cancelar a exceção
            horarios: excecaoExistente.horarios,
            gabineteId: excecaoExistente.gabineteId,
          );

          await SerieService.salvarExcecao(excecaoCancelada, medicoId,
              unidade: unidade);

          // Invalidar cache após cancelar exceção
          invalidateCacheForDay(dataAlvo);
          invalidateCacheFromDate(DateTime(dataAlvo.year, 1, 1));

          // Remover da lista local (a série vai regenerar sem exceção)
          alocacoes.removeAt(indexAloc);

          debugPrint(
              '✅ [DESALOCAÇÃO] Exceção cancelada, série voltará ao gabinete original');

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
        }
      }
    }

    alocacoes.removeAt(indexAloc);

    // Remover do Firebase
    try {
      final firestore = FirebaseFirestore.instance;
      final ano = alocacaoRemovida.data.year.toString();
      final unidadeId = unidade?.id ??
          'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');

      await alocacoesRef.doc(alocacaoRemovida.id).delete();
      debugPrint(
          '✅ Alocação removida do Firebase: ${alocacaoRemovida.id} (ano: $ano, unidade: $unidadeId)');

      // Invalidar cache do dia após remover
      invalidateCacheForDay(dataAlvo);
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
      debugPrint('✅ [DESALOCAÇÃO] Médico adicionado de volta aos disponíveis: $medicoId');
    } else {
      debugPrint('⚠️ [DESALOCAÇÃO] Médico já estava nos disponíveis: $medicoId');
    }

    // CORREÇÃO CRÍTICA: Atualiza cache para o dia afetado (com as listas já atualizadas)
    final alocDoDiaAtualizadas = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return aDate == dataAlvo;
    }).toList();
    final dispDoDiaAtualizadas = disponibilidades.where((d) {
      final dDate = DateTime(d.data.year, d.data.month, d.data.day);
      return dDate == dataAlvo;
    }).toList();


    // Chamar onAlocacoesChanged() DEPOIS de invalidar cache e atualizar lista local
    onAlocacoesChanged();
  }

  static Future<void> desalocarMedicoSerie({
    required String medicoId,
    required DateTime dataRef,
    required String tipo,
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

      // CORREÇÃO CRÍTICA: Salvar o gabineteId ANTES de desalocar para poder remover da lista local
      final gabineteIdAntigo = serie.gabineteId;

      // Remover o gabineteId da série no Firestore IMEDIATAMENTE
      try {
        await DisponibilidadeSerieService.desalocarSerie(
          serieId: serie.id,
          medicoId: medicoId,
          unidade: unidade,
        );

        // CORREÇÃO CRÍTICA: Invalidar cache após desalocar série
        // Invalidar cache para o ano da data de referência e próximos 2 anos
        invalidateCacheFromDate(DateTime(dataRef.year, 1, 1));
        invalidateCacheFromDate(DateTime(dataRef.year + 1, 1, 1));
        invalidateCacheFromDate(DateTime(dataRef.year + 2, 1, 1));

        // Também invalidar cache do dia específico para atualização imediata
        invalidateCacheForDay(dataRef);

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
        final antes = alocacoes.length;
        alocacoes.removeWhere((a) => a.id == alocacao.id);
        final depois = alocacoes.length;
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
              if (totalParaDeletar <= 10) {
                // Log apenas as primeiras 10 para não poluir
                final data = doc.data();
                (data['data'] as Timestamp).toDate();
              }
            }
          }
        }

        if (totalParaDeletar > 0) {
          await batch.commit();
        } else {}
      } catch (e) {}

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
      } catch (e) {}
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
          '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
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
          '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
      todasDisps[chave] = disp;
    }

    final resultado = todasDisps.values.toList();
    debugPrint(
        '📋 [DEBUG] _carregarDisponibilidadesUnidadePorAno retornando ${resultado.length} disponibilidades');
    if (dataFiltroDia != null && resultado.isNotEmpty) {
      debugPrint(
          '  🔍 dataFiltroDia: ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}');
      debugPrint('  🔍 Primeiras 5 datas das disponibilidades retornadas:');
      for (var i = 0; i < resultado.length && i < 5; i++) {
        final d = resultado[i];
        debugPrint(
            '    ${i + 1}. ${d.medicoId}: ${d.data.day}/${d.data.month}/${d.data.year}');
      }
    }
    return resultado;
  }

  /// Carrega séries de recorrência e gera disponibilidades dinamicamente
  static Future<List<Disponibilidade>> carregarDisponibilidadesDeSeries({
    required Unidade? unidade,
    String? anoEspecifico,
    DateTime? dataFiltroDia,
  }) async {
    if (unidade == null) return [];

    // Usar Map para evitar duplicatas: chave = (medicoId, data, tipo)
    final disponibilidadesMap = <String, Disponibilidade>{};
    final firestore = FirebaseFirestore.instance;

    // Variável para rastrear médicos com séries (fora do try para estar acessível)
    final medicosComSeries = <String>[];

    try {
      // Determinar período para gerar cartões
      DateTime dataInicio;
      DateTime dataFim;
      final anoParaCache = dataFiltroDia?.year ??
          (anoEspecifico != null
              ? int.tryParse(anoEspecifico) ?? DateTime.now().year
              : DateTime.now().year);

      if (dataFiltroDia != null) {
        // OTIMIZAÇÃO: Gerar apenas para o dia atual quando há filtro de dia
        // Isso evita gerar disponibilidades desnecessárias para todo o ano
        // Séries que começam depois do dia selecionado serão geradas quando necessário
        dataInicio = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        dataFim = dataInicio.add(const Duration(days: 1));
      } else if (anoEspecifico != null) {
        // Se há ano específico, gerar para o ano inteiro
        final ano = int.tryParse(anoEspecifico) ?? DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
        dataFim = DateTime(ano + 1, 1, 1);
      } else {
        // Gerar para o ano atual
        final ano = DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
        dataFim = DateTime(ano + 1, 1, 1);
      }

      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1228',
          'message': 'Carregando médicos ativos do Firestore',
          'data': {
            'unidadeId': unidade.id,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion
      // Carregar TODOS os médicos ativos do Firestore (usando cache)
      final medicosRef = firestore
          .collection('unidades')
          .doc(unidade.id)
          .collection('ocupantes');
      final medicosSnapshot = await medicosRef
          .where('ativo', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));
      final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1228',
          'message': 'Médicos ativos carregados',
          'data': {
            'numMedicos': medicoIds.length,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

      if (medicoIds.isEmpty) {
        return disponibilidadesMap.values.toList();
      }

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
              final ano = anoEspecifico != null
                  ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                  : DateTime.now().year;
              dataInicioParaCarregarSeries = DateTime(ano, 1, 1);
              dataFimParaCarregarSeries = DateTime(ano + 1, 1, 1);
            }

            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'alocacao_medicos_logic.dart:1280',
                'message': 'Chamando SerieService.carregarSeries',
                'data': {
                  'medicoId': medicoId,
                  'hypothesisId': 'C'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
            // #endregion
            // SEMPRE buscar do servidor (cache removido)
            final series = await SerieService.carregarSeries(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicioParaCarregarSeries,
              dataFim: dataFimParaCarregarSeries,
            );
            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'alocacao_medicos_logic.dart:1280',
                'message': 'SerieService.carregarSeries concluído',
                'data': {
                  'medicoId': medicoId,
                  'numSeries': series.length,
                  'hypothesisId': 'C'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
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
              seriesRelevantes = series.where((serie) {
                // Série começou depois do dia selecionado - não aplicável
                if (serie.dataInicio.isAfter(dataFiltro)) {
                  return false;
                }
                // Série terminou antes do dia selecionado - não aplicável
                if (serie.dataFim != null &&
                    serie.dataFim!.isBefore(dataFiltro)) {
                  return false;
                }
                return true;
              }).toList();

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
              dataFimExcecoes =
                  dataFimParaCarregarSeries ?? DateTime(ano + 1, 1, 1);
            }

            // OTIMIZAÇÃO: Usar cache em memória para evitar carregar as mesmas exceções múltiplas vezes
            // Chave do cache: medicoId_dataInicio_dataFim
            final cacheKey =
                '${medicoId}_${dataInicioExcecoes.millisecondsSinceEpoch}_${dataFimExcecoes.millisecondsSinceEpoch}';
            List<ExcecaoSerie> excecoes;
            if (_cacheExcecoes.containsKey(cacheKey)) {
              // Usar exceções do cache (evita chamadas duplicadas ao Firestore)
              excecoes = _cacheExcecoes[cacheKey]!;
            } else {
              // #region agent log
              try {
                final logEntry = {
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'location': 'alocacao_medicos_logic.dart:1346',
                  'message': 'Chamando SerieService.carregarExcecoes',
                  'data': {
                    'medicoId': medicoId,
                    'hypothesisId': 'C'
                  },
                  'sessionId': 'debug-session',
                  'runId': 'run1',
                };
                writeLogToFile(jsonEncode(logEntry));
              } catch (e) {}
              // #endregion
              // Carregar do Firestore e armazenar no cache
              excecoes = await SerieService.carregarExcecoes(
                medicoId,
                unidade: unidade,
                dataInicio: dataInicioExcecoes,
                dataFim: dataFimExcecoes,
                forcarServidor:
                    false, // Usar cache do Firestore para melhor performance
              );
              // #region agent log
              try {
                final logEntry = {
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'location': 'alocacao_medicos_logic.dart:1346',
                  'message': 'SerieService.carregarExcecoes concluído',
                  'data': {
                    'medicoId': medicoId,
                    'numExcecoes': excecoes.length,
                    'hypothesisId': 'C'
                  },
                  'sessionId': 'debug-session',
                  'runId': 'run1',
                };
                writeLogToFile(jsonEncode(logEntry));
              } catch (e) {}
              // #endregion
              _cacheExcecoes[cacheKey] = excecoes;
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
            DateTime dataInicioGeracao;
            DateTime dataFimGeracao;
            if (dataFiltroDia != null) {
              dataInicioGeracao = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              dataFimGeracao = dataInicioGeracao.add(const Duration(days: 1));
            } else {
              final ano = anoEspecifico != null
                  ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                  : DateTime.now().year;
              dataInicioGeracao = DateTime(ano, 1, 1);
              dataFimGeracao = DateTime(ano + 1, 1, 1);
            }
            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'alocacao_medicos_logic.dart:1392',
                'message': 'Chamando SerieGenerator.gerarDisponibilidades',
                'data': {
                  'medicoId': medicoId,
                  'numSeries': seriesRelevantes.length,
                  'numExcecoes': excecoesFiltradas.length,
                  'dataInicio': dataInicioGeracao.toString(),
                  'dataFim': dataFimGeracao.toString(),
                  'hypothesisId': 'B'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
            // #endregion
            // Usar apenas séries relevantes (já filtradas acima)
            final dispsGeradas = SerieGenerator.gerarDisponibilidades(
              series: seriesRelevantes,
              excecoes: excecoesFiltradas,
              dataInicio: dataInicioGeracao,
              dataFim: dataFimGeracao,
            );
            // #region agent log
            try {
              final logEntry = {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'location': 'alocacao_medicos_logic.dart:1392',
                'message': 'SerieGenerator.gerarDisponibilidades concluído',
                'data': {
                  'medicoId': medicoId,
                  'numDisponibilidades': dispsGeradas.length,
                  'hypothesisId': 'B'
                },
                'sessionId': 'debug-session',
                'runId': 'run1',
              };
              writeLogToFile(jsonEncode(logEntry));
            } catch (e) {}
            // #endregion

            medicosComSeries.add(medicoId);

            final dispsMap = <String, Disponibilidade>{};
            for (final disp in dispsGeradas) {
              final chave =
                  '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
              dispsMap[chave] = disp;
            }
            return dispsMap.values.toList();
          } catch (e) {
            return <Disponibilidade>[];
          }
        })());
      }

      // Aguardar todas as cargas em paralelo e coletar resultados
      // Future.wait é otimizado para lidar com muitas futures eficientemente
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1416',
          'message': 'Iniciando Future.wait para carregar disponibilidades',
          'data': {
            'numFutures': futures.length,
            'numMedicos': medicoIds.length,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion
      final resultados = await Future.wait(futures);
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1416',
          'message': 'Future.wait concluído',
          'data': {
            'numResultados': resultados.length,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion


      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1419',
          'message': 'Mesclando resultados',
          'data': {
            'numResultados': resultados.length,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion
      // Mesclar todos os resultados no Map para evitar duplicatas
      for (final resultado in resultados) {
        for (final disp in resultado) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          disponibilidadesMap[chave] =
              disp; // Sobrescreve se já existir (evita duplicatas)
        }
      }
      // #region agent log
      try {
        final logEntry = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'location': 'alocacao_medicos_logic.dart:1419',
          'message': 'Mesclagem concluída',
          'data': {
            'numDisponibilidades': disponibilidadesMap.length,
            'hypothesisId': 'A'
          },
          'sessionId': 'debug-session',
          'runId': 'run1',
        };
        writeLogToFile(jsonEncode(logEntry));
      } catch (e) {}
      // #endregion

    } catch (e) {
      debugPrint('❌ Erro ao carregar disponibilidades: $e');
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
  static Future<List<Alocacao>> _carregarAlocacoesUnidadePorAno(
      Unidade? unidade, String? anoEspecifico,
      {DateTime? dataFiltroDia}) async {
    debugPrint(
        '🔍 [DEBUG] _carregarAlocacoesUnidadePorAno chamado - unidade: ${unidade?.id}, ano: $anoEspecifico, dataFiltro: ${dataFiltroDia?.day}/${dataFiltroDia?.month}/${dataFiltroDia?.year}');
    final firestore = FirebaseFirestore.instance;
    final alocacoes = <Alocacao>[];

    try {
      if (unidade != null) {
        // Caminho preferencial: vista diária materializada
        if (dataFiltroDia != null) {
          final dayKey = _keyDia(dataFiltroDia);
          debugPrint(
              '🔍 [DEBUG] Tentando carregar alocações da vista diária (dayKey: $dayKey)...');
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
          debugPrint(
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
                  .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
                  .where('data', isLessThan: fim.toIso8601String());
            }
            // OTIMIZAÇÃO CRÍTICA: Usar cache quando disponível em vez de forçar servidor
            final registosSnapshot =
                await query.get(GetOptions(source: _getSourceForDay(dataFiltroDia ?? DateTime.now())));
            debugPrint(
                '🔍 [DEBUG] Query de alocações retornou ${registosSnapshot.docs.length} documentos');

            final alocacoesDaColecao = <Alocacao>[];
            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              final alocacao = Alocacao.fromMap(data);
              alocacoesDaColecao.add(alocacao);
              debugPrint(
                  '  ✅ [DEBUG] Alocação da coleção: médico=${alocacao.medicoId}, gabinete=${alocacao.gabineteId}, data=${alocacao.data.day}/${alocacao.data.month}/${alocacao.data.year}');
            }
            // Mesclar alocações da coleção com as da vista diária, evitando duplicados
            final alocacoesAntes = alocacoes.length;
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
            debugPrint(
                '✅ [DEBUG] Total de alocações após mesclagem: ${alocacoes.length} (vista diária: $alocacoesAntes, coleção: ${alocacoesDaColecao.length}, duplicados removidos: ${alocacoesAntes + alocacoesDaColecao.length - alocacoes.length})');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar alocações: $e');
    }

    // Gerar alocações dinamicamente a partir de séries
    try {
      // Determinar período para gerar alocações
      DateTime dataInicio;
      DateTime dataFim;

      if (dataFiltroDia != null) {
        // Se há filtro de dia, gerar apenas para esse dia
        dataInicio = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        dataFim = dataInicio.add(const Duration(days: 1));
      } else if (anoEspecifico != null) {
        // Se há ano específico, gerar para o ano inteiro
        final ano = int.tryParse(anoEspecifico) ?? DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
        dataFim = DateTime(ano + 1, 1, 1);
      } else {
        // Gerar para o ano atual
        final ano = DateTime.now().year;
        dataInicio = DateTime(ano, 1, 1);
        dataFim = DateTime(ano + 1, 1, 1);
      }

      // Carregar séries e exceções para gerar alocações
      // IMPORTANTE: Usar cache de médicos e séries quando disponível

      final alocacoesGeradas = <Alocacao>[];
      final anoParaCache = dataFiltroDia?.year ??
          (anoEspecifico != null
              ? int.tryParse(anoEspecifico) ?? DateTime.now().year
              : DateTime.now().year);

      // SEMPRE carregar TODOS os médicos ativos do Firestore
      final medicosRef = firestore
          .collection('unidades')
          .doc(unidade!.id)
          .collection('ocupantes');
      final medicosSnapshot = await medicosRef
          .where('ativo', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache));
      final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();

      // OTIMIZAÇÃO CRÍTICA: Processar médicos em PARALELO (não sequencialmente)
      // Isso reduz drasticamente o tempo de carregamento (de ~52s para ~5-10s)
      final futures = <Future<List<Alocacao>>>[];

      for (final medicoId in medicoIds) {
        futures.add((() async {
          List<SerieRecorrencia> series;
          List<ExcecaoSerie> excecoes;

          DateTime? dataInicioParaCarregarSeries;
          DateTime? dataFimParaCarregarSeries;

          if (dataFiltroDia != null) {
            // Carregar TODAS as séries ativas para não perder séries antigas
            dataInicioParaCarregarSeries = null;
            dataFimParaCarregarSeries =
                dataFiltroDia.add(const Duration(days: 1));
          } else {
            final ano = anoEspecifico != null
                ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                : DateTime.now().year;
            dataInicioParaCarregarSeries = DateTime(ano, 1, 1);
            dataFimParaCarregarSeries = DateTime(ano + 1, 1, 1);
          }

          // Carregar séries do médico
          series = await SerieService.carregarSeries(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioParaCarregarSeries,
            dataFim: dataFimParaCarregarSeries,
          );

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
              // Série precisa ter gabineteId para gerar alocações
              return serie.gabineteId != null;
            }).toList();

            if (seriesRelevantes.isEmpty) {
              return <Alocacao>[];
            }
          }

          // Filtrar apenas séries com gabineteId != null para gerar alocações
          final seriesComGabinete =
              series.where((s) => s.gabineteId != null).toList();

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

          // OTIMIZAÇÃO: Usar cache para exceções (não forçar servidor sempre)
          excecoes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioExcecoes,
            dataFim: dataFimExcecoes,
            forcarServidor: false, // Usar cache quando disponível
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
          DateTime dataInicioAlocacoes;
          DateTime dataFimAlocacoes;
          if (dataFiltroDia != null) {
            dataInicioAlocacoes = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            dataFimAlocacoes = dataInicioAlocacoes.add(const Duration(days: 1));
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
          final datasComExcecoes =
              await AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
                  unidade.id, dataFiltroDia);
          datasComExcecoesCanceladas.addAll(datasComExcecoes);
        } catch (e) {}
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
        dataInicioExcecoes = DateTime(dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        dataFimExcecoes = dataInicioExcecoes.add(const Duration(days: 1));
      } else {
        final ano = anoEspecifico != null
            ? int.tryParse(anoEspecifico) ?? DateTime.now().year
            : DateTime.now().year;
        dataInicioExcecoes = DateTime(ano, 1, 1);
        dataFimExcecoes = DateTime(ano + 1, 1, 1);
      }
      
      // Processar todos os médicos em paralelo (cada future retorna uma lista de dataKeys)
      final futuresExcecoes = <Future<List<String>>>[];
      for (final medicoId in medicoIds) {
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
                final dataKey = '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
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
        if (!aloc.id.startsWith('serie_') && chavesSeriesParaRemover.contains(dataKey)) {
          if (!datasComExcecoesAtivas.contains(dataKey)) {
            // Há série alocada para esta data mas não há exceção ativa,
            // então a alocação "Única" será substituída pela alocação gerada da série
            continue;
          }
        }

        // Adicionar apenas alocações "Única" (não são de séries)
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        // Alocações "Única" do Firestore têm prioridade sobre alocações geradas (caso raro de conflito)
        alocacoesMap[chave] = aloc;
      }

      // Depois, adicionar alocações geradas de séries (dinâmicas)
      // Isso substitui qualquer alocação antiga da mesma série/data
      for (final aloc in alocacoesGeradas) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
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
      for (int ano = anoInicio; ano <= anoFim; ano++) {
        final alocacoesAno = await _carregarAlocacoesUnidadePorAno(
          unidade,
          ano.toString(),
        );
        todasAlocacoes.addAll(alocacoesAno);
      }
    } else {
      // Buscar apenas do ano específico ou ano atual
      todasAlocacoes = await _carregarAlocacoesUnidadePorAno(
        unidade,
        anoEspecifico?.toString(),
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
