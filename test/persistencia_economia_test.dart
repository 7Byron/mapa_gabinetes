import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/services/medico_salvar_service.dart'
    as medico_service;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/services/serie_service.dart';
import 'package:mapa_gabinetes/services/alocacao_disponibilidade_remocao_service.dart';
import 'package:mapa_gabinetes/utils/cadastro_persistencia_snapshot.dart';
import 'package:mapa_gabinetes/utils/vista_diaria_sync.dart';

final unidade = Unidade(
    id: 'teste',
    nome: 'Teste',
    tipo: 'Clínica',
    endereco: '',
    dataCriacao: DateTime(2026),
    nomeOcupantes: 'Médicos',
    nomeAlocacao: 'Gabinetes');
SerieRecorrencia serie() => SerieRecorrencia(
    id: 'serie_teste',
    medicoId: 'medico',
    dataInicio: DateTime(2026, 1, 7),
    tipo: 'Semanal',
    horarios: ['14:00', '18:00'],
    gabineteId: '23')
  ..adicionarMudancaGabinete(DateTime(2026, 10, 28), '28');
ExcecaoSerie ausencia() => ExcecaoSerie(
    id: 'ausencia',
    serieId: 'serie_teste',
    data: DateTime(2026, 12, 16),
    cancelada: true,
    horarios: ['15:00', '17:00'],
    gabineteId: '28');

