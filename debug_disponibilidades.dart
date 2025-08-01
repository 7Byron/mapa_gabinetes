import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 === DEBUG DISPONIBILIDADES ===');

  // Configurar Firebase
  FirebaseFirestore.instance.settings = const Settings(
    host: 'localhost:8080',
    sslEnabled: false,
    persistenceEnabled: false,
  );

  final unidadeId = 'fyEj6kOXvCuL65sMfCaR'; // ID da unidade
  final firestore = FirebaseFirestore.instance;

  try {
    // 1. Verificar se a unidade existe
    print('1️⃣ Verificando unidade...');
    final unidadeDoc =
        await firestore.collection('unidades').doc(unidadeId).get();
    if (!unidadeDoc.exists) {
      print('❌ Unidade não encontrada: $unidadeId');
      return;
    }
    print('✅ Unidade encontrada: ${unidadeDoc.data()?['nome']}');

    // 2. Verificar médicos na unidade
    print('\n2️⃣ Verificando médicos na unidade...');
    final medicosRef =
        firestore.collection('unidades').doc(unidadeId).collection('ocupantes');

    final medicosSnapshot = await medicosRef.get();
    print('📊 Médicos encontrados: ${medicosSnapshot.docs.length}');

    for (final medicoDoc in medicosSnapshot.docs) {
      final medicoData = medicoDoc.data();
      print('  👨‍⚕️ ${medicoData['nome']} (${medicoDoc.id})');

      // 3. Verificar disponibilidades do médico
      final dispRef = medicoDoc.reference.collection('disponibilidades');
      final anosSnapshot = await dispRef.get();
      print('    📅 Anos com disponibilidades: ${anosSnapshot.docs.length}');

      for (final anoDoc in anosSnapshot.docs) {
        final ano = anoDoc.id;
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        print(
            '      📊 Ano $ano: ${registosSnapshot.docs.length} disponibilidades');

        for (final dispDoc in registosSnapshot.docs) {
          final dispData = dispDoc.data();
          final data = DateTime.parse(dispData['data']);
          print(
              '        - ${data.day}/${data.month}/${data.year} (${dispData['horarios']?.join(', ') ?? 'sem horários'})');
        }
      }
    }

    // 4. Verificar estrutura antiga (fallback)
    print('\n3️⃣ Verificando estrutura antiga (fallback)...');
    final medicosAntigosRef = firestore.collection('medicos');
    final medicosAntigosSnapshot = await medicosAntigosRef.get();
    print(
        '📊 Médicos na estrutura antiga: ${medicosAntigosSnapshot.docs.length}');

    for (final medicoDoc in medicosAntigosSnapshot.docs) {
      final medicoData = medicoDoc.data();
      print('  👨‍⚕️ ${medicoData['nome']} (${medicoDoc.id})');

      final dispRef = medicoDoc.reference.collection('disponibilidades');
      final dispSnapshot = await dispRef.get();
      print('    📅 Disponibilidades antigas: ${dispSnapshot.docs.length}');
    }
  } catch (e) {
    print('❌ Erro durante debug: $e');
  }

  print('\n🎯 Debug concluído!');
}
