// import '../database/database_helper.dart';
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
import '../utils/conflict_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class AlocacaoMedicosLogic {
  // Cache simples em memória por dia (chave yyyy-MM-dd)
  static final Map<String, List<Disponibilidade>> _cacheDispPorDia = {};
  static final Map<String, List<Alocacao>> _cacheAlocPorDia = {};
  // Cache de séries por médico e período (chave: medicoId_ano)
  static final Map<String, Map<String, dynamic>> _cacheSeriesPorMedico = {};
  // Cache de médicos ativos por unidade (chave: unidadeId)
  static final Map<String, List<String>> _cacheMedicosAtivos = {};
  // Cache de exceções canceladas por dia (chave: unidadeId_yyyy-MM-dd)
  static final Map<String, Set<String>> _cacheExcecoesCanceladasPorDia = {};

  static String _keyDia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
  
  /// Limpa o cache de séries de um médico específico
  static void invalidateSeriesCacheForMedico(String medicoId, int? ano) {
    if (ano != null) {
      final cacheKey = '${medicoId}_$ano';
      _cacheSeriesPorMedico.remove(cacheKey);
    } else {
      // Remover todas as entradas deste médico
      _cacheSeriesPorMedico.removeWhere((key, value) => key.startsWith('${medicoId}_'));
    }
  }
  
  /// Extrai datas com exceções canceladas do cache para um dia específico
  /// Retorna um Set com chaves no formato: medicoId_ano-mes-dia
  /// Se o cache não estiver disponível, carrega diretamente do Firestore
  static Future<Set<String>> extrairExcecoesCanceladasParaDia(String unidadeId, DateTime data) async {
    // Verificar cache primeiro (muito mais rápido)
    final cacheKey = '${unidadeId}_${_keyDia(data)}';
    if (_cacheExcecoesCanceladasPorDia.containsKey(cacheKey)) {
      debugPrint('⚡ Exceções canceladas carregadas do cache para ${data.day}/${data.month}/${data.year}');
      return _cacheExcecoesCanceladasPorDia[cacheKey]!;
    }
    
    final datasComExcecoesCanceladas = <String>{};
    try {
      final anoParaCache = data.year;
      debugPrint('🔍 extrairExcecoesCanceladasParaDia: unidade=$unidadeId, data=${data.day}/${data.month}/${data.year}');
      
      final medicoIds = _cacheMedicosAtivos[unidadeId] ?? [];
      debugPrint('  📊 Médicos no cache: ${medicoIds.length}');
      
      // Se não há médicos no cache, tentar carregar do Firestore
      if (medicoIds.isEmpty) {
        debugPrint('  🔄 Cache de médicos vazio, carregando do Firestore...');
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
        debugPrint('  ✅ Médicos carregados do Firestore: ${medicoIds.length}');
      }
      
      for (final medicoId in medicoIds) {
        final cacheKey = '${medicoId}_$anoParaCache';
        debugPrint('  🔍 Verificando médico $medicoId (cacheKey: $cacheKey)');
        
        // Se o cache não tem dados para este médico, OU se o cache existe mas não tem exceções para este dia específico,
        // carregar do Firestore
        final cacheExiste = _cacheSeriesPorMedico.containsKey(cacheKey);
        final cacheTemExcecoes = cacheExiste && 
            (_cacheSeriesPorMedico[cacheKey]!['excecoes'] as List).isNotEmpty;
        
        // Verificar se o cache tem exceções para o dia específico
        bool cacheTemExcecoesParaEsteDia = false;
        if (cacheTemExcecoes) {
          final excecoesCache = _cacheSeriesPorMedico[cacheKey]!['excecoes'] as List<ExcecaoSerie>;
          cacheTemExcecoesParaEsteDia = excecoesCache.any((e) =>
            e.cancelada &&
            e.data.year == data.year &&
            e.data.month == data.month &&
            e.data.day == data.day
          );
        }
        
        if (!cacheExiste || !cacheTemExcecoes || !cacheTemExcecoesParaEsteDia) {
          if (!cacheExiste) {
            debugPrint('  🔄 Cache não encontrado para $medicoId, carregando exceções do Firestore...');
          } else if (!cacheTemExcecoes) {
            debugPrint('  🔄 Cache existe mas não tem exceções para $medicoId, recarregando do Firestore...');
          } else {
            debugPrint('  🔄 Cache existe mas não tem exceções para ${data.day}/${data.month}/${data.year}, recarregando do Firestore...');
          }
          
          try {
            // Carregar apenas exceções para o dia específico
            final dataInicio = DateTime(data.year, data.month, data.day);
            final dataFim = dataInicio.add(const Duration(days: 1));
            
            // Buscar unidade do Firestore para passar como parâmetro
            final firestore = FirebaseFirestore.instance;
            final unidadeDoc = await firestore.collection('unidades').doc(unidadeId).get();
            Unidade? unidadeObj;
            if (unidadeDoc.exists) {
              final unidadeData = unidadeDoc.data()!;
              // Tratar dataCriacao que pode vir como Timestamp ou string
              DateTime? dataCriacao;
              final dataCriacaoValue = unidadeData['dataCriacao'];
              if (dataCriacaoValue != null) {
                if (dataCriacaoValue is Timestamp) {
                  dataCriacao = dataCriacaoValue.toDate();
                } else if (dataCriacaoValue is String) {
                  try {
                    dataCriacao = DateTime.parse(dataCriacaoValue);
                  } catch (e) {
                    dataCriacao = DateTime.now();
                  }
                } else {
                  dataCriacao = DateTime.now();
                }
              } else {
                dataCriacao = DateTime.now();
              }
              
              unidadeObj = Unidade(
                id: unidadeId,
                nome: unidadeData['nome'] ?? '',
                tipo: unidadeData['tipo'] ?? '',
                ativa: unidadeData['ativa'] ?? true,
                endereco: unidadeData['endereco'] ?? '',
                dataCriacao: dataCriacao,
                nomeOcupantes: unidadeData['nomeOcupantes'] ?? '',
                nomeAlocacao: unidadeData['nomeAlocacao'] ?? '',
              );
            } else {
              // Criar unidade mínima se não existir
              unidadeObj = Unidade(
                id: unidadeId,
                nome: '',
                tipo: '',
                ativa: true,
                endereco: '',
                dataCriacao: DateTime.now(),
                nomeOcupantes: '',
                nomeAlocacao: '',
              );
            }
            
            final excecoes = await SerieService.carregarExcecoes(
              medicoId,
              unidade: unidadeObj,
              dataInicio: dataInicio,
              dataFim: dataFim,
            );
            
            debugPrint('  📊 Exceções carregadas do Firestore para $medicoId: ${excecoes.length}');
            
            // Atualizar ou criar cache
            if (cacheExiste) {
              // Se o cache já existe, mesclar exceções (não sobrescrever)
              final cachedData = _cacheSeriesPorMedico[cacheKey]!;
              final excecoesExistentes = (cachedData['excecoes'] as List<ExcecaoSerie>).toList();
              final todasExcecoes = <ExcecaoSerie>[...excecoesExistentes];
              
              // Adicionar novas exceções que não existem
              for (final novaExcecao in excecoes) {
                if (!todasExcecoes.any((e) => e.id == novaExcecao.id)) {
                  todasExcecoes.add(novaExcecao);
                }
              }
              
              _cacheSeriesPorMedico[cacheKey] = {
                'series': cachedData['series'],
                'excecoes': todasExcecoes,
              };
              debugPrint('  💾 Cache mesclado para $medicoId: ${todasExcecoes.length} exceções');
            } else {
              // Criar novo cache
              _cacheSeriesPorMedico[cacheKey] = {
                'series': <SerieRecorrencia>[],
                'excecoes': excecoes,
              };
              debugPrint('  💾 Cache criado para $medicoId: ${excecoes.length} exceções');
            }
            
            // Processar exceções carregadas
            for (final excecao in excecoes) {
              debugPrint('    - Exceção: ${excecao.serieId} - ${excecao.data.day}/${excecao.data.month}/${excecao.data.year} - Cancelada: ${excecao.cancelada}');
              if (excecao.cancelada && 
                  excecao.data.year == data.year &&
                  excecao.data.month == data.month &&
                  excecao.data.day == data.day) {
                final dataKey = '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                datasComExcecoesCanceladas.add(dataKey);
                debugPrint('    🚫 Exceção cancelada encontrada no Firestore: $medicoId, data ${data.day}/${data.month}/${data.year}');
              }
            }
          } catch (e) {
            debugPrint('    ❌ Erro ao carregar exceções do Firestore para $medicoId: $e');
          }
        } else {
          // Usar dados do cache
          final cachedData = _cacheSeriesPorMedico[cacheKey]!;
          final excecoes = cachedData['excecoes'] as List<ExcecaoSerie>;
          debugPrint('  📊 Exceções no cache para $medicoId: ${excecoes.length}');
          
          for (final excecao in excecoes) {
            debugPrint('    - Exceção no cache: ${excecao.serieId} - ${excecao.data.day}/${excecao.data.month}/${excecao.data.year} - Cancelada: ${excecao.cancelada}');
            if (excecao.cancelada && 
                excecao.data.year == data.year &&
                excecao.data.month == data.month &&
                excecao.data.day == data.day) {
              final dataKey = '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
              datasComExcecoesCanceladas.add(dataKey);
              debugPrint('    🚫 Exceção cancelada encontrada no cache: $medicoId, data ${data.day}/${data.month}/${data.year}');
            }
          }
        }
      }
      
      debugPrint('  ✅ Total de exceções canceladas encontradas: ${datasComExcecoesCanceladas.length}');
      
      // Guardar no cache para evitar queries futuras
      _cacheExcecoesCanceladasPorDia[cacheKey] = datasComExcecoesCanceladas;
    } catch (e) {
      debugPrint('❌ Erro ao extrair exceções canceladas: $e');
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
  }) async {
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
        debugPrint('⚡ Disponibilidades carregadas do cache para $keyDia');
        
        // IMPORTANTE: Filtrar disponibilidades do cache baseado em exceções canceladas
        // Isso garante que mesmo quando os dados vêm do cache, as exceções sejam respeitadas
        if (unidade != null && dataFiltroDia != null) {
          try {
            final datasComExcecoesCanceladas = await extrairExcecoesCanceladasParaDia(
              unidade.id,
              dataFiltroDia,
            );
            
            if (datasComExcecoesCanceladas.isNotEmpty) {
              final dispsAntes = disps.length;
              disps = disps.where((disp) {
                final dataKey = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
                if (datasComExcecoesCanceladas.contains(dataKey)) {
                  debugPrint('🚫 Filtrando disponibilidade do cache com exceção: ${disp.id} - ${disp.data.day}/${disp.data.month}/${disp.data.year}');
                  return false;
                }
                return true;
              }).toList();
              
              if (disps.length < dispsAntes) {
                debugPrint('  🗑️ Removidas ${dispsAntes - disps.length} disponibilidades do cache devido a exceções');
              }
            }
          } catch (e) {
            debugPrint('❌ Erro ao filtrar disponibilidades do cache por exceções: $e');
          }
        }
      }
      if (!precisaAlocs) {
        alocs = _cacheAlocPorDia[keyDia] ?? const [];
        debugPrint('⚡ Alocações carregadas do cache para $keyDia');
        
        // IMPORTANTE: Filtrar alocações do cache baseado em exceções canceladas
        if (unidade != null && dataFiltroDia != null) {
          try {
            final datasComExcecoesCanceladas = await extrairExcecoesCanceladasParaDia(
              unidade.id,
              dataFiltroDia,
            );
            
            if (datasComExcecoesCanceladas.isNotEmpty) {
              final alocsAntes = alocs.length;
              alocs = alocs.where((aloc) {
                final dataKey = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
                if (datasComExcecoesCanceladas.contains(dataKey)) {
                  debugPrint('🚫 Filtrando alocação do cache com exceção: ${aloc.id} - ${aloc.data.day}/${aloc.data.month}/${aloc.data.year}');
                  return false;
                }
                return true;
              }).toList();
              
              if (alocs.length < alocsAntes) {
                debugPrint('  🗑️ Removidas ${alocsAntes - alocs.length} alocações do cache devido a exceções');
              }
            }
          } catch (e) {
            debugPrint('❌ Erro ao filtrar alocações do cache por exceções: $e');
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
        
        debugPrint('⚡ Dados carregados do Firestore (não havia cache)');
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
        debugPrint('⚡ Todos os dados carregados do cache para $keyDia (mudança instantânea)');
      }

      if (keyDia != null) {
        _cacheDispPorDia[keyDia] = List.from(disps);
        _cacheAlocPorDia[keyDia] = List.from(alocs);
      }

      // Atualizar as listas
      onGabinetes(List<Gabinete>.from(gabs));
      onMedicos(List<Medico>.from(meds));
      onDisponibilidades(List<Disponibilidade>.from(disps));
      onAlocacoes(List<Alocacao>.from(alocs));
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');
      // Em caso de erro, inicializar com listas vazias
      onGabinetes(<Gabinete>[]);
      onMedicos(<Medico>[]);
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
    List<String>? horariosForcados, // Novo parâmetro opcional para forçar horários
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final indexAloc = alocacoes.indexWhere((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && alocDate == dataAlvo;
    });
    if (indexAloc != -1) {
      final alocacaoAnterior = alocacoes[indexAloc];
      alocacoes.removeAt(indexAloc);

      // Remover alocação anterior do Firebase
      try {
        final firestore = FirebaseFirestore.instance;
        final ano = alocacaoAnterior.data.year.toString();
        final unidadeId = unidade?.id ??
            'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
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
        print('❌ Erro ao remover alocação anterior do Firebase: $e');
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
      horarioFim =
          dispDoDia.isNotEmpty ? dispDoDia.first.horarios[1] : '00:00';
    }

    // Gerar ID único baseado em timestamp + microsegundos + data + médico + gabinete
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dataStr = '${dataAlvo.year}${dataAlvo.month.toString().padLeft(2, '0')}${dataAlvo.day.toString().padLeft(2, '0')}';
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
    
    // Chamar onAlocacoesChanged() que recarrega tudo do Firebase
    // Mas como já adicionamos localmente, o cartão aparece imediatamente
    onAlocacoesChanged();
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
    if (indexAloc == -1) return;

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

    onAlocacoesChanged();

    // Atualiza cache para o dia afetado
    final diaKey = _keyDia(dataAlvo);
    final alocDoDiaAtualizadas = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return aDate == dataAlvo;
    }).toList();
    _cacheAlocPorDia[diaKey] = alocDoDiaAtualizadas;
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
    debugPrint('🗑️ Desalocando série do médico $medicoId');
    debugPrint('  📅 Data de referência: ${dataRef.day}/${dataRef.month}/${dataRef.year}');
    debugPrint('  📋 Tipo: $tipo');
    
    // BUSCAR TODAS AS ALOCAÇÕES DO MÉDICO DO FIREBASE
    // Buscar do ano atual e do próximo ano (caso a série cruze anos)
    final anoAtual = dataRef.year;
    final anoProximo = anoAtual + 1;
    
    debugPrint('  🔍 Buscando alocações do ano $anoAtual...');
    final alocacoesAnoAtual = await buscarAlocacoesMedico(
      unidade,
      medicoId,
      anoEspecifico: anoAtual,
    );
    
    debugPrint('  🔍 Buscando alocações do ano $anoProximo...');
    final alocacoesAnoProximo = await buscarAlocacoesMedico(
      unidade,
      medicoId,
      anoEspecifico: anoProximo,
    );
    
    final todasAlocacoesMedico = [...alocacoesAnoAtual, ...alocacoesAnoProximo];
    
    debugPrint('  📊 Total de alocações do médico no Firebase: ${todasAlocacoesMedico.length} (${alocacoesAnoAtual.length} do ano $anoAtual + ${alocacoesAnoProximo.length} do ano $anoProximo)');
    
    // Normalizar o tipo para comparação
    final tipoNormalizado = tipo.startsWith('Consecutivo') ? 'Consecutivo' : tipo;
    final dataRefNormalizada = DateTime(dataRef.year, dataRef.month, dataRef.day);
    
    debugPrint('  🔍 Filtrando alocações da série...');
    debugPrint('    Tipo normalizado: $tipoNormalizado');
    debugPrint('    Data referência normalizada: ${dataRefNormalizada.day}/${dataRefNormalizada.month}/${dataRefNormalizada.year}');
    
    // Filtrar todas as alocações que fazem parte da série (a partir da data de referência)
    final alocacoesDaSerie = todasAlocacoesMedico.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
      
      // Verificar se a alocação é do mesmo médico e está na mesma data ou depois da data de referência
      if (a.medicoId != medicoId) return false;
      if (aDateNormalizada.isBefore(dataRefNormalizada)) {
        debugPrint('    ❌ ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Antes da data de referência');
        return false;
      }
      
      // Verificar se a data corresponde ao padrão da série
      bool correspondeAoPadrao = false;
      final diasDiferenca = aDateNormalizada.difference(dataRefNormalizada).inDays;
      
      if (tipoNormalizado == 'Semanal') {
        // Verificar se a diferença em dias é múltiplo de 7
        correspondeAoPadrao = diasDiferenca % 7 == 0;
        debugPrint('    📅 ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Diferença: $diasDiferenca dias - Múltiplo de 7: ${diasDiferenca % 7 == 0} - ${correspondeAoPadrao ? "✅ MATCH" : "❌"}');
      } else if (tipoNormalizado == 'Quinzenal') {
        // Verificar se a diferença em dias é múltiplo de 14
        correspondeAoPadrao = diasDiferenca % 14 == 0;
        debugPrint('    📅 ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Diferença: $diasDiferenca dias - Múltiplo de 14: ${diasDiferenca % 14 == 0} - ${correspondeAoPadrao ? "✅ MATCH" : "❌"}');
      } else if (tipoNormalizado == 'Mensal') {
        // Verificar se é o mesmo dia do mês
        correspondeAoPadrao = aDateNormalizada.day == dataRefNormalizada.day;
        debugPrint('    📅 ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Mesmo dia do mês: ${aDateNormalizada.day == dataRefNormalizada.day} - ${correspondeAoPadrao ? "✅ MATCH" : "❌"}');
      } else if (tipoNormalizado == 'Consecutivo') {
        // Para consecutivo, verificar se está dentro do intervalo
        final match = RegExp(r'Consecutivo:(\d+)').firstMatch(tipo);
        final dias = match != null ? int.tryParse(match.group(1) ?? '') ?? 1 : 1;
        correspondeAoPadrao = diasDiferenca >= 0 && diasDiferenca < dias;
        debugPrint('    📅 ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Diferença: $diasDiferenca dias - Dentro do intervalo (0-$dias): $correspondeAoPadrao - ${correspondeAoPadrao ? "✅ MATCH" : "❌"}');
      } else {
        // Para tipo "Única" ou desconhecido, apenas remover a data exata
        correspondeAoPadrao = aDateNormalizada == dataRefNormalizada;
        debugPrint('    📅 ${aDateNormalizada.day}/${aDateNormalizada.month}/${aDateNormalizada.year} - Data exata: $correspondeAoPadrao - ${correspondeAoPadrao ? "✅ MATCH" : "❌"}');
      }
      
      return correspondeAoPadrao;
    }).toList();
    
    debugPrint('  📋 Alocações da série encontradas: ${alocacoesDaSerie.length}');
    for (final a in alocacoesDaSerie) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year} (ID: ${a.id})');
    }
    
    // Remover todas as alocações da série
    for (final alocacao in alocacoesDaSerie) {
      final dataAlvo = DateTime(alocacao.data.year, alocacao.data.month, alocacao.data.day);
      
      // Remover da lista local
      final indexAloc = alocacoes.indexWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate == dataAlvo;
      });
      
      if (indexAloc != -1) {
        alocacoes.removeAt(indexAloc);
      }

      // Remover do Firebase
      try {
        final firestore = FirebaseFirestore.instance;
        final ano = alocacao.data.year.toString();
        final unidadeId = unidade?.id ??
            'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('alocacoes')
            .doc(ano)
            .collection('registos');

        await alocacoesRef.doc(alocacao.id).delete();
        debugPrint('✅ Alocação removida do Firebase: ${alocacao.id} (${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}, ano: $ano, unidade: $unidadeId)');
      } catch (e) {
        debugPrint('❌ Erro ao remover alocação do Firebase: $e');
      }
      
      // Adicionar médico de volta à lista de disponíveis se houver disponibilidade
      final temDisp = disponibilidades.any((disp2) {
        final dd = DateTime(disp2.data.year, disp2.data.month, disp2.data.day);
        return disp2.medicoId == medicoId && dd == dataAlvo;
      });
      if (temDisp) {
        final medico = medicos.firstWhere(
          (m) => m.id == medicoId,
          orElse: () => Medico(
            id: medicoId,
            nome: 'Médico não identificado',
            especialidade: '',
            disponibilidades: [],
          ),
        );
        if (!medicosDisponiveis.contains(medico)) {
          medicosDisponiveis.add(medico);
        }
      }
    }
    
    debugPrint('✅ Série desalocada: ${alocacoesDaSerie.length} alocações removidas');

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
    final firestore = FirebaseFirestore.instance;
    final disponibilidades = <Disponibilidade>[];
    
    // Carregar séries e gerar cartões dinamicamente PRIMEIRO
    // Isso garante que as exceções sejam aplicadas corretamente
    final disponibilidadesDeSeries = await carregarDisponibilidadesDeSeries(
      unidade: unidade,
      anoEspecifico: anoEspecifico,
      dataFiltroDia: dataFiltroDia,
    );
    
    // Extrair exceções canceladas do cache de séries (já carregado em carregarDisponibilidadesDeSeries)
    // Criar um mapa de datas com exceções canceladas: chave = (medicoId, data)
    final datasComExcecoesCanceladas = <String>{};
    if (unidade != null && dataFiltroDia != null) {
      try {
        // Reutilizar as exceções já carregadas no cache de séries (populado em carregarDisponibilidadesDeSeries)
        // Isso evita carregar exceções novamente do Firestore
        final anoParaCache = dataFiltroDia.year;
        
        // Iterar sobre o cache de séries para extrair exceções canceladas
        // Usar a lista de médicos do cache para garantir que temos os IDs corretos
        final medicoIds = _cacheMedicosAtivos[unidade.id] ?? [];
        for (final medicoId in medicoIds) {
          final cacheKey = '${medicoId}_$anoParaCache';
          if (_cacheSeriesPorMedico.containsKey(cacheKey)) {
            final cachedData = _cacheSeriesPorMedico[cacheKey]!;
            final excecoes = cachedData['excecoes'] as List<ExcecaoSerie>;
            
            // Adicionar datas com exceções canceladas do cache
            for (final excecao in excecoes) {
              if (excecao.cancelada && 
                  excecao.data.year == dataFiltroDia.year &&
                  excecao.data.month == dataFiltroDia.month &&
                  excecao.data.day == dataFiltroDia.day) {
                final dataKey = '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                datasComExcecoesCanceladas.add(dataKey);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Erro ao extrair exceções do cache: $e');
      }
    }
    
    // Usar um Map para evitar duplicatas: chave = (medicoId, data, tipo)
    final disponibilidadesMap = <String, Disponibilidade>{};
    
    // Primeiro, adicionar disponibilidades geradas de séries (com exceções aplicadas)
    for (final disp in disponibilidadesDeSeries) {
      final chave = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
      disponibilidadesMap[chave] = disp;
    }

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
                .collection('disponibilidades')
                .get(const GetOptions(source: Source.serverAndCache));
            if (daySnap.docs.isNotEmpty) {
              for (final doc in daySnap.docs) {
                final disp = Disponibilidade.fromMap(doc.data());
                // Só adicionar se não for gerada de série (para evitar duplicatas)
                if (!disp.id.startsWith('serie_')) {
                  // Verificar se esta data tem uma exceção cancelada
                  final dataKey = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
                  if (datasComExcecoesCanceladas.contains(dataKey)) {
                    debugPrint('🚫 Filtrando disponibilidade individual do Firestore com exceção: ${disp.id} - ${disp.data.day}/${disp.data.month}/${disp.data.year}');
                    continue; // Não adicionar se há exceção cancelada
                  }
                  
                  final chave = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  // Só adicionar se não houver já uma disponibilidade gerada de série para esta data/tipo
                  if (!disponibilidadesMap.containsKey(chave)) {
                    disponibilidadesMap[chave] = disp;
                  }
                }
              }
              // Adicionar disponibilidades do Map (geradas de séries têm prioridade)
              disponibilidades.addAll(disponibilidadesMap.values);
              return disponibilidades;
            }
          } catch (e) {
            // Vista diária indisponível, continuar com fallback
          }
        }

        // Caminho rápido: se houver filtro de dia, tentar usar collectionGroup numa única query
        if (dataFiltroDia != null) {
          try {
            final inicio = DateTime(
                dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
            final fim = inicio.add(const Duration(days: 1));

            // Buscar IDs dos médicos pertencentes à unidade (para filtrar resultados)
            final ocupantesSnapshot = await firestore
                .collection('unidades')
                .doc(unidade.id)
                .collection('ocupantes')
                .get();
            final medicoIdsDaUnidade =
                ocupantesSnapshot.docs.map((d) => d.id).toSet();

            // Uma query global que encontra todos os registos daquele dia, em qualquer árvore .../registos
            final cgQuery = firestore
                .collectionGroup('registos')
                .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
                .where('data', isLessThan: fim.toIso8601String());
            final cgSnapshot = await cgQuery
                .get(const GetOptions(source: Source.serverAndCache));

            for (final doc in cgSnapshot.docs) {
              final data = doc.data();
              final medicoId = data['medicoId']?.toString();
              if (medicoId != null && medicoIdsDaUnidade.contains(medicoId)) {
                final disp = Disponibilidade.fromMap(data);
                // Só adicionar se não for gerada de série (para evitar duplicatas)
                if (!disp.id.startsWith('serie_')) {
                  // Verificar se esta data tem uma exceção cancelada
                  final dataKey = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}';
                  if (datasComExcecoesCanceladas.contains(dataKey)) {
                    debugPrint('🚫 Filtrando disponibilidade individual do Firestore com exceção: ${disp.id} - ${disp.data.day}/${disp.data.month}/${disp.data.year}');
                    continue; // Não adicionar se há exceção cancelada
                  }
                  
                  final chave = '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
                  // Só adicionar se não houver já uma disponibilidade gerada de série para esta data/tipo
                  if (!disponibilidadesMap.containsKey(chave)) {
                    disponibilidadesMap[chave] = disp;
                  }
                }
              }
            }

            disponibilidades.addAll(disponibilidadesMap.values);
            return disponibilidades;
          } catch (e) {
            // Se collectionGroup não estiver disponível/sem índice, continuar com o fallback por médico
          }
        }

        // Carrega disponibilidades da unidade específica por ano
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('ocupantes');

        // IMPORTANTE: Quando há filtro de dia, usar médicos do cache (já carregados)
        // Isso evita carregar todos os médicos novamente
        final medicosIdsParaProcessar = dataFiltroDia != null && _cacheMedicosAtivos.containsKey(unidade.id)
            ? _cacheMedicosAtivos[unidade.id]!
            : null;
        
        final medicosSnapshot = medicosIdsParaProcessar == null
            ? await medicosRef.get()
            : null;

        // Processar médicos (do cache ou da query)
        final medicosIds = medicosIdsParaProcessar ?? 
            (medicosSnapshot?.docs.map((doc) => doc.id).toList() ?? []);

        for (final medicoId in medicosIds) {
          final medicoRef = medicosRef.doc(medicoId);
          final disponibilidadesRef = medicoRef.collection('disponibilidades');

          if (anoEspecifico != null) {
            // Carrega apenas o ano específico (mais eficiente)
            final registosRef =
                disponibilidadesRef.doc(anoEspecifico).collection('registos');
            Query<Map<String, dynamic>> query = registosRef;

            // Otimização: se dataFiltroDia informado, carregar só esse dia
            if (dataFiltroDia != null) {
              final inicio = DateTime(
                  dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
              final fim = inicio.add(const Duration(days: 1));
              query = query
                  .where('data',
                      isGreaterThanOrEqualTo: inicio.toIso8601String())
                  .where('data', isLessThan: fim.toIso8601String());
            }

            final registosSnapshot = await query
                .get(const GetOptions(source: Source.serverAndCache));

              for (final dispDoc in registosSnapshot.docs) {
                final data = dispDoc.data();
                final disponibilidade = Disponibilidade.fromMap(data);
                // Só adicionar se não for gerada de série (para evitar duplicatas)
                if (!disponibilidade.id.startsWith('serie_')) {
                  // Verificar se esta data tem uma exceção cancelada
                  final dataKey = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}';
                  if (datasComExcecoesCanceladas.contains(dataKey)) {
                    debugPrint('🚫 Filtrando disponibilidade individual do Firestore com exceção: ${disponibilidade.id} - ${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}');
                    continue; // Não adicionar se há exceção cancelada
                  }
                  
                  final chave = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}_${disponibilidade.tipo}';
                  // Só adicionar se não houver já uma disponibilidade gerada de série para esta data/tipo
                  if (!disponibilidadesMap.containsKey(chave)) {
                    disponibilidadesMap[chave] = disponibilidade;
                  }
                }
              }
          } else {
            // Carrega todos os anos (para relatórios ou histórico)
            final anosSnapshot = await disponibilidadesRef.get();

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
              final registosSnapshot = await query
                  .get(const GetOptions(source: Source.serverAndCache));

              for (final dispDoc in registosSnapshot.docs) {
                final data = dispDoc.data();
                final disponibilidade = Disponibilidade.fromMap(data);
                // Só adicionar se não for gerada de série (para evitar duplicatas)
                if (!disponibilidade.id.startsWith('serie_')) {
                  // Verificar se esta data tem uma exceção cancelada
                  final dataKey = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}';
                  if (datasComExcecoesCanceladas.contains(dataKey)) {
                    debugPrint('🚫 Filtrando disponibilidade individual do Firestore com exceção: ${disponibilidade.id} - ${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}');
                    continue; // Não adicionar se há exceção cancelada
                  }
                  
                  final chave = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}_${disponibilidade.tipo}';
                  // Só adicionar se não houver já uma disponibilidade gerada de série para esta data/tipo
                  if (!disponibilidadesMap.containsKey(chave)) {
                    disponibilidadesMap[chave] = disponibilidade;
                  }
                }
              }
            }
          }
        }
      } else {
        // Carrega disponibilidades globais (fallback)
        final medicosRef = firestore.collection('medicos');
        final medicosSnapshot = await medicosRef.get();

        for (final medicoDoc in medicosSnapshot.docs) {
          final disponibilidadesRef =
              medicoDoc.reference.collection('disponibilidades');
          final dispSnapshot = await disponibilidadesRef.get();

          for (final dispDoc in dispSnapshot.docs) {
            final data = dispDoc.data();
            final disponibilidade = Disponibilidade.fromMap(data);
            // Só adicionar se não for gerada de série (para evitar duplicatas)
            if (!disponibilidade.id.startsWith('serie_')) {
              // Verificar se esta data tem uma exceção cancelada
              final dataKey = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}';
              if (datasComExcecoesCanceladas.contains(dataKey)) {
                debugPrint('🚫 Filtrando disponibilidade individual do Firestore com exceção: ${disponibilidade.id} - ${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}');
                continue; // Não adicionar se há exceção cancelada
              }
              
              final chave = '${disponibilidade.medicoId}_${disponibilidade.data.year}-${disponibilidade.data.month}-${disponibilidade.data.day}_${disponibilidade.tipo}';
              // Só adicionar se não houver já uma disponibilidade gerada de série para esta data/tipo
              if (!disponibilidadesMap.containsKey(chave)) {
                disponibilidadesMap[chave] = disponibilidade;
              }
            }
          }
        }

      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar disponibilidades: $e');
    }

    // Se já retornamos antes (quando havia filtro de dia e encontramos dados), não chegamos aqui
    // Se chegamos aqui, todas as disponibilidades (do Firestore e geradas de séries) já estão no disponibilidadesMap
    // As disponibilidades geradas de séries têm prioridade porque foram adicionadas primeiro ao Map
    
    // Retornar diretamente do Map (que já contém tudo mesclado corretamente)
    disponibilidades.clear();
    disponibilidades.addAll(disponibilidadesMap.values);

    return disponibilidades;
  }

  /// Carrega séries de recorrência e gera disponibilidades dinamicamente
  static Future<List<Disponibilidade>> carregarDisponibilidadesDeSeries({
    required Unidade? unidade,
    String? anoEspecifico,
    DateTime? dataFiltroDia,
  }) async {
    if (unidade == null) return [];

    final disponibilidades = <Disponibilidade>[];
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Determinar período para gerar cartões
      DateTime dataInicio;
      DateTime dataFim;
      final anoParaCache = dataFiltroDia?.year ?? (anoEspecifico != null ? int.tryParse(anoEspecifico) ?? DateTime.now().year : DateTime.now().year);
      
      if (dataFiltroDia != null) {
        // Se há filtro de dia, gerar apenas para esse dia
        dataInicio = DateTime(dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
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

      // Carregar médicos da unidade (apenas ativos) - usar cache se disponível
      List<String> medicoIds;
      if (_cacheMedicosAtivos.containsKey(unidade.id)) {
        medicoIds = _cacheMedicosAtivos[unidade.id]!;
        // Não fazer log aqui para evitar spam - apenas quando carrega do Firestore
      } else {
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('ocupantes');
        final medicosSnapshot = await medicosRef
            .where('ativo', isEqualTo: true)
            .get(const GetOptions(source: Source.serverAndCache));
        medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
        _cacheMedicosAtivos[unidade.id] = medicoIds;
        debugPrint('📊 Médicos carregados do Firestore para unidade ${unidade.id}: ${medicoIds.length} médicos');
      }
      
      // Se não há médicos, retornar vazio imediatamente (evita processamento desnecessário)
      if (medicoIds.isEmpty) {
        return disponibilidades;
      }

      // Se há filtro de dia, carregar apenas séries que se aplicam a esse dia
      // Caso contrário, carregar todas as séries ativas do ano
      final medicosComSeries = <String>[];
      
      // Carregar séries em paralelo para médicos ativos
      final futures = <Future<List<Disponibilidade>>>[];
      
      for (final medicoId in medicoIds) {
        final cacheKey = '${medicoId}_$anoParaCache';
        
        // Verificar se já temos séries em cache para este médico e ano
        // IMPORTANTE: Para séries infinitas, também verificar cache do ano anterior,
        // pois séries que começaram no ano anterior podem se aplicar ao ano atual
        bool usarCache = _cacheSeriesPorMedico.containsKey(cacheKey);
        Map<String, dynamic>? cachedData;
        List<SerieRecorrencia> seriesDoCache = [];
        List<ExcecaoSerie> excecoesDoCache = [];
        
        if (usarCache) {
          cachedData = _cacheSeriesPorMedico[cacheKey]!;
          seriesDoCache = (cachedData['series'] as List).cast<SerieRecorrencia>();
          excecoesDoCache = (cachedData['excecoes'] as List).cast<ExcecaoSerie>();
          debugPrint('  📦 Cache encontrado para $medicoId (ano $anoParaCache): ${seriesDoCache.length} séries, ${excecoesDoCache.length} exceções');
        } else if (dataFiltroDia != null && anoParaCache > dataFiltroDia.year - 1) {
          // Tentar usar cache do ano anterior se disponível (para séries infinitas)
          final cacheKeyAnoAnterior = '${medicoId}_${anoParaCache - 1}';
          if (_cacheSeriesPorMedico.containsKey(cacheKeyAnoAnterior)) {
            cachedData = _cacheSeriesPorMedico[cacheKeyAnoAnterior]!;
            seriesDoCache = (cachedData['series'] as List).cast<SerieRecorrencia>();
            excecoesDoCache = (cachedData['excecoes'] as List).cast<ExcecaoSerie>();
            // Filtrar apenas séries infinitas ou que se aplicam ao ano atual
            seriesDoCache = seriesDoCache.where((s) => 
              s.dataFim == null || s.dataFim!.year >= anoParaCache
            ).toList();
            debugPrint('  📦 Usando cache do ano anterior para $medicoId: ${seriesDoCache.length} séries aplicáveis');
            usarCache = true;
          }
        }
        
        if (usarCache && seriesDoCache.isNotEmpty) {
          // Se há filtro de dia, filtrar exceções apenas para esse dia
          List<ExcecaoSerie> excecoesFiltradas = excecoesDoCache;
          if (dataFiltroDia != null) {
            excecoesFiltradas = excecoesFiltradas.where((e) =>
              e.data.year == dataFiltroDia.year &&
              e.data.month == dataFiltroDia.month &&
              e.data.day == dataFiltroDia.day
            ).toList();
            debugPrint('  🔍 Exceções filtradas para ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}: ${excecoesFiltradas.length}');
          }
          
          // Gerar disponibilidades do cache apenas para o período necessário
          final dispsGeradas = SerieGenerator.gerarDisponibilidades(
            series: seriesDoCache,
            excecoes: excecoesFiltradas,
            dataInicio: dataInicio,
            dataFim: dataFim,
          );
          disponibilidades.addAll(dispsGeradas);
          
          // Se usamos cache do ano anterior, mesclar com o cache do ano atual
          if (!_cacheSeriesPorMedico.containsKey(cacheKey)) {
            _cacheSeriesPorMedico[cacheKey] = {
              'series': seriesDoCache,
              'excecoes': excecoesDoCache,
            };
            debugPrint('  💾 Cache do ano anterior mesclado para o ano atual ($anoParaCache)');
          }
          
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
              // Para séries infinitas, carregar todas as séries que começaram antes ou no dia selecionado
              // Passar null para dataInicio para carregar todas as séries ativas
              // Passar dataFiltroDia + 1 dia como dataFim para incluir séries que começaram até esse dia
              dataInicioParaCarregarSeries = null; // Carregar todas as séries ativas (sem limite de início)
              dataFimParaCarregarSeries = dataFiltroDia.add(const Duration(days: 1)); // Séries que começaram até este dia
              debugPrint('  🔍 Carregando séries para $medicoId: todas as séries ativas que começaram até ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}');
            } else {
              dataInicioParaCarregarSeries = dataInicio;
              dataFimParaCarregarSeries = dataFim;
            }
            
            // Carregar séries do médico diretamente (sem query extra de verificação)
            // O filtro por período já é feito em SerieService.carregarSeries
            final series = await SerieService.carregarSeries(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicioParaCarregarSeries,
              dataFim: dataFimParaCarregarSeries,
            );
            
            debugPrint('  📊 Séries carregadas para $medicoId: ${series.length}');
            for (final serie in series) {
              debugPrint('    - Série: ${serie.id} - ${serie.tipo} - Início: ${serie.dataInicio.day}/${serie.dataInicio.month}/${serie.dataInicio.year} - Fim: ${serie.dataFim != null ? "${serie.dataFim!.day}/${serie.dataFim!.month}/${serie.dataFim!.year}" : "infinito"} - Gabinete: ${serie.gabineteId ?? "não alocado"}');
            }

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
            debugPrint('  🔍 Carregando exceções para $medicoId de ${dataInicio.day}/${dataInicio.month}/${dataInicio.year} até ${dataFim.day}/${dataFim.month}/${dataFim.year}');
            final excecoes = await SerieService.carregarExcecoes(
              medicoId,
              unidade: unidade,
              dataInicio: dataInicio,
              dataFim: dataFim,
            );
            
            debugPrint('  📊 Exceções carregadas do Firestore para $medicoId: ${excecoes.length}');
            for (final excecao in excecoes) {
              debugPrint('    - Exceção: ${excecao.serieId} - ${excecao.data.day}/${excecao.data.month}/${excecao.data.year} - Cancelada: ${excecao.cancelada}');
            }

            // Guardar no cache
            _cacheSeriesPorMedico[cacheKey] = {
              'series': series,
              'excecoes': excecoes,
            };
            debugPrint('  💾 Cache atualizado para $medicoId: ${series.length} séries, ${excecoes.length} exceções');

            // Gerar disponibilidades dinamicamente
            final dispsGeradas = SerieGenerator.gerarDisponibilidades(
              series: series,
              excecoes: excecoes,
              dataInicio: dataInicio,
              dataFim: dataFim,
            );

            medicosComSeries.add(medicoId);
            return dispsGeradas;
          } catch (e) {
            debugPrint('❌ Erro ao carregar séries do médico $medicoId: $e');
            return <Disponibilidade>[];
          }
        })());
      }
      
      // Aguardar todas as cargas em paralelo e coletar resultados
      final resultados = await Future.wait(futures);
      for (final resultado in resultados) {
        disponibilidades.addAll(resultado);
      }

      if (medicosComSeries.isNotEmpty || disponibilidades.isNotEmpty) {
        debugPrint('✅ Disponibilidades geradas de séries: ${disponibilidades.length} (de ${medicosComSeries.length} médicos com séries)');
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar disponibilidades de séries: $e');
    }

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
                alocacoes.add(Alocacao.fromMap(doc.data()));
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
      debugPrint('❌ Erro ao carregar alocações: $e');
    }

    // Gerar alocações dinamicamente a partir de séries
    // Isso garante que quando uma série é alocada, as alocações futuras apareçam corretamente
    try {
      // Determinar período para gerar alocações
      DateTime dataInicio;
      DateTime dataFim;
      
      if (dataFiltroDia != null) {
        // Se há filtro de dia, gerar apenas para esse dia
        dataInicio = DateTime(dataFiltroDia.year, dataFiltroDia.month, dataFiltroDia.day);
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
      
      // Usar médicos do cache se disponível
      final medicoIds = _cacheMedicosAtivos.containsKey(unidadeId)
          ? _cacheMedicosAtivos[unidadeId]!
          : null;
      
      final medicosSnapshot = medicoIds == null
          ? await firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('ocupantes')
              .where('ativo', isEqualTo: true)
              .get(const GetOptions(source: Source.serverAndCache))
          : null;

      final alocacoesGeradas = <Alocacao>[];
      final anoParaCache = dataFiltroDia?.year ?? (anoEspecifico != null ? int.tryParse(anoEspecifico) ?? DateTime.now().year : DateTime.now().year);
      
      // Processar médicos (do cache ou da query)
      final medicosParaProcessar = medicoIds ?? 
          (medicosSnapshot?.docs.map((doc) => doc.id).toList() ?? []);
      
      for (final medicoId in medicosParaProcessar) {
        final cacheKey = '${medicoId}_$anoParaCache';
        
        // Verificar se já temos séries e exceções em cache
        List<SerieRecorrencia> series;
        List<ExcecaoSerie> excecoes;
        
        if (_cacheSeriesPorMedico.containsKey(cacheKey)) {
          final cachedData = _cacheSeriesPorMedico[cacheKey]!;
          series = (cachedData['series'] as List).cast<SerieRecorrencia>();
          excecoes = (cachedData['excecoes'] as List).cast<ExcecaoSerie>();
          
          // Se há filtro de dia, filtrar exceções apenas para esse dia
          if (dataFiltroDia != null) {
            excecoes = excecoes.where((e) =>
              e.data.year == dataFiltroDia.year &&
              e.data.month == dataFiltroDia.month &&
              e.data.day == dataFiltroDia.day
            ).toList();
          }
          
          // Filtrar séries que se aplicam ao período
          // IMPORTANTE: Para séries infinitas (dataFim == null), incluir se começaram antes ou no período
          series = series.where((s) {
            // Excluir séries que começam depois do fim do período
            if (s.dataInicio.isAfter(dataFim.subtract(const Duration(days: 1)))) return false;
            // Excluir séries que já terminaram antes do início do período
            // Se dataFim é null, a série é infinita e deve ser incluída
            if (s.dataFim != null && s.dataFim!.isBefore(dataInicio)) return false;
            return true;
          }).toList();
        } else {
          // IMPORTANTE: Para séries infinitas, precisamos carregar TODAS as séries ativas
          // que começaram antes ou no período, independentemente do dataFim da série.
          DateTime? dataInicioParaCarregarSeries;
          DateTime? dataFimParaCarregarSeries;
          
          if (dataFiltroDia != null) {
            // Para séries infinitas, carregar todas as séries que começaram antes ou no dia selecionado
            dataInicioParaCarregarSeries = null; // Carregar todas as séries ativas (sem limite de início)
            dataFimParaCarregarSeries = dataFiltroDia.add(const Duration(days: 1)); // Séries que começaram até este dia
            debugPrint('  🔍 Carregando séries para alocações ($medicoId): todas as séries ativas que começaram até ${dataFiltroDia.day}/${dataFiltroDia.month}/${dataFiltroDia.year}');
          } else {
            dataInicioParaCarregarSeries = dataInicio;
            dataFimParaCarregarSeries = dataFim;
          }
          
          // Carregar séries do médico
          series = await SerieService.carregarSeries(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioParaCarregarSeries,
            dataFim: dataFimParaCarregarSeries,
          );
          
          debugPrint('  📊 Séries carregadas para alocações ($medicoId): ${series.length}');

          if (series.isEmpty) continue;

          // Carregar exceções do médico no período
          excecoes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicio,
            dataFim: dataFim,
          );
          
          // Guardar no cache
          _cacheSeriesPorMedico[cacheKey] = {
            'series': series,
            'excecoes': excecoes,
          };
        }

        // Gerar alocações dinamicamente
        final alocsGeradas = SerieGenerator.gerarAlocacoes(
          series: series,
          excecoes: excecoes,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

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
                  final dataKey = '${medicoId}_${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                  datasComExcecoesCanceladas.add(dataKey);
                  debugPrint('🚫 Exceção cancelada encontrada para filtrar alocações: médico $medicoId, data ${excecao.data.day}/${excecao.data.month}/${excecao.data.year}');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Erro ao extrair exceções para filtrar alocações: $e');
        }
      }
      
      // Mesclar alocações do Firestore com alocações geradas de séries
      // Alocações do Firestore têm prioridade (podem ser alocações manuais ou salvas explicitamente)
      // MAS: Filtrar alocações do Firestore que correspondem a datas com exceções canceladas
      final alocacoesMap = <String, Alocacao>{};
      
      // Primeiro, adicionar alocações geradas de séries (já respeitam exceções)
      for (final aloc in alocacoesGeradas) {
        final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        alocacoesMap[chave] = aloc;
      }
      
      // Depois, sobrescrever com alocações do Firestore (que têm prioridade)
      // MAS: Filtrar alocações do Firestore que correspondem a datas com exceções canceladas
      for (final aloc in alocacoes) {
        // Verificar se esta alocação corresponde a uma data com exceção cancelada
        final dataKey = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        if (datasComExcecoesCanceladas.contains(dataKey)) {
          debugPrint('🚫 Filtrando alocação do Firestore com exceção cancelada: ${aloc.id} - médico ${aloc.medicoId}, data ${aloc.data.day}/${aloc.data.month}/${aloc.data.year}');
          continue; // Não adicionar se há exceção cancelada
        }
        
        final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        // Alocações do Firestore sempre têm prioridade (podem ser manuais ou salvas explicitamente)
        alocacoesMap[chave] = aloc;
      }
      
      alocacoes.clear();
      alocacoes.addAll(alocacoesMap.values);
      
      debugPrint('✅ Alocações carregadas: ${alocacoes.length} (${alocacoesGeradas.length} geradas de séries)');
    } catch (e) {
      debugPrint('❌ Erro ao gerar alocações de séries: $e');
      // Em caso de erro, retornar apenas as alocações do Firestore
    }

    return alocacoes;
  }


  /// Busca todas as alocações de um médico específico do Firebase
  static Future<List<Alocacao>> buscarAlocacoesMedico(
    Unidade? unidade,
    String medicoId,
    {int? anoEspecifico}
  ) async {
    final todasAlocacoes = await _carregarAlocacoesUnidadePorAno(
      unidade,
      anoEspecifico?.toString(),
    );
    return todasAlocacoes.where((a) => a.medicoId == medicoId).toList();
  }
}
