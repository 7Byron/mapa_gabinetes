import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../utils/series_helper.dart';

class AlocacaoMedicosDisponiveisService {
  static Future<List<Medico>> calcular({
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required String unidadeId,
    required DateTime data,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    final datasComExcecoesCanceladas =
        await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      unidadeId,
      data,
    );

    final medicosComDisponibilidade = <String>{};
    for (final d in disponibilidades) {
      final dd = DateTime(d.data.year, d.data.month, d.data.day);
      if (dd != dataNormalizada) continue;
      final dataKey =
          '${d.medicoId}_${d.data.year}-${d.data.month}-${d.data.day}';
      final temExcecaoCancelada = datasComExcecoesCanceladas.contains(dataKey);
      final serieId = d.id.startsWith('serie_')
          ? SeriesHelper.extrairSerieIdDeDisponibilidade(d.id)
          : null;
      final disponibilidadeJaAlocada = alocacoes.any((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        if (a.medicoId != d.medicoId || ad != dataNormalizada) return false;
        if (serieId != null) return a.id.contains(serieId);
        return a.horarioInicio == d.horarios.firstOrNull &&
            a.horarioFim == d.horarios.lastOrNull;
      });
      if (!temExcecaoCancelada && !disponibilidadeJaAlocada) {
        medicosComDisponibilidade.add(d.medicoId);
      }
    }

    return medicos.where((m) {
      if (!m.ativo) return false;
      final dataKey = '${m.id}_${data.year}-${data.month}-${data.day}';
      if (datasComExcecoesCanceladas.contains(dataKey)) {
        return false;
      }
      return medicosComDisponibilidade.contains(m.id);
    }).toList();
  }
}
