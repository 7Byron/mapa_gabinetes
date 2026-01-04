import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/desalocacao_serie_service.dart';
import 'dart:convert';

/// Função reutilizável para desalocar um cartão de série de um gabinete para a lista de desalocados
/// 
/// Esta função:
/// 1. Atualiza a UI localmente (otimista) - remove o cartão do gabinete e adiciona aos desalocados
/// 2. Atualiza no Firebase - remove o gabineteId da série
/// 3. Recarrega apenas os gabinetes afetados (origem) e a lista de desalocados
/// 
/// **IMPORTANTE:** Esta função é específica para cartões de série (não únicos).
/// Para cartões únicos, use `desalocarCartaoUnico`.
/// 
/// **IMPORTANTE:** Esta função NÃO mostra diálogo de confirmação.
/// O gesto do utilizador de arrastar o cartão para a área de desalocados já é suficiente
/// para confirmar a intenção de desalocação.
/// 
/// Parâmetros:
/// - [medicoId]: ID do médico a ser desalocado
/// - [data]: Data de referência da desalocação
/// - [tipo]: Tipo da série (Semanal, Quinzenal, Mensal, etc.)
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [disponibilidades]: Lista de disponibilidades
/// - [medicos]: Lista completa de médicos (para encontrar o médico)
/// - [medicosDisponiveis]: Lista de médicos disponíveis (será modificada)
/// - [unidade]: Unidade para operações no Firebase
/// - [setState]: Função setState do widget para atualizar a UI
/// - [recarregarAlocacoesGabinetes]: Função para recarregar apenas os gabinetes afetados
/// - [recarregarDesalocados]: Função para recarregar a lista de médicos desalocados
/// - [onProgresso]: Callback opcional para atualizar progresso (progresso, mensagem)
/// - [context]: Contexto do Flutter para mostrar mensagens de erro
/// 
/// Retorna:
/// - `true` se a desalocação foi bem-sucedida
/// - `false` se houve algum problema
Future<bool> desalocarCartaoSerie({
  required String medicoId,
  required DateTime data,
  required String tipo,
  required List<Alocacao> alocacoes,
  required List<Disponibilidade> disponibilidades,
  required List<Medico> medicos,
  required List<Medico> medicosDisponiveis,
  required Unidade? unidade,
  required VoidCallback setState,
  required Future<void> Function(List<String> gabineteIds) recarregarAlocacoesGabinetes,
  required Future<void> Function() recarregarDesalocados,
  void Function(double progresso, String mensagem)? onProgresso,
  required BuildContext context,
}) async {
  try {

    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // FASE 1: Encontrar gabinete de origem ANTES de desalocar
    // Isso garante que sabemos qual gabinete atualizar mesmo após a remoção
    final alocacaoParaDesalocar = alocacoes.firstWhere(
      (a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate == dataNormalizada;
      },
      orElse: () => Alocacao(
        id: '',
        medicoId: '',
        gabineteId: '',
        data: DateTime(1900, 1, 1),
        horarioInicio: '',
        horarioFim: '',
      ),
    );

    if (alocacaoParaDesalocar.id.isEmpty) {
      debugPrint('⚠️ [UI-DESALOCAR-SERIE] Nenhuma alocação encontrada para desalocar');
      
      return false;
    }

    final gabineteOrigem = alocacaoParaDesalocar.gabineteId;
    debugPrint('🔍 [UI-DESALOCAR-SERIE] Gabinete de origem: $gabineteOrigem');

    // FASE 2: Atualização otimista da UI (adicionar médico aos desalocados)
    debugPrint('🟢 [UI-DESALOCAR-SERIE] FASE 2: Atualização otimista da UI');
    
    // Adicionar médico de volta à lista de disponíveis (se ainda não estiver)
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

    if (!medicosDisponiveis.any((m) => m.id == medicoId)) {
      medicosDisponiveis.add(medico);
      debugPrint('✅ [UI-DESALOCAR-SERIE] Médico adicionado aos desalocados: ${medico.id}');
    } else {
      debugPrint('⚠️ [UI-DESALOCAR-SERIE] Médico já estava nos desalocados: ${medico.id}');
    }

    // Atualizar UI imediatamente após atualização otimista
    setState();
    debugPrint('✅ [UI-DESALOCAR-SERIE] FASE 2 completa: UI atualizada (otimista)');

    // FASE 3: Atualizar no Firebase usando o serviço de desalocação de série
    debugPrint('🟢 [UI-DESALOCAR-SERIE] FASE 3: Atualizando no Firebase');
    
    final sucesso = await DesalocacaoSerieService.desalocar(
      medicoId: medicoId,
      dataRef: data,
      tipo: tipo,
      selectedDate: data,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      unidade: unidade,
      onAlocacoesChanged: () {
        // Não recarregar durante processamento - será feito depois
      },
      onProgresso: onProgresso ?? (progresso, mensagem) {
        debugPrint('📊 [UI-DESALOCAR-SERIE] Progresso: ${(progresso * 100).toStringAsFixed(0)}% - $mensagem');
      },
      context: context,
    );

    if (!sucesso) {
      debugPrint('❌ [UI-DESALOCAR-SERIE] Falha ao desalocar série');
      return false;
    }

    debugPrint('✅ [UI-DESALOCAR-SERIE] FASE 3 completa: Firebase atualizado');

    // FASE 4: Aguardar um pouco para garantir que o Firestore processou a remoção
    // antes de recarregar os dados do Firestore
    debugPrint('🟢 [UI-DESALOCAR-SERIE] FASE 4: Aguardando processamento do Firestore...');
    await Future.delayed(const Duration(milliseconds: 800));

    // FASE 5: Recarregar apenas os gabinetes afetados (origem) e desalocados
    debugPrint('🟢 [UI-DESALOCAR-SERIE] FASE 5: Recarregando gabinetes afetados');
    
    // CRÍTICO: Recarregar os gabinetes para garantir que a UI está sincronizada
    // Mas apenas após dar tempo suficiente ao Firestore processar a remoção
    if (gabineteOrigem.isNotEmpty) {
      await recarregarAlocacoesGabinetes([gabineteOrigem]);
      
      // Verificar novamente após recarregar se alguma alocação da série voltou
      final alocacoesSerieVoltaram = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            (a.id.startsWith('serie_') || aDate == dataNormalizada);
      }).toList();
      
      if (alocacoesSerieVoltaram.isNotEmpty) {
        debugPrint('⚠️ [UI-DESALOCAR-SERIE] Alocações da série voltaram após recarregar! Removendo novamente...');
        // Remover todas as alocações da série que voltaram
        for (final aloc in alocacoesSerieVoltaram) {
          alocacoes.removeWhere((a) => a.id == aloc.id);
        }
        
        // Garantir que o médico está nos desalocados
        if (!medicosDisponiveis.any((m) => m.id == medicoId)) {
          final medicoFinal = medicos.firstWhere(
            (m) => m.id == medicoId,
            orElse: () => Medico(
              id: medicoId,
              nome: 'Médico não identificado',
              especialidade: '',
              disponibilidades: [],
              ativo: true,
            ),
          );
          medicosDisponiveis.add(medicoFinal);
        }
        
        setState();
      }
    }
    
    // Atualizar médicos desalocados (isso verifica se o médico ainda está alocado
    // e o remove da lista se necessário)
    await recarregarDesalocados();
    
    debugPrint('✅ [UI-DESALOCAR-SERIE] FASE 5 completa: Gabinetes atualizados');

    // FASE 6: Verificação final - garantir que o médico está nos desalocados
    // mesmo após recarregar (caso alguma alocação da série tenha voltado temporariamente)
    debugPrint('🟢 [UI-DESALOCAR-SERIE] FASE 6: Verificação final');
    
    // Verificar se ainda existem alocações da série (não deveriam existir)
    final alocacoesSerieFinal = alocacoes.where((a) {
      return a.medicoId == medicoId &&
          (a.id.startsWith('serie_') || 
           (a.gabineteId == gabineteOrigem && 
            DateTime(a.data.year, a.data.month, a.data.day) == dataNormalizada));
    }).toList();
    
    // Se ainda existem alocações da série, removê-las definitivamente
    if (alocacoesSerieFinal.isNotEmpty) {
      debugPrint('⚠️ [UI-DESALOCAR-SERIE] Alocações da série ainda existem na verificação final! Removendo definitivamente...');
      for (final aloc in alocacoesSerieFinal) {
        alocacoes.removeWhere((a) => a.id == aloc.id);
      }
    }
    
    // Garantir que o médico está nos desalocados (independente de estar alocado ou não)
    if (!medicosDisponiveis.any((m) => m.id == medicoId)) {
      final medicoFinal = medicos.firstWhere(
        (m) => m.id == medicoId,
        orElse: () => Medico(
          id: medicoId,
          nome: 'Médico não identificado',
          especialidade: '',
          disponibilidades: [],
          ativo: true,
        ),
      );
      medicosDisponiveis.add(medicoFinal);
      debugPrint('✅ [UI-DESALOCAR-SERIE] Médico garantido nos desalocados na verificação final');
    }
    
    // Atualizar UI final
    setState();
    
    debugPrint('✅ [UI-DESALOCAR-SERIE] FASE 6 completa: Verificação final concluída');

    debugPrint('✅ [UI-DESALOCAR-SERIE] Desalocação concluída: série removida de $gabineteOrigem e médico adicionado aos desalocados');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ [UI-DESALOCAR-SERIE] Erro ao desalocar cartão de série: $e');
    debugPrint('Stack trace: $stackTrace');
    
    return false;
  }
}

