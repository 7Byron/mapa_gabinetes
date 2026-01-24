import 'package:flutter/material.dart';
import 'dart:async';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/alocacao_series_regeneracao_service.dart';
import '../utils/alocacao_alocacoes_merge_utils.dart';
import '../utils/alocacao_cache_store.dart';

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
  static final Map<String, _CacheDia> _cacheResultados = {};

  static DateChangeResult? _getCache(DateTime data) {
    final key = AlocacaoCacheStore.keyDia(data);
    final cached = _cacheResultados[key];
    if (cached == null) return null;
    if (AlocacaoCacheStore.isCacheInvalidado(data)) {
      _cacheResultados.remove(key);
      return null;
    }
    final cacheDisp = AlocacaoCacheStore.getDisponibilidades(data);
    final cacheAloc = AlocacaoCacheStore.getAlocacoes(data);
    if (cacheDisp == null || cacheAloc == null) {
      _cacheResultados.remove(key);
      return null;
    }
    return cached.resultado;
  }

  static void _setCache(DateTime data, DateChangeResult resultado) {
    final key = AlocacaoCacheStore.keyDia(data);
    _cacheResultados[key] = _CacheDia(
      resultado: resultado,
      atualizadoEm: DateTime.now(),
    );
  }

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
      bool calcularMedicosDisponiveis,
      required void Function(double, String) onProgress,
      required VoidCallback onStateUpdate,
    }) atualizarDadosDoDia,
    required void Function(double, String) onProgress,
    required VoidCallback onStateUpdate,
  }) async {
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    final cacheLocal = _getCache(dataNormalizada);
    if (cacheLocal != null) {
      onProgress(0.60, 'A usar cache local do dia...');
      final cacheDisp = AlocacaoCacheStore.getDisponibilidades(dataNormalizada);
      final cacheAloc = AlocacaoCacheStore.getAlocacoes(dataNormalizada);
      if (cacheDisp != null) {
        disponibilidades
          ..clear()
          ..addAll(cacheDisp);
      }
      if (cacheAloc != null) {
        alocacoes
          ..clear()
          ..addAll(cacheAloc);
      }
      final resultadoCache = DateChangeResult(
        clinicaFechada: cacheLocal.clinicaFechada,
        mensagemClinicaFechada: cacheLocal.mensagemClinicaFechada,
        feriados: cacheLocal.feriados,
        diasEncerramento: cacheLocal.diasEncerramento,
        horariosClinica: cacheLocal.horariosClinica,
        encerraFeriados: cacheLocal.encerraFeriados,
        nuncaEncerra: cacheLocal.nuncaEncerra,
        encerraDias: cacheLocal.encerraDias,
        alocacoesAtualizadas: cacheAloc != null
            ? List<Alocacao>.from(cacheAloc)
            : cacheLocal.alocacoesAtualizadas,
      );
      _setCache(dataNormalizada, resultadoCache);
      return resultadoCache;
    }

    final resultado = await atualizarDadosDoDia(
      unidade: unidade,
      data: dataNormalizada,
      gabinetes: gabinetes,
      medicos: medicos,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      medicosDisponiveis: medicosDisponiveis,
      recarregarMedicos: false,
      calcularMedicosDisponiveis: false,
      onProgress: onProgress,
      onStateUpdate: onStateUpdate,
    );

    final cacheSeries =
        AlocacaoCacheStore.getAlocacoesComSeries(dataNormalizada);
    if (cacheSeries != null) {
      onProgress(0.90, 'A usar cache de séries...');
      final resultadoCache = DateChangeResult(
        clinicaFechada: resultado['clinicaFechada'] ?? false,
        mensagemClinicaFechada: resultado['mensagemClinicaFechada'] ?? '',
        feriados: resultado['feriados'] ?? [],
        diasEncerramento: resultado['diasEncerramento'] ?? [],
        horariosClinica: resultado['horariosClinica'] ?? {},
        encerraFeriados: resultado['encerraFeriados'] ?? false,
        nuncaEncerra: resultado['nuncaEncerra'] ?? false,
        encerraDias: resultado['encerraDias'] ?? {},
        alocacoesAtualizadas: List<Alocacao>.from(cacheSeries),
      );
      _setCache(dataNormalizada, resultadoCache);
      return resultadoCache;
    }

    var progressoSeries = 0.60;
    const limiteSeries = 0.90;
    Timer? timerSeries;
    timerSeries = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      progressoSeries += (limiteSeries - progressoSeries) * 0.035;
      if (progressoSeries >= limiteSeries - 0.001) {
        progressoSeries = limiteSeries;
        timer.cancel();
      }
      onProgress(progressoSeries, 'A regenerar alocações de séries...');
    });

    onProgress(0.90, 'A regenerar alocações de séries...');
    final alocacoesSeriesRegeneradas =
        await AlocacaoSeriesRegeneracaoService.regenerarParaDia(
      data: dataNormalizada,
      unidade: unidade,
      alocacoes: alocacoes,
    );
    timerSeries.cancel();
    onProgress(0.94, 'A processar dados...');

    final alocacoesAtualizadas =
        AlocacaoAlocacoesMergeUtils.substituirSeriesNoDia(
      alocacoes: alocacoes,
      alocacoesSeriesRegeneradas: alocacoesSeriesRegeneradas,
      data: dataNormalizada,
    );

    AlocacaoCacheStore.updateAlocacoesComSeries(
        dataNormalizada, alocacoesAtualizadas);

    final resultadoFinal = DateChangeResult(
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
    _setCache(dataNormalizada, resultadoFinal);
    return resultadoFinal;
  }
}

class _CacheDia {
  final DateChangeResult resultado;
  final DateTime atualizadoEm;

  const _CacheDia({
    required this.resultado,
    required this.atualizadoEm,
  });
}
