import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/alocacao_cache_store.dart';
import '../utils/alocacao_disponibilidade_validacao_utils.dart';
import '../utils/cadastro_medicos_helper.dart';
import '../utils/horarios_disponibilidade_utils.dart';
import '../utils/series_helper.dart';
import 'cache_version_service.dart';

class ResultadoAtualizacaoHorarioCartaoUnico {
  final Disponibilidade disponibilidade;
  final Alocacao? alocacao;

  const ResultadoAtualizacaoHorarioCartaoUnico({
    required this.disponibilidade,
    required this.alocacao,
  });
}

/// Mantém o horário da disponibilidade e da respetiva alocação sincronizados.
class AlocacaoHorarioService {
  AlocacaoHorarioService._();

  static String _keyDia(DateTime data) =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  /// Atualiza um cartão único e, quando este já está alocado, conserva o mesmo
  /// documento e gabinete, alterando apenas as horas. A gravação anual e a
  /// vista diária são feitas no mesmo batch para não existir um estado
  /// intermédio em que o mapa veja dois cartões.
  static Future<ResultadoAtualizacaoHorarioCartaoUnico> atualizarCartaoUnico({
    required Disponibilidade disponibilidade,
    required List<String> horariosAnteriores,
    required List<String> novosHorarios,
    required List<Alocacao> alocacoes,
    required Unidade? unidade,
  }) async {
    if (!HorariosDisponibilidadeUtils.temInicioEFim(novosHorarios)) {
      throw ArgumentError('O cartão deve ter hora de entrada e de saída.');
    }

    // Um cartão acabado de criar ainda não possui um intervalo anterior. Só
    // procuramos uma alocação para sincronizar quando esse intervalo existe.
    final correspondentes = HorariosDisponibilidadeUtils.temInicioEFim(
      horariosAnteriores,
    )
        ? alocacoes
            .where(
              (alocacao) => AlocacaoDisponibilidadeValidacaoUtils
                  .alocacaoCorrespondeAoCartao(
                alocacao: alocacao,
                medicoId: disponibilidade.medicoId,
                data: disponibilidade.data,
                horarios: horariosAnteriores,
              ),
            )
            .toList()
        : <Alocacao>[];
    if (correspondentes.length > 1) {
      throw StateError(
        'Existem várias alocações para o horário anterior; '
        'a alteração foi interrompida para não mover o cartão errado.',
      );
    }

    final unidadeId = CadastroMedicosHelper.obterUnidadeId(unidade);
    final firestore = FirebaseFirestore.instance;
    final data = DateTime(
      disponibilidade.data.year,
      disponibilidade.data.month,
      disponibilidade.data.day,
    );
    final ano = data.year.toString();
    final dia = _keyDia(data);
    final disponibilidadeId =
        CadastroMedicosHelper.isIdTemporarioOuInvalido(disponibilidade.id)
            ? CadastroMedicosHelper.gerarIdPermanenteParaDisponibilidade(
                disponibilidade,
                disponibilidade.medicoId,
              )
            : disponibilidade.id;
    final disponibilidadeAtualizada = Disponibilidade(
      id: disponibilidadeId,
      medicoId: disponibilidade.medicoId,
      data: data,
      horarios: List<String>.from(novosHorarios),
      tipo: disponibilidade.tipo,
    );
    final unidadeRef = firestore.collection('unidades').doc(unidadeId);
    final batch = firestore.batch();

    final disponibilidadeAnualRef = unidadeRef
        .collection('ocupantes')
        .doc(disponibilidade.medicoId)
        .collection('disponibilidades')
        .doc(ano)
        .collection('registos')
        .doc(disponibilidadeId);
    final disponibilidadeDiariaRef = unidadeRef
        .collection('dias')
        .doc(dia)
        .collection('disponibilidades')
        .doc(disponibilidadeId);
    batch.set(disponibilidadeAnualRef, disponibilidadeAtualizada.toMap());
    batch.set(disponibilidadeDiariaRef, disponibilidadeAtualizada.toMap());

    Alocacao? alocacaoAtualizada;
    if (correspondentes.isNotEmpty) {
      final anterior = correspondentes.single;
      alocacaoAtualizada = Alocacao(
        id: anterior.id,
        medicoId: anterior.medicoId,
        gabineteId: anterior.gabineteId,
        data: data,
        horarioInicio: novosHorarios[0],
        horarioFim: novosHorarios[1],
      );
      _gravarAlocacaoNoBatch(
        batch: batch,
        unidadeRef: unidadeRef,
        alocacao: alocacaoAtualizada,
      );
    }

    await batch.commit();
    await CacheVersionService.bumpVersions(
      unidadeId: unidadeId,
      fields: [
        CacheVersionService.fieldDisponibilidades,
        if (alocacaoAtualizada != null) CacheVersionService.fieldAlocacoes,
      ],
    );
    AlocacaoCacheStore.invalidateCacheForDay(data);

    return ResultadoAtualizacaoHorarioCartaoUnico(
      disponibilidade: disponibilidadeAtualizada,
      alocacao: alocacaoAtualizada,
    );
  }

