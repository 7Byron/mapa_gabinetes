import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_dados_iniciais_merge_service.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class AlocacaoDadosIniciaisResultado {
  final List<Gabinete> gabinetes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final List<Alocacao> alocacoes;

  const AlocacaoDadosIniciaisResultado({
    required this.gabinetes,
    required this.medicos,
    required this.disponibilidades,
    required this.alocacoes,
  });
}

class AlocacaoDadosIniciaisCarregamentoService {
  static Future<AlocacaoDadosIniciaisResultado> carregar({
    required List<Gabinete> gabinetesAtuais,
    required List<Medico> medicosAtuais,
    required List<Disponibilidade> disponibilidadesAtuais,
    required List<Alocacao> alocacoesAtuais,
    required Unidade unidade,
    required DateTime dataFiltroDia,
    required bool recarregarMedicos,
    required Set<String> excecoesCanceladas,
    void Function(String mensagem)? log,
  }) async {
    var gabinetesAtualizados = List<Gabinete>.from(gabinetesAtuais);
    var medicosAtualizados = List<Medico>.from(medicosAtuais);
    var disponibilidadesAtualizadas =
        List<Disponibilidade>.from(disponibilidadesAtuais);
    var alocacoesAtualizadas = List<Alocacao>.from(alocacoesAtuais);

    await logic.AlocacaoMedicosLogic.carregarDadosIniciais(
      gabinetes: gabinetesAtuais,
      medicos: medicosAtuais,
      disponibilidades: disponibilidadesAtuais,
      alocacoes: alocacoesAtuais,
      onGabinetes: (g) {
        gabinetesAtualizados =
            AlocacaoDadosIniciaisMergeService.atualizarGabinetes(
          gabinetesAtuais: gabinetesAtualizados,
          gabinetesNovos: g,
          recarregarMedicos: recarregarMedicos,
        );
      },
      onMedicos: (m) {
        medicosAtualizados =
            AlocacaoDadosIniciaisMergeService.atualizarMedicos(
          medicosAtuais: medicosAtualizados,
          medicosNovos: m,
          recarregarMedicos: recarregarMedicos,
        );
      },
      onDisponibilidades: (d) {
        disponibilidadesAtualizadas =
            AlocacaoDadosIniciaisMergeService.atualizarDisponibilidades(
          novasDisponibilidades: d,
        );
      },
      onAlocacoes: (a) {
        alocacoesAtualizadas =
            AlocacaoDadosIniciaisMergeService.atualizarAlocacoes(
          alocacoesServidor: a,
          alocacoesLocais: alocacoesAtualizadas,
          data: dataFiltroDia,
          log: log,
        );
      },
      unidade: unidade,
      dataFiltroDia: dataFiltroDia,
      reloadStatic: recarregarMedicos,
      excecoesCanceladas: excecoesCanceladas,
    );

    return AlocacaoDadosIniciaisResultado(
      gabinetes: gabinetesAtualizados,
      medicos: medicosAtualizados,
      disponibilidades: disponibilidadesAtualizadas,
      alocacoes: alocacoesAtualizadas,
    );
  }
}
