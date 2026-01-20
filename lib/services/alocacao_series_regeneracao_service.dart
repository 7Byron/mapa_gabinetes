import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoSeriesRegeneracaoService {
  static Future<List<Alocacao>> regenerarParaDia({
    required DateTime data,
    required Unidade unidade,
    required List<Alocacao> alocacoes,
  }) async {
    try {
      final dataInicio = DateTime(data.year, data.month, data.day);
      final dataFim = dataInicio.add(const Duration(days: 1));

      final alocacoesSeriesDoDia = alocacoes.where((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        return ad == dataInicio && a.id.startsWith('serie_');
      }).toList();

      if (alocacoesSeriesDoDia.isEmpty) {
        return <Alocacao>[];
      }

      final medicoIds =
          alocacoesSeriesDoDia.map((a) => a.medicoId).toSet().toList();

      final futures = medicoIds.map((medicoId) async {
        final seriesCarregadas = await SerieService.carregarSeries(
          medicoId,
          unidade: unidade,
          dataInicio: null,
          dataFim: dataInicio.add(const Duration(days: 1)),
        );

        final series = seriesCarregadas.where((s) {
          final hasGabinete =
              s.gabineteId != null && s.gabineteId!.isNotEmpty;
          return s.ativo && (hasGabinete || s.mudancasGabinete.isNotEmpty);
        }).toList();

        if (series.isEmpty) {
          return <Alocacao>[];
        }

        final cacheInvalidado =
            logic.AlocacaoMedicosLogic.isCacheInvalidado(dataInicio);
        final excecoesCarregadas = await SerieService.carregarExcecoes(
          medicoId,
          unidade: unidade,
          dataInicio: dataInicio,
          dataFim: dataFim,
          forcarServidor: cacheInvalidado,
        );

        final excecoes = excecoesCarregadas
            .where((e) =>
                e.data.year == dataInicio.year &&
                e.data.month == dataInicio.month &&
                e.data.day == dataInicio.day)
            .toList();

        final seriesComGabinete = series
            .where((s) => s.gabineteId != null && s.gabineteId!.isNotEmpty)
            .toList();

        if (seriesComGabinete.isEmpty) {
          return <Alocacao>[];
        }

        return SerieGenerator.gerarAlocacoes(
          series: seriesComGabinete,
          excecoes: excecoes,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );
      }).toList();

      final resultados = await Future.wait(futures);

      final alocacoesGeradas = <Alocacao>[];
      for (final alocs in resultados) {
        alocacoesGeradas.addAll(alocs);
      }

      return alocacoesGeradas;
    } catch (_) {
      return [];
    }
  }
}
