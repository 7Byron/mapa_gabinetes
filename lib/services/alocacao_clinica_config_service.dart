import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/cache_version_service.dart';

class ClinicaConfiguracoes {
  final Map<int, List<String>> horariosClinica;
  final bool nuncaEncerra;
  final bool encerraFeriados;
  final Map<int, bool> encerraDias;

  const ClinicaConfiguracoes({
    required this.horariosClinica,
    required this.nuncaEncerra,
    required this.encerraFeriados,
    required this.encerraDias,
  });
}

class AlocacaoClinicaConfigService {
  static final Map<String, List<Map<String, String>>> _cacheFeriados = {};
  static final Map<String, List<Map<String, dynamic>>> _cacheEncerramentos = {};
  static final Map<String, ClinicaConfiguracoes> _cacheHorarios = {};
  static final Set<String> _cacheInvalidado = {};
  static final Map<String, int> _versaoClinicaPorUnidade = {};
  static int _cacheHits = 0;
  static int _cacheMisses = 0;

  static Future<void> _sincronizarVersao(String unidadeId) async {
    final versoes =
        await CacheVersionService.fetchVersions(unidadeId: unidadeId);
    final versaoRemota =
        versoes[CacheVersionService.fieldClinicaConfig] ?? 0;
    final versaoLocal = _versaoClinicaPorUnidade[unidadeId];
    if (versaoLocal != null && versaoLocal != versaoRemota) {
      invalidateCache(unidadeId);
    }
    _versaoClinicaPorUnidade[unidadeId] = versaoRemota;
  }

  static void invalidateCache([String? unidadeId, int? ano]) {
    if (unidadeId == null || unidadeId.isEmpty) {
      _cacheFeriados.clear();
      _cacheEncerramentos.clear();
      _cacheHorarios.clear();
      _cacheInvalidado.clear();
      _versaoClinicaPorUnidade.clear();
      return;
    }

    if (ano != null) {
      final keyFeriados = '${unidadeId}_feriados_$ano';
      final keyEncerramentos = '${unidadeId}_encerramentos_$ano';
      _cacheFeriados.remove(keyFeriados);
      _cacheEncerramentos.remove(keyEncerramentos);
      _cacheInvalidado.add(keyFeriados);
      _cacheInvalidado.add(keyEncerramentos);
      return;
    }

    final keysToInvalidate = <String>[];
    for (final key in _cacheFeriados.keys) {
      if (key.startsWith('${unidadeId}_feriados_')) {
        keysToInvalidate.add(key);
      }
    }
    for (final key in _cacheEncerramentos.keys) {
      if (key.startsWith('${unidadeId}_encerramentos_')) {
        keysToInvalidate.add(key);
      }
    }
    keysToInvalidate.add('${unidadeId}_horarios');
    for (final key in keysToInvalidate) {
      _cacheInvalidado.add(key);
      _cacheFeriados.remove(key);
      _cacheEncerramentos.remove(key);
      _cacheHorarios.remove(key);
    }
  }

