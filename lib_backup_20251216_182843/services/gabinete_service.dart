// lib/services/gabinete_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';

Future<void> salvarGabineteCompleto(Gabinete gabinete,
    {Unidade? unidade}) async {
  final firestore = FirebaseFirestore.instance;

  DocumentReference gabineteRef;
  if (unidade != null) {
    // Salva na nova estrutura: /unidades/{id}/gabinetes/{gabineteId}
    gabineteRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('gabinetes')
        .doc(gabinete.id);
  } else {
    // Salva na estrutura antiga (fallback)
    gabineteRef = firestore.collection('gabinetes').doc(gabinete.id);
  }

  // Salva o gabinete
  await gabineteRef.set({
    'id': gabinete.id,
    'setor': gabinete.setor,
    'nome': gabinete.nome,
    'especialidades': gabinete.especialidadesPermitidas.join(','),
  });
}

Future<List<Gabinete>> buscarGabinetes({Unidade? unidade}) async {
  final firestore = FirebaseFirestore.instance;
  CollectionReference gabinetesRef;

  if (unidade != null) {
    // Busca gabinetes da unidade específica
    gabinetesRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('gabinetes');
  } else {
    // Busca todos os gabinetes (fallback para compatibilidade)
    gabinetesRef = firestore.collection('gabinetes');
  }

  final gabinetesSnap =
      await gabinetesRef.get(const GetOptions(source: Source.serverAndCache));
  List<Gabinete> gabinetes = [];

  for (final doc in gabinetesSnap.docs) {
    final dados = doc.data() as Map<String, dynamic>;
    // Adiciona o ID do documento se não existir
    if (!dados.containsKey('id')) {
      dados['id'] = doc.id;
    }
    gabinetes.add(Gabinete.fromMap(dados));
  }

  return gabinetes;
}

Future<void> deletarGabinete(String gabineteId, {Unidade? unidade}) async {
  final firestore = FirebaseFirestore.instance;
  DocumentReference gabineteRef;

  if (unidade != null) {
    // Deleta da estrutura da unidade
    gabineteRef = firestore
        .collection('unidades')
        .doc(unidade.id)
        .collection('gabinetes')
        .doc(gabineteId);
  } else {
    // Deleta da estrutura antiga (fallback)
    gabineteRef = firestore.collection('gabinetes').doc(gabineteId);
  }

  await gabineteRef.delete();
}
