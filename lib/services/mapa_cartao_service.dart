import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../utils/alocacao_disponibilidade_validacao_utils.dart';
import '../utils/series_helper.dart';
import 'cache_version_service.dart';
import 'serie_service.dart';

class MapaCartaoService {
  /// Conserva as alterações pontuais quando se suspende uma ocorrência.
  /// Na reativação, uma exceção só de cancelamento deixa de ser necessária.
  static ExcecaoSerie? alterarExcecao({
    required ExcecaoSerie excecao,
    required bool ausente,
    bool ocultarCartao = false,
  }) {
    if (!ausente && excecao.horarios == null && excecao.gabineteId == null) {
      return null;
    }
    return ExcecaoSerie(
      id: excecao.id,
      serieId: excecao.serieId,
      data: excecao.data,
      cancelada: ausente,
      ocultarCartao: ausente && ocultarCartao,
      horarios: excecao.horarios == null ? null : List.from(excecao.horarios!),
      gabineteId: excecao.gabineteId,
    );
  }

  static Future<void> definirAusencia({
    required Unidade unidade,
    required Alocacao cartao,
    required List<Disponibilidade> disponibilidades,
    required bool ausente,
    bool ocultarCartao = false,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final dia = DateTime(cartao.data.year, cartao.data.month, cartao.data.day);
    final diaKey = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
        '${dia.day.toString().padLeft(2, '0')}';
    final unidadeRef = firestore.collection('unidades').doc(unidade.id);
    final medicoRef = unidadeRef.collection('ocupantes').doc(cartao.medicoId);
    final batch = firestore.batch();
    String serieId;
    var converteuUnico = false;

    if (cartao.id.startsWith('serie_')) {
      final id = SeriesHelper.extrairSerieIdDeDisponibilidade(cartao.id);
      final series = await SerieService.carregarSeries(
        cartao.medicoId,
        unidade: unidade,
        forcarServidor: true,
      );
      final correspondentes = series
          .where(
              (s) => SeriesHelper.extrairSerieIdDeDisponibilidade(s.id) == id)
          .toList();
      if (correspondentes.length != 1) {
        throw StateError('Não foi possível identificar a série deste cartão.');
      }
      serieId = correspondentes.single.id;
    } else {
      if (!ausente) {
        throw StateError('Este cartão não tem uma ausência de série.');
      }
      // Os cartões únicos passam a ter uma regra limitada a este único dia.
      // A conversão e a exceção são atómicas: nunca ficam duas ocupações.
      final correspondentes = disponibilidades
          .where((d) =>
              !d.id.startsWith('serie_') &&
              AlocacaoDisponibilidadeValidacaoUtils.disponibilidadeCorresponde(
                disponibilidade: d,
                medicoId: cartao.medicoId,
                data: dia,
                horarioInicio: cartao.horarioInicio,
                horarioFim: cartao.horarioFim,
              ))
          .toList();
      if (correspondentes.length != 1) {
        throw StateError(
            'Não foi possível identificar a disponibilidade deste cartão.');
      }
      final disponibilidadeRef = medicoRef
          .collection('disponibilidades')
          .doc('${dia.year}')
          .collection('registos')
          .doc(correspondentes.single.id);
      final snapshot = await disponibilidadeRef.get(
        const GetOptions(source: Source.server),
      );
      final dados = snapshot.data();
      if (dados == null) {
        throw StateError('A disponibilidade já foi alterada. Atualiza o mapa.');
      }
      final disponibilidade =
          Disponibilidade.fromMap({...dados, 'id': snapshot.id});
      if (!AlocacaoDisponibilidadeValidacaoUtils.disponibilidadeCorresponde(
        disponibilidade: disponibilidade,
        medicoId: cartao.medicoId,
        data: dia,
        horarioInicio: cartao.horarioInicio,
        horarioFim: cartao.horarioFim,
      )) {
        throw StateError('A disponibilidade já foi alterada. Atualiza o mapa.');
      }
      serieId = 'serie_cartao_${cartao.id}';
      final serie = SerieRecorrencia(
        id: serieId,
        medicoId: cartao.medicoId,
        dataInicio: dia,
        dataFim: dia,
        tipo: 'Única',
        horarios: List.from(disponibilidade.horarios),
        gabineteId: cartao.gabineteId,
      );
      batch.set(medicoRef.collection('series').doc(serieId), serie.toMap());
      batch.delete(medicoRef
          .collection('disponibilidades')
          .doc('${dia.year}')
          .collection('registos')
          .doc(disponibilidade.id));
      batch.delete(unidadeRef
          .collection('dias')
          .doc(diaKey)
          .collection('disponibilidades')
          .doc(disponibilidade.id));
      batch.delete(unidadeRef
          .collection('alocacoes')
          .doc('${dia.year}')
          .collection('registos')
          .doc(cartao.id));
      batch.delete(unidadeRef
          .collection('dias')
          .doc(diaKey)
          .collection('alocacoes')
          .doc(cartao.id));
      converteuUnico = true;
    }

    final excecoesRef = medicoRef
        .collection('excecoes')
        .doc('${dia.year}')
        .collection('registos');
    // A falha de leitura deve impedir a gravação, para não perder alterações
    // pontuais que ainda não estejam na cache local.
    final snapshot =
        await excecoesRef.get(const GetOptions(source: Source.server));
    final existentes = snapshot.docs
        .map((doc) => ExcecaoSerie.fromMap({...doc.data(), 'id': doc.id}))
        .where((e) => e.serieId == serieId && e.data == dia)
        .toList();
    if (existentes.length > 1) {
      // Evitar escolher arbitrariamente entre exceções históricas incompatíveis.
      final primeira = existentes.first;
      if (existentes.any((e) =>
          e.gabineteId != primeira.gabineteId ||
          e.horarios?.join(',') != primeira.horarios?.join(','))) {
        throw StateError(
            'Este cartão tem exceções diferentes para a mesma data. '
            'Revê as exceções em Gerir médico.');
      }
    }
    final base = existentes.isEmpty
        ? ExcecaoSerie(
            id: 'excecao_${serieId}_${dia.millisecondsSinceEpoch}',
            serieId: serieId,
            data: dia)
        : existentes.first;
    final alterada = alterarExcecao(
        excecao: base, ausente: ausente, ocultarCartao: ocultarCartao);
    for (final existente in existentes) {
      batch.delete(excecoesRef.doc(existente.id));
    }
    if (alterada != null) {
      batch.set(excecoesRef.doc(alterada.id), alterada.toMap());
    }
    batch.set(
        unidadeRef.collection('cache_control').doc('global'),
        {
          CacheVersionService.fieldSeries: FieldValue.increment(1),
          if (converteuUnico) ...{
            CacheVersionService.fieldAlocacoes: FieldValue.increment(1),
            CacheVersionService.fieldDisponibilidades: FieldValue.increment(1),
          },
        },
        SetOptions(merge: true));
    await batch.commit();
    SerieService.invalidateCacheSeries(unidade.id, cartao.medicoId);
    AlocacaoMedicosLogic.invalidateCacheForDay(dia);
    AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(dia.year, 1, 1));
  }
}