  /// Persiste reparações conservadoras encontradas durante a leitura de dados
  /// antigos. O ID e o gabinete de cada alocação são sempre preservados.
  static Future<Set<String>> persistirCorrecoesInequivocas({
    required String unidadeId,
    required List<AtualizacaoHorarioAlocacao> correcoes,
  }) async {
    if (correcoes.isEmpty) return <String>{};

    final firestore = FirebaseFirestore.instance;
    final unidadeRef = firestore.collection('unidades').doc(unidadeId);
    final batch = firestore.batch();
    final medicosComSerieAtualizada = <String>{};
    var atualizouAlocacaoPersistida = false;
    var removeuDisponibilidadeSombra = false;
    for (final correcao in correcoes) {
      final atualizada = correcao.atualizada;
      if (correcao.original.id.startsWith('serie_')) {
        final serieId = SeriesHelper.extrairSerieIdDeDisponibilidade(
          correcao.original.id,
        );
        batch.update(
          unidadeRef
              .collection('ocupantes')
              .doc(atualizada.medicoId)
              .collection('series')
              .doc(serieId),
          {
            'horarios': [atualizada.horarioInicio, atualizada.horarioFim],
          },
        );
        _removerDisponibilidadeSombraNoBatch(
          batch: batch,
          unidadeRef: unidadeRef,
          medicoId: atualizada.medicoId,
          disponibilidadeId: correcao.original.id,
          data: atualizada.data,
        );
        medicosComSerieAtualizada.add(atualizada.medicoId);
        removeuDisponibilidadeSombra = true;
      } else {
        _gravarAlocacaoNoBatch(
          batch: batch,
          unidadeRef: unidadeRef,
          alocacao: atualizada,
        );
        atualizouAlocacaoPersistida = true;
      }
    }
    await batch.commit();
    await CacheVersionService.bumpVersions(
      unidadeId: unidadeId,
      fields: [
        if (atualizouAlocacaoPersistida) CacheVersionService.fieldAlocacoes,
        if (medicosComSerieAtualizada.isNotEmpty)
          CacheVersionService.fieldSeries,
        if (removeuDisponibilidadeSombra)
          CacheVersionService.fieldDisponibilidades,
      ],
    );
    for (final correcao in correcoes) {
      AlocacaoCacheStore.invalidateCacheForDay(correcao.atualizada.data);
    }
    return medicosComSerieAtualizada;
  }

  /// Remove uma disponibilidade avulsa que foi criada indevidamente para um
  /// cartão cuja fonte verdadeira é uma série de ocorrência única.
  static Future<void> removerDisponibilidadeSombraDeSerie({
    required String unidadeId,
    required String medicoId,
    required String disponibilidadeId,
    required DateTime data,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final unidadeRef = firestore.collection('unidades').doc(unidadeId);
    final batch = firestore.batch();
    _removerDisponibilidadeSombraNoBatch(
      batch: batch,
      unidadeRef: unidadeRef,
      medicoId: medicoId,
      disponibilidadeId: disponibilidadeId,
      data: data,
    );
    await batch.commit();
    await CacheVersionService.bumpVersion(
      unidadeId: unidadeId,
      field: CacheVersionService.fieldDisponibilidades,
    );
    AlocacaoCacheStore.invalidateCacheForDay(data);
  }

  static void _gravarAlocacaoNoBatch({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> unidadeRef,
    required Alocacao alocacao,
  }) {
    final ano = alocacao.data.year.toString();
    final dia = _keyDia(alocacao.data);
    final dados = alocacao.toMap();
    batch.set(
      unidadeRef
          .collection('alocacoes')
          .doc(ano)
          .collection('registos')
          .doc(alocacao.id),
      dados,
    );
    batch.set(
      unidadeRef
          .collection('dias')
          .doc(dia)
          .collection('alocacoes')
          .doc(alocacao.id),
      dados,
    );
  }

  static void _removerDisponibilidadeSombraNoBatch({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> unidadeRef,
    required String medicoId,
    required String disponibilidadeId,
    required DateTime data,
  }) {
    final ano = data.year.toString();
    final dia = _keyDia(data);
    batch.delete(
      unidadeRef
          .collection('ocupantes')
          .doc(medicoId)
          .collection('disponibilidades')
          .doc(ano)
          .collection('registos')
          .doc(disponibilidadeId),
    );
    batch.delete(
      unidadeRef
          .collection('dias')
          .doc(dia)
          .collection('disponibilidades')
          .doc(disponibilidadeId),
    );
  }
}
