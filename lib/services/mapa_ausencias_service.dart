import '../models/alocacao.dart';
import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import 'serie_generator.dart';
import 'serie_service.dart';

/// Cartões apenas visuais: não constituem ocupação nem disponibilidade.
class MapaAusenciasService {
  static List<Alocacao> gerar({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
    required DateTime data,
  }) {
    final dia = DateTime(data.year, data.month, data.day);
    final canceladas = excecoes.where((e) =>
        e.cancelada && DateTime(e.data.year, e.data.month, e.data.day) == dia);
    final ids = canceladas.map((e) => e.serieId).toSet();
    // Recuperar a ocorrência prevista sem reativar a consulta cancelada.
    return SerieGenerator.gerarAlocacoes(
      series: series.where((s) => ids.contains(s.id)).toList(),
      excecoes: const [],
      dataInicio: dia,
      dataFim: dia,
    ).where((a) => a.gabineteId.isNotEmpty).toList();
  }

  static Future<List<Alocacao>> carregar({
    required Unidade unidade,
    required List<String> medicoIds,
    required DateTime data,
  }) async {
    if (medicoIds.isEmpty) return [];
    final series = await SerieService.carregarSeriesDeMedicos(
      medicoIds,
      unidade: unidade,
      dataFim: data,
    );
    final resultados = await Future.wait(medicoIds.map((id) async {
      final excecoes = await SerieService.carregarExcecoes(
        id,
        unidade: unidade,
        dataInicio: data,
        dataFim: data,
      );
      return gerar(series: series[id] ?? [], excecoes: excecoes, data: data);
    }));
    return resultados.expand((a) => a).toList();
  }
}
