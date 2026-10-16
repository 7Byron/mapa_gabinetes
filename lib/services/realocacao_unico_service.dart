/// Serviço para realocação única: de um gabinete para outro gabinete (apenas um dia)
///
/// Este serviço lida com a realocação de um médico de um gabinete para outro
/// em uma data específica (realocação única, não série).
library;

import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';

class RealocacaoUnicoService {
  /// Realoca um médico de um gabinete para outro em uma data específica
  ///
  /// [medicoId] - ID do médico a ser realocado
  /// [gabineteOrigem] - ID do gabinete de origem
  /// [gabineteDestino] - ID do gabinete de destino
  /// [data] - Data da realocação
  /// [alocacoes] - Lista de alocações atuais (para encontrar a alocação)
  /// [unidade] - Unidade para buscar séries/exceções
  /// [onRealocacaoOtimista] - Callback opcional para atualização otimista
  /// [onAlocarMedico] - Callback para alocar o médico se não encontrar alocação
  /// [onAtualizarEstado] - Callback para atualizar o estado após realocação
  /// [onProgresso] - Callback para atualizar progresso (progresso, mensagem)
  /// [context] - Contexto do Flutter para mostrar mensagens
  ///
  /// Retorna true se a realocação foi bem-sucedida, false caso contrário
  static Future<bool> realocar({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime data,
    String? alocacaoId,
    String? serieId,
    List<String>? horarios,
    required List<Alocacao> alocacoes,
    required Unidade? unidade,
    required BuildContext context,
    void Function(String medicoId, String gabineteOrigem,
            String gabineteDestino, DateTime data)?
        onRealocacaoOtimista,
    required Future<void> Function(String medicoId, String gabineteId,
            {DateTime? dataEspecifica, List<String>? horarios})
        onAlocarMedico,
    required Future<void> Function() onAtualizarEstado,
    required void Function(double progresso, String mensagem) onProgresso,
  }) async {
    try {
      // NOTA: A atualização otimista já foi feita em gabinetes_section.dart antes de chamar este serviço.
      // Não chamar onRealocacaoOtimista aqui novamente para evitar duplicação de alocações.
      // A segunda chamada causava duplicação porque _realocacaoOtimista procurava alocações no gabinete origem,
      // mas a alocação já havia sido movida, então criava uma nova alocação otimista no destino.

      onProgresso(0.1, 'Cartão movido, sincronizando...');

      final dataNormalizada = DateTime(data.year, data.month, data.day);

      // Procurar alocação no destino primeiro (após atualização otimista), depois na origem
      Alocacao? alocacaoOrigem;

      try {
        alocacaoOrigem = alocacoes.firstWhere(
          (a) {
            final aDate = DateTime(a.data.year, a.data.month, a.data.day);
            return (alocacaoId == null || a.id == alocacaoId) &&
                a.medicoId == medicoId &&
                a.gabineteId == gabineteDestino &&
                aDate == dataNormalizada;
          },
        );
      } catch (e) {
        try {
          alocacaoOrigem = alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              return (alocacaoId == null || a.id == alocacaoId) &&
                  a.medicoId == medicoId &&
                  a.gabineteId == gabineteOrigem &&
                  aDate == dataNormalizada;
            },
          );
        } catch (e2) {
          // Não encontrou alocação, criar nova
          await onAlocarMedico(
            medicoId,
            gabineteDestino,
            dataEspecifica: data,
            horarios: horarios,
          );
          return true;
        }
      }

      // Verificar se é alocação de série
      final eAlocacaoDeSerie = alocacaoOrigem.id.startsWith('serie_');

      if (eAlocacaoDeSerie) {
        // Extrair ID da série
        String? serieIdAlvo = serieId;
        final partes = alocacaoOrigem.id.split('_');

        if (serieIdAlvo == null &&
            partes.length >= 4 &&
            partes[0] == 'serie' &&
            partes[1] == 'serie') {
          serieIdAlvo = 'serie_${partes[2]}';
        } else if (serieIdAlvo == null &&
            partes.length >= 3 &&
            partes[0] == 'serie') {
          serieIdAlvo =
              partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
        }

        if (serieIdAlvo != null) {
          onProgresso(0.3, 'A criar/atualizar exceção...');

          // Criar ou atualizar exceção para modificar o gabinete deste dia específico
          await DisponibilidadeSerieService.modificarGabineteDataSerie(
            serieId: serieIdAlvo,
            medicoId: medicoId,
            data: dataNormalizada,
            novoGabineteId: gabineteDestino,
            unidade: unidade,
          );

          // A gravação aguardada acima já confirmou a persistência. Não reler
          // todas as exceções do ano nem usar esperas fixas de sincronização.
          onProgresso(0.9, 'A atualizar o mapa...');
          await onAtualizarEstado();
          onProgresso(1.0, 'Completo!');

          return true;
        }
      }

      // Se não é série, usar lógica de alocação normal
      // Remover alocação antiga e criar nova
      onProgresso(0.5, 'A atualizar alocação...');

      // CORREÇÃO CRÍTICA: Invalidar cache ANTES de realocar
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

      // Criar nova alocação no destino
      await onAlocarMedico(
        medicoId,
        gabineteDestino,
        dataEspecifica: data,
        horarios: horarios,
      );

      // CORREÇÃO CRÍTICA: Invalidar cache novamente APÓS realocar
      // Garantir que o cache seja invalidado tanto antes quanto depois para máxima confiabilidade
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

      // Invalidar também cache de séries se houver alguma série relacionada
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      SerieService.invalidateCacheSeries(unidadeId, medicoId);

      onProgresso(1.0, 'Completo!');
      await Future.delayed(const Duration(milliseconds: 300));

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
