import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../utils/alocacao_alocacoes_merge_utils.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoGabinetesReloadService {
  static Future<List<Alocacao>> recarregar({
    required Unidade unidade,
    required DateTime data,
    required List<Alocacao> alocacoesAtuais,
    required List<String> gabineteIds,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

    final novasAlocacoes = await logic.AlocacaoMedicosLogic.carregarAlocacoesUnidade(
      unidade,
      dataFiltroDia: dataNormalizada,
    );

    return AlocacaoAlocacoesMergeUtils.atualizarAlocacoesGabinetes(
      alocacoesAtuais: alocacoesAtuais,
      novasAlocacoes: novasAlocacoes,
      gabineteIds: gabineteIds,
      data: dataNormalizada,
    );
  }
}
