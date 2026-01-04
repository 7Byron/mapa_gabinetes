import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/unidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import 'alocacao_medicos_logic.dart' as logic;

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
/// - [onProgress]: Callback opcional para atualizar o progresso (progresso de 0.0 a 1.0, mensagem)
/// - [onStateUpdate]: Callback opcional para atualizar o estado (chamado quando necessário)
///
/// Retorna:
/// - Map com informações sobre o carregamento:
///   - 'success': bool - se o carregamento foi bem-sucedido
///   - 'clinicaFechada': bool - se a clínica está encerrada
///   - 'mensagemClinicaFechada': String - mensagem se a clínica estiver fechada
///   - 'feriados': List<Map<String, String>> - lista de feriados
///   - 'diasEncerramento': List<Map<String, dynamic>> - lista de dias de encerramento
///   - 'horariosClinica': Map<int, List<String>> - horários da clínica
///   - 'encerraFeriados': bool - se encerra em feriados
///   - 'nuncaEncerra': bool - se nunca encerra
///   - 'encerraDias': Map<int, bool> - dias da semana que encerra
Future<Map<String, dynamic>> atualizarDadosDoDia({
  required Unidade unidade,
  required DateTime data,
  required List<Gabinete> gabinetes,
  required List<Medico> medicos,
  required List<Disponibilidade> disponibilidades,
  required List<Alocacao> alocacoes,
  required List<Medico> medicosDisponiveis,
  bool recarregarMedicos = false,
  Function(double progresso, String mensagem)? onProgress,
  Function()? onStateUpdate,
}) async {
  try {
    // FASE 0: Carregar dados de encerramento (feriados, dias de encerramento, horários)
    onProgress?.call(0.0, 'A verificar configurações...');

    // CORREÇÃO CRÍTICA: Adicionar timeout para prevenir travamentos quando o sistema está lento
    // Carregar dados de encerramento em paralelo com timeout de 10 segundos
    final encerramentoResults = await Future.wait([
      _carregarFeriados(unidade),
      _carregarDiasEncerramento(unidade),
      _carregarHorariosEConfiguracoes(unidade),
    ]).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ [TIMEOUT] Timeout ao carregar dados de encerramento - usando valores padrão');
        return [
          <Map<String, String>>[],
          <Map<String, dynamic>>[],
          {
            'horarios': <int, List<String>>{},
            'encerraFeriados': false,
            'nuncaEncerra': true, // Se timeout, assumir que nunca encerra para evitar bloqueios
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

    final feriados = encerramentoResults[0] as List<Map<String, String>>;
    final diasEncerramento =
        encerramentoResults[1] as List<Map<String, dynamic>>;
    final horariosData = encerramentoResults[2] as Map<String, dynamic>;

    // CORREÇÃO CRÍTICA: Verificar se houve timeout ou erro
    // Se houve timeout, assumir que a clínica está aberta (nuncaEncerra = true)
    final teveTimeout = horariosData['_timeout'] == true;
    if (teveTimeout) {
      debugPrint('⚠️ [TIMEOUT] Dados de encerramento não carregados a tempo - assumindo clínica aberta');
      // Continuar com o fluxo normal, mas com nuncaEncerra = true
    }

    final horariosClinica = horariosData['horarios'] as Map<int, List<String>>;
    final encerraFeriados = horariosData['encerraFeriados'] as bool;
    final nuncaEncerra = horariosData['nuncaEncerra'] as bool;
    final encerraDias = horariosData['encerraDias'] as Map<int, bool>;

    // CORREÇÃO: Verificar se a clínica está encerrada APENAS se os dados foram carregados corretamente
    // Se houver erro ao carregar dados de encerramento OU timeout, assumir que a clínica está aberta
    bool clinicaFechada = false;
    String mensagemClinicaFechada = '';
    
    // Só verificar se nuncaEncerra foi definido E não houve timeout
    // Se houve timeout, nuncaEncerra já será true, então não precisamos verificar
    if (horariosData.containsKey('nuncaEncerra') && !teveTimeout) {
      final clinicaFechadaData = _verificarClinicaFechada(
        data,
        feriados,
        diasEncerramento,
        horariosClinica,
        encerraFeriados,
        nuncaEncerra,
        encerraDias,
      );

      clinicaFechada = clinicaFechadaData['fechada'] as bool;
      mensagemClinicaFechada = clinicaFechadaData['mensagem'] as String;
    } else if (teveTimeout) {
      // Se houve timeout, assumir que a clínica está aberta
      debugPrint('⚠️ [TIMEOUT] Assumindo clínica aberta devido a timeout no carregamento');
      clinicaFechada = false;
      mensagemClinicaFechada = '';
    } else {
      // Se os dados não foram carregados corretamente, assumir que a clínica está aberta
      debugPrint('⚠️ Dados de encerramento não carregados corretamente - assumindo clínica aberta');
    }

    debugPrint(
        '🔍 Verificação de encerramento: clinicaFechada=$clinicaFechada, mensagem="$mensagemClinicaFechada"');
    debugPrint('  - Feriados carregados: ${feriados.length}');
    debugPrint(
        '  - Dias de encerramento carregados: ${diasEncerramento.length}');
    debugPrint('  - encerraFeriados: $encerraFeriados');
    debugPrint(
        '  - Data selecionada: ${DateFormat('yyyy-MM-dd').format(data)}');

    if (clinicaFechada) {
      // Clínica está encerrada - não carregar dados do Firestore
      debugPrint(
          '🚫 Clínica encerrada - pulando carregamento de dados do Firestore');

      // Limpar dados existentes
      disponibilidades.clear();
      alocacoes.clear();
      medicosDisponiveis.clear();

      onProgress?.call(0.0, 'A iniciar...');

      return {
        'success': true,
        'clinicaFechada': true,
        'mensagemClinicaFechada': mensagemClinicaFechada,
        'feriados': feriados,
        'diasEncerramento': diasEncerramento,
        'horariosClinica': horariosClinica,
        'encerraFeriados': encerraFeriados,
        'nuncaEncerra': nuncaEncerra,
        'encerraDias': encerraDias,
      };
    }

    // FASE 1: Carregar exceções canceladas EM PARALELO com início do carregamento de dados
    // Isso melhora a performance ao não esperar sequencialmente
    onProgress?.call(0.1, 'A verificar exceções...');

    // OTIMIZAÇÃO: Carregar exceções canceladas em paralelo com invalidação de cache
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final excecoesFuture = logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      unidade.id,
      data,
    );
    
    // Invalidar cache se necessário (pode ser feito em paralelo)
    if (recarregarMedicos) {
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(data.year, 1, 1));
    }
    
    final datasComExcecoesCanceladas = await excecoesFuture;

    debugPrint(
        '⚡ Exceções canceladas carregadas: ${datasComExcecoesCanceladas.length}');

    // FASE 2: Carregar dados essenciais (gabinetes, médicos, disponibilidades e alocações)
    onProgress?.call(0.2, 'A carregar dados...');

    // Carregar dados usando a lógica existente
    await logic.AlocacaoMedicosLogic.carregarDadosIniciais(
      gabinetes: gabinetes,
      medicos: medicos,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      onGabinetes: (g) {
        if (!recarregarMedicos && g.isEmpty && gabinetes.isNotEmpty) {
          debugPrint(
              '⚠️ Preservando ${gabinetes.length} gabinetes existentes (lista vazia recebida durante mudança de data)');
          return;
        }
        gabinetes.clear();
        gabinetes.addAll(g);
      },
      onMedicos: (m) {
        if (!recarregarMedicos && m.isEmpty && medicos.isNotEmpty) {
          debugPrint(
              '⚠️ Preservando ${medicos.length} médicos existentes (lista vazia recebida durante mudança de data)');
          return;
        }
        medicos.clear();
        medicos.addAll(m);
        debugPrint(
            '👥 Médicos carregados: ${m.length} total, ${m.where((med) => med.ativo).length} ativos');
      },
      onDisponibilidades: (d) {
        debugPrint(
            '📋 onDisponibilidades chamado com ${d.length} disponibilidades');
        disponibilidades.clear();
        disponibilidades.addAll(d);
        debugPrint(
            '📋 Disponibilidades atualizadas: ${disponibilidades.length} total');
      },
      onAlocacoes: (a) {
        // Preservar alocações otimistas durante recarregamento
        final alocacoesMap = <String, Alocacao>{};

        // Primeiro, adicionar alocações do servidor
        for (final aloc in a) {
          final chave =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
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
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';

            if (!alocacoesMap.containsKey(chave)) {
              alocacoesMap[chave] = aloc;
              debugPrint(
                  '✅ Preservando alocação otimista durante recarregamento: ${aloc.id}');
            }
          } else if (aloc.id.startsWith('serie_')) {
            final chave =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
            if (!alocacoesMap.containsKey(chave)) {
              alocacoesMap[chave] = aloc;
            }
          }
        }

        alocacoes.clear();
        alocacoes.addAll(alocacoesMap.values);
        final alocacoesOtimistasPreservadas =
            alocacoes.where((a) => a.id.startsWith('otimista_')).length;
        debugPrint(
            '✅ Alocações mescladas: ${alocacoes.length} total ($alocacoesOtimistasPreservadas otimistas preservadas)');
      },
      unidade: unidade,
      dataFiltroDia: data,
      reloadStatic: recarregarMedicos,
      excecoesCanceladas: datasComExcecoesCanceladas,
    );

    onProgress?.call(0.9, 'A processar médicos disponíveis...');

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
      final dataKey =
          '${m.id}_${data.year}-${data.month}-${data.day}';
      if (datasComExcecoesCanceladas.contains(dataKey)) {
        return false; // Não mostrar se tem exceção cancelada
      }

      // Verificar se o médico está no Set de médicos com disponibilidade
      return medicosComDisponibilidade.contains(m.id);
    }).toList());

    onProgress?.call(1.0, 'Concluído!');

    return {
      'success': true,
      'clinicaFechada': false,
      'mensagemClinicaFechada': '',
      'feriados': feriados,
      'diasEncerramento': diasEncerramento,
      'horariosClinica': horariosClinica,
      'encerraFeriados': encerraFeriados,
      'nuncaEncerra': nuncaEncerra,
      'encerraDias': encerraDias,
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
Future<List<Map<String, String>>> _carregarFeriados(Unidade unidade) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final feriadosRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('configuracoes')
        .doc('feriados');

    final snapshot = await feriadosRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final feriadosList = data['feriados'] as List<dynamic>? ?? [];
      return feriadosList
          .map((f) => Map<String, String>.from(f as Map))
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('❌ Erro ao carregar feriados: $e');
    return [];
  }
}

