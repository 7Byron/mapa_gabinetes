import '../services/alocacao_clinica_config_service.dart';
import '../services/alocacao_clinica_status_service.dart';

class ClinicaPreparacaoResultado {
  final bool clinicaFechada;
  final String mensagemClinicaFechada;
  final List<Map<String, String>> feriados;
  final List<Map<String, dynamic>> diasEncerramento;
  final Map<int, List<String>> horariosClinica;
  final bool encerraFeriados;
  final bool nuncaEncerra;
  final Map<int, bool> encerraDias;

  const ClinicaPreparacaoResultado({
    required this.clinicaFechada,
    required this.mensagemClinicaFechada,
    required this.feriados,
    required this.diasEncerramento,
    required this.horariosClinica,
    required this.encerraFeriados,
    required this.nuncaEncerra,
    required this.encerraDias,
  });
}

class AlocacaoClinicaPreparacaoService {
  static Future<ClinicaPreparacaoResultado> preparar({
    required String unidadeId,
    required DateTime dataReferencia,
    bool forcarServidor = false,
  }) async {
    var feriados = <Map<String, String>>[];
    var diasEncerramento = <Map<String, dynamic>>[];
    var horariosClinica = <int, List<String>>{};
    var encerraFeriados = false;
    var nuncaEncerra = false;
    var encerraDias = <int, bool>{
      1: false,
      2: false,
      3: false,
      4: false,
      5: false,
      6: false,
      7: false,
    };

    try {
      feriados = await AlocacaoClinicaConfigService.carregarFeriados(
        unidadeId: unidadeId,
        anoSelecionado: dataReferencia.year,
        forcarServidor: forcarServidor,
      );
      diasEncerramento =
          await AlocacaoClinicaConfigService.carregarDiasEncerramento(
        unidadeId: unidadeId,
        anoSelecionado: dataReferencia.year,
        forcarServidor: forcarServidor,
      );
      final config =
          await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
        unidadeId: unidadeId,
        forcarServidor: forcarServidor,
      );
      horariosClinica = config.horariosClinica;
      nuncaEncerra = config.nuncaEncerra;
      encerraFeriados = config.encerraFeriados;
      encerraDias = Map<int, bool>.from(config.encerraDias);
    } catch (_) {
      return const ClinicaPreparacaoResultado(
        clinicaFechada: false,
        mensagemClinicaFechada: '',
        feriados: [],
        diasEncerramento: [],
        horariosClinica: {},
        encerraFeriados: false,
        nuncaEncerra: false,
        encerraDias: {
          1: false,
          2: false,
          3: false,
          4: false,
          5: false,
          6: false,
          7: false,
        },
      );
    }

    var clinicaFechada = false;
    var mensagemClinicaFechada = '';

    if (horariosClinica.isNotEmpty ||
        encerraDias.isNotEmpty ||
        feriados.isNotEmpty ||
        diasEncerramento.isNotEmpty) {
      final resultado = AlocacaoClinicaStatusService.verificar(
        data: dataReferencia,
        nuncaEncerra: nuncaEncerra,
        encerraFeriados: encerraFeriados,
        encerraDias: encerraDias,
        horariosClinica: horariosClinica,
        diasEncerramento: diasEncerramento,
        feriados: feriados,
      );
      clinicaFechada = resultado.fechada;
      mensagemClinicaFechada = resultado.mensagem;
    }

    return ClinicaPreparacaoResultado(
      clinicaFechada: clinicaFechada,
      mensagemClinicaFechada: mensagemClinicaFechada,
      feriados: feriados,
      diasEncerramento: diasEncerramento,
      horariosClinica: horariosClinica,
      encerraFeriados: encerraFeriados,
      nuncaEncerra: nuncaEncerra,
      encerraDias: encerraDias,
    );
  }
}
