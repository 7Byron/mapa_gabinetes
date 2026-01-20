import '../models/alocacao.dart';
import '../utils/alocacao_alocacoes_merge_utils.dart';
import '../services/alocacao_clinica_status_service.dart';

class AlocacaoPosCarregamentoResultado {
  final List<Alocacao> alocacoesAtualizadas;
  final bool clinicaFechada;
  final String mensagemClinicaFechada;

  const AlocacaoPosCarregamentoResultado({
    required this.alocacoesAtualizadas,
    required this.clinicaFechada,
    required this.mensagemClinicaFechada,
  });
}

class AlocacaoPosCarregamentoService {
  static Future<AlocacaoPosCarregamentoResultado> processar({
    required DateTime data,
    required List<Alocacao> alocacoesAtuais,
    required Future<List<Alocacao>> Function() regenerarSeries,
    required Future<void> Function(double, String) atualizarProgresso,
    required Future<void> Function() atualizarMedicosDisponiveis,
    required List<Map<String, String>> feriados,
    required List<Map<String, dynamic>> diasEncerramento,
    required Map<int, List<String>> horariosClinica,
    required bool encerraFeriados,
    required bool nuncaEncerra,
    required Map<int, bool> encerraDias,
  }) async {
    await atualizarProgresso(0.80, 'A processar dados...');
    final alocacoesSeriesRegeneradas = await regenerarSeries();

    final alocacoesAtualizadas =
        AlocacaoAlocacoesMergeUtils.substituirSeriesPreservandoOtimistas(
      alocacoesAtuais: alocacoesAtuais,
      alocacoesSeriesRegeneradas: alocacoesSeriesRegeneradas,
      data: data,
    );

    await atualizarProgresso(0.90, 'A processar médicos disponíveis...');
    await atualizarMedicosDisponiveis();

    final resultadoClinica = AlocacaoClinicaStatusService.verificar(
      data: data,
      nuncaEncerra: nuncaEncerra,
      encerraFeriados: encerraFeriados,
      encerraDias: encerraDias,
      horariosClinica: horariosClinica,
      diasEncerramento: diasEncerramento,
      feriados: feriados,
    );

    return AlocacaoPosCarregamentoResultado(
      alocacoesAtualizadas: alocacoesAtualizadas,
      clinicaFechada: resultadoClinica.fechada,
      mensagemClinicaFechada: resultadoClinica.mensagem,
    );
  }
}
