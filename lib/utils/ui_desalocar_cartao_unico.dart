import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

/// Função reutilizável para desalocar um cartão único de um gabinete para a lista de desalocados
/// 
/// Esta função:
/// 1. Atualiza a UI localmente (otimista) - remove o cartão do gabinete e adiciona aos desalocados
/// 2. Atualiza no Firebase - remove a alocação do gabinete
/// 3. Recarrega apenas os gabinetes afetados (origem) e a lista de desalocados
/// 
/// **IMPORTANTE:** Esta função é específica para cartões únicos (não séries).
/// Para séries, use o serviço de desalocação de série.
/// 
/// **IMPORTANTE:** Esta função NÃO mostra diálogo de confirmação.
/// O gesto do utilizador de arrastar o cartão para a área de desalocados já é suficiente
/// para confirmar a intenção de desalocação.
/// 
/// Parâmetros:
/// - [medicoId]: ID do médico a ser desalocado
/// - [data]: Data da desalocação
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [disponibilidades]: Lista de disponibilidades
/// - [medicos]: Lista completa de médicos (para encontrar o médico)
/// - [medicosDisponiveis]: Lista de médicos disponíveis (será modificada)
/// - [unidade]: Unidade para operações no Firebase
/// - [setState]: Função setState do widget para atualizar a UI
/// - [recarregarAlocacoesGabinetes]: Função para recarregar apenas os gabinetes afetados
/// - [recarregarDesalocados]: Função para recarregar a lista de médicos desalocados
/// 
/// Retorna:
/// - `true` se a desalocação foi bem-sucedida
/// - `false` se houve algum problema
Future<bool> desalocarCartaoUnico({
  required String medicoId,
  required DateTime data,
  required List<Alocacao> alocacoes,
  required List<Disponibilidade> disponibilidades,
  required List<Medico> medicos,
  required List<Medico> medicosDisponiveis,
  required Unidade? unidade,
  required VoidCallback setState,
  required Future<void> Function(List<String> gabineteIds) recarregarAlocacoesGabinetes,
  required Future<void> Function() recarregarDesalocados,
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
      debugPrint('⚠️ [UI-DESALOCAR] Nenhuma alocação encontrada para desalocar');
      
      return false;
    }

    final gabineteOrigem = alocacaoParaDesalocar.gabineteId;
    debugPrint('🔍 [UI-DESALOCAR] Gabinete de origem: $gabineteOrigem');

    // FASE 2: Invalidar cache ANTES de desalocar
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    // FASE 3: Atualização otimista da UI (remover cartão do gabinete e adicionar aos desalocados)
    debugPrint('🟢 [UI-DESALOCAR] FASE 3: Atualização otimista da UI');
    
    // NOTA: Não removemos a alocação localmente aqui porque desalocarMedicoDiaUnico
    // já faz isso. Apenas adicionamos o médico aos desalocados para feedback visual imediato.
    
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
      debugPrint('✅ [UI-DESALOCAR] Médico adicionado aos desalocados: ${medico.id}');
    } else {
      debugPrint('⚠️ [UI-DESALOCAR] Médico já estava nos desalocados: ${medico.id}');
    }

    // Atualizar UI imediatamente após atualização otimista
    setState();
    debugPrint('✅ [UI-DESALOCAR] FASE 3 completa: UI atualizada (otimista)');

    // FASE 4: Atualizar no Firebase
    debugPrint('🟢 [UI-DESALOCAR] FASE 4: Atualizando no Firebase');
    
    await logic.AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
      selectedDate: data,
      medicoId: medicoId,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      onAlocacoesChanged: () {
        // Não recarregar durante processamento
      },
      unidade: unidade,
    );

    debugPrint('✅ [UI-DESALOCAR] FASE 4 completa: Firebase atualizado');

    // FASE 5: Invalidar cache APÓS desalocar
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    // FASE 6: Verificar se a alocação foi realmente removida antes de recarregar
    // Isso previne que o recarregamento traga a alocação de volta se o Firestore
    // ainda não processou a remoção
    debugPrint('🟢 [UI-DESALOCAR] FASE 6: Verificando se alocação foi removida...');
    
    // Verificar se ainda existe alocação local (não deveria existir após remoção)
    final alocacaoAindaExiste = alocacoes.any((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate == dataNormalizada;
    });
    
    if (alocacaoAindaExiste) {
      debugPrint('⚠️ [UI-DESALOCAR] Alocação ainda existe localmente, removendo novamente...');
      alocacoes.removeWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            aDate == dataNormalizada;
      });
    }

    // FASE 7: Aguardar um pouco para garantir que o Firestore processou a remoção
    // antes de recarregar os dados do Firestore
    debugPrint('🟢 [UI-DESALOCAR] FASE 7: Aguardando processamento do Firestore...');
    await Future.delayed(const Duration(milliseconds: 800));

    // FASE 8: Recarregar apenas os gabinetes afetados (origem) e desalocados
    debugPrint('🟢 [UI-DESALOCAR] FASE 8: Recarregando gabinetes afetados');
    
    // CRÍTICO: Recarregar os gabinetes para garantir que a UI está sincronizada
    // Mas apenas após dar tempo suficiente ao Firestore processar a remoção
    if (gabineteOrigem.isNotEmpty) {
      await recarregarAlocacoesGabinetes([gabineteOrigem]);
      
      // Verificar novamente após recarregar se a alocação voltou
      final alocacaoVoltou = alocacoes.any((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            aDate == dataNormalizada;
      });
      
      if (alocacaoVoltou) {
        debugPrint('⚠️ [UI-DESALOCAR] Alocação voltou após recarregar! Removendo novamente...');
        alocacoes.removeWhere((a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == medicoId &&
              a.gabineteId == gabineteOrigem &&
              aDate == dataNormalizada;
        });
        
        // Garantir que o médico está nos desalocados
        if (!medicosDisponiveis.any((m) => m.id == medicoId)) {
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
          medicosDisponiveis.add(medico);
        }
        
        setState();
      }
    }
    
    // Atualizar médicos desalocados (isso verifica se o médico ainda está alocado
    // e o remove da lista se necessário)
    await recarregarDesalocados();
    
    // FASE 9: Verificação final - garantir que o médico está nos desalocados
    // mesmo após recarregar (caso a alocação tenha voltado temporariamente)
    debugPrint('🟢 [UI-DESALOCAR] FASE 9: Verificação final');
    
    // Verificar se a alocação ainda existe (não deveria)
    final alocacaoFinalExiste = alocacoes.any((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate == dataNormalizada;
    });
    
    // Se a alocação ainda existe, removê-la definitivamente
    if (alocacaoFinalExiste) {
      debugPrint('⚠️ [UI-DESALOCAR] Alocação ainda existe na verificação final! Removendo definitivamente...');
      alocacoes.removeWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            aDate == dataNormalizada;
      });
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
      debugPrint('✅ [UI-DESALOCAR] Médico garantido nos desalocados na verificação final');
    }
    
    // Atualizar UI final
    setState();
    
    debugPrint('✅ [UI-DESALOCAR] FASE 9 completa: Verificação final concluída');

    debugPrint('✅ [UI-DESALOCAR] Desalocação concluída: cartão removido de $gabineteOrigem e adicionado aos desalocados');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ [UI-DESALOCAR] Erro ao desalocar cartão: $e');
    debugPrint('Stack trace: $stackTrace');
    
    return false;
  }
}

