// Script para limpar dados corrompidos no Firestore
// Execute este código temporariamente no seu app para limpar dados problemáticos

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> limparDadosCorrompidos() async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Busca todos os gabinetes
    final snapshot = await firestore.collection('gabinetes').get();

    print('Encontrados ${snapshot.docs.length} gabinetes');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      print('Documento ${doc.id}: $data');

      // Verifica se tem campos obrigatórios
      final id = data['id'] as String? ?? doc.id;
      final setor = data['setor'] as String? ?? '';
      final nome = data['nome'] as String? ?? '';
      final especialidades = data['especialidades'] as String? ?? '';

      // Se algum campo obrigatório estiver vazio, elimina o documento
      if (setor.isEmpty || nome.isEmpty) {
        print('Eliminando documento corrompido: ${doc.id}');
        await doc.reference.delete();
      } else {
        // Corrige o documento se necessário
        final dadosCorrigidos = {
          'id': id,
          'setor': setor,
          'nome': nome,
          'especialidades': especialidades,
        };

        await doc.reference.set(dadosCorrigidos);
        print('Documento corrigido: ${doc.id}');
      }
    }

    print('Limpeza concluída!');
  } catch (e) {
    print('Erro durante limpeza: $e');
  }
}

// Para usar, adicione temporariamente este código no seu app:
// await limparDadosCorrompidos();
