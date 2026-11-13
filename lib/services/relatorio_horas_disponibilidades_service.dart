import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';
import 'serie_generator.dart';

/// Leituras restritas ao médico, unidade e período, sem carregar o ano inteiro.
class RelatorioHorasDisponibilidadesService {
  static Future<List<Disponibilidade>> carregar({
    required FirebaseFirestore firestore,
    required String unidadeId,
    required String medicoId,
    required DateTime inicio,
    required DateTime fim,
    bool forcarServidor = false,
    void Function(String colecao, int documentos)? onLeitura,
  }) async {
    final medico = firestore.doc('unidades/$unidadeId/ocupantes/$medicoId');
    final opcoes = GetOptions(
        source: forcarServidor ? Source.server : Source.serverAndCache);
    final limite = DateTime(fim.year, fim.month, fim.day + 1);
    final de = DateTime(inicio.year, inicio.month, inicio.day)
        .toIso8601String()
        .substring(0, 10);
    final ate = limite.toIso8601String().substring(0, 10);
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> registos(
        String colecao) async {
      final documentos = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (var ano = inicio.year; ano <= fim.year; ano++) {
        // Apenas um campo de intervalo: usa o índice simples existente.
        final snapshot = await medico
            .collection(colecao)
            .doc('$ano')
            .collection('registos')
            .where('data', isGreaterThanOrEqualTo: de)
            .where('data', isLessThan: ate)
            .get(opcoes);
        onLeitura?.call(colecao, snapshot.docs.length);
        documentos.addAll(snapshot.docs);
      }
      return documentos;
    }

    final unicasFuture = registos('disponibilidades');
    final seriesFuture = (() async {
      final snapshot = await medico
          .collection('series')
          .where('ativo', isEqualTo: true)
          .get(opcoes);
      onLeitura?.call('series', snapshot.docs.length);
      return snapshot.docs
          .map((doc) => SerieRecorrencia.fromMap({...doc.data(), 'id': doc.id}))
          .where((s) =>
              !s.dataInicio.isAfter(fim) &&
              (s.dataFim == null || !s.dataFim!.isBefore(inicio)))
          .toList();
    })();
    final resultados = await Future.wait<Object>([seriesFuture, unicasFuture]);
    final series = resultados[0] as List<SerieRecorrencia>;
    final unicas = (resultados[1]
            as List<QueryDocumentSnapshot<Map<String, dynamic>>>)
        .map((doc) => Disponibilidade.fromMap({...doc.data(), 'id': doc.id}))
        .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
        .toList();
    if (series.isEmpty) return unicas;
    final excecoes = (await registos('excecoes'))
        .map((doc) => ExcecaoSerie.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    return [
      ...SerieGenerator.gerarDisponibilidades(
          series: series, excecoes: excecoes, dataInicio: inicio, dataFim: fim),
      ...unicas,
    ];
  }
}
