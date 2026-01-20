import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../utils/alocacao_alocacoes_merge_utils.dart';

class AlocacaoDadosIniciaisMergeService {
  static List<Gabinete> atualizarGabinetes({
    required List<Gabinete> gabinetesAtuais,
    required List<Gabinete> gabinetesNovos,
    required bool recarregarMedicos,
  }) {
    if (!recarregarMedicos &&
        gabinetesNovos.isEmpty &&
        gabinetesAtuais.isNotEmpty) {
      return gabinetesAtuais;
    }
    return gabinetesNovos;
  }

  static List<Medico> atualizarMedicos({
    required List<Medico> medicosAtuais,
    required List<Medico> medicosNovos,
    required bool recarregarMedicos,
  }) {
    if (!recarregarMedicos && medicosNovos.isEmpty && medicosAtuais.isNotEmpty) {
      return medicosAtuais;
    }
    return medicosNovos;
  }

  static List<Disponibilidade> atualizarDisponibilidades({
    required List<Disponibilidade> novasDisponibilidades,
  }) {
    return novasDisponibilidades;
  }

  static List<Alocacao> atualizarAlocacoes({
    required List<Alocacao> alocacoesServidor,
    required List<Alocacao> alocacoesLocais,
    required DateTime data,
    void Function(String mensagem)? log,
  }) {
    return AlocacaoAlocacoesMergeUtils.mesclarServidorComOtimistas(
      alocacoesServidor: alocacoesServidor,
      alocacoesLocais: alocacoesLocais,
      data: data,
      log: log,
    );
  }
}
