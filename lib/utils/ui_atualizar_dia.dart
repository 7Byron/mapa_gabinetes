import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/unidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import 'alocacao_medicos_logic.dart' as logic;
import '../services/alocacao_clinica_config_service.dart';
import '../services/cache_version_service.dart';
import 'alocacao_cache_store.dart';

// Cache para dados de encerramento (feriados, dias de encerramento, horários)
// Esses dados mudam raramente, então podemos cacheá-los por unidade e ano
/// Função pública para invalidar o cache de encerramento
/// Deve ser chamada quando o administrador salva alterações em feriados, dias de encerramento ou horários
Future<void> invalidateCacheEncerramento([String? unidadeId, int? ano]) async {
  if (unidadeId == null || unidadeId.isEmpty) return;
  AlocacaoClinicaConfigService.invalidateCache(unidadeId, ano);
  await CacheVersionService.bumpVersion(
    unidadeId: unidadeId,
    field: CacheVersionService.fieldClinicaConfig,
  );
}

/// Função reutilizável para atualizar os dados do dia
/// Esta função carrega os dados do dia de forma otimizada, sem usar listeners do Firebase
///
/// Parâmetros:
/// - [unidade]: A unidade para carregar os dados
/// - [data]: A data do dia a ser carregado
/// - [gabinetes]: Lista de gabinetes (será atualizada se recarregarMedicos for true)
/// - [medicos]: Lista de médicos (será atualizada se recarregarMedicos for true)
/// - [disponibilidades]: Lista de disponibilidades (será atualizada)
/// - [alocacoes]: Lista de alocações (será atualizada)
/// - [medicosDisponiveis]: Lista de médicos disponíveis (será atualizada)
/// - [recarregarMedicos]: Se true, recarrega gabinetes e médicos do servidor
/// - [calcularMedicosDisponiveis]: Se false, adia cálculo para outra fase
/// - [onProgress]: Callback opcional para atualizar o progresso (progresso de 0.0 a 1.0, mensagem)
/// - [onStateUpdate]: Callback opcional para atualizar o estado (chamado quando necessário)
///
/// Retorna:
/// - Map com informações sobre o carregamento:
///   - 'success': bool - se o carregamento foi bem-sucedido
///   - 'clinicaFechada': bool - se a clínica está encerrada
///   - 'mensagemClinicaFechada': String - mensagem se a clínica estiver fechada
///   - 'feriados': `List<Map<String, String>>` - lista de feriados
///   - 'diasEncerramento': `List<Map<String, dynamic>>` - lista de dias de encerramento
///   - 'horariosClinica': `Map<int, List<String>>` - horários da clínica
///   - 'encerraFeriados': bool - se encerra em feriados
///   - 'nuncaEncerra': bool - se nunca encerra
///   - 'encerraDias': `Map<int, bool>` - dias da semana que encerra
Future<Map<String, dynamic>> atualizarDadosDoDia({
  required Unidade unidade,
  required DateTime data,
  required List<Gabinete> gabinetes,
  required List<Medico> medicos,
  required List<Disponibilidade> disponibilidades,
  required List<Alocacao> alocacoes,
  required List<Medico> medicosDisponiveis,
  bool recarregarMedicos = false,
  bool calcularMedicosDisponiveis = true,
  Function(double progresso, String mensagem)? onProgress,
  Function()? onStateUpdate,
}) async {
  final inicioTotal = DateTime.now();
  try {
    // FASE 0: Carregar dados de encerramento (feriados, dias de encerramento, horários)
    // OTIMIZAÇÃO: Usar timeout curto (2 segundos) e começar a carregar outros dados em paralelo
    onProgress?.call(0.0, 'A verificar configurações...');
    final inicioEncerramento = DateTime.now();

    // OTIMIZAÇÃO: Carregar dados de encerramento com timeout curto (2 segundos)
    // Se demorar mais que isso, assumir clínica aberta e continuar carregamento
    final encerramentoFuture = Future.wait([
      _carregarFeriados(unidade, data: data),
      _carregarDiasEncerramento(unidade, data: data),
      _carregarHorariosEConfiguracoes(unidade),
    ]).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint(
            '⚠️ [TIMEOUT] Timeout ao carregar dados de encerramento - assumindo clínica aberta');
        return [
          <Map<String, String>>[],
          <Map<String, dynamic>>[],
          {
            'horarios': <int, List<String>>{},
            'encerraFeriados': false,
            'nuncaEncerra':
                true, // Se timeout, assumir que nunca encerra para evitar bloqueios
            'encerraDias': {
              1: false,
              2: false,
              3: false,
              4: false,
              5: false,
              6: false,
              7: false,
            },
            '_timeout': true, // Flag para indicar que houve timeout
          },
        ];
      },
    );

    // OTIMIZAÇÃO: Começar a carregar exceções canceladas em paralelo enquanto esperamos dados de encerramento
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final excecoesFuture =
        logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      unidade.id,
      data,
    );

    // Aguardar dados de encerramento (com timeout curto)
    final encerramentoResults = await encerramentoFuture;
    final tempoEncerramento =
        DateTime.now().difference(inicioEncerramento).inMilliseconds;
    debugPrint(
        '⏱️ [PERF] Tempo para carregar dados de encerramento: ${tempoEncerramento}ms');

    final feriados = encerramentoResults[0] as List<Map<String, String>>;
    final diasEncerramento =
        encerramentoResults[1] as List<Map<String, dynamic>>;
    final horariosData = encerramentoResults[2] as Map<String, dynamic>;

    // CORREÇÃO CRÍTICA: Verificar se houve timeout ou erro
    // Se houve timeout, assumir que a clínica está aberta (nuncaEncerra = true)
    final teveTimeout = horariosData['_timeout'] == true;
    if (teveTimeout) {
      debugPrint(
          '⚠️ [TIMEOUT] Dados de encerramento não carregados a tempo - assumindo clínica aberta');
      // Continuar com o fluxo normal, mas com nuncaEncerra = true
    }

    final horariosClinica = horariosData['horarios'] as Map<int, List<String>>;
    final encerraFeriados = horariosData['encerraFeriados'] as bool;
    final nuncaEncerra = horariosData['nuncaEncerra'] as bool;
    final encerraDias = horariosData['encerraDias'] as Map<int, bool>;

    // CORREÇÃO CRÍTICA: Verificar se a clínica está encerrada ANTES de carregar os dados
    // Se estiver fechada, retornar imediatamente sem carregar mais nada
    bool clinicaFechada = false;
    String mensagemClinicaFechada = '';

    // Só verificar se nuncaEncerra foi definido E não houve timeout
    // Se houve timeout, nuncaEncerra já será true, então não precisamos verificar
    if (horariosData.containsKey('nuncaEncerra') && !teveTimeout) {
      try {
        // Converter encerraDias para Map normal antes de passar para evitar problemas de serialização
        final encerraDiasNormal = Map<int, bool>.from(encerraDias);

        final clinicaFechadaData = _verificarClinicaFechada(
          data,
          feriados,
          diasEncerramento,
          horariosClinica,
          encerraFeriados,
          nuncaEncerra,
          encerraDiasNormal,
        );

        clinicaFechada = clinicaFechadaData['fechada'] as bool;
        mensagemClinicaFechada = clinicaFechadaData['mensagem'] as String;
      } catch (e, stackTrace) {
        // Se houver erro na verificação, assumir que a clínica está aberta e continuar
        debugPrint('⚠️ Erro ao verificar clínica fechada: $e');
        debugPrint('Stack trace: $stackTrace');
        clinicaFechada = false;
        mensagemClinicaFechada = '';
      }
    } else if (teveTimeout) {
      // Se houve timeout, assumir que a clínica está aberta
      debugPrint(
          '⚠️ [TIMEOUT] Assumindo clínica aberta devido a timeout no carregamento');
      clinicaFechada = false;
      mensagemClinicaFechada = '';
    } else {
      // Se os dados não foram carregados corretamente, assumir que a clínica está aberta
      debugPrint(
          '⚠️ Dados de encerramento não carregados corretamente - assumindo clínica aberta');
      clinicaFechada = false;
      mensagemClinicaFechada = '';
    }

    // CORREÇÃO CRÍTICA: Se a clínica estiver fechada, limpar dados e retornar IMEDIATAMENTE sem carregar mais dados
    if (clinicaFechada) {
      // Limpar dados existentes quando a clínica está fechada
      disponibilidades.clear();
      alocacoes.clear();
      medicosDisponiveis.clear();

      debugPrint(
          '🚫 Clínica fechada - limpando dados e retornando: $mensagemClinicaFechada');

      // Converter encerraDias para Map normal para evitar problemas de serialização
      final encerraDiasNormal = Map<int, bool>.from(encerraDias);

      return {
        'success': true,
        'error': null,
        'clinicaFechada': true,
        'mensagemClinicaFechada': mensagemClinicaFechada,
        'feriados': feriados,
        'diasEncerramento': diasEncerramento,
        'horariosClinica': horariosClinica,
        'encerraFeriados': encerraFeriados,
        'nuncaEncerra': nuncaEncerra,
        'encerraDias': encerraDiasNormal,
      };
    }

    // NOTA: A verificação de clínica fechada já foi feita acima e retornou imediatamente se estiver fechada
    // Se chegou aqui, a clínica está aberta e podemos continuar com o carregamento

    // FASE 1: Aguardar exceções canceladas (já iniciadas em paralelo acima)
    onProgress?.call(0.05, 'A verificar configurações...');

    // Invalidar cache se necessário (pode ser feito em paralelo)
    if (recarregarMedicos) {
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(data.year, 1, 1));
    }

    onProgress?.call(0.1, 'A verificar exceções...');
    final inicioExcecoes = DateTime.now();
    final datasComExcecoesCanceladas = await excecoesFuture;
    final tempoExcecoes =
        DateTime.now().difference(inicioExcecoes).inMilliseconds;
    // CORREÇÃO: Reduzir logs - apenas mostrar se demorar muito (> 500ms)
    if (tempoExcecoes > 500) {
      debugPrint('⏱️ [PERF] Exceções: ${tempoExcecoes}ms');
    }

    final cacheDisp = AlocacaoCacheStore.getDisponibilidades(dataNormalizada);
    final cacheAloc = AlocacaoCacheStore.getAlocacoes(dataNormalizada);
    final podeUsarCache = !recarregarMedicos &&
        cacheDisp != null &&
        cacheAloc != null &&
        gabinetes.isNotEmpty &&
        medicos.isNotEmpty;

    if (podeUsarCache) {
      onProgress?.call(0.60, 'A usar cache do dia...');
      disponibilidades
        ..clear()
        ..addAll(cacheDisp);
      alocacoes
        ..clear()
        ..addAll(cacheAloc);
    } else {
      // FASE 2: Carregar dados essenciais (gabinetes, médicos, disponibilidades e alocações)
      onProgress?.call(0.15, 'A carregar dados...');
      final inicioDados = DateTime.now();

      // Timer para atualizar progresso continuamente durante carregamento (15% -> 70%)
      Timer? timerProgressoContinuo;
      double progressoAtual = 0.15;
      bool carregamentoCompleto =
          false; // Flag para controlar quando o carregamento termina

      const limiteProgresso = 0.85;
      timerProgressoContinuo =
          Timer.periodic(const Duration(milliseconds: 80), (timer) {
        // CORREÇÃO: Cancelar timer imediatamente se carregamento completo ou progresso atingido
        if (carregamentoCompleto || progressoAtual >= limiteProgresso) {
          timer.cancel();
          timerProgressoContinuo = null;
          return;
        }
        progressoAtual =
            progressoAtual + (limiteProgresso - progressoAtual) * 0.03;
        progressoAtual = progressoAtual.clamp(0.15, limiteProgresso);
        onProgress?.call(progressoAtual, 'A carregar dados...');
      });

      try {
        // Carregar dados usando a lógica existente
        await logic.AlocacaoMedicosLogic.carregarDadosIniciais(
          gabinetes: gabinetes,
          medicos: medicos,
          disponibilidades: disponibilidades,
          alocacoes: alocacoes,
          onGabinetes: (g) {
            if (!recarregarMedicos && g.isEmpty && gabinetes.isNotEmpty) {
              return;
            }
            gabinetes.clear();
            gabinetes.addAll(g);
          },
          onMedicos: (m) {
            if (!recarregarMedicos && m.isEmpty && medicos.isNotEmpty) {
              return;
            }
            medicos.clear();
            medicos.addAll(m);
          },
          onDisponibilidades: (d) {
            disponibilidades.clear();
            disponibilidades.addAll(d);
          },
          onAlocacoes: (a) {
            // Preservar alocações otimistas durante recarregamento
            final alocacoesMap = <String, Alocacao>{};

            // Primeiro, adicionar alocações do servidor
            for (final aloc in a) {
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
              alocacoesMap[chave] = aloc;
            }

            // Verificar se a alocação é do dia selecionado antes de preservar
            final dataNormalized = DateTime(data.year, data.month, data.day);

            // Preservar alocações otimistas do dia selecionado
            for (final aloc in alocacoes) {
              final alocDateNormalized = DateTime(
                aloc.data.year,
                aloc.data.month,
                aloc.data.day,
              );
              if (alocDateNormalized != dataNormalized) {
                continue;
              }

              if (aloc.id.startsWith('otimista_')) {
                final chave =
                    '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';

                if (!alocacoesMap.containsKey(chave)) {
                  alocacoesMap[chave] = aloc;
                }
              } else if (aloc.id.startsWith('serie_')) {
                final chave =
                    '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
                if (!alocacoesMap.containsKey(chave)) {
                  alocacoesMap[chave] = aloc;
                }
              }
            }

            alocacoes.clear();
            alocacoes.addAll(alocacoesMap.values);
          },
          unidade: unidade,
          dataFiltroDia: data,
          reloadStatic: recarregarMedicos,
          excecoesCanceladas: datasComExcecoesCanceladas,
        );

        // CORREÇÃO: Marcar carregamento como completo e cancelar timer imediatamente
        carregamentoCompleto = true;
        timerProgressoContinuo?.cancel();
        timerProgressoContinuo = null;

        final tempoDados =
            DateTime.now().difference(inicioDados).inMilliseconds;
        // Reduzir logs desnecessários - apenas mostrar se demorar muito
        if (tempoDados > 1000) {
          debugPrint('⏱️ [PERF] Dados Firestore: ${tempoDados}ms');
        }
      } finally {
        // CORREÇÃO CRÍTICA: Garantir que timer seja sempre cancelado, mesmo em caso de erro
        carregamentoCompleto = true;
        timerProgressoContinuo?.cancel();
        timerProgressoContinuo = null;
      }
    }

    if (calcularMedicosDisponiveis) {
      // Garantir que o progresso esteja em 70% após carregar dados
      onProgress?.call(0.75, 'A processar médicos disponíveis...');

      // FASE 3: Calcular médicos disponíveis
      // Isso garante que os médicos disponíveis sejam sempre calculados após carregar os dados
      // dataNormalizada já foi definida acima

      // Identificar médicos alocados no dia
      final medicosAlocados = alocacoes
          .where((a) {
            final aDate = DateTime(a.data.year, a.data.month, a.data.day);
            return aDate == dataNormalizada;
          })
          .map((a) => a.medicoId)
          .toSet();

      // Criar Set de médicos com disponibilidade para o dia
      final medicosComDisponibilidade = <String>{};
      for (final d in disponibilidades) {
        final dDate = DateTime(d.data.year, d.data.month, d.data.day);
        if (dDate == dataNormalizada) {
          // Verificar se esta disponibilidade não tem exceção cancelada
          final dataKey =
              '${d.medicoId}_${d.data.year}-${d.data.month}-${d.data.day}';
          if (!datasComExcecoesCanceladas.contains(dataKey)) {
            medicosComDisponibilidade.add(d.medicoId);
          }
        }
      }

      // Calcular médicos disponíveis
      medicosDisponiveis.clear();
      medicosDisponiveis.addAll(medicos.where((m) {
        // Filtrar: Não mostrar médicos inativos
        if (!m.ativo) {
          return false;
        }

        // Verifica se não está alocado
        if (medicosAlocados.contains(m.id)) {
          return false;
        }

        // Verifica se tem exceção cancelada para esse dia
        final dataKey = '${m.id}_${data.year}-${data.month}-${data.day}';
        if (datasComExcecoesCanceladas.contains(dataKey)) {
          return false; // Não mostrar se tem exceção cancelada
        }

        // Verificar se o médico está no Set de médicos com disponibilidade
        return medicosComDisponibilidade.contains(m.id);
      }).toList());
    }

    final tempoTotal = DateTime.now().difference(inicioTotal).inMilliseconds;
    // CORREÇÃO: Reduzir logs - apenas mostrar se demorar muito (> 2000ms)
    if (tempoTotal > 2000) {
      debugPrint('⏱️ [PERF] Total: ${tempoTotal}ms');
    }

    onProgress?.call(0.85, 'A preparar alocações de séries...');

    // Converter encerraDias para Map normal para evitar problemas de serialização
    final encerraDiasNormal = Map<int, bool>.from(encerraDias);

    return {
      'success': true,
      'error': null,
      'clinicaFechada': false,
      'mensagemClinicaFechada': '',
      'feriados': feriados,
      'diasEncerramento': diasEncerramento,
      'horariosClinica': horariosClinica,
      'encerraFeriados': encerraFeriados,
      'nuncaEncerra': nuncaEncerra,
      'encerraDias': encerraDiasNormal,
    };
  } catch (e, stackTrace) {
    debugPrint('❌ Erro ao atualizar dados do dia: $e');
    debugPrint('Stack trace: $stackTrace');

    return {
      'success': false,
      'error': e.toString(),
      'clinicaFechada': false,
      'mensagemClinicaFechada': '',
      'feriados': <Map<String, String>>[],
      'diasEncerramento': <Map<String, dynamic>>[],
      'horariosClinica': <int, List<String>>{},
      'encerraFeriados': false,
      'nuncaEncerra': false,
      'encerraDias': <int, bool>{},
    };
  }
}

