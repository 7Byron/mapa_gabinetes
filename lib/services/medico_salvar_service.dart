// lib/services/medico_salvar_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart'; // Corrigido: Importação do modelo Disponibilidade para evitar erro de referência.

Future<void> salvarMedicoCompleto(Medico medico, {Unidade? unidade}) async {
  final firestore = FirebaseFirestore.instance;

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

  // Salva o médico (dados básicos)
  await medicoRef.set({
    'id': medico.id,
    'nome': medico.nome,
    'especialidade': medico.especialidade,
    'observacoes': medico.observacoes,
  });
  
  print('✅ Médico salvo: ${medico.nome} (ID: ${medico.id})');
  print('📊 Total de disponibilidades a salvar: ${medico.disponibilidades.length}');

  // Salva as disponibilidades como subcoleção por ano
  final dispRef = medicoRef.collection('disponibilidades');

  // Remove todas as disponibilidades antigas (todos os anos)
  final batch = firestore.batch();
  final anosSnapshot = await dispRef.get();
  for (final anoDoc in anosSnapshot.docs) {
    final registosRef = anoDoc.reference.collection('registos');
    final registosSnapshot = await registosRef.get();
    for (final doc in registosSnapshot.docs) {
      batch.delete(doc.reference);
    }
    // Remove o documento do ano se estiver vazio
    batch.delete(anoDoc.reference);
  }
  await batch.commit();

  // Agrupa disponibilidades por ano
  final disponibilidadesPorAno = <String, List<Disponibilidade>>{};
  for (final disp in medico.disponibilidades) {
    final ano = disp.data.year.toString();
    disponibilidadesPorAno.putIfAbsent(ano, () => []).add(disp);
  }

  // Adiciona as novas disponibilidades organizadas por ano
  for (final entry in disponibilidadesPorAno.entries) {
    final ano = entry.key;
    final disponibilidadesDoAno = entry.value;
    
    final anoRef = dispRef.doc(ano);
    final registosRef = anoRef.collection('registos');
    
    for (final disp in disponibilidadesDoAno) {
      await registosRef.doc(disp.id).set({
        'id': disp.id,
        'medicoId': medico.id,
        'data': disp.data.toIso8601String(),
        'horarios': disp.horarios,
        'tipo': disp.tipo,
      });
    }
    
    print('✅ Disponibilidades salvas para o ano $ano: ${disponibilidadesDoAno.length} registos');
  }
}

Future<List<Medico>> buscarMedicos({Unidade? unidade}) async {
  final firestore = FirebaseFirestore.instance;
  CollectionReference medicosRef;

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

  final medicosSnap = await medicosRef.get();
  List<Medico> medicos = [];
  for (final doc in medicosSnap.docs) {
    final dados = doc.data() as Map<String, dynamic>;
    // Busca disponibilidades da nova estrutura por ano
    final dispRef = doc.reference.collection('disponibilidades');
    final disponibilidades = <Map<String, dynamic>>[];
    
    // Carrega apenas o ano atual por padrão (otimização)
    final anoAtual = DateTime.now().year.toString();
    final anoRef = dispRef.doc(anoAtual);
    final registosRef = anoRef.collection('registos');
    
    try {
      final registosSnapshot = await registosRef.get();
      for (final d in registosSnapshot.docs) {
        final data = d.data();
        disponibilidades.add({
          ...data,
          'horarios': data['horarios'] is List ? data['horarios'] : [],
        });
      }
      print('📊 Disponibilidades carregadas para ${dados['nome']}: ${disponibilidades.length} (ano: $anoAtual)');
    } catch (e) {
      print('⚠️ Erro ao carregar disponibilidades do ano $anoAtual para ${dados['nome']}: $e');
      // Fallback: tenta carregar de todos os anos
      final anosSnapshot = await dispRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        for (final d in registosSnapshot.docs) {
          final data = d.data();
          disponibilidades.add({
            ...data,
            'horarios': data['horarios'] is List ? data['horarios'] : [],
          });
        }
      }
      print('📊 Disponibilidades carregadas (fallback) para ${dados['nome']}: ${disponibilidades.length}');
    }
    medicos.add(Medico(
      id: dados['id'],
      nome: dados['nome'],
      especialidade: dados['especialidade'],
      observacoes: dados['observacoes'],
      disponibilidades:
          disponibilidades.map((e) => Disponibilidade.fromMap(e)).toList(),
    ));
  }
  return medicos;
}
