import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_series_regeneracao_service.dart';
import '../utils/alocacao_alocacoes_merge_utils.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;

class DateChangeResult {
  final bool clinicaFechada;
  final String mensagemClinicaFechada;
  final List<Map<String, String>> feriados;
  final List<Map<String, dynamic>> diasEncerramento;
  final Map<int, List<String>> horariosClinica;
  final bool encerraFeriados;
  final bool nuncaEncerra;
  final Map<int, bool> encerraDias;
  final List<Alocacao> alocacoesAtualizadas;

  const DateChangeResult({
    required this.clinicaFechada,
    required this.mensagemClinicaFechada,
    required this.feriados,
    required this.diasEncerramento,
    required this.horariosClinica,
    required this.encerraFeriados,
    required this.nuncaEncerra,
    required this.encerraDias,
    required this.alocacoesAtualizadas,
  });
}

class AlocacaoDateChangeHandler {
  static Future<DateChangeResult> processarMudancaData({
    required Unidade unidade,
    required DateTime data,
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicosDisponiveis,
    required Future<Map<String, dynamic>> Function({
      required Unidade unidade,
      required DateTime data,
      required List<Gabinete> gabinetes,
      required List<Medico> medicos,
      required List<Disponibilidade> disponibilidades,
      required List<Alocacao> alocacoes,
      required List<Medico> medicosDisponiveis,
      required bool recarregarMedicos,
      required void Function(double, String) onProgress,
      required VoidCallback onStateUpdate,
    }) atualizarDadosDoDia,
    required void Function(double, String) onProgress,
    required VoidCallback onStateUpdate,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(data.year, 1, 1));

    final resultado = await atualizarDadosDoDia(
      unidade: unidade,
      data: dataNormalizada,
      gabinetes: gabinetes,
      medicos: medicos,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      medicosDisponiveis: medicosDisponiveis,
      recarregarMedicos: false,
      onProgress: onProgress,
      onStateUpdate: onStateUpdate,
    );

    onProgress(0.75, 'A regenerar alocações de séries...');
    final alocacoesSeriesRegeneradas =
        await AlocacaoSeriesRegeneracaoService.regenerarParaDia(
      data: dataNormalizada,
      unidade: unidade,
      alocacoes: alocacoes,
    );
    onProgress(0.80, 'A processar dados...');

    final alocacoesAtualizadas =
        AlocacaoAlocacoesMergeUtils.substituirSeriesNoDia(
      alocacoes: alocacoes,
      alocacoesSeriesRegeneradas: alocacoesSeriesRegeneradas,
      data: dataNormalizada,
    );

    return DateChangeResult(
      clinicaFechada: resultado['clinicaFechada'] ?? false,
      mensagemClinicaFechada: resultado['mensagemClinicaFechada'] ?? '',
      feriados: resultado['feriados'] ?? [],
      diasEncerramento: resultado['diasEncerramento'] ?? [],
      horariosClinica: resultado['horariosClinica'] ?? {},
      encerraFeriados: resultado['encerraFeriados'] ?? false,
      nuncaEncerra: resultado['nuncaEncerra'] ?? false,
      encerraDias: resultado['encerraDias'] ?? {},
      alocacoesAtualizadas: alocacoesAtualizadas,
    );
  }
}
