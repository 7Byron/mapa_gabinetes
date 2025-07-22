// lib/debug_firebase.dart
// Script para debug do Firebase - Execute temporariamente no main.dart

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugFirebase() async {
  print('🔍 === DEBUG FIREBASE ===');

  try {
    final firestore = FirebaseFirestore.instance;

    // 1. Verificar se a coleção 'unidades' existe
    print('📂 Verificando coleção "unidades"...');
    final unidadesSnapshot = await firestore.collection('unidades').get();
    print(
        '📊 Total de documentos na coleção "unidades": ${unidadesSnapshot.docs.length}');

    // 2. Listar todos os documentos
    for (final doc in unidadesSnapshot.docs) {
      print('📄 Documento ID: ${doc.id}');
      print('📄 Dados: ${doc.data()}');
      print('---');
    }

    // 3. Verificar documentos com ativa = true
    print('✅ Verificando documentos com ativa = true...');
    final ativasSnapshot = await firestore
        .collection('unidades')
        .where('ativa', isEqualTo: true)
        .get();
    print('📊 Documentos ativos: ${ativasSnapshot.docs.length}');

    for (final doc in ativasSnapshot.docs) {
      print('✅ Ativa - ID: ${doc.id}');
      print('✅ Dados: ${doc.data()}');
      print('---');
    }

    // 4. Verificar documentos com ativa = false
    print('❌ Verificando documentos com ativa = false...');
    final inativasSnapshot = await firestore
        .collection('unidades')
        .where('ativa', isEqualTo: false)
        .get();
    print('📊 Documentos inativos: ${inativasSnapshot.docs.length}');

    for (final doc in inativasSnapshot.docs) {
      print('❌ Inativa - ID: ${doc.id}');
      print('❌ Dados: ${doc.data()}');
      print('---');
    }

    // 5. Verificar documentos sem campo 'ativa'
    print('❓ Verificando documentos sem campo "ativa"...');
    final semAtivaSnapshot = await firestore.collection('unidades').get();

    final semAtiva = semAtivaSnapshot.docs
        .where((doc) => !doc.data().containsKey('ativa'))
        .toList();
    print('📊 Documentos sem campo "ativa": ${semAtiva.length}');

    for (final doc in semAtiva) {
      print('❓ Sem ativa - ID: ${doc.id}');
      print('❓ Dados: ${doc.data()}');
      print('---');
    }

    print('🔍 === FIM DEBUG FIREBASE ===');
  } catch (e) {
    print('❌ Erro no debug: $e');
  }
}