/// Carrega dias de encerramento da unidade
Future<List<Map<String, dynamic>>> _carregarDiasEncerramento(
    Unidade unidade) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final encerramentoRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('configuracoes')
        .doc('encerramento');

    final snapshot = await encerramentoRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final diasList = data['dias'] as List<dynamic>? ?? [];
      return diasList.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    }
    return [];
  } catch (e) {
    debugPrint('❌ Erro ao carregar dias de encerramento: $e');
    return [];
  }
}

/// Carrega horários e configurações de encerramento da unidade
Future<Map<String, dynamic>> _carregarHorariosEConfiguracoes(
    Unidade unidade) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final horariosRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('configuracoes')
        .doc('horarios');

    final snapshot = await horariosRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      return {
        'horarios': Map<int, List<String>>.from(
          (data['horarios'] as Map<dynamic, dynamic>?)?.map(
                (k, v) => MapEntry(
                  int.parse(k.toString()),
                  List<String>.from(v as List),
                ),
              ) ??
              {},
        ),
        'encerraFeriados': data['encerraFeriados'] as bool? ?? false,
        'nuncaEncerra': data['nuncaEncerra'] as bool? ?? false,
        'encerraDias': Map<int, bool>.from(
          (data['encerraDias'] as Map<dynamic, dynamic>?)?.map(
                (k, v) => MapEntry(int.parse(k.toString()), v as bool),
              ) ??
              {
                1: false,
                2: false,
                3: false,
                4: false,
                5: false,
                6: false,
                7: false,
              },
        ),
      };
    }
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

  // Verificar se é feriado
  final dataStr =
      '${data.day.toString().padLeft(2, '0')}-${data.month.toString().padLeft(2, '0')}';
  final isFeriado = feriados.any((f) => f['data'] == dataStr);

  if (isFeriado && encerraFeriados) {
    return {
      'fechada': true,
      'mensagem': 'A clínica está encerrada por ser feriado.',
    };
  }

  // Verificar se é dia de encerramento específico
  final isDiaEncerramento = diasEncerramento.any((d) {
    final diaEncerramento = d['data'] as String?;
    if (diaEncerramento == null) return false;
    final partes = diaEncerramento.split('-');
    if (partes.length != 3) return false;
    final dia = int.tryParse(partes[2]);
    final mes = int.tryParse(partes[1]);
    final ano = int.tryParse(partes[0]);
    if (dia == null || mes == null || ano == null) return false;
    return dia == data.day && mes == data.month && ano == data.year;
  });

  if (isDiaEncerramento) {
    return {
      'fechada': true,
      'mensagem': 'A clínica está encerrada neste dia.',
    };
  }

  // Verificar se encerra neste dia da semana
  final weekday = data.weekday;
  if (encerraDias[weekday] == true) {
    return {
      'fechada': true,
      'mensagem': 'A clínica está encerrada neste dia da semana.',
    };
  }

  return {'fechada': false, 'mensagem': ''};
}
