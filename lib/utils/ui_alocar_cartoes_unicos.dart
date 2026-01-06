import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';

/// Função reutilizável para atualizar a UI ao alocar um cartão único
/// 
/// Esta função:
/// 1. Remove o cartão da caixa de desalocados (atualiza medicosDisponiveis)
/// 2. Adiciona o cartão no gabinete de destino (atualiza alocacoes)
/// 
/// **IMPORTANTE:** Esta função apenas atualiza a UI localmente.
/// Não faz chamadas ao Firestore, não invalida cache, não recarrega dados.
/// É responsabilidade do chamador fazer essas operações se necessário.
/// 
/// Parâmetros:
/// - [medicoId]: ID do médico a ser alocado
/// - [gabineteId]: ID do gabinete de destino
/// - [data]: Data da alocação
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [medicosDisponiveis]: Lista de médicos disponíveis (será modificada)
/// - [medicos]: Lista completa de médicos (para encontrar o médico)
/// - [setState]: Função setState do widget para atualizar a UI
/// 
/// Retorna:
/// - `true` se a atualização foi bem-sucedida
/// - `false` se houve algum problema (ex: médico não encontrado)
Future<bool> atualizarUIAlocarCartaoUnico({
  required String medicoId,
  required String gabineteId,
  required DateTime data,
  required List<Alocacao> alocacoes,
  required List<Medico> medicosDisponiveis,
  required List<Medico> medicos,
  required VoidCallback setState,
  String horarioInicio = '00:00',
  String horarioFim = '00:00',
}) async {
  try {

    // 1. Verificar se o médico existe na lista de médicos disponíveis
    final medicoIndex = medicosDisponiveis.indexWhere((m) => m.id == medicoId);
    if (medicoIndex == -1) {
      debugPrint('⚠️ [UI-ALOCAR] Médico $medicoId não encontrado em medicosDisponiveis');
      
      return false;
    }

    // 2. Remover o médico da lista de disponíveis
    final medicoRemovido = medicosDisponiveis.removeAt(medicoIndex);
    debugPrint('✅ [UI-ALOCAR] Médico removido dos desalocados: ${medicoRemovido.id}');

    // 3. Verificar se já existe uma alocação para este médico neste gabinete nesta data
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final alocacaoExistente = alocacoes.firstWhere(
      (a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteId &&
            aDate == dataNormalizada;
      },
      orElse: () => Alocacao(
        id: '',
        medicoId: '',
        gabineteId: '',
        data: DateTime(1900),
        horarioInicio: '00:00',
        horarioFim: '00:00',
      ),
    );

    // 4. Se não existe, criar nova alocação otimista
    Alocacao? novaAlocacao;
    if (alocacaoExistente.id.isEmpty) {
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final dataStr =
          '${dataNormalizada.year}${dataNormalizada.month.toString().padLeft(2, '0')}${dataNormalizada.day.toString().padLeft(2, '0')}';
      novaAlocacao = Alocacao(
        id: 'otimista_${timestamp}_${medicoId}_${gabineteId}_$dataStr',
        medicoId: medicoId,
        gabineteId: gabineteId,
        data: dataNormalizada,
        horarioInicio: horarioInicio,
        horarioFim: horarioFim,
      );

      alocacoes.add(novaAlocacao);
      debugPrint('✅ [UI-ALOCAR] Nova alocação otimista criada: ${novaAlocacao.id}');
      debugPrint('   📍 Alocação adicionada: médico=$medicoId, gabinete=$gabineteId, data=${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}');
      debugPrint('   📊 Total de alocações agora: ${alocacoes.length}');
      
      // Verificar se a alocação está realmente na lista
      final alocacoesDoGabinete = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.gabineteId == gabineteId && aDate == dataNormalizada;
      }).toList();
      debugPrint('   🔍 Alocações do gabinete $gabineteId no dia: ${alocacoesDoGabinete.length}');
      for (final aloc in alocacoesDoGabinete) {
        debugPrint('      - ${aloc.id}: médico=${aloc.medicoId}');
      }
    } else {
      debugPrint('✅ [UI-ALOCAR] Alocação já existe, mantendo: ${alocacaoExistente.id}');
    }

    // 5. Atualizar a UI imediatamente após todas as modificações
    // CORREÇÃO CRÍTICA: Chamar setState de forma síncrona para garantir rebuild imediato
    // O Flutter precisa detectar a mudança na lista para reconstruir o GabinetesSection
    debugPrint('🔄 [UI-ALOCAR] Chamando setState() para atualizar UI...');
    debugPrint('   📊 Estado antes do setState: ${alocacoes.length} alocações, ${medicosDisponiveis.length} médicos disponíveis');
    
    // Verificar se a nova alocação está realmente na lista antes de chamar setState
    if (novaAlocacao != null) {
      final encontrada = alocacoes.any((a) => a.id == novaAlocacao!.id);
      debugPrint('   ✅ Nova alocação ${encontrada ? "ENCONTRADA" : "NÃO ENCONTRADA"} na lista antes do setState');
    }
    
    // CORREÇÃO CRÍTICA: Chamar setState imediatamente para forçar rebuild
    // Isso garante que o GabinetesSection seja reconstruído com a nova alocação
    setState();
    
    // O setState já foi chamado acima - não precisamos de PostFrameCallback adicional
    
    debugPrint('✅ [UI-ALOCAR] setState() chamado com sucesso');

    debugPrint('✅ [UI-ALOCAR] Atualização UI concluída: cartão removido dos desalocados e adicionado ao gabinete $gabineteId');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ [UI-ALOCAR] Erro ao atualizar UI: $e');
    debugPrint('Stack trace: $stackTrace');
    
    return false;
  }
}

