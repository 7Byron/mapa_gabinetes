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

  // Salva as disponibilidades como subcoleção
  final dispRef = medicoRef.collection('disponibilidades');

  // Remove todas as disponibilidades antigas
  final batch = firestore.batch();
  final antigas = await dispRef.get();
  for (final doc in antigas.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();

  // Adiciona as novas disponibilidades
  for (final disp in medico.disponibilidades) {
    await dispRef.doc(disp.id).set({
      'id': disp.id,
      'medicoId': medico.id,
      'data': disp.data.toIso8601String(),
      'horarios': disp.horarios,
      'tipo': disp.tipo,
    });
  }
}

Future<List<Medico>> buscarMedicos() async {
  final firestore = FirebaseFirestore.instance;
  final medicosSnap = await firestore.collection('medicos').get();
  List<Medico> medicos = [];
  for (final doc in medicosSnap.docs) {
    final dados = doc.data();
    // Busca disponibilidades
    final dispSnap = await doc.reference.collection('disponibilidades').get();
    final disponibilidades = dispSnap.docs
        .map((d) => {
              ...d.data(),
              'horarios':
                  d.data()['horarios'] is List ? d.data()['horarios'] : [],
            })
        .toList();
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
