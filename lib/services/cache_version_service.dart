import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_init_service.dart';
import 'matriz_distribuicao_cache_service.dart';

class CacheVersionService {
  static final Object _chaveEscopo = Object();

  /// Partilha apenas as leituras da mesma ação; a ação seguinte valida de novo
  /// no servidor. Não introduz TTL nem reutiliza versões entre consultas.
  static Future<T> comVersoesPartilhadas<T>(Future<T> Function() acao) async {
    final atual = Zone.current[_chaveEscopo] as _EscopoVersoes?;
    if (atual != null && atual.ativo) return acao();
    final escopo = _EscopoVersoes();
    try {
      return await runZoned(acao, zoneValues: {_chaveEscopo: escopo});
    } finally {
      escopo.ativo = false;
      escopo.leituras.clear();
    }
  }

  static const String _docId = 'global';
  static const String _collection = 'cache_control';

  static const String fieldSeries = 'seriesVersion';
  static const String fieldAlocacoes = 'alocacoesVersion';
  static const String fieldDisponibilidades = 'disponibilidadesVersion';
  static const String fieldMedicos = 'medicosVersion';
  static const String fieldGabinetes = 'gabinetesVersion';
  static const String fieldClinicaConfig = 'clinicaConfigVersion';
  static const String _globalKey = '_global';
  static final Map<String, Map<String, int>> _lastVersionsByKey = {};

  static DocumentReference<Map<String, dynamic>> _docRef(String? unidadeId,
      [FirebaseFirestore? banco]) {
    final firestore = banco ?? FirebaseFirestore.instance;
    if (unidadeId == null || unidadeId.isEmpty) {
      return firestore.collection(_collection).doc(_docId);
    }
    return firestore
        .collection('unidades')
        .doc(unidadeId)
        .collection(_collection)
        .doc(_docId);
  }

  static String _cacheKey(String? unidadeId) {
    if (unidadeId == null || unidadeId.isEmpty) {
      return _globalKey;
    }
    return unidadeId;
  }

  static Map<String, int> _buildZeroVersions() {
    return {
      fieldSeries: 0,
      fieldAlocacoes: 0,
      fieldDisponibilidades: 0,
      fieldMedicos: 0,
      fieldGabinetes: 0,
      fieldClinicaConfig: 0,
    };
  }

  static Map<String, int> _parseSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      return _buildZeroVersions();
    }
    final data = snapshot.data();
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return {
      fieldSeries: asInt(data?[fieldSeries]),
      fieldAlocacoes: asInt(data?[fieldAlocacoes]),
      fieldDisponibilidades: asInt(data?[fieldDisponibilidades]),
      fieldMedicos: asInt(data?[fieldMedicos]),
      fieldGabinetes: asInt(data?[fieldGabinetes]),
      fieldClinicaConfig: asInt(data?[fieldClinicaConfig]),
    };
  }

  static void _cacheVersions(String key, Map<String, int> versions) {
    _lastVersionsByKey[key] = Map<String, int>.from(versions);
  }

  static Future<Map<String, int>> fetchVersions({
    String? unidadeId,
    FirebaseFirestore? firestore,
  }) async {
    final escopo = Zone.current[_chaveEscopo] as _EscopoVersoes?;
    if (escopo == null || !escopo.ativo) {
      return _buscarVersoes(unidadeId, firestore);
    }
    final leitura = escopo.leituras.putIfAbsent(
      (firestore, _cacheKey(unidadeId)),
      () => _buscarVersoes(unidadeId, firestore),
    );
    return Map<String, int>.from(await leitura);
  }

  static Future<Map<String, int>> _buscarVersoes(
      String? unidadeId, FirebaseFirestore? firestore) async {
    final key = _cacheKey(unidadeId);
    try {
      if (firestore == null) await FirebaseInitService.ensureInitialized();
      final snapshot = await _docRef(unidadeId, firestore)
          .get(const GetOptions(source: Source.server));
      final versions = _parseSnapshot(snapshot);
      _cacheVersions(key, versions);
      return versions;
    } catch (_) {
      try {
        final snapshot = await _docRef(unidadeId, firestore)
            .get(const GetOptions(source: Source.cache));
        final versions = _parseSnapshot(snapshot);
        _cacheVersions(key, versions);
        return versions;
      } catch (_) {}
      final cached = _lastVersionsByKey[key];
      if (cached != null) {
        return Map<String, int>.from(cached);
      }
      return _buildZeroVersions();
    }
  }

  static Future<void> bumpVersion({
    String? unidadeId,
    required String field,
    FirebaseFirestore? firestore,
  }) async {
    await bumpVersions(
        unidadeId: unidadeId, fields: [field], firestore: firestore);
  }

  static Future<void> bumpVersions({
    String? unidadeId,
    required List<String> fields,
    FirebaseFirestore? firestore,
  }) async {
    // Uma escrita dentro da ação invalida também a fotografia de versões.
    final escopo = Zone.current[_chaveEscopo] as _EscopoVersoes?;
    escopo?.leituras.removeWhere((key, _) => key.$2 == _cacheKey(unidadeId));
    if (fields.any((field) =>
        field == fieldMedicos ||
        field == fieldGabinetes ||
        field == fieldSeries)) {
      MatrizDistribuicaoCacheService.invalidar(unidadeId: unidadeId);
    }
    try {
      if (firestore == null) await FirebaseInitService.ensureInitialized();
      if (fields.isEmpty) return;
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final field in fields) {
        updates[field] = FieldValue.increment(1);
      }
      final ref = firestore == null
          ? _docRef(unidadeId)
          : (unidadeId == null || unidadeId.isEmpty
              ? firestore.collection(_collection).doc(_docId)
              : firestore
                  .collection('unidades')
                  .doc(unidadeId)
                  .collection(_collection)
                  .doc(_docId));
      await ref.set(
        updates,
        SetOptions(merge: true),
      );
      escopo?.leituras.removeWhere((key, _) => key.$2 == _cacheKey(unidadeId));
    } catch (_) {}
  }
}

class _EscopoVersoes {
  bool ativo = true;
  final leituras = <(FirebaseFirestore?, String), Future<Map<String, int>>>{};
}
