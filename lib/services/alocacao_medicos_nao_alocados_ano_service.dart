import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_ano_alocacoes_service.dart';
import '../services/alocacao_disponibilidades_ano_service.dart';
import '../services/alocacao_medicos_nao_alocados_service.dart';

class MedicosNaoAlocadosAnoResultado {
  final DisponibilidadesAnoResultado disponibilidades;
  final MedicosNaoAlocadosResultado naoAlocados;

  const MedicosNaoAlocadosAnoResultado({
    required this.disponibilidades,
    required this.naoAlocados,
  });
}

class AlocacaoMedicosNaoAlocadosAnoService {
  static Future<MedicosNaoAlocadosAnoResultado> carregar({
    required Unidade unidade,
    required int ano,
    required List<Medico> medicos,
    void Function(double)? onProgresso,
  }) async {
    onProgresso?.call(0.10);
    final disponibilidadesAno =
        await AlocacaoDisponibilidadesAnoService.carregar(
      unidade: unidade,
      ano: ano,
      medicos: medicos,
      onSeriesCarregadas: () => onProgresso?.call(0.30),
      onUnicasCarregadas: () => onProgresso?.call(0.50),
    );

    final todasAlocacoes = await AlocacaoAnoAlocacoesService.carregar(
      unidade: unidade,
      ano: ano,
      medicos: medicos,
    );

    onProgresso?.call(0.70);
    final resultadoNaoAlocados = AlocacaoMedicosNaoAlocadosService.calcular(
      medicos: medicos,
      disponibilidades: disponibilidadesAno.todas,
      alocacoes: todasAlocacoes,
      ano: ano,
      onProgress: (processed, total) {
        if (total > 0) {
          final progressoProcessamento = 0.70 + (processed / total) * 0.25;
          onProgresso?.call(progressoProcessamento.clamp(0.0, 0.95));
        }
      },
    );

    return MedicosNaoAlocadosAnoResultado(
      disponibilidades: disponibilidadesAno,
      naoAlocados: resultadoNaoAlocados,
    );
  }
}
