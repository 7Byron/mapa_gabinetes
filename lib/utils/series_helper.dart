import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';

/// Helper functions for series (séries) management
/// Extracted from cadastro_medicos.dart to improve code organization
class SeriesHelper {
  /// Extrai o ID da série a partir do ID da disponibilidade
  /// Formato esperado: 'serie_{serieId}_{dataKey}' ou 'serie_serie_{timestamp}_{dataKey}'
  /// Retorna o ID da série formatado (sempre com prefixo 'serie_')
  static String extrairSerieIdDeDisponibilidade(String disponibilidadeId) {
    // Padrão para encontrar o sufixo de data: _YYYY-MM-DD
    final dataKeyPattern = RegExp(r'_\d{4}-\d{2}-\d{2}$');
    final match = dataKeyPattern.firstMatch(disponibilidadeId);

    if (match != null) {
      final serieId = disponibilidadeId.substring(0, match.start);
      // Garantir que tem o prefixo 'serie_'
      return serieId.startsWith('serie_') ? serieId : 'serie_$serieId';
    }

    // Se não encontrou padrão, retornar como está (pode ser um ID direto)
    return disponibilidadeId.startsWith('serie_')
        ? disponibilidadeId
        : 'serie_$disponibilidadeId';
  }

  /// Verifica se uma data corresponde ao padrão de uma série
  /// Retorna true se a data corresponde ao tipo de recorrência da série
  static bool verificarDataCorrespondeAoPadraoSerie(
    DateTime data,
    SerieRecorrencia serie,
  ) {
    switch (serie.tipo) {
      case 'Semanal':
        // Para semanal, verificar se o dia da semana corresponde
        return data.weekday == serie.dataInicio.weekday;
      case 'Quinzenal':
        // Para quinzenal, verificar se a diferença em dias é múltipla de 14
        final diffDias = data.difference(serie.dataInicio).inDays;
        return diffDias >= 0 && diffDias % 14 == 0;
      case 'Mensal':
        // Para mensal, verificar se o dia do mês corresponde
        return data.day == serie.dataInicio.day;
      default:
        // Para outros tipos, apenas verificar se está no período
        return true;
    }
  }

  /// Descobre a ocorrência de um dia no mês (1ª segunda, 2ª terça, etc.)
  /// Usado para séries mensais
  static int descobrirOcorrenciaNoMes(DateTime data) {
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

  /// Agrupa exceções por período (datas consecutivas da mesma série)
  static List<Map<String, dynamic>> agruparExcecoesPorPeriodo(
    List<ExcecaoSerie> excecoes,
    List<SerieRecorrencia> series,
  ) {
    if (excecoes.isEmpty) return [];

    // Ordenar exceções por data
    final excecoesOrdenadas = List<ExcecaoSerie>.from(excecoes);
    excecoesOrdenadas.sort((a, b) => a.data.compareTo(b.data));

    final grupos = <Map<String, dynamic>>[];
    List<ExcecaoSerie>? grupoAtual;
    DateTime? dataFimGrupo;

    for (final excecao in excecoesOrdenadas) {
      if (grupoAtual == null) {
        // Iniciar novo grupo
        grupoAtual = [excecao];
        dataFimGrupo = excecao.data;
      } else {
        // Verificar se é data consecutiva (mesma série e data seguinte)
        final ultimaData = dataFimGrupo!;
        final dataEsperada = ultimaData.add(const Duration(days: 1));
        final mesmaSerie = grupoAtual.first.serieId == excecao.serieId;
        final dataConsecutiva = excecao.data.year == dataEsperada.year &&
            excecao.data.month == dataEsperada.month &&
            excecao.data.day == dataEsperada.day;

        if (mesmaSerie && dataConsecutiva) {
          // Adicionar ao grupo atual
          grupoAtual.add(excecao);
          dataFimGrupo = excecao.data;
        } else {
          // Finalizar grupo atual e iniciar novo
          final serie = series.firstWhere(
            (s) => s.id == grupoAtual!.first.serieId,
            orElse: () => series.isNotEmpty
                ? series.first
                : SerieRecorrencia(
                    id: '',
                    medicoId: '',
                    dataInicio: DateTime.now(),
                    tipo: '',
                    horarios: [],
                  ),
          );

          grupos.add({
            'excecoes': List<ExcecaoSerie>.from(grupoAtual),
            'serie': serie,
            'dataInicio': grupoAtual.first.data,
            'dataFim': dataFimGrupo,
            'isPeriodo': grupoAtual.length > 1,
          });

          grupoAtual = [excecao];
          dataFimGrupo = excecao.data;
        }
      }
    }

    // Adicionar último grupo
    if (grupoAtual != null && grupoAtual.isNotEmpty) {
      final serie = series.firstWhere(
        (s) => s.id == grupoAtual!.first.serieId,
        orElse: () => series.isNotEmpty
            ? series.first
            : SerieRecorrencia(
                id: '',
                medicoId: '',
                dataInicio: DateTime.now(),
                tipo: '',
                horarios: [],
              ),
      );

      grupos.add({
        'excecoes': grupoAtual,
        'serie': serie,
        'dataInicio': grupoAtual.first.data,
        'dataFim': dataFimGrupo!,
        'isPeriodo': grupoAtual.length > 1,
      });
    }

    return grupos;
  }
}
