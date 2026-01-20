import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';

class AlocacaoMedicosSearchUtils {
  static List<Medico> medicosAlocadosNoDia({
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
    required DateTime data,
  }) {
    final medicosPorId = {for (final m in medicos) m.id: m};
    final vistos = <String>{};
    final medicosAlocados = <Medico>[];
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    for (final alocacao in alocacoes) {
      final alocDate = DateTime(
        alocacao.data.year,
        alocacao.data.month,
        alocacao.data.day,
      );
      if (alocDate != dataNormalizada) continue;
      final medico = medicosPorId[alocacao.medicoId];
      if (medico == null || !medico.ativo) continue;
      if (vistos.add(medico.id)) {
        medicosAlocados.add(medico);
      }
    }
    return medicosAlocados;
  }

  static List<String> opcoesPesquisaNome(List<Medico> medicosAlocados) {
    final nomes = medicosAlocados.map((m) => m.nome).toList();
    nomes.sort();
    return nomes;
  }

  static List<String> opcoesPesquisaEspecialidade(
      List<Medico> medicosAlocados) {
    final especialidades =
        medicosAlocados.map((m) => m.especialidade).toSet().toList();
    especialidades.sort();
    return especialidades;
  }

  static Set<String> medicosDestacados({
    required List<Medico> medicosAlocados,
    String? pesquisaNome,
    String? pesquisaEspecialidade,
  }) {
    final destacados = <String>{};
    if (pesquisaNome != null && pesquisaNome.isNotEmpty) {
      for (final medico in medicosAlocados) {
        if (medico.nome == pesquisaNome) {
          destacados.add(medico.id);
          break;
        }
      }
      return destacados;
    }

    if (pesquisaEspecialidade != null && pesquisaEspecialidade.isNotEmpty) {
      for (final medico in medicosAlocados) {
        if (medico.especialidade == pesquisaEspecialidade) {
          destacados.add(medico.id);
        }
      }
    }
    return destacados;
  }

  static List<String> especialidadesGabinetes(List<Gabinete> gabinetes) {
    final especialidades = <String>{};
    for (final gabinete in gabinetes) {
      especialidades.addAll(gabinete.especialidadesPermitidas);
    }
    final lista = especialidades.toList();
    lista.sort();
    return lista;
  }
}
