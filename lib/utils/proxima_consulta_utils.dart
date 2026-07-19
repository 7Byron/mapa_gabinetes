import '../models/alocacao.dart';
import '../models/medico.dart';

class ProximaConsultaItem {
  final Alocacao alocacao;
  final Medico medico;

  const ProximaConsultaItem({
    required this.alocacao,
    required this.medico,
  });
}

class ProximaConsultaUtils {
  static List<ProximaConsultaItem> encontrar({
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
    required DateTime desde,
    String? medicoId,
    String? especialidade,
    int limite = 5,
  }) {
    if (medicoId == null && especialidade == null) return const [];

    final inicioDoDia = DateTime(desde.year, desde.month, desde.day);
    final medicosPorId = {for (final medico in medicos) medico.id: medico};
    final itens = <ProximaConsultaItem>[];

    for (final alocacao in alocacoes) {
      final medico = medicosPorId[alocacao.medicoId];
      if (medico == null || alocacao.data.isBefore(inicioDoDia)) continue;
      if (medicoId != null && medico.id != medicoId) continue;
      if (especialidade != null && medico.especialidade != especialidade) {
        continue;
      }
      itens.add(ProximaConsultaItem(alocacao: alocacao, medico: medico));
    }

    itens.sort((a, b) {
      final porData = a.alocacao.data.compareTo(b.alocacao.data);
      if (porData != 0) return porData;
      return a.alocacao.horarioInicio.compareTo(b.alocacao.horarioInicio);
    });

    return itens.take(limite).toList();
  }
}
