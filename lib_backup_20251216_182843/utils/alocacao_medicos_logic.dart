// import '../database/database_helper.dart';
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
import '../utils/debug_log_file.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlocacaoMedicosLogic {
  // Cache simples em memória por dia (chave yyyy-MM-dd)
  static final Map<String, List<Disponibilidade>> _cacheDispPorDia = {};
  static final Map<String, List<Alocacao>> _cacheAlocPorDia = {};
  // Cache de séries por médico e período (chave: medicoId_ano)
  static final Map<String, Map<String, dynamic>> _cacheSeriesPorMedico = {};
  // Flag para indicar que o cache de séries foi invalidado e precisa ler do servidor
  static final Set<String> _cacheSeriesInvalidado = {};
  // Flag para indicar que o cache de séries foi invalidado para TODOS os anos de um médico
  // (chave: medicoId, usado quando invalida com ano == null)
  static final Set<String> _cacheSeriesInvalidadoTodosAnos = {};
  // Cache de médicos ativos por unidade (chave: unidadeId)
  static final Map<String, List<String>> _cacheMedicosAtivos = {};
  // Flag para indicar que o cache foi invalidado recentemente e precisa ler do servidor
  static final Set<String> _cacheMedicosAtivosInvalidado = {};
  // Cache de exceções canceladas por dia (chave: unidadeId_yyyy-MM-dd)
  static final Map<String, Set<String>> _cacheExcecoesCanceladasPorDia = {};

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

  /// Atualiza (ou invalida) o cache do dia.
  static void updateCacheForDay({
    required DateTime day,
    List<Disponibilidade>? disponibilidades,
    List<Alocacao>? alocacoes,
  }) {
    final key = _keyDia(day);
    if (disponibilidades != null) {
      _cacheDispPorDia[key] = List<Disponibilidade>.from(disponibilidades);
    }
    if (alocacoes != null) {
      _cacheAlocPorDia[key] = List<Alocacao>.from(alocacoes);
    }
  }

  /// Remove o cache do dia específico (será recarregado na próxima consulta)
  static void invalidateCacheForDay(DateTime day) {
    final key = _keyDia(day);
    _cacheDispPorDia.remove(key);
    _cacheAlocPorDia.remove(key);
    // Invalidar também cache de exceções canceladas para este dia
    _cacheExcecoesCanceladasPorDia.removeWhere((k, v) => k.endsWith('_$key'));
  }

  /// Remove o cache de todos os dias a partir de uma data específica
  /// Útil quando um médico é deletado "a partir de hoje"
  static void invalidateCacheFromDate(DateTime fromDate) {
    final fromKey = _keyDia(fromDate);
    final keysToRemove = <String>[];

    // Encontra todas as chaves de cache que são >= fromDate
    // As chaves estão no formato "yyyy-MM-dd", então comparação de strings funciona
    for (final key in _cacheDispPorDia.keys) {
      if (key.compareTo(fromKey) >= 0) {
        keysToRemove.add(key);
      }
    }

    // Remove as chaves encontradas
    for (final key in keysToRemove) {
      _cacheDispPorDia.remove(key);
      _cacheAlocPorDia.remove(key);
    }

    // Limpar cache de séries também (será recarregado quando necessário)
    _cacheSeriesPorMedico.clear();
    // Não limpar cache de médicos - eles mudam raramente
  }

  /// Retorna lista de médicos que têm séries alocadas (com gabineteId) no cache
  /// Útil para otimizar processamento e evitar carregar séries de todos os médicos
  static List<String> obterMedicosComSeriesAlocadasNoCache(int ano) {
    final medicosComSeriesAlocadas = <String>[];
    for (final entry in _cacheSeriesPorMedico.entries) {
      final parts = entry.key.split('_');
      if (parts.length >= 2) {
        final anoCache = int.tryParse(parts[1]);
        if (anoCache == ano || anoCache == ano - 1) {
          final medicoId = parts[0];
          final cachedData = entry.value;
          final series =
              (cachedData['series'] as List).cast<SerieRecorrencia>();
          // Só incluir se tem séries ativas COM gabineteId (alocadas)
          if (series.any((s) => s.ativo && s.gabineteId != null)) {
            medicosComSeriesAlocadas.add(medicoId);
          }
        }
      }
    }
    return medicosComSeriesAlocadas.toSet().toList();
  }

  /// Obtém séries e exceções do cache para um médico específico
  /// Retorna null se não há cache ou se foi invalidado
  static Map<String, dynamic>? obterSeriesDoCache(String medicoId, int ano) {
    final cacheKey = '${medicoId}_$ano';
    if (_cacheSeriesInvalidado.contains(cacheKey)) {
      return null; // Cache foi invalidado
    }
    return _cacheSeriesPorMedico[cacheKey];
  }

  /// Verifica se o cache de séries foi invalidado para um médico específico
  static bool cacheFoiInvalidado(String medicoId, int ano) {
    final cacheKey = '${medicoId}_$ano';
    return _cacheSeriesInvalidado.contains(cacheKey) ||
        _cacheSeriesInvalidadoTodosAnos.contains(medicoId);
  }

  /// Verifica se o médico tem algum cache invalidado (qualquer ano)
  /// Útil quando o cache foi invalidado para todos os anos (ano == null)
  static bool medicoTemCacheInvalidado(String medicoId) {
    return _cacheSeriesInvalidado
            .any((key) => key.startsWith('${medicoId}_')) ||
        _cacheSeriesInvalidadoTodosAnos.contains(medicoId);
  }

  /// Limpa o cache de séries de um médico específico
  static void invalidateSeriesCacheForMedico(String medicoId, int? ano) {
    if (ano != null) {
      final cacheKey = '${medicoId}_$ano';
      _cacheSeriesPorMedico.remove(cacheKey);
      _cacheSeriesInvalidado.add(cacheKey); // Marcar como invalidado
      // Remover da lista de todos os anos se estava lá
      _cacheSeriesInvalidadoTodosAnos.remove(medicoId);
    } else {
      // Remover todas as entradas deste médico
      final keysToRemove = _cacheSeriesPorMedico.keys
          .where((key) => key.startsWith('${medicoId}_'))
          .toList();
      for (final key in keysToRemove) {
        _cacheSeriesPorMedico.remove(key);
        _cacheSeriesInvalidado.add(key); // Marcar como invalidado
      }
      // CORREÇÃO: Marcar que TODOS os anos deste médico devem ser recarregados
      // Isso garante que mesmo anos que não estavam no cache sejam recarregados do servidor
      _cacheSeriesInvalidadoTodosAnos.add(medicoId);
      print('🔄 Cache invalidado para TODOS os anos do médico $medicoId');
    }
  }

  /// Invalida o cache de médicos ativos para uma unidade
  /// Útil quando um novo médico é criado ou quando o status ativo de um médico muda
  static void invalidateMedicosAtivosCache({String? unidadeId}) {
    if (unidadeId != null) {
      _cacheMedicosAtivos.remove(unidadeId);
      _cacheMedicosAtivosInvalidado.add(unidadeId); // Marcar como invalidado
    } else {
      // Se não especificou unidade, limpar todo o cache
      _cacheMedicosAtivos.clear();
      _cacheMedicosAtivosInvalidado.clear(); // Marcar todos como invalidados
    }
  }

  /// Extrai datas com exceções canceladas do cache para um dia específico
  /// Retorna um Set com chaves no formato: medicoId_ano-mes-dia
  /// Se o cache não estiver disponível, carrega diretamente do Firestore
  /// OTIMIZADO: Usa collectionGroup para carregar exceções de todos os médicos de uma vez
  static Future<Set<String>> extrairExcecoesCanceladasParaDia(
      String unidadeId, DateTime data) async {
    // Verificar cache primeiro (muito mais rápido)
    final cacheKey = '${unidadeId}_${_keyDia(data)}';
    if (_cacheExcecoesCanceladasPorDia.containsKey(cacheKey)) {
      return _cacheExcecoesCanceladasPorDia[cacheKey]!;
    }

    final datasComExcecoesCanceladas = <String>{};
    try {
      final anoParaCache = data.year;

      // OTIMIZAÇÃO 1: Carregar exceções apenas para médicos que têm séries ativas
      // Primeiro, identificar médicos com séries no cache
      final medicoIds = _cacheMedicosAtivos[unidadeId] ?? <String>[];

      // Se não há médicos no cache, tentar carregar do Firestore
      if (medicoIds.isEmpty) {
        final firestore = FirebaseFirestore.instance;
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes');
        final medicosSnapshot = await medicosRef
            .where('ativo', isEqualTo: true)
            .get(const GetOptions(source: Source.serverAndCache));
        medicoIds.addAll(medicosSnapshot.docs.map((d) => d.id).toList());
        _cacheMedicosAtivos[unidadeId] = medicoIds;
      }

      // OTIMIZAÇÃO CRÍTICA: Verificar apenas médicos que têm séries no cache
      // Médicos sem séries não precisam ter exceções carregadas
      final medicosParaVerificar = <String>[];
      for (final medicoId in medicoIds) {
        final cacheKeyMedico = '${medicoId}_$anoParaCache';
        final cacheExiste = _cacheSeriesPorMedico.containsKey(cacheKeyMedico);

        // Se não tem cache, pular (não tem séries, então não precisa verificar exceções)
        if (!cacheExiste) {
          continue;
        }

        final cachedData = _cacheSeriesPorMedico[cacheKeyMedico]!;
        final series = cachedData['series'] as List<SerieRecorrencia>;

        // Se não tem séries, não precisa verificar exceções
        if (series.isEmpty) {
          continue;
        }

        final cacheTemExcecoes = (cachedData['excecoes'] as List).isNotEmpty;

        // Verificar se o cache tem exceções para o dia específico
        bool cacheTemExcecoesParaEsteDia = false;
        if (cacheTemExcecoes) {
          final excecoesCache = cachedData['excecoes'] as List<ExcecaoSerie>;
          cacheTemExcecoesParaEsteDia = excecoesCache.any((e) =>
              e.cancelada &&
              e.data.year == data.year &&
              e.data.month == data.month &&
              e.data.day == data.day);

          // Se tem no cache, processar diretamente
          if (cacheTemExcecoesParaEsteDia) {
            for (final excecao in excecoesCache) {
              if (excecao.cancelada &&
                  excecao.data.year == data.year &&
                  excecao.data.month == data.month &&
                  excecao.data.day == data.day) {
                final dataKey =
                    '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                datasComExcecoesCanceladas.add(dataKey);
              }
            }
          }
        }

        // Se não tem exceções no cache ou não tem para este dia específico, adicionar à lista
        if (!cacheTemExcecoes || !cacheTemExcecoesParaEsteDia) {
          medicosParaVerificar.add(medicoId);
        }
      }

      // OTIMIZAÇÃO 2: Carregar exceções em paralelo apenas para médicos que precisam
      if (medicosParaVerificar.isNotEmpty) {
        final firestore = FirebaseFirestore.instance;

        // Carregar exceções em paralelo para todos os médicos que precisam
        final futures = medicosParaVerificar.map((medicoId) async {
          try {
            final medicoExcecoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('ocupantes')
                .doc(medicoId)
                .collection('excecoes')
                .doc(anoParaCache.toString())
                .collection('registos');

            final snapshot = await medicoExcecoesRef
                .get(const GetOptions(source: Source.serverAndCache));

            final excecoes = <ExcecaoSerie>[];
            for (final doc in snapshot.docs) {
              final excecao =
                  ExcecaoSerie.fromMap({...doc.data(), 'id': doc.id});
              if (excecao.cancelada &&
                  excecao.data.year == data.year &&
                  excecao.data.month == data.month &&
                  excecao.data.day == data.day) {
                excecoes.add(excecao);
                final dataKey =
                    '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                datasComExcecoesCanceladas.add(dataKey);
              }
            }

            return {'medicoId': medicoId, 'excecoes': excecoes};
          } catch (e) {
            return {'medicoId': medicoId, 'excecoes': <ExcecaoSerie>[]};
          }
        });

        final resultados = await Future.wait(futures);

        // Atualizar cache com exceções carregadas
        for (final resultado in resultados) {
          final medicoId = resultado['medicoId'] as String;
          final excecoes = resultado['excecoes'] as List<ExcecaoSerie>;

          if (excecoes.isNotEmpty) {
            final cacheKeyMedico = '${medicoId}_$anoParaCache';
            if (_cacheSeriesPorMedico.containsKey(cacheKeyMedico)) {
              final cachedData = _cacheSeriesPorMedico[cacheKeyMedico]!;
              final excecoesExistentes =
                  (cachedData['excecoes'] as List<ExcecaoSerie>).toList();
              final todasExcecoes = <ExcecaoSerie>[...excecoesExistentes];

              for (final novaExcecao in excecoes) {
                if (!todasExcecoes.any((e) => e.id == novaExcecao.id)) {
                  todasExcecoes.add(novaExcecao);
                }
              }

              _cacheSeriesPorMedico[cacheKeyMedico] = {
                'series': cachedData['series'],
                'excecoes': todasExcecoes,
              };
            } else {
              _cacheSeriesPorMedico[cacheKeyMedico] = {
                'series': <SerieRecorrencia>[],
                'excecoes': excecoes,
              };
            }
          }
        }
      }

      // Guardar no cache para evitar queries futuras
      _cacheExcecoesCanceladasPorDia[cacheKey] = datasComExcecoesCanceladas;
    } catch (e) {
      // Em caso de erro, retornar conjunto vazio
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

      // Carrega disponibilidades e alocações (com cache por dia), em paralelo quando necessário
      List<Disponibilidade> disps = const [];
      List<Alocacao> alocs = const [];
      // chave do dia (se houver)
      final String? keyDia =
          dataFiltroDia != null ? _keyDia(dataFiltroDia) : null;
      final precisaDisps =
          keyDia == null ? true : !_cacheDispPorDia.containsKey(keyDia);
      final precisaAlocs =
          keyDia == null ? true : !_cacheAlocPorDia.containsKey(keyDia);

      if (!precisaDisps) {
        disps = _cacheDispPorDia[keyDia] ?? const [];

        // IMPORTANTE: Filtrar disponibilidades baseado em exceções canceladas
        // O cache já deve conter disponibilidades de séries, mas precisamos garantir
        // que exceções canceladas sejam respeitadas
        if (unidade != null && dataFiltroDia != null) {
          try {
            // Usar exceções já carregadas ou carregar se não foram fornecidas
            final datasComExcecoesCanceladas = excecoesCanceladas ??
                await extrairExcecoesCanceladasParaDia(
                    unidade.id, dataFiltroDia);

            if (datasComExcecoesCanceladas.isNotEmpty) {
              final dispsAntes = disps.length;
              disps = disps.where((disp) {
                final dataKey =
                    '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
                if (datasComExcecoesCanceladas.contains(dataKey)) {
                  return false;
                }
                return true;
              }).toList();
            }

            // IMPORTANTE: Verificar se há novas séries que não estão no cache
            // Se o cache não contém disponibilidades de séries (nenhuma com ID começando com "serie_"),
            // então precisamos gerar novamente
            final temDispsDeSeriesNoCache =
                disps.any((d) => d.id.startsWith('serie_'));
            if (!temDispsDeSeriesNoCache) {
              final anoEspecifico = dataFiltroDia.year.toString();
              final dispsDeSeries = await carregarDisponibilidadesDeSeries(
                unidade: unidade,
                anoEspecifico: anoEspecifico,
                dataFiltroDia: dataFiltroDia,
              );

              // Mesclar apenas se houver novas disponibilidades de séries
              if (dispsDeSeries.isNotEmpty) {
                final dispsUnicas = <String, Disponibilidade>{};

                // CORREÇÃO: Filtrar disponibilidades antigas do cache
                // Manter apenas séries e únicas válidas
                final dispsAntigasFiltradas = disps
                    .where(
                        (d) => d.id.startsWith('serie_') || d.tipo == 'Única')
                    .toList();

                // Adicionar apenas disponibilidades de séries do cache (filtrar antigas)
                for (final disp in dispsAntigasFiltradas) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicas[chave] = disp;
                }

                // Adicionar disponibilidades geradas de séries (sobrescrevem se houver duplicata)
                for (final disp in dispsDeSeries) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicas[chave] = disp;
                }

                disps = dispsUnicas.values.toList();
              } else {
                // Se não há disponibilidades de séries, filtrar disponibilidades antigas do cache
                // Mas manter únicas válidas
                final dispsAntigasFiltradas = disps
                    .where(
                        (d) => d.id.startsWith('serie_') || d.tipo == 'Única')
                    .toList();
                disps = dispsAntigasFiltradas;
              }

              // Carregar disponibilidades "Única" do Firestore e mesclar
              List<Disponibilidade> dispsUnicas = [];
              try {
                final firestore = FirebaseFirestore.instance;
                final diasRef = firestore
                    .collection('unidades')
                    .doc(unidade.id)
                    .collection('dias')
                    .doc(keyDia)
                    .collection('disponibilidades');

                final snapshot = await diasRef.get();
                dispsUnicas = snapshot.docs
                    .map((doc) => Disponibilidade.fromMap(doc.data()))
                    .where((d) => d.tipo == 'Única')
                    .toList();

                // Mesclar com disponibilidades do cache
                final dispsUnicasMap = <String, Disponibilidade>{};
                for (final disp in disps) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicasMap[chave] = disp;
                }
                for (final disp in dispsUnicas) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicasMap[chave] = disp;
                }
                disps = dispsUnicasMap.values.toList();
              } catch (e) {
                // Em caso de erro, manter disponibilidades do cache
              }
            }
          } catch (e) {
            // Em caso de erro, continuar com disponibilidades do cache
          }
        }
      }

      if (!precisaAlocs) {
        alocs = _cacheAlocPorDia[keyDia] ?? const [];

        // IMPORTANTE: Filtrar alocações do cache baseado em exceções canceladas
        if (unidade != null && dataFiltroDia != null) {
          try {
            // Usar exceções já carregadas ou carregar se não foram fornecidas
            final datasComExcecoesCanceladas = excecoesCanceladas ??
                await extrairExcecoesCanceladasParaDia(
                    unidade.id, dataFiltroDia);

            if (datasComExcecoesCanceladas.isNotEmpty) {
              alocs = alocs.where((aloc) {
                final dataKey =
                    '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
                if (datasComExcecoesCanceladas.contains(dataKey)) {
                  return false;
                }
                return true;
              }).toList();
            }
          } catch (e) {
            // Em caso de erro, manter alocações do cache
          }
        }
      }

      if (precisaDisps && precisaAlocs) {
        // Carregar disponibilidades e alocações em paralelo para melhor performance
        final results = await Future.wait([
          _carregarDisponibilidadesUnidade(unidade,
              dataFiltroDia: dataFiltroDia),
          _carregarAlocacoesUnidade(unidade, dataFiltroDia: dataFiltroDia),
        ]);
        disps = results[0] as List<Disponibilidade>;
        alocs = results[1] as List<Alocacao>;
      } else if (precisaDisps) {
        disps = await _carregarDisponibilidadesUnidade(unidade,
            dataFiltroDia: dataFiltroDia);
      } else if (precisaAlocs) {
        alocs = await _carregarAlocacoesUnidade(unidade,
            dataFiltroDia: dataFiltroDia);
      } else {
        // Ambos em cache: evita trabalho extra e garante mudança de dia instantânea
        disps = _cacheDispPorDia[keyDia] ?? const [];
        alocs = _cacheAlocPorDia[keyDia] ?? const [];
      }

      // Aplicar exceções canceladas aos dados carregados (se fornecidas e não foram aplicadas antes)
      if (excecoesCanceladas != null &&
          excecoesCanceladas.isNotEmpty &&
          unidade != null &&
          dataFiltroDia != null) {
        // Filtrar disponibilidades
        final dispsAntes = disps.length;
        disps = disps.where((disp) {
          final dataKey =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
          return !excecoesCanceladas.contains(dataKey);
        }).toList();

        // Filtrar alocações
        final alocsAntes = alocs.length;
        alocs = alocs.where((aloc) {
          final dataKey =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          return !excecoesCanceladas.contains(dataKey);
        }).toList();
      }

      if (keyDia != null) {
        // CORREÇÃO: Carregar disponibilidades "Única" do Firestore (coleção dias)
        // e mesclar com disponibilidades de séries
        List<Disponibilidade> dispsUnicas = [];
        if (unidade != null && dataFiltroDia != null) {
          try {
            final firestore = FirebaseFirestore.instance;
            final diasRef = firestore
                .collection('unidades')
                .doc(unidade.id)
                .collection('dias')
                .doc(keyDia)
                .collection('disponibilidades');

            final snapshot = await diasRef.get();
            dispsUnicas = snapshot.docs
                .map((doc) => Disponibilidade.fromMap(doc.data()))
                .where(
                    (d) => d.tipo == 'Única') // Apenas disponibilidades "Única"
                .toList();
          } catch (e) {}
        }

        // Filtrar disponibilidades antigas (que não são séries nem únicas válidas)
        // Manter apenas séries (começam com "serie_") e únicas válidas (tipo "Única")
        final dispsAntesFiltro = disps.length;
        disps = disps
            .where((d) => d.id.startsWith('serie_') || d.tipo == 'Única')
            .toList();

        // Mesclar com disponibilidades "Única" do Firestore
        final dispsUnicasMap = <String, Disponibilidade>{};
        for (final disp in disps) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          dispsUnicasMap[chave] = disp;
        }
        for (final disp in dispsUnicas) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          dispsUnicasMap[chave] = disp;
        }
        disps = dispsUnicasMap.values.toList();

        // IMPORTANTE: Garantir que o cache sempre inclui disponibilidades de séries
        // Mas apenas se ainda não estiverem no cache para evitar duplicação
        if (unidade != null && dataFiltroDia != null) {
          try {
            // Verificar se o cache já contém disponibilidades de séries
            final temDispsDeSeriesNoCache =
                disps.any((d) => d.id.startsWith('serie_'));

            // CORREÇÃO: Sempre gerar disponibilidades de séries se o cache está vazio
            // ou se não contém disponibilidades de séries para o dia específico
            if (!temDispsDeSeriesNoCache || disps.isEmpty) {
              // Se não há disponibilidades de séries no cache, gerar e mesclar
              final anoEspecifico = dataFiltroDia.year.toString();
              final dispsDeSeries = await carregarDisponibilidadesDeSeries(
                unidade: unidade,
                anoEspecifico: anoEspecifico,
                dataFiltroDia: dataFiltroDia,
              );

              // Mesclar com disponibilidades existentes usando mapa para evitar duplicatas
              final dispsUnicas = <String, Disponibilidade>{};
              for (final disp in disps) {
                final chave =
                    '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                dispsUnicas[chave] = disp;
              }
              for (final disp in dispsDeSeries) {
                final chave =
                    '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                dispsUnicas[chave] = disp;
              }

              // CORREÇÃO: Manter apenas séries e únicas válidas
              // Não filtrar disponibilidades "Única" válidas
              final dispsFiltradas = dispsUnicas.values
                  .where((d) => d.id.startsWith('serie_') || d.tipo == 'Única')
                  .toList();
              disps = dispsFiltradas;
            } else {
              // CORREÇÃO: Mesmo quando cache já tem séries, filtrar antigas mas manter únicas válidas
              final dispsAntes = disps.length;
              disps = disps
                  .where((d) => d.id.startsWith('serie_') || d.tipo == 'Única')
                  .toList();

              // Carregar disponibilidades "Única" do Firestore e mesclar
              List<Disponibilidade> dispsUnicas = [];
              try {
                final firestore = FirebaseFirestore.instance;
                final diasRef = firestore
                    .collection('unidades')
                    .doc(unidade.id)
                    .collection('dias')
                    .doc(keyDia)
                    .collection('disponibilidades');

                final snapshot = await diasRef.get();
                dispsUnicas = snapshot.docs
                    .map((doc) => Disponibilidade.fromMap(doc.data()))
                    .where((d) => d.tipo == 'Única')
                    .toList();

                // Mesclar com disponibilidades do cache
                final dispsUnicasMap = <String, Disponibilidade>{};
                for (final disp in disps) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicasMap[chave] = disp;
                }
                for (final disp in dispsUnicas) {
                  final chave =
                      '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  dispsUnicasMap[chave] = disp;
                }
                disps = dispsUnicasMap.values.toList();
              } catch (e) {}
            }
          } catch (e) {}
        }

        _cacheDispPorDia[keyDia] = List.from(disps);
        _cacheAlocPorDia[keyDia] = List.from(alocs);
      }

      // Atualizar as listas
      onGabinetes(List<Gabinete>.from(gabs));
      onMedicos(List<Medico>.from(meds));
      onDisponibilidades(List<Disponibilidade>.from(disps));
      onAlocacoes(List<Alocacao>.from(alocs));
    } catch (e) {
      // CORREÇÃO CRÍTICA: Em caso de erro, NÃO limpar dados estáticos (gabinetes e médicos)
      // Esses dados não mudam com a data e não devem ser perdidos
      // Preservar dados estáticos existentes para evitar que sejam perdidos durante mudança de data
      print('❌ Erro ao carregar dados iniciais: $e');

      // Se não estamos recarregando dados estáticos e já havia dados, preservar
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
    // Isso garante que mesmo se houver duplicações, todas sejam removidas
    final alocacoesAnteriores = alocacoes.where((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && alocDate == dataAlvo;
    }).toList();

    if (alocacoesAnteriores.isNotEmpty) {
      print(
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
          print(
              '✅ Alocação anterior removida do Firebase: ${alocacaoAnterior.id}');
        } catch (e) {
          print(
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
      print('✅ Usando horários forçados: $horarioInicio - $horarioFim');
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

      print('✅ Alocação salva no Firebase: ${novaAloc.id}');
    } catch (e) {
      print('❌ Erro ao salvar alocação no Firebase: $e');
      rethrow; // Re-throw para que o erro seja tratado no nível superior
    }

    // Adicionar localmente IMEDIATAMENTE para feedback visual instantâneo
    // O listener do Firestore vai atualizar depois, mas isso garante que o cartão apareça no gabinete
    final indexExistente = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });

    if (indexExistente != -1) {
      // Se já existe, substituir
      alocacoes[indexExistente] = novaAloc;
    } else {
      // Se não existe, adicionar
      alocacoes.add(novaAloc);
    }

    // Invalidar cache para o dia selecionado - será recarregado quando onAlocacoesChanged() for chamado
    invalidateCacheForDay(dataAlvo);

    // Atualizar cache local também
    updateCacheForDay(day: dataAlvo, alocacoes: alocacoes);

    // CORREÇÃO: Chamar onAlocacoesChanged() que recarrega tudo do Firebase
    // Mas como já adicionamos localmente, o cartão aparece imediatamente
    // O delay aumentado ajuda a consolidar atualizações e reduzir "piscar"
    // Removido - será chamado pela tela principal após operação
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

    final indexAloc = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });
    if (indexAloc == -1) {
      return;
    }

    final alocacaoRemovida = alocacoes[indexAloc];
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
      print(
          '✅ Alocação removida do Firebase: ${alocacaoRemovida.id} (ano: $ano, unidade: $unidadeId)');
    } catch (e) {
      print('❌ Erro ao remover alocação do Firebase: $e');
    }

    // Invalidar cache IMEDIATAMENTE para garantir que a próxima verificação seja correta
    invalidateCacheForDay(dataAlvo);

    final temDisp = disponibilidades.any((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataAlvo;
    });
    if (temDisp) {
      final medico = medicos.firstWhere(
        (m) => m.id == medicoId,
        orElse: () => Medico(
          id: medicoId,
          nome: 'Médico não identificado',
          especialidade: '',
          disponibilidades: [],
          ativo: false, // Médico não identificado é considerado inativo
        ),
      );
      if (!medicosDisponiveis.contains(medico)) {
        medicosDisponiveis.add(medico);
      }
    }

    // Atualiza cache para o dia afetado (com a lista já atualizada)
    final diaKey = _keyDia(dataAlvo);
    final alocDoDiaAtualizadas = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return aDate == dataAlvo;
    }).toList();
    _cacheAlocPorDia[diaKey] = alocDoDiaAtualizadas;

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

    // Invalidar cache antes de buscar para garantir dados atualizados
    invalidateSeriesCacheForMedico(medicoId, dataRef.year);
    final series = await SerieService.carregarSeries(
      medicoId,
      unidade: unidade,
    );
    for (final s in series) {}

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
      // Se não encontrou a série, pode haver alocação individual para este dia
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

        // CORREÇÃO: Invalidar cache ANTES e DEPOIS de desalocar para garantir dados atualizados
        invalidateSeriesCacheForMedico(medicoId, dataRef.year);

        // Verificar se foi realmente removido buscando novamente do servidor
        final seriesVerificacao = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
        );
        final serieVerificada = seriesVerificacao.firstWhere(
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
              .get(const GetOptions(source: Source.server));

          // Filtrar apenas as que têm ID começando com o prefixo da série
          for (final doc in snapshot.docs) {
            final alocId = doc.id;
            if (alocId.startsWith(serieIdPrefix)) {
              batch.delete(alocacoesRef.doc(alocId));
              totalParaDeletar++;
              if (totalParaDeletar <= 10) {
                // Log apenas as primeiras 10 para não poluir
                final data = doc.data();
                final alocData = (data['data'] as Timestamp).toDate();
              }
            }
          }
        }

        if (totalParaDeletar > 0) {
          await batch.commit();
        } else {}
      } catch (e) {}

      // Invalidar cache para o dia atual e próximos dias (as alocações serão regeneradas dinamicamente)
      invalidateCacheForDay(dataRef);
      // Invalidar também para os próximos 90 dias (mesmo período que foi criado quando alocou)
      for (int i = 1; i <= 90; i++) {
        invalidateCacheForDay(dataRef.add(Duration(days: i)));
      }
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

    // Série: invalidar cache a partir da data de referência (próximos dias serão recalculados conforme navegação)
    invalidateCacheForDay(dataRef);
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

        // CORREÇÃO CRÍTICA: Sempre usar Source.server para garantir dados atualizados da Cloud Function
        // A Cloud Function pode levar alguns milissegundos para atualizar a vista diária
        // Usar Source.server garante que obtemos os dados mais recentes
        final snapshot =
            await diasRef.get(const GetOptions(source: Source.server));
        dispsUnicas = snapshot.docs
            .map((doc) => Disponibilidade.fromMap(doc.data()))
            .where((d) => d.tipo == 'Única')
            .toList();
      } catch (e) {}
    }

    // Mesclar séries e únicas
    final todasDisps = <String, Disponibilidade>{};
    int seriesFiltradas = 0;
    int unicasFiltradas = 0;

    for (final disp in disponibilidadesDeSeries) {
      // CORREÇÃO: Se há filtro de dia, incluir apenas disponibilidades desse dia
      if (dataFiltroDia != null) {
        final dispData =
            DateTime(disp.data.year, disp.data.month, disp.data.day);
        final filtroData = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        if (dispData != filtroData) {
          seriesFiltradas++;
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
          unicasFiltradas++;
          continue; // Pular disponibilidades de outros dias
        }
      }
      final chave =
          '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
      todasDisps[chave] = disp;
    }

    return todasDisps.values.toList();
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

      // OTIMIZAÇÃO CRÍTICA: Carregar médicos apenas se realmente necessário
      // Se há dataFiltroDia, podemos usar cache de médicos que já têm séries
      // Isso evita carregar TODOS os médicos quando só precisa de alguns
      List<String> medicoIds;
      final cacheFoiInvalidado =
          _cacheMedicosAtivosInvalidado.contains(unidade.id);

      // OTIMIZAÇÃO: Se há dataFiltroDia, tentar usar apenas médicos que já têm séries no cache
      // Isso reduz drasticamente o número de médicos para processar
      if (dataFiltroDia != null) {
        final anoParaCache = dataFiltroDia.year;
        final medicosComSeriesNoCache = <String>[];

        // Verificar quais médicos já têm séries em cache para este ano
        // E que se aplicam ao dia específico
        final dataFiltroNormalizada = DateTime(
            dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
        for (final entry in _cacheSeriesPorMedico.entries) {
          final parts = entry.key.split('_');
          if (parts.length >= 2) {
            final anoCache = int.tryParse(parts[1]);
            if (anoCache == anoParaCache || anoCache == anoParaCache - 1) {
              final medicoId = parts[0];
              final cacheKey = '${medicoId}_$anoParaCache';
              // Verificar se o cache não foi invalidado
              if (!_cacheSeriesInvalidado.contains(cacheKey)) {
                final cachedData = entry.value;
                final series =
                    (cachedData['series'] as List).cast<SerieRecorrencia>();
                // Verificar se alguma série ativa se aplica ao dia específico
                bool temSerieAplicavel = false;
                for (final serie in series) {
                  if (!serie.ativo) continue;

                  final serieDataInicioNormalizada = DateTime(
                      serie.dataInicio.year,
                      serie.dataInicio.month,
                      serie.dataInicio.day);

                  if (serieDataInicioNormalizada
                      .isAfter(dataFiltroNormalizada)) {
                    continue; // Série começa depois do dia
                  }
                  if (serie.dataFim != null) {
                    final serieDataFimNormalizada = DateTime(
                        serie.dataFim!.year,
                        serie.dataFim!.month,
                        serie.dataFim!.day);
                    if (serieDataFimNormalizada
                        .isBefore(dataFiltroNormalizada)) {
                      continue; // Série já terminou antes do dia
                    }
                  }

                  // Verificar se a série realmente se aplica ao dia específico
                  bool serieSeAplicaAoDia = false;
                  switch (serie.tipo) {
                    case 'Semanal':
                      final diasDiferenca = dataFiltroNormalizada
                          .difference(serieDataInicioNormalizada)
                          .inDays;
                      serieSeAplicaAoDia =
                          diasDiferenca >= 0 && diasDiferenca % 7 == 0;
                      break;
                    case 'Quinzenal':
                      final diasDiferenca = dataFiltroNormalizada
                          .difference(serieDataInicioNormalizada)
                          .inDays;
                      serieSeAplicaAoDia =
                          diasDiferenca >= 0 && diasDiferenca % 14 == 0;
                      break;
                    case 'Mensal':
                      if (dataFiltroNormalizada.weekday ==
                          serie.dataInicio.weekday) {
                        final ocorrenciaSerie =
                            _descobrirOcorrenciaNoMes(serie.dataInicio);
                        final ocorrenciaDia =
                            _descobrirOcorrenciaNoMes(dataFiltroNormalizada);
                        serieSeAplicaAoDia = ocorrenciaSerie == ocorrenciaDia;
                      }
                      break;
                    case 'Consecutivo':
                      final numeroDias =
                          serie.parametros['numeroDias'] as int? ?? 5;
                      final diasDiferenca = dataFiltroNormalizada
                          .difference(serieDataInicioNormalizada)
                          .inDays;
                      serieSeAplicaAoDia =
                          diasDiferenca >= 0 && diasDiferenca < numeroDias;
                      break;
                    case 'Única':
                      serieSeAplicaAoDia =
                          serieDataInicioNormalizada == dataFiltroNormalizada;
                      break;
                    default:
                      serieSeAplicaAoDia = true;
                  }

                  if (serieSeAplicaAoDia) {
                    temSerieAplicavel = true;
                    break; // Já encontrou uma série aplicável, não precisa verificar mais
                  }
                }

                if (temSerieAplicavel) {
                  medicosComSeriesNoCache.add(medicoId);
                }
              }
            }
          }
        }

        // Se encontrou médicos com séries no cache, usar apenas esses
        // Senão, carregar todos os médicos ativos
        if (medicosComSeriesNoCache.isNotEmpty && !cacheFoiInvalidado) {
          medicoIds = medicosComSeriesNoCache.toSet().toList();
        } else if (_cacheMedicosAtivos.containsKey(unidade.id) &&
            !cacheFoiInvalidado) {
          medicoIds = _cacheMedicosAtivos[unidade.id]!;
        } else {
          // Carregar todos os médicos ativos apenas se necessário
          final medicosRef = firestore
              .collection('unidades')
              .doc(unidade.id)
              .collection('ocupantes');
          final source =
              cacheFoiInvalidado ? Source.server : Source.serverAndCache;
          final medicosSnapshot = await medicosRef
              .where('ativo', isEqualTo: true)
              .get(GetOptions(source: source));
          medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
          _cacheMedicosAtivos[unidade.id] = medicoIds;
          _cacheMedicosAtivosInvalidado.remove(unidade.id);
        }
      } else if (_cacheMedicosAtivos.containsKey(unidade.id) &&
          !cacheFoiInvalidado) {
        medicoIds = _cacheMedicosAtivos[unidade.id]!;
      } else {
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('ocupantes');
        final source =
            cacheFoiInvalidado ? Source.server : Source.serverAndCache;
        final medicosSnapshot = await medicosRef
            .where('ativo', isEqualTo: true)
            .get(GetOptions(source: source));
        medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
        _cacheMedicosAtivos[unidade.id] = medicoIds;
        _cacheMedicosAtivosInvalidado.remove(unidade.id);
      }

      // Se não há médicos, retornar vazio imediatamente (evita processamento desnecessário)
      if (medicoIds.isEmpty) {
        return disponibilidadesMap.values.toList();
      }

      // Carregar séries em paralelo para médicos ativos
      final futures = <Future<List<Disponibilidade>>>[];

      for (final medicoId in medicoIds) {
        final cacheKey = '${medicoId}_$anoParaCache';

        // OTIMIZAÇÃO: Verificar se o cache foi invalidado antes de usar
        final cacheFoiInvalidado = _cacheSeriesInvalidado.contains(cacheKey);

        // Verificar se já temos séries em cache para este médico e ano
        // IMPORTANTE: Para séries infinitas, também verificar cache do ano anterior,
        // pois séries que começaram no ano anterior podem se aplicar ao ano atual
        bool usarCache =
            _cacheSeriesPorMedico.containsKey(cacheKey) && !cacheFoiInvalidado;
        Map<String, dynamic>? cachedData;
        List<SerieRecorrencia> seriesDoCache = [];
        List<ExcecaoSerie> excecoesDoCache = [];

        if (usarCache) {
          cachedData = _cacheSeriesPorMedico[cacheKey]!;
          seriesDoCache =
              (cachedData['series'] as List).cast<SerieRecorrencia>();
          excecoesDoCache =
              (cachedData['excecoes'] as List).cast<ExcecaoSerie>();
          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('  📦 Cache encontrado para $medicoId (ano $anoParaCache): ${seriesDoCache.length} séries, ${excecoesDoCache.length} exceções');
        } else if (dataFiltroDia != null &&
            anoParaCache > dataFiltroDia.year - 1 &&
            !cacheFoiInvalidado) {
          // Tentar usar cache do ano anterior se disponível (para séries infinitas)
          final cacheKeyAnoAnterior = '${medicoId}_${anoParaCache - 1}';
          if (_cacheSeriesPorMedico.containsKey(cacheKeyAnoAnterior) &&
              !_cacheSeriesInvalidado.contains(cacheKeyAnoAnterior)) {
            cachedData = _cacheSeriesPorMedico[cacheKeyAnoAnterior]!;
            seriesDoCache =
                (cachedData['series'] as List).cast<SerieRecorrencia>();
            excecoesDoCache =
                (cachedData['excecoes'] as List).cast<ExcecaoSerie>();
            // Filtrar apenas séries infinitas ou que se aplicam ao ano atual
            seriesDoCache = seriesDoCache
                .where(
                    (s) => s.dataFim == null || s.dataFim!.year >= anoParaCache)
                .toList();
            // Mensagem de debug removida para reduzir ruído no terminal
            // debugPrint('  📦 Usando cache do ano anterior para $medicoId: ${seriesDoCache.length} séries aplicáveis');
            usarCache = true;
          }
        }

        if (usarCache && seriesDoCache.isNotEmpty) {
          // OTIMIZAÇÃO: Se há filtro de dia, verificar rapidamente se alguma série se aplica ao dia
          // antes de gerar disponibilidades. Isso evita processamento desnecessário.
          if (dataFiltroDia != null) {
            // Verificar se alguma série se aplica ao dia antes de gerar
            // Usar a mesma lógica dos geradores de séries para verificação precisa
            bool temSerieAplicavel = false;
            final dataFiltroNormalizada = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);

            for (final serie in seriesDoCache) {
              if (!serie.ativo) continue;

              // Verificar se a série está dentro do período
              final serieDataInicioNormalizada = DateTime(serie.dataInicio.year,
                  serie.dataInicio.month, serie.dataInicio.day);

              if (serieDataInicioNormalizada.isAfter(dataFiltroNormalizada)) {
                continue; // Série começa depois do dia
              }
              if (serie.dataFim != null) {
                final serieDataFimNormalizada = DateTime(serie.dataFim!.year,
                    serie.dataFim!.month, serie.dataFim!.day);
                if (serieDataFimNormalizada.isBefore(dataFiltroNormalizada)) {
                  continue; // Série já terminou antes do dia
                }
              }

              // Verificar se a série realmente se aplica ao dia específico
              bool serieSeAplicaAoDia = false;

              switch (serie.tipo) {
                case 'Semanal':
                  // Verificar se é o mesmo dia da semana e a diferença é múltiplo de 7
                  final diasDiferenca = dataFiltroNormalizada
                      .difference(serieDataInicioNormalizada)
                      .inDays;
                  serieSeAplicaAoDia =
                      diasDiferenca >= 0 && diasDiferenca % 7 == 0;
                  break;
                case 'Quinzenal':
                  // Verificar se a diferença é múltiplo de 14
                  final diasDiferenca = dataFiltroNormalizada
                      .difference(serieDataInicioNormalizada)
                      .inDays;
                  serieSeAplicaAoDia =
                      diasDiferenca >= 0 && diasDiferenca % 14 == 0;
                  break;
                case 'Mensal':
                  // Verificar se é o mesmo dia do mês e mesma ocorrência do dia da semana
                  if (dataFiltroNormalizada.weekday ==
                      serie.dataInicio.weekday) {
                    // Calcular ocorrência no mês (1ª, 2ª, 3ª, 4ª, última)
                    final ocorrenciaSerie =
                        _descobrirOcorrenciaNoMes(serie.dataInicio);
                    final ocorrenciaDia =
                        _descobrirOcorrenciaNoMes(dataFiltroNormalizada);
                    serieSeAplicaAoDia = ocorrenciaSerie == ocorrenciaDia;
                  }
                  break;
                case 'Consecutivo':
                  // Verificar se está dentro do período consecutivo
                  final numeroDias =
                      serie.parametros['numeroDias'] as int? ?? 5;
                  final diasDiferenca = dataFiltroNormalizada
                      .difference(serieDataInicioNormalizada)
                      .inDays;
                  serieSeAplicaAoDia =
                      diasDiferenca >= 0 && diasDiferenca < numeroDias;
                  break;
                case 'Única':
                  // Verificar se é a data exata
                  serieSeAplicaAoDia =
                      serieDataInicioNormalizada == dataFiltroNormalizada;
                  break;
                default:
                  // Para tipos desconhecidos, assumir que pode se aplicar
                  serieSeAplicaAoDia = true;
              }

              if (serieSeAplicaAoDia) {
                temSerieAplicavel = true;
                break;
              }
            }

            if (!temSerieAplicavel) {
              // Nenhuma série se aplica ao dia, pular este médico
              continue;
            }
          }

          // Se há filtro de dia, filtrar exceções apenas para esse dia
          List<ExcecaoSerie> excecoesFiltradas = excecoesDoCache;
          if (dataFiltroDia != null) {
            excecoesFiltradas = excecoesFiltradas
                .where((e) =>
                    e.data.year == dataFiltroDia.year &&
                    e.data.month == dataFiltroDia.month &&
                    e.data.day == dataFiltroDia.day)
                .toList();
          }

          // Gerar disponibilidades do cache apenas para o período necessário
          final dispsGeradas = SerieGenerator.gerarDisponibilidades(
            series: seriesDoCache,
            excecoes: excecoesFiltradas,
            dataInicio: dataInicio,
            dataFim: dataFim,
          );

          // CORREÇÃO: Adicionar médico à lista mesmo quando usa cache
          if (dispsGeradas.isNotEmpty) {
            medicosComSeries.add(medicoId);
          }

          // Adicionar ao Map de disponibilidades únicas para evitar duplicatas
          for (final disp in dispsGeradas) {
            final chave =
                '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
            disponibilidadesMap[chave] =
                disp; // Sobrescreve se já existir (evita duplicatas)
          }

          // Se usamos cache do ano anterior, mesclar com o cache do ano atual
          if (!_cacheSeriesPorMedico.containsKey(cacheKey)) {
            _cacheSeriesPorMedico[cacheKey] = {
              'series': seriesDoCache,
              'excecoes': excecoesDoCache,
            };
          }

          continue;
        }

        // OTIMIZAÇÃO: Só carregar séries se realmente necessário
        // Se não há dataFiltroDia e não há anoEspecifico, não precisa carregar
        if (dataFiltroDia == null && anoEspecifico == null) {
          // Se não há filtro específico, não carregar séries (economiza recursos)
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
              // OTIMIZAÇÃO: Para séries infinitas, carregar apenas séries que podem se aplicar ao dia
              // Limitar a busca para séries que começaram até o dia selecionado
              // Isso reduz drasticamente o número de séries carregadas
              dataInicioParaCarregarSeries =
                  null; // Carregar todas as séries ativas (sem limite de início)
              dataFimParaCarregarSeries = dataFiltroDia.add(
                  const Duration(days: 1)); // Séries que começaram até este dia
            } else {
              // Se não há filtro de dia, usar o período completo do ano
              final ano = anoEspecifico != null
                  ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                  : DateTime.now().year;
              dataInicioParaCarregarSeries = DateTime(ano, 1, 1);
              dataFimParaCarregarSeries = DateTime(ano + 1, 1, 1);
            }

            // OTIMIZAÇÃO: Usar Source.serverAndCache para usar cache quando disponível
            // Isso reduz drasticamente leituras desnecessárias do servidor
            final series = await SerieService.carregarSeries(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicioParaCarregarSeries,
              dataFim: dataFimParaCarregarSeries,
            );

            // OTIMIZAÇÃO: Se há filtro de dia e não há séries, pular este médico imediatamente
            // Isso evita carregar exceções desnecessariamente
            if (dataFiltroDia != null && series.isEmpty) {
              return <Disponibilidade>[];
            }

            // Mensagens de debug removidas para reduzir ruído no terminal
            // debugPrint('  📊 Séries carregadas para $medicoId: ${series.length}');
            // for (final serie in series) {
            //   debugPrint('    - Série: ${serie.id} - ${serie.tipo} - Início: ${serie.dataInicio.day}/${serie.dataInicio.month}/${serie.dataInicio.year} - Fim: ${serie.dataFim != null ? "${serie.dataFim!.day}/${serie.dataFim!.month}/${serie.dataFim!.year}" : "infinito"} - Gabinete: ${serie.gabineteId ?? "não alocado"}');
            // }

            if (series.isEmpty) {
              // Guardar no cache vazio para evitar futuras verificações
              _cacheSeriesPorMedico[cacheKey] = {
                'series': <SerieRecorrencia>[],
                'excecoes': <ExcecaoSerie>[],
              };
              return <Disponibilidade>[];
            }

            // IMPORTANTE: Se há filtro de dia, carregar exceções APENAS para esse dia
            // Isso evita carregar exceções de todo o ano quando só precisa de um dia
            // Mensagem de debug removida para reduzir ruído no terminal
            // debugPrint('  🔍 Carregando exceções para $medicoId de ${dataInicioParaCarregarSeries?.day}/${dataInicioParaCarregarSeries?.month}/${dataInicioParaCarregarSeries?.year} até ${dataFimParaCarregarSeries?.day}/${dataFimParaCarregarSeries?.month}/${dataFimParaCarregarSeries?.year}');
            // Se o cache foi invalidado, forçar carregamento do servidor (sem cache)
            // Isso garante que exceções recém-criadas sejam carregadas imediatamente
            final cacheFoiInvalidado =
                _cacheSeriesInvalidado.contains(cacheKey);
            final excecoes = await SerieService.carregarExcecoes(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicioParaCarregarSeries,
              dataFim: dataFimParaCarregarSeries,
              forcarServidor:
                  cacheFoiInvalidado, // Forçar servidor se cache foi invalidado
            );

            // Debug: mostrar exceções carregadas para séries mensais
            final excecoesMensais =
                excecoes.where((e) => e.gabineteId != null).toList();
            if (excecoesMensais.isNotEmpty && dataFiltroDia != null) {
              print(
                  '📋 Exceções carregadas para médico $medicoId: ${excecoes.length} total, ${excecoesMensais.length} com gabinete');
              for (final ex in excecoesMensais) {
                final dataKey =
                    '${ex.data.year}-${ex.data.month.toString().padLeft(2, '0')}-${ex.data.day.toString().padLeft(2, '0')}';
                print(
                    '   📋 Exceção: série=${ex.serieId}, data=$dataKey, gabinete=${ex.gabineteId}');
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

            // Debug: mostrar exceções filtradas
            if (dataFiltroDia != null && excecoesFiltradas.isNotEmpty) {
              print(
                  '📋 Exceções filtradas para data ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}: ${excecoesFiltradas.length}');
              for (final ex in excecoesFiltradas) {
                print(
                    '   📋 Exceção filtrada: série=${ex.serieId}, data=${ex.data.day}/${ex.data.month}/${ex.data.year}, gabinete=${ex.gabineteId}');
              }
            }

            // Mensagens de debug removidas para reduzir ruído no terminal
            // debugPrint('  📊 Exceções carregadas do Firestore para $medicoId: ${excecoes.length} (filtradas: ${excecoesFiltradas.length})');
            // for (final excecao in excecoesFiltradas) {
            //   debugPrint('    - Exceção: ${excecao.serieId} - ${excecao.data.day}/${excecao.data.month}/${excecao.data.year} - Cancelada: ${excecao.cancelada}');
            // }

            // Guardar no cache
            _cacheSeriesPorMedico[cacheKey] = {
              'series': series,
              'excecoes': excecoes,
            };
            // OTIMIZAÇÃO: Remover flag de invalidação após recarregar do servidor
            _cacheSeriesInvalidado.remove(cacheKey);
            // Mensagem de debug removida para reduzir ruído no terminal
            // debugPrint('  💾 Cache atualizado para $medicoId: ${series.length} séries, ${excecoes.length} exceções');

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

            final dispsGeradas = SerieGenerator.gerarDisponibilidades(
              series: series,
              excecoes: excecoesFiltradas,
              dataInicio: dataInicioGeracao,
              dataFim: dataFimGeracao,
            );

            medicosComSeries.add(medicoId);

            // Retornar como Map para evitar duplicatas ao mesclar
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
      final resultados = await Future.wait(futures);

      // Mesclar todos os resultados no Map para evitar duplicatas
      for (final resultado in resultados) {
        for (final disp in resultado) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          disponibilidadesMap[chave] =
              disp; // Sobrescreve se já existir (evita duplicatas)
        }
      }
    } catch (e) {}

    final disponibilidades = disponibilidadesMap.values.toList();

    return disponibilidades;
  }

  /// Carrega todas as alocações de uma unidade (otimizado para ano atual)
  static Future<List<Alocacao>> _carregarAlocacoesUnidade(Unidade? unidade,
      {DateTime? dataFiltroDia}) async {
    final alvo = dataFiltroDia ?? DateTime.now();
    final anoAlvo = alvo.year.toString();
    return _carregarAlocacoesUnidadePorAno(unidade, anoAlvo,
        dataFiltroDia: dataFiltroDia); // Carrega apenas o ano alvo
  }

  /// Carrega alocações de uma unidade por ano específico
  static Future<List<Alocacao>> _carregarAlocacoesUnidadePorAno(
      Unidade? unidade, String? anoEspecifico,
      {DateTime? dataFiltroDia}) async {
    final firestore = FirebaseFirestore.instance;
    final alocacoes = <Alocacao>[];

    try {
      if (unidade != null) {
        // Caminho preferencial: vista diária materializada
        if (dataFiltroDia != null) {
          final dayKey = _keyDia(dataFiltroDia);
          try {
            final daySnap = await firestore
                .collection('unidades')
                .doc(unidade.id)
                .collection('dias')
                .doc(dayKey)
                .collection('alocacoes')
                .get(const GetOptions(source: Source.serverAndCache));
            if (daySnap.docs.isNotEmpty) {
              for (final doc in daySnap.docs) {
                final aloc = Alocacao.fromMap(doc.data());
                alocacoes.add(aloc);
                // #region agent log
                if (aloc.medicoId.contains('1765868847681') ||
                    aloc.medicoId.contains('1765868812290') ||
                    aloc.medicoId.contains('1758898385280')) {
                  // Escrever log diretamente no arquivo
                  try {
                    final logEntry = {
                      'id': 'log_${DateTime.now().millisecondsSinceEpoch}_FIX4',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                      'location': 'alocacao_medicos_logic.dart:2001',
                      'message':
                          'Alocação carregada do Firestore (vista diária)',
                      'data': {
                        'alocacaoId': aloc.id,
                        'medicoId': aloc.medicoId,
                        'gabineteId': aloc.gabineteId,
                        'horarioInicio': aloc.horarioInicio,
                        'horarioFim': aloc.horarioFim,
                        'data':
                            '${aloc.data.year}-${aloc.data.month}-${aloc.data.day}',
                        'dayKey': dayKey,
                      },
                      'sessionId': 'debug-session',
                      'runId': 'run1',
                      'hypothesisId': 'FIX4',
                    };
                    writeLogToFile('${jsonEncode(logEntry)}\n');
                  } catch (e) {
                    // Ignorar erro de log
                  }
                }
                // #endregion
              }
              return alocacoes;
            }
          } catch (e) {
            // Vista diária indisponível, continuar com fallback
          }
        }
        // Carrega alocações da unidade específica por ano
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
          final registosSnapshot = await query.get();

          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            final alocacao = Alocacao.fromMap(data);
            alocacoes.add(alocacao);
            // #region agent log
            if (alocacao.medicoId.contains('1765868847681') ||
                alocacao.medicoId.contains('1765868812290') ||
                alocacao.medicoId.contains('1758898385280')) {
              try {
                final logEntry = {
                  'id': 'log_${DateTime.now().millisecondsSinceEpoch}_FIX4',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'location': 'alocacao_medicos_logic.dart:2032',
                  'message':
                      'Alocação carregada do Firestore (coleção registos)',
                  'data': {
                    'alocacaoId': alocacao.id,
                    'medicoId': alocacao.medicoId,
                    'gabineteId': alocacao.gabineteId,
                    'horarioInicio': alocacao.horarioInicio,
                    'horarioFim': alocacao.horarioFim,
                    'data':
                        '${alocacao.data.year}-${alocacao.data.month}-${alocacao.data.day}',
                    'anoEspecifico': anoEspecifico,
                    'dataFiltroDia': dataFiltroDia != null
                        ? '${dataFiltroDia.year}-${dataFiltroDia.month}-${dataFiltroDia.day}'
                        : null,
                  },
                  'sessionId': 'debug-session',
                  'runId': 'run1',
                  'hypothesisId': 'FIX4',
                };
                writeLogToFile('${jsonEncode(logEntry)}\n');
              } catch (e) {
                // Ignorar erro de log
              }
            }
            // #endregion
          }
        } else {
          // Carrega todos os anos (para relatórios ou histórico)
          final anosSnapshot = await alocacoesRef.get();

          for (final anoDoc in anosSnapshot.docs) {
            final registosRef = anoDoc.reference.collection('registos');
            Query<Map<String, dynamic>> query = registosRef;
            if (dataFiltroDia != null &&
                anoDoc.id == dataFiltroDia.year.toString()) {
              final inicio = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              final fim = inicio.add(const Duration(days: 1));
              query = query
                  .where('data',
                      isGreaterThanOrEqualTo: inicio.toIso8601String())
                  .where('data', isLessThan: fim.toIso8601String());
            }
            final registosSnapshot = await query.get();

            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              final alocacao = Alocacao.fromMap(data);
              alocacoes.add(alocacao);
            }
          }
        }
      } else {
        // Carrega alocações globais (fallback)
        final alocacoesRef = firestore.collection('alocacoes');
        final alocacoesSnapshot = await alocacoesRef.get();

        for (final doc in alocacoesSnapshot.docs) {
          final data = doc.data();
          alocacoes.add(Alocacao.fromMap(data));
        }
      }
    } catch (e) {
      // Em caso de erro, continuar sem alocações do Firestore
    }

    // Gerar alocações dinamicamente a partir de séries
    // Isso garante que quando uma série é alocada, as alocações futuras apareçam corretamente
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
      final firestore = FirebaseFirestore.instance;
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      final alocacoesGeradas = <Alocacao>[];
      final anoParaCache = dataFiltroDia?.year ??
          (anoEspecifico != null
              ? int.tryParse(anoEspecifico) ?? DateTime.now().year
              : DateTime.now().year);

      // OTIMIZAÇÃO: Usar apenas médicos que já têm séries alocadas no cache
      // Isso evita processar médicos que não têm séries alocadas
      // IMPORTANTE: Incluir também médicos com cache invalidado para garantir recarregamento
      final medicosComSeriesAlocadasNoCache = <String>[];
      final medicosComCacheInvalidado = <String>[];
      for (final entry in _cacheSeriesPorMedico.entries) {
        final parts = entry.key.split('_');
        if (parts.length >= 2) {
          final anoCache = int.tryParse(parts[1]);
          if (anoCache == anoParaCache || anoCache == anoParaCache - 1) {
            final medicoId = parts[0];
            final cacheKey = '${medicoId}_$anoParaCache';
            final cacheFoiInvalidado =
                _cacheSeriesInvalidado.contains(cacheKey);

            if (cacheFoiInvalidado) {
              // Se o cache foi invalidado, incluir na lista para recarregar do servidor
              medicosComCacheInvalidado.add(medicoId);
            } else {
              final cachedData = entry.value;
              final series =
                  (cachedData['series'] as List).cast<SerieRecorrencia>();
              // Só incluir se tem séries alocadas (com gabineteId)
              if (series.any((s) =>
                  s.ativo &&
                  s.gabineteId != null &&
                  s.gabineteId!.isNotEmpty)) {
                medicosComSeriesAlocadasNoCache.add(medicoId);
              }
            }
          }
        }
      }

      // IMPORTANTE: Incluir médicos com cache invalidado na lista para processar
      // Isso garante que exceções recém-criadas sejam carregadas do servidor
      final todosMedicosParaProcessar = <String>{
        ...medicosComSeriesAlocadasNoCache,
        ...medicosComCacheInvalidado,
      };

      // Se não encontrou médicos com séries alocadas no cache E não há cache invalidado, não processar nenhum
      if (todosMedicosParaProcessar.isEmpty) {
        return alocacoesGeradas;
      }

      // Processar médicos com séries alocadas no cache E médicos com cache invalidado
      final medicosParaProcessar = todosMedicosParaProcessar.toList();

      for (final medicoId in medicosParaProcessar) {
        final cacheKey = '${medicoId}_$anoParaCache';

        // Verificar se já temos séries e exceções em cache
        // CORREÇÃO: Se o cache foi invalidado, forçar recarregamento do servidor
        final cacheFoiInvalidado = _cacheSeriesInvalidado.contains(cacheKey);

        // Debug: mostrar se o cache foi invalidado
        if (cacheFoiInvalidado && dataFiltroDia != null) {
          print(
              '🔄 Cache invalidado para médico $medicoId, ano $anoParaCache, data ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year} - forçando recarregamento do servidor');
        }

        List<SerieRecorrencia> series;
        List<ExcecaoSerie> excecoes;

        if (_cacheSeriesPorMedico.containsKey(cacheKey) &&
            !cacheFoiInvalidado) {
          final cachedData = _cacheSeriesPorMedico[cacheKey]!;
          series = (cachedData['series'] as List).cast<SerieRecorrencia>();
          excecoes = (cachedData['excecoes'] as List).cast<ExcecaoSerie>();

          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('  📦 Usando cache de séries para $medicoId (ano $anoParaCache): ${series.length} séries');

          // Se há filtro de dia, filtrar exceções apenas para esse dia
          if (dataFiltroDia != null) {
            excecoes = excecoes
                .where((e) =>
                    e.data.year == dataFiltroDia.year &&
                    e.data.month == dataFiltroDia.month &&
                    e.data.day == dataFiltroDia.day)
                .toList();
          }

          // Filtrar séries que se aplicam ao período
          // IMPORTANTE: Para séries infinitas (dataFim == null), incluir se começaram antes ou no período
          // Determinar período para filtrar séries
          DateTime dataInicioFiltro;
          DateTime dataFimFiltro;
          if (dataFiltroDia != null) {
            dataInicioFiltro = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            dataFimFiltro = dataInicioFiltro.add(const Duration(days: 1));
          } else {
            final ano = anoEspecifico != null
                ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                : DateTime.now().year;
            dataInicioFiltro = DateTime(ano, 1, 1);
            dataFimFiltro = DateTime(ano + 1, 1, 1);
          }

          series = series.where((s) {
            // Excluir séries que começam depois do fim do período
            if (s.dataInicio
                .isAfter(dataFimFiltro.subtract(const Duration(days: 1)))) {
              return false;
            }
            // Excluir séries que já terminaram antes do início do período
            // Se dataFim é null, a série é infinita e deve ser incluída
            if (s.dataFim != null && s.dataFim!.isBefore(dataInicioFiltro)) {
              return false;
            }
            return true;
          }).toList();
        } else {
          // IMPORTANTE: Para séries infinitas, precisamos carregar TODAS as séries ativas
          // que começaram antes ou no período, independentemente do dataFim da série.
          DateTime? dataInicioParaCarregarSeries;
          DateTime? dataFimParaCarregarSeries;

          if (dataFiltroDia != null) {
            // Para séries infinitas, carregar todas as séries que começaram antes ou no dia selecionado
            dataInicioParaCarregarSeries =
                null; // Carregar todas as séries ativas (sem limite de início)
            dataFimParaCarregarSeries = dataFiltroDia.add(
                const Duration(days: 1)); // Séries que começaram até este dia
            // Mensagem de debug removida para reduzir ruído no terminal
            // debugPrint('  🔍 Carregando séries para alocações ($medicoId): todas as séries ativas que começaram até ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}');
          } else {
            // Se não há filtro de dia, usar o período completo do ano
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

          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('  📊 Séries carregadas para alocações ($medicoId): ${series.length}');

          if (series.isEmpty) continue;

          // Carregar exceções do médico no período
          // Determinar período para carregar exceções
          DateTime dataInicioExcecoes;
          DateTime dataFimExcecoes;
          if (dataFiltroDia != null) {
            // IMPORTANTE: Carregar exceções do dia específico, mas garantir que o ano seja incluído
            // Quando o cache é invalidado, precisamos carregar exceções do ano correto
            dataInicioExcecoes = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            dataFimExcecoes = dataInicioExcecoes.add(const Duration(days: 1));
            // Debug: mostrar período de carregamento
            if (cacheFoiInvalidado) {
              print(
                  '🔍 Carregando exceções para data específica: ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year} (ano: ${dataFiltroDia.year})');
              print(
                  '   📅 Período: ${dataInicioExcecoes.day}/${dataInicioExcecoes.month}/${dataInicioExcecoes.year} até ${dataFimExcecoes.day}/${dataFimExcecoes.month}/${dataFimExcecoes.year}');
            }
          } else {
            final ano = anoEspecifico != null
                ? int.tryParse(anoEspecifico) ?? DateTime.now().year
                : DateTime.now().year;
            dataInicioExcecoes = DateTime(ano, 1, 1);
            dataFimExcecoes = DateTime(ano + 1, 1, 1);
          }

          // Se o cache foi invalidado, forçar carregamento do servidor (sem cache)
          // Isso garante que exceções recém-criadas sejam carregadas imediatamente
          excecoes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioExcecoes,
            dataFim: dataFimExcecoes,
            forcarServidor:
                cacheFoiInvalidado, // Forçar servidor se cache foi invalidado
          );

          // Debug: mostrar exceções carregadas após invalidar cache
          if (cacheFoiInvalidado && dataFiltroDia != null) {
            final excecoesParaData = excecoes
                .where((e) =>
                    e.data.year == dataFiltroDia.year &&
                    e.data.month == dataFiltroDia.month &&
                    e.data.day == dataFiltroDia.day)
                .toList();
            print(
                '📋 Exceções carregadas para ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}: ${excecoesParaData.length} (total: ${excecoes.length})');
            for (final ex in excecoesParaData) {
              print(
                  '   📋 Exceção encontrada: série=${ex.serieId}, data=${ex.data.day}/${ex.data.month}/${ex.data.year}, gabinete=${ex.gabineteId}');
            }
          }

          // Guardar no cache e remover flag de invalidação
          // IMPORTANTE: Guardar excecoes completas no cache (não filtradas)
          // para uso futuro, mas usar excecoesFiltradas na geração
          _cacheSeriesPorMedico[cacheKey] = {
            'series': series,
            'excecoes': excecoes, // Guardar exceções completas no cache
          };
          _cacheSeriesInvalidado
              .remove(cacheKey); // Remover flag após recarregar
          // CORREÇÃO: Remover também da lista de invalidação de todos os anos
          // (só remove se este era o último ano a ser recarregado)
          // Verificar se ainda há outros anos invalidados para este médico
          final aindaHaAnosInvalidados = _cacheSeriesInvalidado
              .any((key) => key.startsWith('${medicoId}_'));
          if (!aindaHaAnosInvalidados) {
            _cacheSeriesInvalidadoTodosAnos.remove(medicoId);
          }
        }

        // CORREÇÃO: Filtrar apenas séries com gabineteId != null para gerar alocações
        // Séries sem gabineteId não devem gerar alocações (ainda não foram alocadas)
        final seriesComGabinete =
            series.where((s) => s.gabineteId != null).toList();

        for (final s in seriesComGabinete) {}

        // Gerar alocações dinamicamente apenas de séries com gabineteId
        // Determinar período para gerar alocações
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

        // Debug: mostrar exceções que serão passadas para o gerador
        if (cacheFoiInvalidado && dataFiltroDia != null) {
          final excecoesComGabinete =
              excecoes.where((e) => e.gabineteId != null).toList();
          print(
              '🔍 Passando ${excecoes.length} exceções para SerieGenerator (${excecoesComGabinete.length} com gabinete)');
          for (final ex in excecoesComGabinete) {
            print(
                '   📋 Exceção: série=${ex.serieId}, data=${ex.data.day}/${ex.data.month}/${ex.data.year}, gabinete=${ex.gabineteId}');
          }
        }

        final alocsGeradas = SerieGenerator.gerarAlocacoes(
          series: seriesComGabinete,
          excecoes: excecoes,
          dataInicio: dataInicioAlocacoes,
          dataFim: dataFimAlocacoes,
        );

        for (final aloc in alocsGeradas.take(5)) {}

        alocacoesGeradas.addAll(alocsGeradas);
      }

      // Criar mapa de datas com exceções canceladas para filtrar alocações do Firestore
      final datasComExcecoesCanceladas = <String>{};
      if (dataFiltroDia != null && unidade != null) {
        try {
          // Carregar exceções canceladas para filtrar alocações do Firestore
          final medicoIds = _cacheMedicosAtivos[unidade.id] ?? [];
          for (final medicoId in medicoIds) {
            final anoParaCache = dataFiltroDia.year;
            final cacheKey = '${medicoId}_$anoParaCache';

            if (_cacheSeriesPorMedico.containsKey(cacheKey)) {
              final cachedData = _cacheSeriesPorMedico[cacheKey]!;
              final excecoes = cachedData['excecoes'] as List<ExcecaoSerie>;

              for (final excecao in excecoes) {
                if (excecao.cancelada &&
                    excecao.data.year == dataFiltroDia.year &&
                    excecao.data.month == dataFiltroDia.month &&
                    excecao.data.day == dataFiltroDia.day) {
                  final dataKey =
                      '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                  datasComExcecoesCanceladas.add(dataKey);
                }
              }
            }
          }
        } catch (e) {}
      }

      // CORREÇÃO: Simplificar mesclagem de alocações
      // Alocações de séries: geradas dinamicamente (não salvas no Firestore)
      // Alocações "Única": salvas no Firestore (ID não começa com "serie_")

      // CORREÇÃO CRÍTICA: Criar conjunto de chaves de séries para identificar quais remover
      // Isso garante que quando uma exceção muda o gabinete, a alocação antiga é removida
      final chavesSeriesParaRemover = <String>{};
      for (final aloc in alocacoesGeradas) {
        // Criar chave sem gabineteId para identificar todas as alocações da mesma série/data
        final chaveSemGabinete =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        chavesSeriesParaRemover.add(chaveSemGabinete);
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
