import '../models/taxa_ocupacao.dart';
import '../models/unidade.dart';
import 'relatorios_service.dart';

class RelatorioTaxasOcupacaoService {
  static Future<Map<String, TaxaOcupacao>> carregar({
    required Unidade unidade,
    required DateTime inicio,
    required DateTime fim,
    required List<String> gabineteIds,
  }) async {
    if (fim.isBefore(inicio)) {
      throw ArgumentError(
          'A data final deve ser igual ou posterior à inicial.');
    }
    final taxas = {for (final id in gabineteIds) id: const TaxaOcupacao()};
    await RelatoriosService.ocupacaoPorGabinetesPorDia(
      inicio: inicio,
      fim: fim,
      unidade: unidade,
      gabineteIds: gabineteIds,
      onHorasGabinete: (id, ocupadas, disponiveis) {
        taxas[id] = taxas[id]!.somar(TaxaOcupacao(
          horasOcupadas: ocupadas,
          horasDisponiveis: disponiveis,
        ));
      },
    );
    return taxas;
  }
}
