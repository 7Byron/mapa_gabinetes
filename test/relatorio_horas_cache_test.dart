import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/resumo_horas_mes.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ResumoHorasMes _resumo({int horas = 2, int quantidade = 1, String? nome}) =>
    ResumoHorasMes(mes: DateTime(2026, 11), medicos: [
      for (var i = 0; i < quantidade; i++)
        MedicoHorasMes(
            id: 'medico$i',
            nome: nome ?? 'Médico $i',
            especialidade: 'MGF',
            minutos: [horas * 60, ...List.filled(29, 0)]),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late SharedPreferences prefs;
  late RelatorioHorasCacheService cache;
  final mes = DateTime(2026, 11);
  const versao = '1_0_0_0';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = FakeFirebaseFirestore();
    await db.doc('unidades/u/cache_control/global').set({'seriesVersion': 1});
    cache = RelatorioHorasCacheService(firestore: db);
  });

  test(
      'Resumo sobrevive a outra instância e é reutilizado por outro dispositivo',
      () async {
    await cache.guardar('u', versao, [_resumo()]);
    final outra = RelatorioHorasCacheService(firestore: db);
    // A cópia local continua a servir mesmo sem o documento remoto.
    final ref = db.doc('unidades/u/cache_relatorio_horas/2026-11');
    final remoto = (await ref.get()).data()!;
    await ref.delete();
    expect(
        (await outra.ler('u', mes, versao))!.medicos.single.minutos.first, 120);
    await ref.set(remoto);
    await prefs.clear();
    expect(
        (await outra.ler('u', mes, versao))!.medicos.single.minutos.first, 120);
    expect(prefs.getKeys(), hasLength(1));
    expect(await outra.ler('outra', mes, versao), isNull);
  });

  for (final campo in [
    'seriesVersion',
    'disponibilidadesVersion',
    'medicosVersion',
    'clinicaConfigVersion'
  ]) {
    test('Alterar $campo invalida as cópias local e partilhada', () async {
      await cache.guardar('u', versao, [_resumo()]);
      final ref = db.doc('unidades/u/cache_control/global');
      final dados = (await ref.get()).data()!;
      await ref.update({campo: ((dados[campo] as int?) ?? 0) + 1});
      final nova =
          RelatorioHorasCacheService.versaoDados((await ref.get()).data()!);
      expect(nova, isNot(versao));
      expect(await cache.ler('u', mes, nova), isNull);
      await prefs.clear();
      expect(await cache.ler('u', mes, nova), isNull);
      await cache.guardar('u', nova, [_resumo(horas: 4)]);
      expect(
          (await cache.ler('u', mes, nova))!.medicos.single.minutos.first, 240);
    });
  }

  test('Um cálculo de versão antiga não publica nem substitui um resumo novo',
      () async {
    await db
        .doc('unidades/u/cache_control/global')
        .update({'seriesVersion': 2});
    await cache.guardar('u', '2_0_0_0', [_resumo(horas: 4)]);
    await cache.guardar('u', versao, [_resumo()]);
    expect(await cache.ler('u', mes, versao), isNull);
    expect((await cache.ler('u', mes, '2_0_0_0'))!.medicos.single.minutos.first,
        240);
    await prefs.clear();
    expect((await cache.ler('u', mes, '2_0_0_0'))!.medicos.single.minutos.first,
        240);
  });

  test(
      'Cache local danificada é recuperada; resumo remoto danificado é ignorado',
      () async {
    await cache.guardar('u', versao, [_resumo()]);
    await prefs.setString(prefs.getKeys().single, '{inválido');
    expect(await cache.ler('u', mes, versao), isNotNull);
    await prefs.clear();
    await db.doc('unidades/u/cache_relatorio_horas/2026-11').update({
      'payload': base64Encode(utf8.encode('{}')),
    });
    expect(await cache.ler('u', mes, versao), isNull);
    await cache.guardar('u', versao, [_resumo()]);
    await prefs.clear();
    expect(await cache.ler('u', mes, versao), isNotNull);
  });

  test('Algoritmo antigo e mês errado nunca são aceites', () async {
    await cache.guardar('u', versao, [_resumo()]);
    final ref = db.doc('unidades/u/cache_relatorio_horas/2026-11');
    final pacote = (await ref.get()).data()!;
    await prefs.clear();
    await ref.update({'esquema': 0});
    expect(await cache.ler('u', mes, versao), isNull);
    await db.doc('unidades/u/cache_relatorio_horas/2026-12').set(pacote);
    expect(await cache.ler('u', DateTime(2026, 12), versao), isNull);
  });

  test('Clínica sem médicos também tem um resumo reutilizável', () async {
    await cache.guardar('u', versao, [_resumo(quantidade: 0)]);
    await prefs.clear();
    expect((await cache.ler('u', mes, versao))!.medicos, isEmpty);
  });

  test('Resumos grandes usam blocos e removem os blocos da versão substituída',
      () async {
    final grande =
        _resumo(quantidade: 200, nome: List.filled(1000, 'Á').join());
    await cache.guardar('u', versao, [grande]);
    final ref = db.doc('unidades/u/cache_relatorio_horas/2026-11');
    final pacote = (await ref.get()).data()!;
    expect(pacote['partes'], greaterThan(1));
    expect(pacote.containsKey('payload'), isFalse);
    final blocos = await ref.collection('blocos').get();
    expect(blocos.docs, hasLength(pacote['partes'] as int));
    for (final bloco in blocos.docs) {
      expect((bloco.data()['payload'] as String).length,
          lessThanOrEqualTo(500000));
    }
    await prefs.clear();
    expect((await cache.ler('u', mes, versao))!.toMap(), grande.toMap());
    // Um bloco ausente implica reconstrução a partir dos dados originais.
    await prefs.clear();
    await blocos.docs.first.reference.delete();
    expect(await cache.ler('u', mes, versao), isNull);
    await cache.guardar('u', versao, [grande]);
    await prefs.clear();
    expect((await cache.ler('u', mes, versao))!.toMap(), grande.toMap());
    await db
        .doc('unidades/u/cache_control/global')
        .update({'seriesVersion': 2});
    await cache.guardar('u', '2_0_0_0', [_resumo(horas: 3)]);
    expect((await ref.collection('blocos').get()).docs, isEmpty);
    await prefs.clear();
    expect((await cache.ler('u', mes, '2_0_0_0'))!.medicos.single.minutos.first,
        180);
  });

  test('Detalhe diário mantém períodos parciais, ano bissexto e total global',
      () {
    final fevereiro = ResumoHorasMes(mes: DateTime(2024, 2), medicos: [
      MedicoHorasMes(
          id: 'a',
          nome: 'Ana',
          especialidade: 'MGF',
          minutos: [...List.filled(27, 0), 60, 120]),
      MedicoHorasMes(
          id: 'b',
          nome: 'Rui',
          especialidade: 'ORL',
          minutos: [...List.filled(27, 0), 0, 180]),
    ]);
    final marco = ResumoHorasMes(mes: DateTime(2024, 3), medicos: [
      MedicoHorasMes(
          id: 'a',
          nome: 'Ana',
          especialidade: 'MGF',
          minutos: [240, ...List.filled(30, 0)]),
      MedicoHorasMes(
          id: 'b',
          nome: 'Rui',
          especialidade: 'ORL',
          minutos: [360, ...List.filled(30, 0)]),
    ]);
    final relatorio = ResumoHorasMes.relatorio(
        meses: [fevereiro, marco],
        inicio: DateTime(2024, 2, 29),
        fim: DateTime(2024, 3, 1),
        medicoIds: {'a'});
    expect(relatorio.medicos.single.horasConsulta, 6);
    expect(relatorio.totalHorasConsultaClinica, 15);
    expect(relatorio.mediaHorasPorMedicoClinica, 7.5);
    expect(relatorio.medicos.single.percentagemContribuicao(15), 40);
  });
}
