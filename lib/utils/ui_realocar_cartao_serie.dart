import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../services/realocacao_serie_service.dart';
import '../services/realocacao_unico_service.dart';

/// Função reutilizável para realocar um cartão de série de um gabinete para outro
///
/// Esta função:
/// 1. Atualiza a UI localmente (otimista) - move o cartão da origem para o destino
/// 2. Chama o serviço apropriado:
///    - Se [realocarTodaSerie] = true: usa RealocacaoSerieService para realocar toda a série
///    - Se [realocarTodaSerie] = false: usa RealocacaoUnicoService para realocar apenas um dia (criando exceção)
/// 3. NÃO recarrega os gabinetes após realocação (o estado local já está correto após atualização otimista)
///
/// **IMPORTANTE:** Esta função é específica para cartões de série.
/// Para cartões únicos, use ui_realocar_cartoes_unicos.dart.
///
/// Parâmetros:
/// - [medicoId]: ID do médico a ser realocado
/// - [gabineteOrigem]: ID do gabinete de origem
/// - [gabineteDestino]: ID do gabinete de destino
/// - [data]: Data da realocação
/// - [tipoSerie]: Tipo da série (Semanal, Quinzenal, Mensal, etc.)
/// - [realocarTodaSerie]: Se true, realoca toda a série; se false, apenas o dia específico
/// - [alocacoes]: Lista de alocações (será modificada)
/// - [unidade]: Unidade para operações no Firebase
/// - [context]: Contexto do Flutter
/// - [setState]: Função setState do widget para atualizar a UI
/// - [onRealocacaoOtimista]: Callback para atualização otimista (opcional, já chamado aqui)
/// - [onAtualizarEstado]: Callback para atualizar estado após realocação
/// - [onProgresso]: Callback para atualizar progresso (progresso, mensagem)
/// - [verificarSeDataCorrespondeSerie]: Função para verificar se uma data corresponde à série
///
/// Retorna:
/// - `true` se a realocação foi bem-sucedida
/// - `false` se houve algum problema
Future<bool> realocarCartaoSerie({
  required String medicoId,
  required String gabineteOrigem,
  required String gabineteDestino,
  required DateTime data,
  required String tipoSerie,
  required bool realocarTodaSerie,
  required List<Alocacao> alocacoes,
  required Unidade unidade,
  required BuildContext context,
  required VoidCallback setState,
  void Function(String medicoId, String gabineteOrigem, String gabineteDestino, DateTime data)? onRealocacaoOtimista,
  required Future<void> Function() onAtualizarEstado,
  required void Function(double progresso, String mensagem) onProgresso,
  required bool Function(DateTime data, SerieRecorrencia serie) verificarSeDataCorrespondeSerie,
}) async {
  try {

    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // FASE 1: Atualização otimista da UI (mover cartão da origem para o destino)
    debugPrint('🟢 [UI-REALOCAR-SERIE] FASE 1: Atualização otimista da UI');

    // Encontrar alocação no gabinete de origem (pode ser série)
    final alocacoesParaMover = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate == dataNormalizada &&
          a.id.startsWith('serie_'); // Apenas cartões de série
    }).toList();

    if (alocacoesParaMover.isEmpty) {
      debugPrint('⚠️ [UI-REALOCAR-SERIE] Nenhuma alocação de série encontrada no gabinete origem para mover');

      return false;
    }

    // Remover alocações da origem e mover para o destino
    for (final aloc in alocacoesParaMover) {
      debugPrint('   - Removendo alocação de série da origem: id=${aloc.id}, gabinete=${aloc.gabineteId}');
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

    // Chamar callback de atualização otimista se fornecido
    if (onRealocacaoOtimista != null) {
      onRealocacaoOtimista(medicoId, gabineteOrigem, gabineteDestino, data);
    }

    // Atualizar UI imediatamente após atualização otimista
    setState();
    debugPrint('✅ [UI-REALOCAR-SERIE] FASE 1 completa: UI atualizada (otimista)');

    // FASE 2: Chamar serviço apropriado para atualizar no Firebase
    debugPrint('🟢 [UI-REALOCAR-SERIE] FASE 2: Atualizando no Firebase');

    bool sucesso = false;

    if (realocarTodaSerie) {
      // Realocar toda a série
      debugPrint('   - Realocando TODA a série');
      sucesso = await RealocacaoSerieService.realocar(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: gabineteDestino,
        dataRef: data,
        tipoSerie: tipoSerie,
        alocacoes: alocacoes,
        unidade: unidade,
        context: context,
        onRealocacaoOtimista: null, // Já chamado acima
        onAtualizarEstado: onAtualizarEstado,
        onProgresso: onProgresso,
        onRealocacaoConcluida: null, // Não limpar flags aqui
        verificarSeDataCorrespondeSerie: verificarSeDataCorrespondeSerie,
      );
    } else {
      // Realocar apenas um dia (criar/atualizar exceção)
      debugPrint('   - Realocando apenas UM DIA (criando exceção)');
      sucesso = await RealocacaoUnicoService.realocar(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: gabineteDestino,
        data: data,
        alocacoes: alocacoes,
        unidade: unidade,
        context: context,
        onRealocacaoOtimista: null, // Já chamado acima
        onAlocarMedico: (String medicoId, String gabineteId, {DateTime? dataEspecifica}) async {
          // Esta função não será chamada para séries (o serviço cria exceção diretamente),
          // mas é obrigatória na assinatura do serviço
          debugPrint('⚠️ [UI-REALOCAR-SERIE] onAlocarMedico chamado inesperadamente para série');
        },
        onAtualizarEstado: onAtualizarEstado,
        onProgresso: onProgresso,
      );
    }

    if (!sucesso) {
      debugPrint('❌ [UI-REALOCAR-SERIE] Serviço retornou false');
      
      return false;
    }

    debugPrint('✅ [UI-REALOCAR-SERIE] FASE 2 completa: Firebase atualizado');

    debugPrint('✅ [UI-REALOCAR-SERIE] Realocação concluída: cartão ${realocarTodaSerie ? "de série" : "único"} movido de $gabineteOrigem para $gabineteDestino');
    return true;
  } catch (e, stackTrace) {
    debugPrint('❌ [UI-REALOCAR-SERIE] Erro ao realocar cartão de série: $e');
    debugPrint('Stack trace: $stackTrace');

    return false;
  }
}