  static Future<List<Map<String, String>>> carregarFeriados({
    required String unidadeId,
    required int anoSelecionado,
    bool forcarServidor = false,
  }) async {
    final feriadosRef = FirebaseFirestore.instance
        .collection('unidades')
        .doc(unidadeId)
        .collection('feriados');

    final cacheKey = '${unidadeId}_$anoSelecionado';
    await _sincronizarVersao(unidadeId);
    final cache = _cacheFeriados[cacheKey];
    final cacheInvalidado = _cacheInvalidado.contains(cacheKey);
    if (!forcarServidor && cache != null && !cacheInvalidado) {
      _cacheHits++;
      return List<Map<String, String>>.from(cache);
    }
    _cacheMisses++;

    final feriadosTemp = <Map<String, String>>[];
    try {
      final anoRef = feriadosRef.doc(anoSelecionado.toString());
      final registosSnapshot = await anoRef
          .collection('registos')
          .get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
      for (final doc in registosSnapshot.docs) {
        final data = doc.data();
        feriadosTemp.add(<String, String>{
          'id': doc.id,
          'data': data['data'] as String? ?? '',
          'descricao': data['descricao'] as String? ?? '',
        });
      }
      _cacheFeriados[cacheKey] = List<Map<String, String>>.from(feriadosTemp);
      _cacheInvalidado.remove(cacheKey);
      return feriadosTemp;
    } catch (_) {
      // Fallback: carregar todos os anos
      final anosSnapshot =
          await feriadosRef.get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
      for (final anoDoc in anosSnapshot.docs) {
        final registosSnapshot =
            await anoDoc.reference
                .collection('registos')
                .get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          feriadosTemp.add(<String, String>{
            'id': doc.id,
            'data': data['data'] as String? ?? '',
            'descricao': data['descricao'] as String? ?? '',
          });
        }
      }
      _cacheFeriados[cacheKey] = List<Map<String, String>>.from(feriadosTemp);
      _cacheInvalidado.remove(cacheKey);
      return feriadosTemp;
    }
  }

  static Future<List<Map<String, dynamic>>> carregarDiasEncerramento({
    required String unidadeId,
    required int anoSelecionado,
    bool forcarServidor = false,
  }) async {
    final encerramentosRef = FirebaseFirestore.instance
        .collection('unidades')
        .doc(unidadeId)
        .collection('encerramentos');

    final cacheKey = '${unidadeId}_$anoSelecionado';
    await _sincronizarVersao(unidadeId);
    final cache = _cacheEncerramentos[cacheKey];
    final cacheInvalidado = _cacheInvalidado.contains(cacheKey);
    if (!forcarServidor && cache != null && !cacheInvalidado) {
      _cacheHits++;
      return List<Map<String, dynamic>>.from(cache);
    }
    _cacheMisses++;

    final diasTemp = <Map<String, dynamic>>[];
    try {
      final anoRef = encerramentosRef.doc(anoSelecionado.toString());
      final registosSnapshot = await anoRef
          .collection('registos')
          .get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
      for (final doc in registosSnapshot.docs) {
        final data = doc.data();
        diasTemp.add(<String, dynamic>{
          'id': doc.id,
          'data': data['data'] as String? ?? '',
          'descricao': data['descricao'] as String? ?? '',
          'motivo': data['motivo'] as String? ?? 'Encerramento',
        });
      }
      _cacheEncerramentos[cacheKey] =
          List<Map<String, dynamic>>.from(diasTemp);
      _cacheInvalidado.remove(cacheKey);
      return diasTemp;
    } catch (_) {
      // Fallback: carregar todos os anos
      final anosSnapshot =
          await encerramentosRef.get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
      for (final anoDoc in anosSnapshot.docs) {
        final registosSnapshot =
            await anoDoc.reference
                .collection('registos')
                .get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          diasTemp.add({
            'id': doc.id,
            'data': data['data'] as String? ?? '',
            'descricao': data['descricao'] as String? ?? '',
            'motivo': data['motivo'] as String? ?? 'Encerramento',
          });
        }
      }
      _cacheEncerramentos[cacheKey] =
          List<Map<String, dynamic>>.from(diasTemp);
      _cacheInvalidado.remove(cacheKey);
      return diasTemp;
    }
  }

  static Future<ClinicaConfiguracoes> carregarHorariosEConfiguracoes({
    required String unidadeId,
    bool forcarServidor = false,
  }) async {
    final horariosRef = FirebaseFirestore.instance
        .collection('unidades')
        .doc(unidadeId)
        .collection('horarios_clinica');

    await _sincronizarVersao(unidadeId);
    final cache = _cacheHorarios[unidadeId];
    final cacheInvalidado = _cacheInvalidado.contains('${unidadeId}_horarios');
    if (!forcarServidor && cache != null && !cacheInvalidado) {
      _cacheHits++;
      return cache;
    }
    _cacheMisses++;

    final horariosSnapshot =
        await horariosRef.get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
    final horariosTemp = <int, List<String>>{};
    for (final doc in horariosSnapshot.docs) {
      final data = doc.data();
      final diaSemana = data['diaSemana'] as int? ?? 0;
      final horaAbertura = data['horaAbertura'] as String? ?? '';
      final horaFecho = data['horaFecho'] as String? ?? '';
      if (horaAbertura.isNotEmpty && horaFecho.isNotEmpty) {
        horariosTemp[diaSemana] = [horaAbertura, horaFecho];
      }
    }

    bool nuncaEncerra = false;
    bool encerraFeriados = false;
    final encerraDias = <int, bool>{
      1: false,
      2: false,
      3: false,
      4: false,
      5: false,
      6: false,
      7: false,
    };

    try {
      final configDoc = await horariosRef
          .doc('config')
          .get(GetOptions(source: forcarServidor ? Source.server : Source.serverAndCache));
      if (configDoc.exists) {
        final configData = configDoc.data() as Map<String, dynamic>;
        nuncaEncerra = configData['nuncaEncerra'] as bool? ?? false;
        encerraFeriados = configData['encerraFeriados'] as bool? ?? false;
        for (int i = 1; i <= 7; i++) {
          encerraDias[i] = configData['encerraDia$i'] as bool? ?? false;
        }
      }
    } catch (_) {}

    final resultado = ClinicaConfiguracoes(
      horariosClinica: horariosTemp,
      nuncaEncerra: nuncaEncerra,
      encerraFeriados: encerraFeriados,
      encerraDias: encerraDias,
    );
    _cacheHorarios[unidadeId] = resultado;
    _cacheInvalidado.remove('${unidadeId}_horarios');
    return resultado;
  }

  static void logResumo() {
    if (!kDebugMode) return;
    debugPrint(
        '📊 [CACHE-CLINICA] hits=$_cacheHits, misses=$_cacheMisses');
  }

  static void resetResumo() {
    _cacheHits = 0;
    _cacheMisses = 0;
  }
}
