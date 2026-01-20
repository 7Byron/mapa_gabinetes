import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_dados_iniciais_carregamento_service.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoDadosEssenciaisService {
  static Future<AlocacaoDadosIniciaisResultado> carregar({
    required Unidade unidade,
    required DateTime selectedDate,
    required bool recarregarMedicos,
    required List<Gabinete> gabinetesAtuais,
    required List<Medico> medicosAtuais,
    required List<Disponibilidade> disponibilidadesAtuais,
    required List<Alocacao> alocacoesAtuais,
    required void Function(double, String) atualizarProgresso,
    required void Function() iniciarProgressao,
    required void Function() pararProgressao,
    void Function(String mensagem)? log,
  }) async {
    atualizarProgresso(0.05, 'A verificar exceções...');
    final excecoesCanceladas =
        await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      unidade.id,
      selectedDate,
    );

    atualizarProgresso(0.15, 'A carregar dados...');
    iniciarProgressao();

    if (recarregarMedicos) {
      final dataNormalizada =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(selectedDate.year, 1, 1));
      await Future.delayed(const Duration(milliseconds: 50));
    }

    final resultado =
        await AlocacaoDadosIniciaisCarregamentoService.carregar(
      gabinetesAtuais: gabinetesAtuais,
      medicosAtuais: medicosAtuais,
      disponibilidadesAtuais: disponibilidadesAtuais,
      alocacoesAtuais: alocacoesAtuais,
      unidade: unidade,
      dataFiltroDia: selectedDate,
      recarregarMedicos: recarregarMedicos,
      excecoesCanceladas: excecoesCanceladas,
      log: log,
    );

    pararProgressao();

    return resultado;
  }
}
