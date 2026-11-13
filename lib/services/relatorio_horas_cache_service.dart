import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/resumo_horas_mes.dart';
import 'cache_version_service.dart';

/// Cache local persistente e resumos partilhados. Não tem expiração por tempo:
/// a versão dos dados e do algoritmo determina se o resumo pode ser utilizado.
class RelatorioHorasCacheService {
  static final padrao = RelatorioHorasCacheService();
  static const esquema = 1;
  static const _prefixo = 'relatorio_horas_mensal_v1_';
  static const _tamanhoBloco = 500000;
  final FirebaseFirestore? firestore;
  final Future<SharedPreferences> Function() preferencias;

  RelatorioHorasCacheService(
      {this.firestore, Future<SharedPreferences> Function()? preferencias})
      : preferencias = preferencias ?? SharedPreferences.getInstance;

  static String versaoDados(Map<String, dynamic> dados) => [
        CacheVersionService.fieldSeries,
        CacheVersionService.fieldDisponibilidades,
        CacheVersionService.fieldMedicos,
        CacheVersionService.fieldClinicaConfig,
      ].map((campo) => (dados[campo] as num?)?.toInt() ?? 0).join('_');

  static String _mes(DateTime mes) =>
      '${mes.year}-${mes.month.toString().padLeft(2, '0')}';
  static String _chave(String unidade, DateTime mes) =>
      '$_prefixo${Uri.encodeComponent(unidade)}_${_mes(mes)}';
  DocumentReference<Map<String, dynamic>> _ref(String unidade, DateTime mes) =>
      (firestore ?? FirebaseFirestore.instance)
          .doc('unidades/$unidade/cache_relatorio_horas/${_mes(mes)}');

  Future<ResumoHorasMes?> ler(
      String unidade, DateTime mes, String versao) async {
    try {
      final texto = (await preferencias()).getString(_chave(unidade, mes));
      if (texto != null) {
        final local = jsonDecode(texto) as Map<String, dynamic>;
        final resumo = _validar(local, mes, versao);
        if (resumo != null) return resumo;
      }
    } catch (_) {/* Cache danificada ou armazenamento local indisponível. */}
    try {
      final ref = _ref(unidade, mes);
      final dados =
          (await ref.get(const GetOptions(source: Source.server))).data();
      if (dados == null ||
          dados['versao'] != versao ||
          dados['esquema'] != esquema) {
        return null;
      }
      String? payload = dados['payload'] as String?;
      if (payload == null) {
        final partes = dados['partes'] as int;
        if (partes < 1 || partes > 100) return null;
        final blocos = await Future.wait(List.generate(
            partes,
            (i) => ref
                .collection('blocos')
                .doc('${dados['hash']}_$i')
                .get(const GetOptions(source: Source.server))));
        payload = blocos.map((b) => b.data()!['payload'] as String).join();
      }
      final pacote = {...dados, 'payload': payload};
      final resumo = _validar(pacote, mes, versao);
      if (resumo != null) await _guardarLocal(unidade, mes, pacote);
      return resumo;
    } catch (erro) {
      debugPrint('Cache partilhada de horas indisponível: $erro');
      return null;
    }
  }

  static ResumoHorasMes? _validar(
      Map<String, dynamic> pacote, DateTime mes, String versao) {
    if (pacote['esquema'] != esquema || pacote['versao'] != versao) return null;
    final payload = pacote['payload'] as String;
    if (sha256.convert(utf8.encode(payload)).toString() != pacote['hash']) {
      return null;
    }
    final resumo = ResumoHorasMes.fromMap(
        jsonDecode(utf8.decode(base64Decode(payload))) as Map<String, dynamic>);
    return resumo.mes == DateTime(mes.year, mes.month) ? resumo : null;
  }

