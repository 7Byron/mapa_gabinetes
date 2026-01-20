import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/disponibilidade_unica_service.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class DisponibilidadesAnoResultado {
  final List<Disponibilidade> series;
  final List<Disponibilidade> unicas;
  final List<Disponibilidade> todas;
  final List<Medico> medicosAtivos;

  const DisponibilidadesAnoResultado({
    required this.series,
    required this.unicas,
    required this.todas,
    required this.medicosAtivos,
  });
}

class AlocacaoDisponibilidadesAnoService {
  static Future<DisponibilidadesAnoResultado> carregar({
    required Unidade unidade,
    required int ano,
    required List<Medico> medicos,
    void Function()? onSeriesCarregadas,
    void Function()? onUnicasCarregadas,
  }) async {
    final disponibilidadesSeries =
        await logic.AlocacaoMedicosLogic.carregarDisponibilidadesDeSeries(
      unidade: unidade,
      anoEspecifico: ano.toString(),
    );
    onSeriesCarregadas?.call();

    final medicosAtivos = medicos.where((m) => m.ativo).toList();
    final futuresUnicas = medicosAtivos.map((medico) {
      return DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
        medico.id,
        ano,
        unidade,
      ).catchError((_) {
        // Retornar lista vazia em caso de erro
        return <Disponibilidade>[];
      });
    }).toList();

    final resultadosUnicas = await Future.wait(futuresUnicas);
    final disponibilidadesUnicas = <Disponibilidade>[];
    for (final resultado in resultadosUnicas) {
      disponibilidadesUnicas.addAll(resultado);
    }
    onUnicasCarregadas?.call();

    final todasDisponibilidades = <Disponibilidade>[
      ...disponibilidadesSeries,
      ...disponibilidadesUnicas,
    ];

    return DisponibilidadesAnoResultado(
      series: disponibilidadesSeries,
      unicas: disponibilidadesUnicas,
      todas: todasDisponibilidades,
      medicosAtivos: medicosAtivos,
    );
  }
}
