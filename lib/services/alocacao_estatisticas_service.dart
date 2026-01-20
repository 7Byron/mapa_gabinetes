import '../models/alocacao.dart';
import '../models/estatisticas_alocacao.dart';
import '../models/gabinete.dart';

class AlocacaoEstatisticasService {
  static EstatisticasAlocacaoData calcular({
    required DateTime selectedDate,
    required List<Alocacao> alocacoes,
    required List<Gabinete> gabinetes,
    required int numMedicosPorAlocar,
  }) {
    final dataAlvo = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final medicosAlocadosIds = alocacoes
        .where((a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return aDate == dataAlvo;
        })
        .map((a) => a.medicoId)
        .toSet();

    final gabinetesOcupadosIds = alocacoes
        .where((a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return aDate == dataAlvo;
        })
        .map((a) => a.gabineteId)
        .toSet();

    final numGabinetesOcupados = gabinetesOcupadosIds.length;
    final numGabinetesLivres = gabinetes.length - numGabinetesOcupados;

    return EstatisticasAlocacaoData(
      numMedicosAlocados: medicosAlocadosIds.length,
      numMedicosPorAlocar: numMedicosPorAlocar,
      numGabinetesOcupados: numGabinetesOcupados,
      numGabinetesLivres: numGabinetesLivres,
    );
  }
}
