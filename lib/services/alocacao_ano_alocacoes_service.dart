import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';

class AlocacaoAnoAlocacoesService {
  static Future<List<Alocacao>> carregar({
    required Unidade unidade,
    required int ano,
    List<Medico>? medicos,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final todasAlocacoes = <Alocacao>[];

    final alocacoesRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('alocacoes')
        .doc(ano.toString())
        .collection('registos');

    final registosSnapshot =
        await alocacoesRef.get(const GetOptions(source: Source.server));

    if (kDebugMode) {
      debugPrint(
          '🔍 [MÉDICOS NÃO ALOCADOS] Carregadas ${registosSnapshot.docs.length} alocações do ano $ano do servidor');
    }

    for (final doc in registosSnapshot.docs) {
      final data = doc.data();
      final alocacao = Alocacao.fromMap(data);
      todasAlocacoes.add(alocacao);
    }

    try {
      final alocacoesGeradasAno = <Alocacao>[];

      final medicoIds = medicos != null
          ? medicos.where((m) => m.ativo).map((m) => m.id).toList()
          : await _carregarMedicosAtivosIds(firestore, unidade.id);

      final dataInicioAno = DateTime(ano, 1, 1);
      final dataFimAno = DateTime(ano, 12, 31);

      final seriesPorMedico = await SerieService.carregarSeriesDeMedicos(
        medicoIds,
        unidade: unidade,
        dataFim: dataFimAno,
      );
      final futures = <Future<List<Alocacao>>>[];
      for (final medicoId in medicoIds) {
        futures.add((() async {
          final series = seriesPorMedico[medicoId] ?? const [];

          final seriesComGabinete = series
              .where(
                  (s) => s.gabineteId != null || s.mudancasGabinete.isNotEmpty)
              .toList();

          if (seriesComGabinete.isEmpty) return <Alocacao>[];

          final excecoes = await SerieService.carregarExcecoes(
            medicoId,
            unidade: unidade,
            dataInicio: dataInicioAno,
            dataFim: dataFimAno,
            forcarServidor: false,
          );

          return SerieGenerator.gerarAlocacoes(
            series: seriesComGabinete,
            dataInicio: dataInicioAno,
            dataFim: dataFimAno,
            excecoes: excecoes,
          );
        })());
      }

      final resultados = await Future.wait(futures);
      for (final resultado in resultados) {
        alocacoesGeradasAno.addAll(resultado);
      }

      if (kDebugMode) {
        debugPrint(
            '🔍 [MÉDICOS NÃO ALOCADOS] Geradas ${alocacoesGeradasAno.length} alocações de séries para o ano $ano');
      }

      final alocacoesMap = <String, Alocacao>{};
      for (final aloc in todasAlocacoes) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
        alocacoesMap[chave] = aloc;
      }
      for (final aloc in alocacoesGeradasAno) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
        alocacoesMap[chave] = aloc;
      }

      todasAlocacoes
        ..clear()
        ..addAll(alocacoesMap.values);

      if (kDebugMode) {
        debugPrint(
            '🔍 [MÉDICOS NÃO ALOCADOS] Total após mesclar com séries: ${todasAlocacoes.length} alocações');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ [MÉDICOS NÃO ALOCADOS] Erro ao carregar alocações de séries: $e');
      }
    }

    return todasAlocacoes;
  }

  static Future<List<String>> _carregarMedicosAtivosIds(
    FirebaseFirestore firestore,
    String unidadeId,
  ) async {
    final medicosRef = firestore
        .collection('unidades')
        .doc(unidadeId)
        .collection('ocupantes')
        .where('ativo', isEqualTo: true);
    final medicosSnapshot =
        await medicosRef.get(const GetOptions(source: Source.server));
    return medicosSnapshot.docs.map((d) => d.id).toList();
  }
}
