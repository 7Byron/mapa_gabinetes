import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

/// Função reutilizável para realocar um cartão único de um gabinete para outro
/// 
/// Esta função:
/// 1. Atualiza a UI localmente (otimista) - move o cartão da origem para o destino
/// 2. Atualiza no Firebase - cria nova alocação no destino (que automaticamente remove da origem)
/// 3. Recarrega apenas os gabinetes afetados (origem e destino) para atualizar o layout
/// 
/// **IMPORTANTE:** Esta função é específica para cartões únicos (não séries).
/// Para séries, use o serviço de realocação de série.
/// 
/// Parâmetros:
/// - [medicoId]: ID do médico a ser realocado
/// - [gabineteOrigem]: ID do gabinete de origem
/// - [gabineteDestino]: ID do gabinete de destino
/// - [data]: Data da realocação
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [disponibilidades]: Lista de disponibilidades (para buscar horários)
/// - [unidade]: Unidade para operações no Firebase
/// - [setState]: Função setState do widget para atualizar a UI
/// - [recarregarAlocacoesGabinetes]: Função para recarregar apenas os gabinetes afetados
/// 
/// Retorna:
/// - `true` se a realocação foi bem-sucedida
/// - `false` se houve algum problema
Future<bool> realocarCartaoUnico({
  required String medicoId,
  required String gabineteOrigem,
  required String gabineteDestino,
  required DateTime data,
  required List<Alocacao> alocacoes,
  required List<Disponibilidade> disponibilidades,
  required Unidade unidade,
  required VoidCallback setState,
  required Future<void> Function(List<String> gabineteIds) recarregarAlocacoesGabinetes,
}) async {
  try {

    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // FASE 1: Atualização otimista da UI (mover cartão da origem para o destino)
    debugPrint('🟢 [UI-REALOCAR] FASE 1: Atualização otimista da UI');
    
    // Encontrar alocação no gabinete de origem
    final alocacoesParaMover = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate == dataNormalizada &&
          !a.id.startsWith('serie_'); // Apenas cartões únicos (não séries)
    }).toList();

    if (alocacoesParaMover.isEmpty) {
      debugPrint('⚠️ [UI-REALOCAR] Nenhuma alocação encontrada no gabinete origem para mover');
      
      return false;
    }

    // Remover alocações da origem e mover para o destino
    for (final aloc in alocacoesParaMover) {
      debugPrint('   - Removendo alocação da origem: id=${aloc.id}, gabinete=${aloc.gabineteId}');
      alocacoes.remove(aloc);

      // Criar nova alocação no destino (manter mesmo ID para atualização otimista)
      final novaAloc = Alocacao(
        id: aloc.id, // Manter o mesmo ID
        medicoId: aloc.medicoId,
        gabineteId: gabineteDestino, // NOVO gabinete
        data: aloc.data,
        horarioInicio: aloc.horarioInicio,
        horarioFim: aloc.horarioFim,
      );

      alocacoes.add(novaAloc);
      debugPrint('   - Adicionado no destino: id=${novaAloc.id}, novo gabinete=${novaAloc.gabineteId}');
    }

    // Atualizar UI imediatamente após atualização otimista
    setState();
    debugPrint('✅ [UI-REALOCAR] FASE 1 completa: UI atualizada (otimista)');

    // FASE 2: Atualizar no Firebase
    debugPrint('🟢 [UI-REALOCAR] FASE 2: Atualizando no Firebase');
    
    // Invalidar cache antes de atualizar
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    // Buscar horários da disponibilidade
    String horarioInicio = '00:00';
    String horarioFim = '00:00';
    final dispDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataNormalizada;
    }).toList();
    if (dispDoDia.isNotEmpty && dispDoDia.first.horarios.length >= 2) {
      horarioInicio = dispDoDia.first.horarios[0];
      horarioFim = dispDoDia.first.horarios[1];
    }

    // Usar alocarMedico que remove a alocação anterior e cria nova no destino
    await logic.AlocacaoMedicosLogic.alocarMedico(
      selectedDate: data,
      medicoId: medicoId,
      gabineteId: gabineteDestino,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      onAlocacoesChanged: () {
        // Não recarregar durante processamento
      },
      unidade: unidade,
      horariosForcados: [horarioInicio, horarioFim],
    );

    debugPrint('✅ [UI-REALOCAR] FASE 2 completa: Firebase atualizado');

    // FASE 3: Recarregar apenas os gabinetes afetados (origem e destino)
    debugPrint('🟢 [UI-REALOCAR] FASE 3: Recarregando gabinetes afetados');
    await recarregarAlocacoesGabinetes([gabineteOrigem, gabineteDestino]);
    debugPrint('✅ [UI-REALOCAR] FASE 3 completa: Gabinetes atualizados');

    debugPrint('✅ [UI-REALOCAR] Realocação concluída: cartão movido de $gabineteOrigem para $gabineteDestino');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ [UI-REALOCAR] Erro ao realocar cartão: $e');
    debugPrint('Stack trace: $stackTrace');
    
    return false;
  }
}

