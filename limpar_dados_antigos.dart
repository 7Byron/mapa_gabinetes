// limpar_dados_antigos.dart
// Script para limpar dados antigos do Firebase
// Execute este script uma vez para limpar a estrutura antiga

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  print('🚀 Iniciando limpeza de dados antigos...');

  try {
    final firestore = FirebaseFirestore.instance;

    // Lista de coleções antigas para remover
    final colecoesAntigas = [
      'medicos',
      'gabinetes',
      'alocacoes',
      'horarios_clinica',
      'feriados',
      'especialidades',
      'config_clinica',
    ];

    int totalRemovidos = 0;

    for (final colecao in colecoesAntigas) {
      print('🗑️ Removendo coleção: $colecao');

      final snapshot = await firestore.collection(colecao).get();
      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        // Se for a coleção de médicos, remover também as disponibilidades
        if (colecao == 'medicos') {
          final disponibilidadesSnapshot =
              await doc.reference.collection('disponibilidades').get();

          for (final dispDoc in disponibilidadesSnapshot.docs) {
            batch.delete(dispDoc.reference);
          }
        }

        batch.delete(doc.reference);
      }

      await batch.commit();
      totalRemovidos += snapshot.docs.length;

      print('✅ Coleção $colecao removida: ${snapshot.docs.length} documentos');
    }

    print('🎉 Limpeza concluída!');
    print('📊 Total de documentos removidos: $totalRemovidos');
    print('✨ Firebase limpo e pronto para a nova estrutura!');
  } catch (e) {
    print('❌ Erro durante limpeza: $e');
  }
}

// Para executar este script:
// 1. Adicione este arquivo ao seu projeto
// 2. Execute: dart limpar_dados_antigos.dart
// 3. Ou chame a função main() de dentro do app
