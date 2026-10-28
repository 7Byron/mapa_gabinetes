import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/services/cache_version_service.dart';

void main() {
  test('Ação partilha versões; ação seguinte consulta de novo', () async {
    final db = FakeFirebaseFirestore();
    final ref = db.doc('unidades/u/cache_control/global');
    await ref.set({'seriesVersion': 1});
    Future<Map<String, int>> ler() =>
        CacheVersionService.fetchVersions(unidadeId: 'u', firestore: db);
    await CacheVersionService.comVersoesPartilhadas(() async {
      final primeira = await ler();
      await ref.update({'seriesVersion': 2});
      final segunda = await CacheVersionService.comVersoesPartilhadas(ler);
      expect(primeira['seriesVersion'], 1);
      expect(segunda['seriesVersion'], 1);
      primeira['seriesVersion'] = 999;
      expect((await ler())['seriesVersion'], 1,
          reason: 'O chamador recebe uma cópia');
    });
    expect(
        (await CacheVersionService.comVersoesPartilhadas(ler))['seriesVersion'],
        2);
  });

  test('Unidades diferentes mantêm versões independentes', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('unidades/a/cache_control/global').set({'seriesVersion': 4});
    await db.doc('unidades/b/cache_control/global').set({'seriesVersion': 8});
    await CacheVersionService.comVersoesPartilhadas(() async {
      final leituras = await Future.wait([
        CacheVersionService.fetchVersions(unidadeId: 'a', firestore: db),
        CacheVersionService.fetchVersions(unidadeId: 'b', firestore: db),
      ]);
      expect(leituras.map((v) => v['seriesVersion']), [4, 8]);
    });
  });

  test('Escrita dentro da ação invalida a fotografia de versões', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('unidades/u/cache_control/global').set({'seriesVersion': 1});
    await CacheVersionService.comVersoesPartilhadas(() async {
      expect(
          (await CacheVersionService.fetchVersions(
              unidadeId: 'u', firestore: db))['seriesVersion'],
          1);
      await CacheVersionService.bumpVersion(
          unidadeId: 'u',
          field: CacheVersionService.fieldSeries,
          firestore: db);
      expect(
          (await CacheVersionService.fetchVersions(
              unidadeId: 'u', firestore: db))['seriesVersion'],
          2);
    });
  });

  test('Callbacks tardios não reutilizam o escopo já encerrado', () async {
    final db = FakeFirebaseFirestore();
    final ref = db.doc('unidades/u/cache_control/global');
    await ref.set({'seriesVersion': 1});
    final disparar = Completer<void>();
    late Future<Map<String, int>> tardia;
    await CacheVersionService.comVersoesPartilhadas(() async {
      await CacheVersionService.fetchVersions(unidadeId: 'u', firestore: db);
      tardia = disparar.future.then((_) =>
          CacheVersionService.fetchVersions(unidadeId: 'u', firestore: db));
    });
    await ref.update({'seriesVersion': 3});
    disparar.complete();
    expect((await tardia)['seriesVersion'], 3);
  });
}
