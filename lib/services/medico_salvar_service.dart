// lib/services/medico_salvar_service.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart'; // Corrigido: Importação do modelo Disponibilidade para evitar erro de referência.
import 'cache_version_service.dart';
import 'matriz_distribuicao_cache_service.dart';

final Map<String, List<Medico>> _cacheMedicosPorUnidade = {};

String _cacheKeyMedicos(Unidade? unidade) {
  final id = unidade?.id;
  return (id == null || id.isEmpty) ? '_global' : id;
}

void limparCacheMedicos({Unidade? unidade}) {
  MatrizDistribuicaoCacheService.invalidar(unidadeId: unidade?.id);
  if (unidade == null) {
    _cacheMedicosPorUnidade.clear();
    return;
  }
  _cacheMedicosPorUnidade.remove(_cacheKeyMedicos(unidade));
}

/// Busca todas as especialidades existentes dos médicos
Future<List<String>> buscarEspecialidadesExistentes({Unidade? unidade}) async {
  final List<String> especialidades = [];

  try {
    final medicos = await buscarMedicos(unidade: unidade);
    for (final medico in medicos) {
      final especialidade = medico.especialidade.trim();
      if (especialidade.isNotEmpty) {
        especialidades.add(especialidade);
      }
    }

    // Remove duplicatas e ordena alfabeticamente
    final especialidadesUnicas = especialidades.toSet().toList()..sort();
    return especialidadesUnicas;
  } catch (e) {
    debugPrint('❌ Erro ao buscar especialidades: $e');
    return [];
  }
}

Future<void> salvarMedicoCompleto(
  Medico medico, {
  Unidade? unidade,
  Medico? medicoOriginal,
  FirebaseFirestore? firestoreParaTeste,
  List<Disponibilidade>? disponibilidadesOriginais, // opcional: evita reler
}) async {
  final firestore = firestoreParaTeste ?? FirebaseFirestore.instance;

  DocumentReference medicoRef;
  if (unidade != null) {
    // Salva na nova estrutura: /unidades/{id}/ocupantes/{medicoId}
    medicoRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('ocupantes')
        .doc(medico.id);
  } else {
    // Salva na estrutura antiga (fallback)
    medicoRef = firestore.collection('medicos').doc(medico.id);
  }

  final dadosMedicoAlterados = medicoOriginal == null ||
      medicoOriginal.nome != medico.nome ||
      medicoOriginal.especialidade != medico.especialidade ||
      medicoOriginal.observacoes != medico.observacoes ||
      medicoOriginal.ativo != medico.ativo;
  if (dadosMedicoAlterados) {
    await medicoRef.set({
      if (medicoOriginal == null) 'id': medico.id,
      if (medicoOriginal == null || medicoOriginal.nome != medico.nome)
        'nome': medico.nome,
      if (medicoOriginal == null ||
          medicoOriginal.especialidade != medico.especialidade)
        'especialidade': medico.especialidade,
      if (medicoOriginal == null ||
          medicoOriginal.observacoes != medico.observacoes)
        'observacoes': medico.observacoes,
      if (medicoOriginal == null || medicoOriginal.ativo != medico.ativo)
        'ativo': medico.ativo,
      if (medicoOriginal == null || medicoOriginal.nome != medico.nome)
        'nomeSearch': _normalize(medico.nome),
      if (medicoOriginal == null ||
          medicoOriginal.nome != medico.nome ||
          medicoOriginal.especialidade != medico.especialidade)
        'searchTokens': _buildSearchTokens(medico.nome, medico.especialidade),
    }, SetOptions(merge: true));
  }

  debugPrint('✅ Médico salvo: ${medico.nome} (ID: ${medico.id})');
  debugPrint('📊 Disps (novas): ${medico.disponibilidades.length}');
  debugPrint('🔄 Campo ativo salvo: ${medico.ativo}');

  // Caminho base das disponibilidades
  final dispRef = medicoRef.collection('disponibilidades');

  // 1) Ler existentes caso não tenham sido fornecidas
  Map<String, Disponibilidade> existentes = {};
  if (disponibilidadesOriginais != null) {
    for (final d in disponibilidadesOriginais) {
      if (!d.id.startsWith('serie_')) existentes[d.id] = d;
    }
  } else {
    final anosSnap =
        await dispRef.get(const GetOptions(source: Source.serverAndCache));
    for (final anoDoc in anosSnap.docs) {
      final registosSnap = await anoDoc.reference
          .collection('registos')
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in registosSnap.docs) {
        if (!doc.id.startsWith('serie_')) {
          existentes[doc.id] = Disponibilidade.fromMap(doc.data());
        }
      }
    }
  }

  // 2) Map das novas
  final Map<String, Disponibilidade> novas = {
    for (final d in medico.disponibilidades)
      if (!d.id.startsWith('serie_')) d.id: d
  };

  // 3) Calcular diff
  final idsExistentes = existentes.keys.toSet();
  final idsNovas = novas.keys.toSet();
  final idsParaApagar = idsExistentes.difference(idsNovas);
  final idsParaCriar = idsNovas.difference(idsExistentes);
  final idsPossiveisUpdates = idsExistentes.intersection(idsNovas);

  final disponibilidadesAlteradas = medico.disponibilidades.where((d) {
    // Cartões gerados pertencem à regra da série, não a documentos por dia.
    if (d.id.startsWith('serie_')) return false;
    final original = existentes[d.id];
    return original == null ||
        original.medicoId != d.medicoId ||
        original.data != d.data ||
        original.tipo != d.tipo ||
        !listEquals(original.horarios, d.horarios);
  }).toList();

  final batch = firestore.batch();

  // Deletes
  for (final id in idsParaApagar) {
    final d = existentes[id]!;
    final ano = d.data.year.toString();
    final ref = dispRef.doc(ano).collection('registos').doc(id);
    batch.delete(ref);
  }

  // Gravar apenas registos novos ou alterados.
  for (final d in disponibilidadesAlteradas) {
    final ano = d.data.year.toString();
    final ref = dispRef.doc(ano).collection('registos').doc(d.id);
    batch.set(ref, {
      'id': d.id,
      'medicoId': medico.id,
      'data': d.data.toIso8601String(),
      'horarios': d.horarios,
      'tipo': d.tipo,
    });
  }

  if (idsParaApagar.isNotEmpty || disponibilidadesAlteradas.isNotEmpty) {
    await batch.commit();
  }
  final disponibilidadesMudaram =
      idsParaApagar.isNotEmpty || disponibilidadesAlteradas.isNotEmpty;
  if (dadosMedicoAlterados || disponibilidadesMudaram) {
    await CacheVersionService.bumpVersions(
      firestore: firestoreParaTeste,
      unidadeId: unidade?.id,
      fields: [
        if (dadosMedicoAlterados) CacheVersionService.fieldMedicos,
        if (disponibilidadesMudaram) CacheVersionService.fieldDisponibilidades,
      ],
    );
    limparCacheMedicos(unidade: unidade);
  }
  debugPrint(
      '✅ Diff aplicado: -${idsParaApagar.length} / +${idsParaCriar.length} / ~${idsPossiveisUpdates.length}');
}

