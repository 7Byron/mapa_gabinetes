import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import 'serie_generator.dart';
import 'serie_service.dart';

/// Cartões apenas visuais: não constituem ocupação nem disponibilidade.
class MapaAusenciasService {
  /// As leituras de alocações e exceções podem terminar em momentos diferentes.
  /// Uma ausência já confirmada substitui a cópia ativa da mesma ocorrência.
  static ({List<Alocacao> ativas, List<Alocacao> ausencias}) conciliar({
    required List<Alocacao> alocacoes,
    required List<Alocacao> ausencias,
  }) {
    (String, String, DateTime) chave(Alocacao a) => (
          a.medicoId,
          a.id,
          DateTime(a.data.year, a.data.month, a.data.day),
        );
    final ausenciasPorChave = {for (final a in ausencias) chave(a): a};
    return (
      ativas: alocacoes
          .where((a) => !ausenciasPorChave.containsKey(chave(a)))
          .toList(),
      ausencias: ausenciasPorChave.values.toList(),
    );
  }

  static List<Alocacao> gerar({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
    required DateTime data,
  }) {
    final dia = DateTime(data.year, data.month, data.day);
    final canceladas = excecoes.where((e) =>
        e.cancelada &&
        !e.ocultarCartao &&
        DateTime(e.data.year, e.data.month, e.data.day) == dia);
    final ids = canceladas.map((e) => e.serieId).toSet();
    // Recuperar a ocorrência prevista sem reativar a consulta cancelada.
    return SerieGenerator.gerarAlocacoes(
      series: series.where((s) => ids.contains(s.id)).toList(),
      // Recuperar também o gabinete/horário pontual que existia antes da ausência.
      excecoes: canceladas
          .where((e) => e.gabineteId != null || e.horarios != null)
          .map((e) => ExcecaoSerie(
                id: e.id,
                serieId: e.serieId,
                data: e.data,
                horarios: e.horarios,
                gabineteId: e.gabineteId ??
                    series
                        .where((s) => s.id == e.serieId)
                        .firstOrNull
                        ?.obterGabineteParaData(dia),
              ))
          .toList(),
      dataInicio: dia,
      dataFim: dia,
    ).where((a) => a.gabineteId.isNotEmpty).toList();
  }

  /// Projeção exclusiva da apresentação: não entra nas disponibilidades ativas.
  static ({List<Disponibilidade> disponibilidades, List<Alocacao> alocacoes})
      projetarCartoesAusentes({
    required List<SerieRecorrencia> series,
    required List<ExcecaoSerie> excecoes,
  }) {
    final disponibilidades = <Disponibilidade>[];
    final alocacoes = <Alocacao>[];
    final dias = excecoes
        .where((e) => e.cancelada && !e.ocultarCartao)
        .map((e) => DateTime(e.data.year, e.data.month, e.data.day))
        .toSet();
    for (final dia in dias) {
      final canceladas = excecoes
          .where((e) =>
              e.cancelada &&
              !e.ocultarCartao &&
              DateTime(e.data.year, e.data.month, e.data.day) == dia)
          .toList();
      final ids = canceladas.map((e) => e.serieId).toSet();
      disponibilidades.addAll(SerieGenerator.gerarDisponibilidades(
        series: series.where((s) => ids.contains(s.id)).toList(),
        excecoes: canceladas
            .map((e) => ExcecaoSerie(
                  id: e.id,
                  serieId: e.serieId,
                  data: e.data,
                  horarios: e.horarios,
                  gabineteId: e.gabineteId,
                ))
            .toList(),
        dataInicio: dia,
        dataFim: dia,
      ));
      alocacoes.addAll(gerar(series: series, excecoes: canceladas, data: dia));
    }
    return (disponibilidades: disponibilidades, alocacoes: alocacoes);
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
