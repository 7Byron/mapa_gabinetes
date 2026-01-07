import 'package:flutter/foundation.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../utils/series_helper.dart';

/// Serviço para criar exceções de séries
/// Extracted from cadastro_medicos.dart to reduce code size
class ExcecaoSerieCriacaoService {
  /// Verifica se uma data corresponde ao padrão de uma série
  static bool verificarDataCorrespondeSerie(
      DateTime data, SerieRecorrencia serie) {
    switch (serie.tipo) {
      case 'Semanal':
        return data.weekday == serie.dataInicio.weekday;
      case 'Quinzenal':
        final diff = data.difference(serie.dataInicio).inDays;
        return diff >= 0 && diff % 14 == 0;
      case 'Mensal':
        final ocorrencia =
            SeriesHelper.descobrirOcorrenciaNoMes(serie.dataInicio);
        final ocorrenciaAtual = SeriesHelper.descobrirOcorrenciaNoMes(data);
        return data.weekday == serie.dataInicio.weekday &&
            ocorrenciaAtual == ocorrencia;
      case 'Consecutivo':
        final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
        final diff = data.difference(serie.dataInicio).inDays;
        return diff >= 0 && diff < numeroDias;
      default:
        return data.year == serie.dataInicio.year &&
            data.month == serie.dataInicio.month &&
            data.day == serie.dataInicio.day;
    }
  }

  /// Verifica se uma data está dentro do período de uma série
  static bool verificarDataDentroPeriodoSerie(
      DateTime data, SerieRecorrencia serie) {
    return data.isAfter(serie.dataInicio.subtract(const Duration(days: 1))) &&
        (serie.dataFim == null ||
            data.isBefore(serie.dataFim!.add(const Duration(days: 1))));
  }

  /// Cria exceções para um período de datas em todas as séries ativas
  /// Retorna o número total de exceções criadas
  static Future<int> criarExcecoesParaPeriodoGeral(
    List<SerieRecorrencia> series,
    List<ExcecaoSerie> excecoesExistentes,
    DateTime dataInicio,
    DateTime dataFim,
    String medicoId,
    Function(ExcecaoSerie) onExcecaoCriada,
  ) async {
    int totalExcecoesCriadas = 0;

    for (final serie in series) {
      if (!serie.ativo) continue;

      DateTime dataAtual = dataInicio;
      while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
        if (verificarDataDentroPeriodoSerie(dataAtual, serie) &&
            verificarDataCorrespondeSerie(dataAtual, serie)) {
          final excecaoId =
              'excecao_${serie.id}_${dataAtual.millisecondsSinceEpoch}';

          // Verificar se já existe exceção para esta data
          final jaExiste = excecoesExistentes.any((e) =>
              e.serieId == serie.id &&
              e.data.year == dataAtual.year &&
              e.data.month == dataAtual.month &&
              e.data.day == dataAtual.day);

          if (!jaExiste) {
            // CORREÇÃO CRÍTICA: Normalizar a data antes de criar a exceção
            // Isso garante correspondência exata na busca
            final dataNormalizada = DateTime(
              dataAtual.year,
              dataAtual.month,
              dataAtual.day,
            );
            
            final excecao = ExcecaoSerie(
              id: excecaoId,
              serieId: serie.id,
              data: dataNormalizada,
              cancelada: true,
            );

            debugPrint('➕ [CRIAR EXCEÇÃO] Série=${serie.id}, Data=${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}, Chave esperada=${serie.id}_${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}');
            
            onExcecaoCriada(excecao);
            totalExcecoesCriadas++;
          }
        }

        dataAtual = dataAtual.add(const Duration(days: 1));
      }
    }

    return totalExcecoesCriadas;
  }

  /// Cria exceções para um período de datas em uma série específica
  /// Retorna o número de exceções criadas
  static Future<int> criarExcecoesParaPeriodoSerie(
    SerieRecorrencia serie,
    List<ExcecaoSerie> excecoesExistentes,
    DateTime dataInicio,
    DateTime dataFim,
    String medicoId,
    Function(ExcecaoSerie) onExcecaoCriada,
  ) async {
    int excecoesCriadas = 0;

    DateTime dataAtual = dataInicio;
    while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
      if (verificarDataDentroPeriodoSerie(dataAtual, serie) &&
          verificarDataCorrespondeSerie(dataAtual, serie)) {
        final excecaoId =
            'excecao_${serie.id}_${dataAtual.millisecondsSinceEpoch}';

        // Verificar se já existe exceção para esta data
        final jaExiste = excecoesExistentes.any((e) =>
            e.serieId == serie.id &&
            e.data.year == dataAtual.year &&
            e.data.month == dataAtual.month &&
            e.data.day == dataAtual.day);

        if (!jaExiste) {
          // CORREÇÃO CRÍTICA: Normalizar a data antes de criar a exceção
          // Isso garante correspondência exata na busca
          final dataNormalizada = DateTime(
            dataAtual.year,
            dataAtual.month,
            dataAtual.day,
          );
          
          final excecao = ExcecaoSerie(
            id: excecaoId,
            serieId: serie.id,
            data: dataNormalizada,
            cancelada: true,
          );

          debugPrint('➕ [CRIAR EXCEÇÃO SÉRIE] Série=${serie.id}, Data=${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}, Chave esperada=${serie.id}_${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}');
          
          onExcecaoCriada(excecao);
          excecoesCriadas++;
        }
      }

      dataAtual = dataAtual.add(const Duration(days: 1));
    }

    return excecoesCriadas;
  }
}
