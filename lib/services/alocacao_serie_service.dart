/// Serviço para alocação de série: dos desalocados para um gabinete (toda a série)
/// 
/// Este serviço lida com a alocação de um médico que está nos desalocados
/// para um gabinete específico em toda a série (não apenas um dia).
library;

import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';

class AlocacaoSerieService {
  /// Aloca um médico dos desalocados para um gabinete em toda a série
  /// 
  /// [medicoId] - ID do médico a ser alocado
  /// [gabineteId] - ID do gabinete de destino
  /// [data] - Data de referência da alocação
  /// [disponibilidade] - Disponibilidade do médico para a data
  /// [unidade] - Unidade para buscar séries
  /// [onAlocacaoSerieOtimista] - Callback opcional para atualização otimista
  /// [onAtualizarEstado] - Callback para atualizar o estado após alocação
  /// [onProgresso] - Callback para atualizar progresso (progresso, mensagem)
  /// [context] - Contexto do Flutter para mostrar mensagens
  /// 
  /// Retorna true se a alocação foi bem-sucedida, false caso contrário
  static Future<bool> alocar({
    required String medicoId,
    required String gabineteId,
    required DateTime data,
    required Disponibilidade disponibilidade,
    required Unidade? unidade,
    required BuildContext context,
    void Function(String medicoId, String gabineteId, DateTime data)? onAlocacaoSerieOtimista,
    required VoidCallback onAtualizarEstado,
    required void Function(double progresso, String mensagem) onProgresso,
    String? serieIdExtraido,
  }) async {

    try {
      final dataRefNormalizada = DateTime(data.year, data.month, data.day);

      // ATUALIZAÇÃO OTIMISTA: Remover cartão dos desalocados e criar alocação temporária IMEDIATAMENTE
      if (onAlocacaoSerieOtimista != null) {
        onAlocacaoSerieOtimista(medicoId, gabineteId, dataRefNormalizada);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      onProgresso(0.1, 'A verificar série...');

      if (unidade == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro: Unidade não definida'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      onProgresso(0.2, 'A localizar série...');

      // Normalizar o tipo da série
      final tipoDisponibilidade = disponibilidade.tipo;
      final tipoNormalizado =
          tipoDisponibilidade.startsWith('Consecutivo')
              ? 'Consecutivo'
              : tipoDisponibilidade;

      // Extrair número de dias para séries consecutivas
      int? numeroDiasConsecutivo;
      if (tipoNormalizado == 'Consecutivo') {
        final match = RegExp(r'Consecutivo:(\d+)')
            .firstMatch(tipoDisponibilidade);
        numeroDiasConsecutivo = match != null
            ? int.tryParse(match.group(1) ?? '') ?? 5
            : 5;
      }

      // Usar horários da disponibilidade
      final horariosRef =
          disponibilidade.horarios.isNotEmpty
              ? disponibilidade.horarios
              : ['08:00', '15:00']; // Fallback

      // CORREÇÃO: Se temos o ID da série extraído do ID da disponibilidade,
      // usar diretamente em vez de procurar pela data/tipo
      SerieRecorrencia? serieEncontrada;

      if (serieIdExtraido != null) {
        try {
          final series = await SerieService.carregarSeries(
            medicoId,
            unidade: unidade,
          );
          serieEncontrada = series.firstWhere(
            (s) => s.id == serieIdExtraido,
            orElse: () => SerieRecorrencia(
              id: '',
              medicoId: '',
              dataInicio: DateTime(1900, 1, 1),
              tipo: '',
              horarios: [],
              parametros: {},
              ativo: false,
            ),
          );
          if (serieEncontrada.id.isEmpty) {
            serieEncontrada = null;
          }
        } catch (e) {
          serieEncontrada = null;
        }
      }

      // Se não encontrou pelo ID, tentar encontrar pela data/tipo
      if (serieEncontrada == null || serieEncontrada.id.isEmpty) {
        serieEncontrada = await _encontrarSerieCorrespondente(
          medicoId: medicoId,
          tipo: tipoDisponibilidade,
          data: dataRefNormalizada,
          unidade: unidade,
        );
      }

      // Para séries consecutivas, verificar se o número de dias corresponde
      if (serieEncontrada != null &&
          tipoNormalizado == 'Consecutivo' &&
          numeroDiasConsecutivo != null) {
        final numeroDiasSerie = serieEncontrada
                .parametros['numeroDias'] as int? ??
            5;
        if (numeroDiasSerie != numeroDiasConsecutivo) {
          serieEncontrada = null; // Não corresponde
        }
      }

      onProgresso(0.4, serieEncontrada == null
          ? 'A criar série...'
          : 'Série encontrada');

      // Se não encontrou série, criar uma nova
      if (serieEncontrada == null || serieEncontrada.id.isEmpty) {
        
        serieEncontrada = await DisponibilidadeSerieService.criarSerie(
          medicoId: medicoId,
          dataInicial: dataRefNormalizada,
          tipo: tipoDisponibilidade,
          horarios: horariosRef,
          unidade: unidade,
        );
      }

      onProgresso(0.5, 'A alocar série...');
      onProgresso(0.6, 'A atualizar série no servidor...');

      // Verificar se a série já está alocada neste gabinete
      
      if (serieEncontrada.gabineteId == gabineteId) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A série já está alocada neste gabinete.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        onAtualizarEstado();
        return true;
      }

      // Verificar se a série está alocada em outro gabinete
      if (serieEncontrada.gabineteId != null &&
          serieEncontrada.gabineteId != gabineteId) {
        if (context.mounted) {
          final confirmacao = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Série já alocada'),
              content: Text(
                'Esta série já está alocada em outro gabinete.\n\n'
                'Deseja realocar a série para este gabinete?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Realocar'),
                ),
              ],
            ),
          );

          if (confirmacao == false) {
            return false;
          }
        }
      }

      onProgresso(0.7, 'A atualizar série...');

      // Atualizar o gabineteId da série
      await DisponibilidadeSerieService.alocarSerie(
        serieId: serieEncontrada.id,
        medicoId: medicoId,
        gabineteId: gabineteId,
        unidade: unidade,
      );

      onProgresso(0.8, 'A invalidar cache...');

      // CORREÇÃO CRÍTICA: Aguardar mais tempo para garantir que o Firestore salvou completamente a série
      // e que a escrita foi replicada no servidor antes de invalidar o cache
      await Future.delayed(const Duration(milliseconds: 1500));

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      // Buscar a série atualizada do servidor para garantir que temos os dados mais recentes
      // CORREÇÃO: Capturar o ID da série antes de usar no closure para evitar problemas de null safety
      final serieIdParaBuscar = serieEncontrada.id;
      SerieRecorrencia serieAtualizada = serieEncontrada;
      
      try {
        final seriesAtualizadas = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
          forcarServidor: true, // Forçar servidor para garantir dados atualizados
        );
        
        final seriesFiltradas = seriesAtualizadas.where(
          (s) => s.id == serieIdParaBuscar,
        ).toList();
        
        if (seriesFiltradas.isNotEmpty) {
          serieAtualizada = seriesFiltradas.first;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar série atualizada do servidor: $e');
        // Continuar com a série original se houver erro
      }
      
      // Invalidar cache para todos os dias que a série afeta
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada, unidade: unidade);

      await Future.delayed(const Duration(milliseconds: 800));

      onProgresso(0.9, 'A sincronizar...');
      await Future.delayed(const Duration(milliseconds: 500));
      onProgresso(1.0, 'Concluído!');
      await Future.delayed(const Duration(milliseconds: 500));

      // Atualizar estado para sincronizar com o servidor
      onAtualizarEstado();

      return true;
    } catch (e) {

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alocar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Encontra a série correspondente para um tipo e data específicos
  static Future<SerieRecorrencia?> _encontrarSerieCorrespondente({
    required String medicoId,
    required String tipo,
    required DateTime data,
    required Unidade? unidade,
  }) async {
    try {
      final series = await SerieService.carregarSeries(
        medicoId,
        unidade: unidade,
      );

      final tipoNormalizado =
          tipo.startsWith('Consecutivo') ? 'Consecutivo' : tipo;
      final dataNormalizada = DateTime(data.year, data.month, data.day);

      for (final serie in series) {
        if (!serie.ativo) {
          continue;
        }

        // Verificar se a data está dentro do período da série
        if (dataNormalizada.isBefore(serie.dataInicio)) {
          continue;
        }
        if (serie.dataFim != null && dataNormalizada.isAfter(serie.dataFim!)) {
          continue;
        }

        // Verificar padrão da série
        bool corresponde = false;
        if (tipoNormalizado == 'Semanal') {
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          corresponde = weekdayData == weekdaySerie && diasDiferenca % 7 == 0;
        } else if (tipoNormalizado == 'Quinzenal') {
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          corresponde = weekdayData == weekdaySerie && diasDiferenca % 14 == 0;
        } else if (tipoNormalizado == 'Mensal') {
          final weekdayData = dataNormalizada.weekday;
          final weekdaySerie = serie.dataInicio.weekday;
          if (weekdayData == weekdaySerie) {
            final ocorrenciaData = _descobrirOcorrenciaNoMes(dataNormalizada);
            final ocorrenciaSerie = _descobrirOcorrenciaNoMes(serie.dataInicio);
            corresponde = ocorrenciaData == ocorrenciaSerie;
          }
        } else if (tipoNormalizado == 'Consecutivo') {
          final diasDiferenca =
              dataNormalizada.difference(serie.dataInicio).inDays;
          final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
          corresponde = diasDiferenca >= 0 && diasDiferenca < numeroDias;
        }

        if (corresponde) {
          return serie;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
  static int _descobrirOcorrenciaNoMes(DateTime data) {
    final weekday = data.weekday;
    final ano = data.year;
    final mes = data.month;
    final dia = data.day;

    final weekdayDia1 = DateTime(ano, mes, 1).weekday;
    final offset = (weekday - weekdayDia1 + 7) % 7;
    final primeiroDesteMes = 1 + offset;
    final dif = dia - primeiroDesteMes;
    return 1 + (dif ~/ 7);
  }
}