void main() {
  test('guardar apenas observações não regrava séries nem ausências', () async {
    final db = FakeFirebaseFirestore();
    final s = serie(), e = ausencia();
    final original = CadastroPersistenciaSnapshot()
      ..registarSeries([s])
      ..registarExcecoes([e]);
    await SerieService.salvarAlteracoes(
        series: original.seriesPendentes([s]),
        excecoes: original.excecoesPendentes([e]),
        medicoId: 'medico',
        unidade: unidade,
        firestore: db);
    expect(db.dump(), '{}');
  });
  test('alterar horários conserva a mudança de gabinete e a ausência',
      () async {
    final db = FakeFirebaseFirestore();
    final s = serie(), e = ausencia();
    final original = CadastroPersistenciaSnapshot()
      ..registarSeries([s])
      ..registarExcecoes([e]);
    s.horarios[0] = '15:00';
    e.ocultarCartao = true;
    await SerieService.salvarAlteracoes(
        series: original.seriesPendentes([s]),
        excecoes: original.excecoesPendentes([e]),
        medicoId: 'medico',
        unidade: unidade,
        firestore: db);
    final dados = (await db
            .doc('unidades/teste/ocupantes/medico/series/serie_teste')
            .get())
        .data()!;
    final guardada = SerieRecorrencia.fromMap(dados);
    expect(guardada.obterGabineteParaData(DateTime(2026, 11, 4)), '28');
    expect(guardada.horarios, ['15:00', '18:00']);
    final ex = (await db
            .doc(
                'unidades/teste/ocupantes/medico/excecoes/2026/registos/ausencia')
            .get())
        .data()!;
    expect(ex['cancelada'], true);
    expect(ex['ocultarCartao'], true);
    expect(ex['horarios'], ['15:00', '17:00']);
    expect(
        (await db.doc('unidades/teste/cache_control/global').get())
            .data()!['seriesVersion'],
        1);
    original.registarSeries([s]);
    original.registarExcecoes([e]);
    expect(original.seriesPendentes([s]), isEmpty);
    expect(original.excecoesPendentes([e]), isEmpty);
  });
  test(
      'comparação não depende da ordem dos parâmetros e deteta mutações internas',
      () {
    final s = serie()..parametros = {'a': 1, 'b': 2};
    final original = CadastroPersistenciaSnapshot()..registarSeries([s]);
    s.parametros = {'b': 2, 'a': 1};
    expect(original.seriesPendentes([s]), isEmpty);
    s.mudancasGabinete.single.gabineteId = '30';
    expect(original.seriesPendentes([s]), hasLength(1));
  });
  test('consulta pontual só devolve exceções da data e série certas', () async {
    final db = FakeFirebaseFirestore();
    final ref =
        db.collection('unidades/teste/ocupantes/medico/excecoes/2026/registos');
    await ref.doc('certa').set(ausencia().toMap());
    await ref
        .doc('outra_data')
        .set((ausencia()..data = DateTime(2026, 12, 23)).toMap());
    await ref.doc('outra_serie').set((ausencia()..serieId = 'outra').toMap());
    final resultado = await SerieService.carregarExcecoesDaData(
        medicoId: 'medico',
        serieId: 'serie_teste',
        data: DateTime(2026, 12, 16, 18),
        unidade: unidade,
        firestore: db);
    expect(resultado.map((e) => e.id), ['certa']);
  });
  test('lote recusado propaga falha e não atualiza a versão', () async {
    final db = FakeFirebaseFirestore(securityRules: '''service cloud.firestore {
      match /databases/{database}/documents { match /{document=**} { allow read: if true; allow write: if false; } }
    }''');
    await expectLater(
        SerieService.salvarAlteracoes(
            series: [serie()],
            excecoes: [ausencia()],
            medicoId: 'medico',
            unidade: unidade,
            firestore: db),
        throwsException);
    expect((await db.doc('unidades/teste/cache_control/global').get()).exists,
        false);
  });
  test(
      'ausência de 30 dias lê só o médico/período e preserva os restantes dados',
      () async {
    final db = FakeFirebaseFirestore();
    final anual = db.collection('unidades/teste/alocacoes/2026/registos');
    final disps = db.collection(
        'unidades/teste/ocupantes/medico/disponibilidades/2026/registos');
    Map<String, dynamic> dados(String id, String medico, DateTime data) => {
          'id': id,
          'medicoId': medico,
          'data': data.toIso8601String(),
          'tipo': 'Única',
          'horarioInicio': '14:00',
          'horarioFim': '18:00',
          'horarios': ['14:00', '18:00']
        };
    await anual.doc('alvo').set(dados('alvo', 'medico', DateTime(2026, 11, 4)));
    await anual
        .doc('fora_periodo')
        .set(dados('fora_periodo', 'medico', DateTime(2026, 10, 28)));
    for (var i = 0; i < 50; i++) {
      await anual
          .doc('outro_$i')
          .set(dados('outro_$i', 'outro', DateTime(2026, 11, 4)));
    }
    await disps.doc('alvo').set(dados('alvo', 'medico', DateTime(2026, 11, 4)));
    await disps
        .doc('fora_periodo')
        .set(dados('fora_periodo', 'medico', DateTime(2026, 12, 2)));
    final dia = db.doc('unidades/teste/dias/2026-11-04');
    await dia
        .collection('alocacoes')
        .doc('alvo')
        .set(dados('alvo', 'medico', DateTime(2026, 11, 4)));
    await dia
        .collection('alocacoes')
        .doc('outro')
        .set(dados('outro', 'outro', DateTime(2026, 11, 4)));
    await dia
        .collection('disponibilidades')
        .doc('alvo')
        .set(dados('alvo', 'medico', DateTime(2026, 11, 4)));
    final ex = db
        .doc('unidades/teste/ocupantes/medico/excecoes/2026/registos/ausencia');
    await ex.set(ausencia().toMap());
    final leituras = <int>[];
    final resultado = await AlocacaoDisponibilidadeRemocaoService
        .removerAlocacoesEDisponibilidades(
            'teste', 'medico', DateTime(2026, 11, 1), DateTime(2026, 11, 30),
            firestore: db, onConsulta: leituras.add);
    expect(
        resultado, {'alocacoesRemovidas': 1, 'disponibilidadesRemovidas': 1});
    expect(leituras.length,
        62); // Duas anuais, mais duas por dia, sem reler o ano.
    expect(leituras.fold<int>(0, (a, b) => a + b), 4);
    expect((await anual.get()).docs, hasLength(51));
    expect((await disps.doc('fora_periodo').get()).exists, true);
    expect((await dia.collection('alocacoes').doc('outro').get()).exists, true);
    expect((await dia.collection('disponibilidades').doc('alvo').get()).exists,
        false);
    expect((await ex.get()).data()!['cancelada'], true);
    final versao =
        (await db.doc('unidades/teste/cache_control/global').get()).data()!;
    expect(versao['alocacoesVersion'], 1);
    expect(versao['disponibilidadesVersion'], 1);
  });
  test('intervalo entre anos é inclusivo e não apaga séries vizinhas',
      () async {
    final db = FakeFirebaseFirestore();
    for (final data in [DateTime(2026, 12, 31), DateTime(2027, 1, 1)]) {
      final ref =
          db.collection('unidades/teste/alocacoes/${data.year}/registos');
      await ref.doc('serie_alvo').set({
        'medicoId': 'medico',
        'data': data.toIso8601String(),
        'serieId': 'alvo'
      });
      await ref.doc('serie_outra').set({
        'medicoId': 'medico',
        'data': data.toIso8601String(),
        'serieId': 'outra'
      });
    }
    final leituras = <int>[];
    final resultado = await AlocacaoDisponibilidadeRemocaoService
        .removerAlocacoesEDisponibilidades('teste', 'medico',
            DateTime(2026, 12, 31, 14), DateTime(2027, 1, 1, 18),
            serieId: 'alvo', firestore: db, onConsulta: leituras.add);
    expect(resultado['alocacoesRemovidas'], 2);
    expect(leituras.length, 8);
    expect(
        (await db
                .doc('unidades/teste/alocacoes/2027/registos/serie_outra')
                .get())
            .exists,
        true);
  });
  test('falha de leitura da remoção não é anunciada como sucesso', () async {
    final db = FakeFirebaseFirestore(
        securityRules:
            "service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read: if false; allow write: if true; } } }");
    await db.doc('unidades/teste/alocacoes/2026/registos/alvo').set({
      'medicoId': 'medico',
      'data': DateTime(2026, 11, 1).toIso8601String()
    });
    await expectLater(
        AlocacaoDisponibilidadeRemocaoService.removerAlocacoesEDisponibilidades(
            'teste', 'medico', DateTime(2026, 11, 1), DateTime(2026, 11, 2),
            firestore: db),
        throwsException);
  });
  test(
      'realocação substitui gabinetes futuros sem apagar ausências, horários ou outros médicos',
      () async {
    final db = FakeFirebaseFirestore();
    final s = serie();
    final serieRef =
        db.doc('unidades/teste/ocupantes/medico/series/serie_teste');
    await serieRef.set({
      ...s.toMap(),
      'horarios': ['13:00', '19:00']
    });
    final ref =
        db.collection('unidades/teste/ocupantes/medico/excecoes/2026/registos');
    await ref.doc('passada').set((ausencia()
          ..data = DateTime(2026, 10, 21)
          ..gabineteId = '23')
        .toMap());
    await ref.doc('futura').set((ausencia()
          ..data = DateTime(2026, 11, 4)
          ..gabineteId = '23')
        .toMap());
    await db
        .doc('unidades/teste/ocupantes/medico/excecoes/2027/registos/futura')
        .set((ausencia()
              ..data = DateTime(2027, 1, 6)
              ..gabineteId = '23')
            .toMap());
    final outro =
        db.doc('unidades/outra/ocupantes/medico/excecoes/2026/registos/futura');
    await outro.set((ausencia()..gabineteId = '23').toMap());
    await SerieService.salvarRealocacaoSerie(
        s, DateTime(2026, 10, 28, 14), '28',
        unidade: unidade, firestore: db);
    expect((await ref.doc('passada').get()).data()!['gabineteId'], '23');
    final futura = (await ref.doc('futura').get()).data()!;
    expect(futura['gabineteId'], '28');
    expect(futura['cancelada'], true);
    expect(futura['horarios'], ['15:00', '17:00']);
    expect(
        (await db
                .doc(
                    'unidades/teste/ocupantes/medico/excecoes/2027/registos/futura')
                .get())
            .data()!['gabineteId'],
        '28');
    expect((await outro.get()).data()!['gabineteId'], '23');
    expect((await serieRef.get()).data()!['horarios'], ['13:00', '19:00']);
  });
  test(
      'observações alteradas custam só o perfil e uma versão; segundo guardar é vazio',
      () async {
    final db = FakeFirebaseFirestore();
    final original = Medico(
        id: 'medico',
        nome: 'Teste',
        especialidade: 'Teste',
        disponibilidades: [],
        observacoes: 'antes');
    final alterado = Medico(
        id: 'medico',
        nome: 'Teste',
        especialidade: 'Teste',
        disponibilidades: [],
        observacoes: 'depois');
    await medico_service.salvarMedicoCompleto(alterado,
        unidade: unidade,
        medicoOriginal: original,
        disponibilidadesOriginais: [],
        firestoreParaTeste: db);
    final ref = db.doc('unidades/teste/cache_control/global');
    expect((await ref.get()).data()!['medicosVersion'], 1);
    expect((await ref.get()).data()!.containsKey('disponibilidadesVersion'),
        false);
    final antes = db.dump();
    await medico_service.salvarMedicoCompleto(alterado,
        unidade: unidade,
        medicoOriginal: alterado,
        disponibilidadesOriginais: [],
        firestoreParaTeste: db);
    expect(db.dump(), antes);
  });
  test(
      'cartões gerados de uma série nunca são materializados ao guardar o perfil',
      () async {
    final db = FakeFirebaseFirestore();
    final original = Medico(
        id: 'medico',
        nome: 'Teste',
        especialidade: 'Teste',
        disponibilidades: []);
    final atual = Medico(
        id: 'medico',
        nome: 'Teste',
        especialidade: 'Teste',
        disponibilidades: [
          for (var i = 1; i <= 52; i++)
            Disponibilidade(
                id: 'serie_serie_teste_$i',
                medicoId: 'medico',
                data: DateTime(2026, 1, 1).add(Duration(days: i * 7)),
                horarios: ['14:00', '18:00'],
                tipo: 'Semanal')
        ]);
    await medico_service.salvarMedicoCompleto(atual,
        unidade: unidade,
        medicoOriginal: original,
        disponibilidadesOriginais: [],
        firestoreParaTeste: db);
    expect((await db.doc('unidades/teste/ocupantes/medico').get()).exists, false);
    expect((await db.doc('unidades/teste/cache_control/global').get()).exists, false);
    expect((await db.collectionGroup('registos').get()).docs, isEmpty);
  });
  test(
      'ausência de uma série não remove cartões únicos nem séries com ID semelhante',
      () async {
    final db = FakeFirebaseFirestore();
    final dia = DateTime(2026, 11, 4);
    final ref = db.collection('unidades/teste/alocacoes/2026/registos');
    await ref
        .doc('serie_serie_12_2026-11-04')
        .set({'medicoId': 'medico', 'data': dia.toIso8601String()});
    await ref
        .doc('serie_serie_123_2026-11-04')
        .set({'medicoId': 'medico', 'data': dia.toIso8601String()});
    final unico = db.doc(
        'unidades/teste/ocupantes/medico/disponibilidades/2026/registos/unico');
    await unico.set(
        {'medicoId': 'medico', 'data': dia.toIso8601String(), 'tipo': 'Única'});
    await AlocacaoDisponibilidadeRemocaoService
        .removerAlocacoesEDisponibilidades('teste', 'medico', dia, dia,
            serieId: 'serie_12', firestore: db);
    expect((await ref.doc('serie_serie_12_2026-11-04').get()).exists, false);
    expect((await ref.doc('serie_serie_123_2026-11-04').get()).exists, true);
    expect((await unico.get()).exists, true);
  });
  test('guardar horários não repõe o gabinete alterado por outro cliente',
      () async {
    final db = FakeFirebaseFirestore();
    final s = serie(), e = ausencia();
    s.parametros = {'remover': true, 'manter': 1};
    final original = CadastroPersistenciaSnapshot()
      ..registarSeries([s])
      ..registarExcecoes([e]);
    final ref = db.doc('unidades/teste/ocupantes/medico/series/serie_teste');
    final remoto = SerieRecorrencia.fromMap(s.toMap())
      ..adicionarMudancaGabinete(DateTime(2026, 11, 4), '30');
    await ref.set(remoto.toMap());
    final ex = db
        .doc('unidades/teste/ocupantes/medico/excecoes/2026/registos/ausencia');
    await ex.set({...e.toMap(), 'gabineteId': '31'});
    s.horarios[0] = '15:00';
    s.parametros.remove('remover');
    e.ocultarCartao = true;
    await SerieService.salvarAlteracoes(
        series: original.seriesPendentes([s]),
        excecoes: original.excecoesPendentes([e]),
        medicoId: 'medico',
        unidade: unidade,
        firestore: db,
        originais: original);
    final guardada = SerieRecorrencia.fromMap((await ref.get()).data()!);
    expect(guardada.obterGabineteParaData(DateTime(2026, 11, 11)), '30');
    expect(guardada.horarios, ['15:00', '18:00']);
    // A base simulada funde mapas em update, ao contrário do Firestore.
    // Validar o mapa completo entregue ao update para substituir parâmetros.
    expect(original.camposSerie(s)['parametros'], {'manter': 1});
    expect((await ex.get()).data()!['gabineteId'], '31');
    expect((await ex.get()).data()!['ocultarCartao'], true);
  });
  test('assinatura Dart é compatível com a função Node e não altera o payload',
      () {
    final dados = {
      'id': 'cartao',
      'medicoId': 'teste',
      'data': '2026-10-28T00:00:00.000',
      'horarios': ['14:00', '18:00']
    };
    expect(VistaDiariaSync.assinatura(dados),
        '6730aeb9a0b2284c14d4e137826f0a4a7950006dcb6100b2bd27e840ef7f8d6b');
    expect(dados.containsKey(VistaDiariaSync.campoHash), false);
    expect(VistaDiariaSync.assinatura(VistaDiariaSync.marcar(dados)),
        VistaDiariaSync.assinatura(dados));
  });
}
