import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';
import 'cache_version_service.dart';
import '../utils/alocacao_medicos_logic.dart';

class AlocacaoDisponibilidadeRemocaoService {
  static bool _alocacaoDoCartao(
    String id,
    Map<String, dynamic> data,
    Disponibilidade disponibilidade,
  ) {
    if (id.startsWith('serie_') || data['serieId'] != null) return false;
    final horarios = disponibilidade.horarios;
    return horarios.length >= 2 &&
        horarios[0].isNotEmpty &&
        horarios[1].isNotEmpty &&
        data['horarioInicio'] == horarios[0] &&
        data['horarioFim'] == horarios[1];
  }

  /// Duas consultas anuais por ano abrangido; vistas diárias limitadas ao médico.
  /// As falhas propagam-se: o editor não pode anunciar uma remoção incompleta.
  static Future<Map<String, int>> removerAlocacoesEDisponibilidades(
      String unidadeId, String medicoId, DateTime dataInicio, DateTime dataFim,
      {String? serieId,
      Disponibilidade? disponibilidade,
      FirebaseFirestore? firestore,
      void Function(int documentos)? onConsulta}) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final inicio = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);
    final fim = DateTime(dataFim.year, dataFim.month, dataFim.day);
    final limite = fim.add(const Duration(days: 1));
    if (fim.isBefore(inicio)) {
      throw ArgumentError('O fim do período é anterior ao início.');
    }
    final unidadeRef = db.collection('unidades').doc(unidadeId);
    final medicoRef = unidadeRef.collection('ocupantes').doc(medicoId);
    final remover =
        <String, (DocumentReference<Map<String, dynamic>>, String)>{};

    Future<QuerySnapshot<Map<String, dynamic>>> consultar(
        Query<Map<String, dynamic>> query) async {
      final snapshot = await query.get(const GetOptions(source: Source.server));
      onConsulta?.call(snapshot.docs.length);
      return snapshot;
    }

    bool pertenceSerie(String id, Map<String, dynamic> dados) {
      if (serieId == null) return true;
      if (dados['serieId'] != null) return dados['serieId'] == serieId;
      // IDs antigos podem codificar a série; exigir o separador evita
      // confundir, por exemplo, serie_12 com serie_123.
      return id.startsWith('serie_${serieId}_') || id.startsWith('${serieId}_');
    }

    bool alocacaoSelecionada(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        pertenceSerie(doc.id, doc.data()) &&
        (disponibilidade == null ||
            _alocacaoDoCartao(doc.id, doc.data(), disponibilidade));
    bool disponibilidadeSelecionada(
            QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        serieId == null &&
        doc.data()['tipo'] == 'Única' &&
        (disponibilidade == null || doc.id == disponibilidade.id);
    void adicionar(
        QueryDocumentSnapshot<Map<String, dynamic>> doc, String tipo) {
      remover[doc.reference.path] = (doc.reference, tipo);
    }

    for (var ano = inicio.year; ano <= fim.year; ano++) {
      final alocacoesRef =
          unidadeRef.collection('alocacoes').doc('$ano').collection('registos');
      final disponibilidadesRef = medicoRef
          .collection('disponibilidades')
          .doc('$ano')
          .collection('registos');
      Query<Map<String, dynamic>> periodo(
              CollectionReference<Map<String, dynamic>> ref) =>
          ref
              .where('medicoId', isEqualTo: medicoId)
              .where('data', isGreaterThanOrEqualTo: inicio.toIso8601String())
              .where('data', isLessThan: limite.toIso8601String());
      final snapshots = await Future.wait([
        consultar(periodo(alocacoesRef)),
        consultar(periodo(disponibilidadesRef)),
      ]);
      for (final doc in snapshots[0].docs.where(alocacaoSelecionada)) {
        adicionar(doc, 'alocacao');
      }
      for (final doc in snapshots[1].docs.where(disponibilidadeSelecionada)) {
        adicionar(doc, 'disponibilidade');
      }
    }

    for (var dia = inicio;
        dia.isBefore(limite);
        dia = dia.add(const Duration(days: 1))) {
      final key = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
          '${dia.day.toString().padLeft(2, '0')}';
      final diaRef = unidadeRef.collection('dias').doc(key);
      final snapshots = await Future.wait([
        consultar(diaRef
            .collection('alocacoes')
            .where('medicoId', isEqualTo: medicoId)),
        consultar(diaRef
            .collection('disponibilidades')
            .where('medicoId', isEqualTo: medicoId)),
      ]);
      for (final doc in snapshots[0].docs.where(alocacaoSelecionada)) {
        adicionar(doc, 'vista');
      }
      for (final doc in snapshots[1].docs.where(disponibilidadeSelecionada)) {
        adicionar(doc, 'vista');
      }
    }

    var alocacoesRemovidas = 0;
    var disponibilidadesRemovidas = 0;
    final documentos = remover.values.toList();
    try {
      for (var pos = 0; pos < documentos.length; pos += 400) {
        final lote = documentos.skip(pos).take(400).toList();
        final batch = db.batch();
        for (final (ref, _) in lote) {
          batch.delete(ref);
        }
        batch.set(
            unidadeRef.collection('cache_control').doc('global'),
            {
              CacheVersionService.fieldAlocacoes: FieldValue.increment(1),
              CacheVersionService.fieldDisponibilidades:
                  FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        await batch.commit();
        alocacoesRemovidas += lote.where((d) => d.$2 == 'alocacao').length;
        disponibilidadesRemovidas +=
            lote.where((d) => d.$2 == 'disponibilidade').length;
      }
    } finally {
      if (documentos.isNotEmpty) {
        for (var dia = inicio;
            dia.isBefore(limite);
            dia = dia.add(const Duration(days: 1))) {
          AlocacaoMedicosLogic.invalidateCacheForDay(dia);
        }
      }
    }
    return {
      'alocacoesRemovidas': alocacoesRemovidas,
      'disponibilidadesRemovidas': disponibilidadesRemovidas
    };
  }

  static Future<Map<String, int>> removerAlocacoesEDisponibilidadesPorData(
          String unidadeId, String medicoId, DateTime data,
          {String? serieId, Disponibilidade? disponibilidade}) =>
      removerAlocacoesEDisponibilidades(unidadeId, medicoId, data, data,
          serieId: serieId, disponibilidade: disponibilidade);
}
