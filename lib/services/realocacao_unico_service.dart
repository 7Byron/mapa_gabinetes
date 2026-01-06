/// Serviço para realocação única: de um gabinete para outro gabinete (apenas um dia)
///
/// Este serviço lida com a realocação de um médico de um gabinete para outro
/// em uma data específica (realocação única, não série).
library;

import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../models/excecao_serie.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';
import 'dart:convert';

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
    required List<Alocacao> alocacoes,
    required Unidade? unidade,
    required BuildContext context,
    void Function(String medicoId, String gabineteOrigem,
            String gabineteDestino, DateTime data)?
        onRealocacaoOtimista,
    required Future<void> Function(String medicoId, String gabineteId,
            {DateTime? dataEspecifica})
        onAlocarMedico,
    required VoidCallback onAtualizarEstado,
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
            return a.medicoId == medicoId &&
                a.gabineteId == gabineteDestino &&
                aDate == dataNormalizada;
          },
        );
      } catch (e) {
        try {
          alocacaoOrigem = alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              return a.medicoId == medicoId &&
                  a.gabineteId == gabineteOrigem &&
                  aDate == dataNormalizada;
            },
          );
        } catch (e2) {
          // Não encontrou alocação, criar nova
          await onAlocarMedico(medicoId, gabineteDestino, dataEspecifica: data);
          return true;
        }
      }

      // Verificar se é alocação de série
      final eAlocacaoDeSerie = alocacaoOrigem.id.startsWith('serie_');

      if (eAlocacaoDeSerie) {

        // Extrair ID da série
        String? serieId;
        final partes = alocacaoOrigem.id.split('_');

        if (partes.length >= 4 &&
            partes[0] == 'serie' &&
            partes[1] == 'serie') {
          serieId = 'serie_${partes[2]}';
        } else if (partes.length >= 3 && partes[0] == 'serie') {
          serieId =
              partes[1].startsWith('serie') ? partes[1] : 'serie_${partes[1]}';
        }

        if (serieId != null) {
          onProgresso(0.3, 'A criar/atualizar exceção...');

          // CORREÇÃO CRÍTICA: Verificar se já existe uma exceção para esta data
          // Se existir, atualizar; se não, criar nova
          final excecoesExistentes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataNormalizada,
            dataFim: dataNormalizada,
            serieId: serieId,
            forcarServidor:
                true, // Forçar servidor para garantir dados atualizados
          );

          final excecaoExistente = excecoesExistentes.firstWhere(
            (e) =>
                e.serieId == serieId &&
                e.data.year == dataNormalizada.year &&
                e.data.month == dataNormalizada.month &&
                e.data.day == dataNormalizada.day &&
                !e.cancelada,
            orElse: () => ExcecaoSerie(
              id: '',
              serieId: '',
              data: DateTime(1900, 1, 1),
            ),
          );

          // Criar ou atualizar exceção para modificar o gabinete deste dia específico
          await DisponibilidadeSerieService.modificarGabineteDataSerie(
            serieId: serieId,
            medicoId: medicoId,
            data: dataNormalizada,
            novoGabineteId: gabineteDestino,
            unidade: unidade,
          );

          onProgresso(0.5, 'A verificar exceção...');

          // Verificar se a exceção foi salva
          bool excecaoEncontrada = false;
          int tentativas = 0;
          const maxTentativas = 5;

          while (!excecaoEncontrada && tentativas < maxTentativas) {
            await Future.delayed(const Duration(milliseconds: 800));
            tentativas++;
            onProgresso(0.5 + (tentativas / maxTentativas) * 0.3,
                'A verificar exceção... ($tentativas/$maxTentativas)');

            try {
              final excecoes = await SerieService.carregarExcecoes(
                medicoId,
                unidade: unidade,
                dataInicio: dataNormalizada,
                dataFim: dataNormalizada.add(const Duration(days: 1)),
                serieId: serieId,
                forcarServidor: true,
              );

              final excecao = excecoes.firstWhere(
                (e) =>
                    e.serieId == serieId &&
                    e.data.year == dataNormalizada.year &&
                    e.data.month == dataNormalizada.month &&
                    e.data.day == dataNormalizada.day &&
                    e.gabineteId == gabineteDestino &&
                    !e.cancelada,
                orElse: () => ExcecaoSerie(
                  id: '',
                  serieId: '',
                  data: DateTime(1900, 1, 1),
                ),
              );

              if (excecao.id.isNotEmpty) {
                excecaoEncontrada = true;
              }
            } catch (e) {
              // Continuar tentando
            }
          }

          onProgresso(0.8, 'A sincronizar...');
          await Future.delayed(const Duration(milliseconds: 300));
          onProgresso(0.9, 'A sincronizar com servidor...');
          onAtualizarEstado();
          await Future.delayed(const Duration(milliseconds: 300));
          onProgresso(1.0, 'Completo!');
          await Future.delayed(const Duration(milliseconds: 300));

          return true;
        }
      }

      // Se não é série, usar lógica de alocação normal
      // Remover alocação antiga e criar nova
      onProgresso(0.5, 'A atualizar alocação...');

      // Invalidar cache
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      // Criar nova alocação no destino
      await onAlocarMedico(medicoId, gabineteDestino, dataEspecifica: data);

      // Invalidar cache novamente
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(data.year, 1, 1));

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