/// Carrega feriados da unidade
/// CORREÇÃO: Usar o mesmo caminho que alocacao_medicos_screen.dart
/// Caminho correto: unidades/{id}/feriados/{ano}/registos
/// OTIMIZAÇÃO: Usa cache para evitar buscar do Firestore toda vez
Future<List<Map<String, String>>> _carregarFeriados(Unidade unidade,
    {required DateTime data}) async {
  try {
    return await AlocacaoClinicaConfigService.carregarFeriados(
      unidadeId: unidade.id,
      anoSelecionado: data.year,
    );
  } catch (e) {
    debugPrint('❌ Erro ao carregar feriados: $e');
    return [];
  }
}

/// Carrega dias de encerramento da unidade
/// CORREÇÃO: Usar o mesmo caminho que alocacao_medicos_screen.dart
/// Caminho correto: unidades/{id}/encerramentos/{ano}/registos
/// OTIMIZAÇÃO: Usa cache para evitar buscar do Firestore toda vez
Future<List<Map<String, dynamic>>> _carregarDiasEncerramento(Unidade unidade,
    {required DateTime data}) async {
  try {
    return await AlocacaoClinicaConfigService.carregarDiasEncerramento(
      unidadeId: unidade.id,
      anoSelecionado: data.year,
    );
  } catch (e) {
    debugPrint('❌ Erro ao carregar dias de encerramento: $e');
    return [];
  }
}

