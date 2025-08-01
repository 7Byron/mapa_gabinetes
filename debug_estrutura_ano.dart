import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('🔍 === DEBUG ESTRUTURA POR ANO ===');

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

    // 2. Verificar alocações por ano
    print('\n2️⃣ Verificando alocações por ano...');
    final alocacoesRef =
        firestore.collection('unidades').doc(unidadeId).collection('alocacoes');

    final anosAlocacoesSnapshot = await alocacoesRef.get();
    print('📊 Anos com alocações: ${anosAlocacoesSnapshot.docs.length}');

    for (final anoDoc in anosAlocacoesSnapshot.docs) {
      final ano = anoDoc.id;
      final registosRef = anoDoc.reference.collection('registos');
      final registosSnapshot = await registosRef.get();
      print('  📅 Ano $ano: ${registosSnapshot.docs.length} alocações');

      for (final alocDoc in registosSnapshot.docs) {
        final alocData = alocDoc.data();
        final data = DateTime.parse(alocData['data']);
        print(
            '    - ${data.day}/${data.month}/${data.year} (${alocData['medicoId']} -> ${alocData['gabineteId']})');
      }
    }

    // 3. Verificar disponibilidades por ano
    print('\n3️⃣ Verificando disponibilidades por ano...');
    final medicosRef =
        firestore.collection('unidades').doc(unidadeId).collection('ocupantes');

    final medicosSnapshot = await medicosRef.get();
    print('📊 Médicos encontrados: ${medicosSnapshot.docs.length}');

    for (final medicoDoc in medicosSnapshot.docs) {
      final medicoData = medicoDoc.data();
      print('  👨‍⚕️ ${medicoData['nome']} (${medicoDoc.id})');

      final dispRef = medicoDoc.reference.collection('disponibilidades');
      final anosDisponibilidadesSnapshot = await dispRef.get();
      print(
          '    📅 Anos com disponibilidades: ${anosDisponibilidadesSnapshot.docs.length}');

      for (final anoDoc in anosDisponibilidadesSnapshot.docs) {
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

    // 4. Verificar feriados por ano
    print('\n4️⃣ Verificando feriados por ano...');
    final feriadosRef =
        firestore.collection('unidades').doc(unidadeId).collection('feriados');

    final anosFeriadosSnapshot = await feriadosRef.get();
    print('📊 Anos com feriados: ${anosFeriadosSnapshot.docs.length}');

    for (final anoDoc in anosFeriadosSnapshot.docs) {
      final ano = anoDoc.id;
      final registosRef = anoDoc.reference.collection('registos');
      final registosSnapshot = await registosRef.get();
      print('  📅 Ano $ano: ${registosSnapshot.docs.length} feriados');

      for (final feriadoDoc in registosSnapshot.docs) {
        final feriadoData = feriadoDoc.data();
        final data = DateTime.parse(feriadoData['data']);
        print(
            '    - ${data.day}/${data.month}/${data.year}: ${feriadoData['descricao']}');
      }
    }

    // 5. Verificar estrutura antiga (fallback)
    print('\n5️⃣ Verificando estrutura antiga (fallback)...');

    // Verificar médicos antigos
    final medicosAntigosRef = firestore.collection('medicos');
    final medicosAntigosSnapshot = await medicosAntigosRef.get();
    print(
        '📊 Médicos na estrutura antiga: ${medicosAntigosSnapshot.docs.length}');

    // Verificar feriados antigos
    final feriadosAntigosRef = firestore.collection('feriados');
    final feriadosAntigosSnapshot = await feriadosAntigosRef.get();
    print(
        '📊 Feriados na estrutura antiga: ${feriadosAntigosSnapshot.docs.length}');

    // Verificar alocações antigas
    final alocacoesAntigasRef = firestore.collection('alocacoes');
    final alocacoesAntigasSnapshot = await alocacoesAntigasRef.get();
    print(
        '📊 Alocações na estrutura antiga: ${alocacoesAntigasSnapshot.docs.length}');
  } catch (e) {
    print('❌ Erro durante debug: $e');
  }

  print('\n🎯 Debug concluído!');
}
