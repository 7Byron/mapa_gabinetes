import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/medico.dart';

class MedicosNaoAlocadosResultado {
  final List<Medico> medicosComDiasNaoAlocados;
  final Map<String, int> medicosComDias;
  final Map<String, List<DateTime>> medicosComDatas;

  const MedicosNaoAlocadosResultado({
    required this.medicosComDiasNaoAlocados,
    required this.medicosComDias,
    required this.medicosComDatas,
  });
}

class AlocacaoMedicosNaoAlocadosService {
  static MedicosNaoAlocadosResultado calcular({
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required int ano,
    void Function(int processed, int total)? onProgress,
  }) {
    final medicosComDisponibilidade = disponibilidades
        .where((d) => d.data.year == ano)
        .map((d) => d.medicoId)
        .toSet();

    final medicosNaoAlocadosIds = medicosComDisponibilidade.toList();

    final medicosNaoAlocados = medicosNaoAlocadosIds
        .map((id) => medicos.firstWhere(
              (m) => m.id == id,
              orElse: () => Medico(
                id: id,
                nome: 'Desconhecido',
                especialidade: '',
                disponibilidades: [],
                ativo: false,
              ),
            ))
        .where((m) => m.ativo && m.nome != 'Desconhecido')
        .toList();

    medicosNaoAlocados.sort((a, b) => a.nome.compareTo(b.nome));

    final medicosComDias = <String, int>{};
    final medicosComDatas = <String, List<DateTime>>{};

    final totalMedicos = medicosNaoAlocadosIds.length;
    var processedMedicos = 0;

    for (final medicoId in medicosNaoAlocadosIds) {
      final diasComDisponibilidade = disponibilidades
          .where((d) =>
              d.medicoId == medicoId &&
              d.data.year == ano &&
              !alocacoes.any((a) =>
                  a.medicoId == medicoId &&
                  a.data.year == d.data.year &&
                  a.data.month == d.data.month &&
                  a.data.day == d.data.day))
          .map((d) => DateTime(d.data.year, d.data.month, d.data.day))
          .toSet()
          .toList();
      diasComDisponibilidade.sort();

      medicosComDias[medicoId] = diasComDisponibilidade.length;
      medicosComDatas[medicoId] = diasComDisponibilidade;

      processedMedicos++;
      onProgress?.call(processedMedicos, totalMedicos);
    }

    final medicosComDiasNaoAlocados = medicosNaoAlocados
        .where((m) => (medicosComDias[m.id] ?? 0) > 0)
        .toList();

    return MedicosNaoAlocadosResultado(
      medicosComDiasNaoAlocados: medicosComDiasNaoAlocados,
      medicosComDias: medicosComDias,
      medicosComDatas: medicosComDatas,
    );
  }
}
