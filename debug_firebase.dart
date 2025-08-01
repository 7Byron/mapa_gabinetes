// debug_firebase.dart
// Script para debug do Firebase - Execute temporariamente no main.dart

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 === DEBUG ESPECÍFICO DR. FRANCISCO ===');

  final firestore = FirebaseFirestore.instance;
  final unidadeId = 'fyEj6kOXvCuL65sMfCaR'; // ID da unidade que vi nos logs

  try {
    // 1. Verificar se a unidade existe
    print('📋 Verificando unidade: $unidadeId');
    final unidadeDoc =
        await firestore.collection('unidades').doc(unidadeId).get();
    if (!unidadeDoc.exists) {
      print('❌ Unidade $unidadeId não encontrada!');
      return;
    }
    print('✅ Unidade encontrada: ${unidadeDoc.data()?['nome']}');

    // 2. Verificar médicos da unidade
    print('\n👥 Verificando médicos da unidade...');
    final medicosRef =
        firestore.collection('unidades').doc(unidadeId).collection('ocupantes');

    final medicosSnapshot = await medicosRef.get();
    print('📊 Total de médicos encontrados: ${medicosSnapshot.docs.length}');

    for (final medicoDoc in medicosSnapshot.docs) {
      final medicoData = medicoDoc.data();
      final medicoNome = medicoData['nome'] ?? 'Sem nome';
      final medicoId = medicoDoc.id;

      print('👨‍⚕️ Médico: $medicoNome (ID: $medicoId)');

      // 3. Verificar disponibilidades do médico
      final disponibilidadesRef =
          medicoDoc.reference.collection('disponibilidades');
      final dispSnapshot = await disponibilidadesRef.get();
      print('  📅 Disponibilidades: ${dispSnapshot.docs.length}');

      for (final dispDoc in dispSnapshot.docs) {
        final dispData = dispDoc.data();
        final data = DateTime.parse(dispData['data']);
        final horarios = List<String>.from(dispData['horarios'] ?? []);
        final tipo = dispData['tipo'] ?? 'Desconhecido';

        print(
            '    - ${data.day}/${data.month}/${data.year} ($tipo) - Horários: ${horarios.join(', ')}');
      }
    }

    // 4. Verificar especificamente o Dr. Francisco
    print('\n🔍 Procurando especificamente pelo Dr. Francisco...');
    final drFranciscoDocs = medicosSnapshot.docs.where((doc) {
      final nome = doc.data()['nome'] ?? '';
      return nome.toLowerCase().contains('francisco');
    }).toList();

    if (drFranciscoDocs.isEmpty) {
      print('❌ Dr. Francisco não encontrado na unidade!');
    } else {
      print('✅ Dr. Francisco encontrado!');
      for (final doc in drFranciscoDocs) {
        final data = doc.data();
        print('  - Nome: ${data['nome']}');
        print('  - Especialidade: ${data['especialidade']}');
        print('  - ID: ${doc.id}');

        // Verificar disponibilidades específicas para 29/7/2025
        final disponibilidadesRef =
            doc.reference.collection('disponibilidades');
        final dispSnapshot = await disponibilidadesRef.get();

        print('  📅 Total de disponibilidades: ${dispSnapshot.docs.length}');

        for (final dispDoc in dispSnapshot.docs) {
          final dispData = dispDoc.data();
          final data = DateTime.parse(dispData['data']);
          final horarios = List<String>.from(dispData['horarios'] ?? []);

          print(
              '    - ${data.day}/${data.month}/${data.year} - Horários: ${horarios.join(', ')}');

          // Verificar especificamente 29/7/2025
          if (data.day == 29 && data.month == 7 && data.year == 2025) {
            print('    🎯 ENCONTRADA DISPONIBILIDADE PARA 29/7/2025!');
          }
        }
      }
    }
  } catch (e) {
    print('❌ Erro durante debug: $e');
  }

  print('\n🔍 === FIM DEBUG ESPECÍFICO ===');
}