Future<List<Medico>> buscarMedicos({
  Unidade? unidade,
  bool usarCache = true,
  bool forcarAtualizacao = false,
}) async {
  final firestore = FirebaseFirestore.instance;
  CollectionReference medicosRef;
  final cacheKey = _cacheKeyMedicos(unidade);

  if (usarCache && !forcarAtualizacao) {
    final cached = _cacheMedicosPorUnidade[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return List<Medico>.from(cached);
    }
  }

  if (unidade != null) {
    // Busca médicos da unidade específica
    medicosRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('ocupantes');
  } else {
    // Busca todos os médicos (fallback para compatibilidade)
    medicosRef = firestore.collection('medicos');
  }

  final medicosSnap =
      await medicosRef.get(const GetOptions(source: Source.serverAndCache));
  final medicos = <Medico>[];
  for (final doc in medicosSnap.docs) {
    final dados = doc.data() as Map<String, dynamic>;
    // Buscar TODOS os médicos (ativos e inativos) para que os cartões antigos
    // mostrem o nome correto mesmo quando o médico está inativo
    final ativo = dados['ativo'] ?? true;
    medicos.add(Medico(
      id: dados['id'],
      nome: dados['nome'],
      especialidade: dados['especialidade'],
      observacoes: dados['observacoes'],
      // Não carregar disponibilidades aqui para evitar centenas de leituras no arranque
      disponibilidades: const [],
      ativo: ativo,
    ));
  }
  if (medicos.isNotEmpty) {
    _cacheMedicosPorUnidade[cacheKey] = List<Medico>.from(medicos);
  }
  return medicos;
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[áàâã]"), 'a')
    .replaceAll(RegExp(r"[éê]"), 'e')
    .replaceAll(RegExp(r"[í]"), 'i')
    .replaceAll(RegExp(r"[óôõ]"), 'o')
    .replaceAll(RegExp(r"[ú]"), 'u')
    .replaceAll(RegExp(r"[ç]"), 'c');

List<String> _buildSearchTokens(String nome, String especialidade) {
  final base = ('${_normalize(nome)} ${_normalize(especialidade)}')
      .split(RegExp(r"\s+"))
      .where((t) => t.isNotEmpty)
      .toSet();
  return base.toList();
}
