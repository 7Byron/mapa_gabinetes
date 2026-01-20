import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoMedicosDisponiveisService {
  static Future<List<Medico>> calcular({
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required String unidadeId,
    required DateTime data,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    final medicosAlocados = alocacoes
        .where((a) {
          final ad = DateTime(a.data.year, a.data.month, a.data.day);
          return ad == dataNormalizada;
        })
        .map((a) => a.medicoId)
        .toSet();

    final datasComExcecoesCanceladas =
        await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      unidadeId,
      data,
    );

    final medicosComDisponibilidade = <String>{};
    for (final d in disponibilidades) {
      final dd = DateTime(d.data.year, d.data.month, d.data.day);
      if (dd != dataNormalizada) continue;
      final dataKey = '${d.medicoId}_${d.data.year}-${d.data.month}-${d.data.day}';
      final temExcecaoCancelada = datasComExcecoesCanceladas.contains(dataKey);
      if (!temExcecaoCancelada) {
        medicosComDisponibilidade.add(d.medicoId);
      }
    }

    return medicos.where((m) {
      if (!m.ativo) return false;
      if (medicosAlocados.contains(m.id)) return false;
      final dataKey = '${m.id}_${data.year}-${data.month}-${data.day}';
      if (datasComExcecoesCanceladas.contains(dataKey)) {
        return false;
      }
      return medicosComDisponibilidade.contains(m.id);
    }).toList();
  }
}