/// Carrega horários e configurações de encerramento da unidade
/// CORREÇÃO: Usar o mesmo caminho que alocacao_medicos_screen.dart
/// Caminho correto: unidades/{id}/horarios_clinica (coleção) com documento 'config'
/// OTIMIZAÇÃO: Usa cache para evitar buscar do Firestore toda vez (mudam raramente)
Future<Map<String, dynamic>> _carregarHorariosEConfiguracoes(
    Unidade unidade) async {
  try {
    final config =
        await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
      unidadeId: unidade.id,
    );
    return {
      'horarios': config.horariosClinica,
      'encerraFeriados': config.encerraFeriados,
      'nuncaEncerra': config.nuncaEncerra,
      'encerraDias': config.encerraDias,
    };
  } catch (e) {
    debugPrint('❌ Erro ao carregar horários: $e');
    return {
      'horarios': <int, List<String>>{},
      'encerraFeriados': false,
      'nuncaEncerra': false,
      'encerraDias': {
        1: false,
        2: false,
        3: false,
        4: false,
        5: false,
        6: false,
        7: false,
      },
    };
  }
}

/// Verifica se a clínica está fechada para uma data específica
Map<String, dynamic> _verificarClinicaFechada(
  DateTime data,
  List<Map<String, String>> feriados,
  List<Map<String, dynamic>> diasEncerramento,
  Map<int, List<String>> horariosClinica,
  bool encerraFeriados,
  bool nuncaEncerra,
  Map<int, bool> encerraDias,
) {
  if (nuncaEncerra) {
    return {'fechada': false, 'mensagem': ''};
  }

  // PRIMEIRO: Verificar se há um dia específico de encerramento configurado
  // CORREÇÃO: Usar o mesmo formato de data que alocacao_medicos_screen.dart (yyyy-MM-dd)
  final dataFormatada = DateFormat('yyyy-MM-dd').format(data);

  for (final d in diasEncerramento) {
    final dataDia = d['data']?.toString() ?? '';
    if (dataDia.isEmpty) continue;
    try {
      // Extrair apenas a parte da data (yyyy-MM-dd) se for um timestamp ISO
      String dataDiaNormalizada = dataDia;
      if (dataDia.contains('T')) {
        dataDiaNormalizada = dataDia.split('T')[0];
      }

      // Comparar apenas a parte da data (yyyy-MM-dd)
      if (dataDiaNormalizada == dataFormatada) {
        return {
          'fechada': true,
          'mensagem': d['descricao'] as String? ??
              'A clínica está encerrada neste dia.',
        };
      }
    } catch (e) {
      // Fallback: tentar comparar diretamente
      if (dataDia.contains(dataFormatada) ||
          dataFormatada.contains(dataDia.split('T')[0])) {
        return {
          'fechada': true,
          'mensagem': d['descricao'] as String? ??
              'A clínica está encerrada neste dia.',
        };
      }
    }
  }

  // SEGUNDO: Verificar se o dia específico da semana está configurado para encerrar
  final diaSemana = data.weekday;

  if (encerraDias[diaSemana] == true) {
    final diasSemana = [
      '',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    return {
      'fechada': true,
      'mensagem': '${diasSemana[diaSemana]}s',
    };
  }

  // TERCEIRO: Verificar se é feriado e se está configurado para encerrar em feriados
  // CORREÇÃO: Verificar tanto na lista de feriados quanto em diasEncerramento com motivo "Feriado"
  // CORREÇÃO: Usar o mesmo formato de data que alocacao_medicos_screen.dart (yyyy-MM-dd)

  // Primeiro, verificar na lista de feriados
  Map<String, dynamic>? feriadoEncontrado;

  final feriado = feriados.firstWhere(
    (f) {
      final dataFeriado = f['data']?.toString() ?? '';
      if (dataFeriado.isEmpty) return false;
      try {
        final dataFeriadoParsed = DateTime.parse(dataFeriado);
        final dataFormatadaParsed = DateTime.parse(dataFormatada);
        return dataFeriadoParsed.year == dataFormatadaParsed.year &&
            dataFeriadoParsed.month == dataFormatadaParsed.month &&
            dataFeriadoParsed.day == dataFormatadaParsed.day;
      } catch (e) {
        return dataFeriado == dataFormatada;
      }
    },
    orElse: () => <String, String>{},
  );

  if (feriado.containsKey('id') && feriado['id']!.isNotEmpty) {
    feriadoEncontrado = {
      'id': feriado['id'],
      'data': feriado['data'],
      'descricao': feriado['descricao'] ?? 'Feriado',
    };
  } else {
    // Se não encontrou na lista de feriados, verificar em diasEncerramento com motivo "Feriado"
    final feriadoEncerramento = diasEncerramento.firstWhere(
      (d) {
        final motivo = d['motivo']?.toString() ?? '';
        if (motivo != 'Feriado') return false;
        final dataDia = d['data']?.toString() ?? '';
        if (dataDia.isEmpty) return false;
        try {
          // Extrair apenas a parte da data (yyyy-MM-dd) se for um timestamp ISO
          String dataDiaNormalizada = dataDia;
          if (dataDia.contains('T')) {
            dataDiaNormalizada = dataDia.split('T')[0];
          }
          // Comparar apenas a parte da data (yyyy-MM-dd)
          return dataDiaNormalizada == dataFormatada;
        } catch (e) {
          // Fallback: tentar comparar diretamente
          return dataDia.contains(dataFormatada) ||
              dataFormatada.contains(dataDia.split('T')[0]);
        }
      },
      orElse: () => <String, dynamic>{},
    );

    if (feriadoEncerramento.containsKey('id') &&
        feriadoEncerramento['id']!.toString().isNotEmpty) {
      feriadoEncontrado = {
        'id': feriadoEncerramento['id'],
        'data': feriadoEncerramento['data'],
        'descricao': feriadoEncerramento['descricao'] ?? 'Feriado',
      };
    }
  }

  if (feriadoEncontrado != null && encerraFeriados) {
    return {
      'fechada': true,
      'mensagem': feriadoEncontrado['descricao'] ?? 'Feriado',
    };
  }

  return {'fechada': false, 'mensagem': ''};
}
