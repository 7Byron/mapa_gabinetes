import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_init_service.dart';

class CacheVersionService {
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

  static DocumentReference<Map<String, dynamic>> _docRef(String? unidadeId) {
    final firestore = FirebaseFirestore.instance;
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

  static Future<Map<String, int>> fetchVersions({String? unidadeId}) async {
    final key = _cacheKey(unidadeId);
    try {
      await FirebaseInitService.ensureInitialized();
      final snapshot = await _docRef(unidadeId)
          .get(const GetOptions(source: Source.server));
      final versions = _parseSnapshot(snapshot);
      _cacheVersions(key, versions);
      return versions;
    } catch (_) {
      try {
        final snapshot = await _docRef(unidadeId)
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
  }) async {
    await bumpVersions(unidadeId: unidadeId, fields: [field]);
  }

  static Future<void> bumpVersions({
    String? unidadeId,
    required List<String> fields,
  }) async {
    try {
      await FirebaseInitService.ensureInitialized();
      if (fields.isEmpty) return;
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      for (final field in fields) {
        updates[field] = FieldValue.increment(1);
      }
      await _docRef(unidadeId).set(
        updates,
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