  Future<void> _guardarLocal(
      String unidade, DateTime mes, Map<String, dynamic> pacote) async {
    try {
      final prefs = await preferencias();
      await prefs.setString(_chave(unidade, mes), jsonEncode(pacote));
      // Limite de espaço, sem TTL: os meses conservados duram até serem alterados.
      final chaves =
          prefs.getKeys().where((k) => k.startsWith(_prefixo)).toList()..sort();
      for (final chave in chaves
          .where((k) => k != _chave(unidade, mes))
          .take(math.max(0, chaves.length - 36))) {
        await prefs.remove(chave);
      }
    } catch (_) {/* O relatório continua disponível mesmo sem espaço local. */}
  }

  Future<void> guardar(
      String unidade, String versao, List<ResumoHorasMes> resumos) async {
    final pacotes = <DateTime, Map<String, dynamic>>{};
    for (final resumo in resumos) {
      final payload = base64Encode(utf8.encode(jsonEncode(resumo.toMap())));
      pacotes[resumo.mes] = {
        'esquema': esquema,
        'versao': versao,
        'hash': sha256.convert(utf8.encode(payload)).toString(),
        'payload': payload
      };
    }
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final aceite = await db.runTransaction((tx) async {
        final controlo =
            await tx.get(db.doc('unidades/$unidade/cache_control/global'));
        if (versaoDados(controlo.data() ?? {}) != versao) return false;
        // Ler todos os manifestos antes de escrever qualquer documento.
        final anteriores = <DateTime, Map<String, dynamic>?>{};
        for (final mes in pacotes.keys) {
          anteriores[mes] = (await tx.get(_ref(unidade, mes))).data();
        }
        var operacoes = 0;
        for (final entrada in pacotes.entries) {
          final texto = entrada.value['payload'] as String;
          final partes = texto.length <= _tamanhoBloco
              ? 0
              : (texto.length / _tamanhoBloco).ceil();
          final antigas = (anteriores[entrada.key]?['partes'] as int?) ?? 0;
          operacoes += 1 + partes + antigas;
          if (partes > 100 || antigas > 100 || operacoes > 450) return false;
        }
        for (final entrada in pacotes.entries) {
          final pacote = entrada.value, anterior = anteriores[entrada.key];
          final texto = pacote['payload'] as String;
          final partes = texto.length <= _tamanhoBloco
              ? 0
              : (texto.length / _tamanhoBloco).ceil();
          if (anterior?['versao'] == versao &&
              anterior?['esquema'] == esquema &&
              anterior?['hash'] == pacote['hash'] &&
              partes == 0 &&
              anterior?['partes'] == 0 &&
              anterior?['payload'] == texto) {
            continue;
          }
          final ref = _ref(unidade, entrada.key);
          // Repor todos os blocos também repara uma cache incompleta com o
          // mesmo hash (por exemplo, após remoção de um bloco no servidor).
          final antigas = (anterior?['partes'] as int?) ?? 0;
          for (var i = 0; i < partes; i++) {
            tx.set(ref.collection('blocos').doc('${pacote['hash']}_$i'), {
              'payload': texto.substring(i * _tamanhoBloco,
                  math.min((i + 1) * _tamanhoBloco, texto.length))
            });
          }
          tx.set(ref, {
            for (final campo in pacote.entries)
              if (partes == 0 || campo.key != 'payload') campo.key: campo.value,
            'partes': partes
          });
          if (anterior?['hash'] != pacote['hash']) {
            for (var i = 0; i < antigas; i++) {
              tx.delete(
                  ref.collection('blocos').doc('${anterior!['hash']}_$i'));
            }
          }
        }
        return true;
      });
      if (!aceite) {
        return; // Alteração durante o cálculo: não publicar uma cache antiga.
      }
    } catch (erro) {
      debugPrint('Resumo de horas conservado apenas localmente: $erro');
    }
    for (final entrada in pacotes.entries) {
      await _guardarLocal(unidade, entrada.key, entrada.value);
    }
  }
}
