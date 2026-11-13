import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/services/alocacao_clinica_config_service.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_especialidade_service.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends RelatorioHorasEspecialidadeService {
  RelatorioHorasCacheService? persistencia;
  @override
  RelatorioHorasCacheService? get cachePersistente => persistencia;
  final Map<String, List<Disponibilidade>> disponibilidades;
  final carregados = <String>[];
  final periodos = <(DateTime, DateTime)>[];
  String versao = '1';
  int configuracoes = 0;
  int emCurso = 0;
  int pico = 0;
  int extras = 0;
  bool falhar = false;
  Duration atraso = Duration.zero;
  Future<void>? suspender;
  Completer<void>? iniciados;
  _Service(this.disponibilidades);

  @override
  Future<String> obterVersaoCache({required Unidade unidade}) async => versao;

  @override
  Future<List<Medico>> carregarMedicos(
          {required Unidade unidade, bool forcarServidor = false}) async =>
      [
        for (final (id, ativo) in [
          ('ana', true),
          ('rui', true),
          ('zero', true),
          ('inativo', false)
        ])
          Medico(
              id: id,
              nome: id,
              especialidade: id == 'ana' ? 'MGF' : 'ORL',
              disponibilidades: [],
              ativo: ativo),
        for (var i = 0; i < extras; i++)
          Medico(
              id: 'extra$i',
              nome: 'Extra $i',
              especialidade: 'ORL',
              disponibilidades: []),
      ];

  @override
  Future<ClinicaConfiguracoes> carregarConfiguracoes(
      {required Unidade unidade, required bool forcarServidor}) async {
    configuracoes++;
    return ClinicaConfiguracoes(
        horariosClinica: {
          for (var i = 1; i <= 7; i++) i: ['08:00', '20:00']
        },
        nuncaEncerra: false,
        encerraFeriados: false,
        encerraDias: {});
  }

  @override
  Future<List<Map<String, String>>> carregarFeriados(
          {required Unidade unidade,
          required int ano,
          required bool forcarServidor}) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> carregarEncerramentos(
          {required Unidade unidade,
          required int ano,
          required bool forcarServidor}) async =>
      [];

  @override
  Future<List<Disponibilidade>> carregarDisponibilidadesMedicoPeriodo({
    required Medico medico,
    required Unidade unidade,
    required List<int> anos,
    required DateTime inicio,
    required DateTime fim,
    required bool forcarServidor,
  }) async {
    carregados.add(medico.id);
    periodos.add((inicio, fim));
    final resultado = disponibilidades[medico.id] ?? <Disponibilidade>[];
    final bloqueio = suspender;
    if (carregados.length == 3 && iniciados?.isCompleted == false) {
      iniciados!.complete();
    }
    emCurso++;
    if (emCurso > pico) pico = emCurso;
    try {
      await Future<void>.delayed(atraso);
      if (bloqueio != null) await bloqueio;
      if (falhar && medico.id == 'rui') throw StateError('Erro de leitura');
      return resultado;
    } finally {
      emCurso--;
    }
  }
}

Disponibilidade _dia(String id, int dia, List<String> horarios) =>
    Disponibilidade(
        id: '$id-$dia-$horarios',
        medicoId: id,
        data: DateTime(2026, 11, dia),
        horarios: horarios,
        tipo: 'Única');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unidade = Unidade(
      id: 'contribuicao',
      nome: 'Clínica',
      tipo: 'Clínica',
      endereco: '',
      dataCriacao: DateTime(2026),
      nomeOcupantes: 'Médicos',
      nomeAlocacao: 'Gabinetes');
  final inicio = DateTime(2026, 11, 1), fim = DateTime(2026, 11, 30);

  test(
      '20 de 200 horas representa 10%, independentemente dos médicos selecionados',
      () async {
    final service = _Service({
      'ana': [
        for (var i = 1; i <= 2; i++) _dia('ana', i, ['08:00', '18:00'])
      ],
      'rui': [
        for (var i = 1; i <= 18; i++) _dia('rui', i, ['08:00', '18:00'])
      ],
      'inativo': [
        _dia('inativo', 1, ['08:00', '20:00'])
      ],
    });
    var primeiraConsulta = true;
    for (final ids in [
      {'ana'},
      {'ana', 'rui'},
      {'zero'}
    ]) {
      service.carregados.clear();
      final relatorio = await service.calcular(
          unidade: unidade, inicio: inicio, fim: fim, medicoIds: ids);
      expect(relatorio.medicos.map((m) => m.medicoId).toSet(), ids);
      expect(relatorio.totalHorasConsultaClinica, 200);
      expect(relatorio.totalMedicosAtivosClinica, 3);
      final orl = relatorio.especialidadesClinica['ORL']!;
      expect(orl.horasConsulta, 180);
      expect(orl.medicosAtivos, 2); // Inclui o médico com zero horas.
      expect(orl.medicosComDisponibilidade, 1);
      expect(orl.mediaHorasPorMedicoAtivo, 90);
      expect(relatorio.especialidadesClinica['MGF']!.horasConsulta, 20);
      expect(relatorio.mediaHorasPorMedicoClinica, closeTo(200 / 3, 1e-9));
      expect(service.carregados.toSet(),
          primeiraConsulta ? {'ana', 'rui', 'zero'} : <String>{});
      expect(service.configuracoes, 1);
      primeiraConsulta = false;
      if (ids.contains('ana')) {
        final ana = relatorio.medicos.firstWhere((m) => m.medicoId == 'ana');
        expect(ana.horasConsulta, 20);
        expect(ana.percentagemContribuicao(relatorio.totalHorasConsultaClinica),
            10);
      }
    }
  });

  test('Total clínico aplica período, abertura e união de horários sobrepostos',
      () async {
    final service = _Service({
      'ana': [
        _dia('ana', 1, ['07:00', '12:00']),
        _dia('ana', 1, ['10:00', '14:00']),
        _dia('ana', 1, ['19:00', '23:00']),
        _dia('ana', 0, ['08:00', '20:00']),
      ],
      'rui': [
        _dia('rui', 1, ['08:00', '11:00'])
      ],
    });
    final relatorio = await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    expect(relatorio.medicos.single.horasConsulta, 7);
    expect(relatorio.totalHorasConsultaClinica, 10);
    expect(relatorio.medicos.single.percentagemContribuicao(10), 70);
  });

  test('Clínica sem horas apresenta contribuição e média iguais a zero',
      () async {
    final relatorio = await _Service({}).calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    expect(relatorio.totalHorasConsultaClinica, 0);
    expect(relatorio.medicos.single.percentagemContribuicao(0), 0);
    expect(relatorio.mediaHorasPorMedicoClinica, 0);
  });

  test('Seleção inválida continua a ser recusada', () async {
    await expectLater(
        _Service({}).calcular(
            unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'inativo'}),
        throwsStateError);
  });

  test(
      'Versão e atualização explícita recalculam; períodos do mesmo mês reutilizam',
      () async {
    final service = _Service({
      'ana': [
        _dia('ana', 1, ['08:00', '10:00'])
      ]
    });
    Future<double> consultar(
            {bool forcar = false, DateTime? ate, Unidade? clinica}) async =>
        (await service.calcular(
                unidade: clinica ?? unidade,
                inicio: inicio,
                fim: ate ?? fim,
                medicoIds: {'ana'},
                forcarServidor: forcar))
            .totalHorasConsultaClinica;
    expect(await consultar(), 2);
    service.disponibilidades['ana'] = [
      _dia('ana', 1, ['08:00', '12:00'])
    ];
    service.versao = '2';
    expect(await consultar(), 4);
    expect(service.carregados.length, 6);
    service.disponibilidades['ana'] = [
      _dia('ana', 1, ['08:00', '13:00'])
    ];
    expect(await consultar(forcar: true), 5);
    expect(service.carregados.length, 9);
    expect(await consultar(ate: DateTime(2026, 11, 29)), 5);
    expect(
        service.carregados.length, 9); // Outro intervalo reutiliza o mesmo mês.
    final outra = Unidade(
        id: 'outra',
        nome: 'Outra',
        tipo: 'Clínica',
        endereco: '',
        dataCriacao: inicio,
        nomeOcupantes: 'Médicos',
        nomeAlocacao: 'Gabinetes');
    expect(await consultar(clinica: outra), 5);
    expect(service.carregados.length, 12);
  });

  test(
      'Consultas simultâneas partilham o cálculo e falhas não guardam resultados parciais',
      () async {
    final service = _Service({})..atraso = const Duration(milliseconds: 5);
    await Future.wait([
      service.calcular(
          unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'}),
      service.calcular(
          unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'rui'}),
    ]);
    expect(service.carregados.length, 3);
    service.falhar = true;
    await expectLater(
        service.calcular(
            unidade: unidade,
            inicio: inicio,
            fim: fim,
            medicoIds: {'ana'},
            forcarServidor: true),
        throwsStateError);
    service.falhar = false;
    await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    expect(service.carregados.length, 9);
  });

  test(
      'Primeiro cálculo usa lotes limitados; mudar médico não volta a carregar a clínica',
      () async {
    final service = _Service({})
      ..extras = 27
      ..atraso = const Duration(milliseconds: 10);
    final cronometro = Stopwatch()..start();
    await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    cronometro.stop();
    final primeiro = cronometro.elapsedMilliseconds;
    expect(service.carregados.length, 30);
    expect(service.pico, 6);
    service.carregados.clear();
    cronometro.reset();
    cronometro.start();
    await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'rui'});
    cronometro.stop();
    expect(service.carregados, isEmpty);
    // Medição controlada de latência, sem depender da rede de produção.
    debugPrint(
        '30 médicos (latência simulada de 10 ms): primeiro $primeiro ms; '
        'troca ${cronometro.elapsedMilliseconds} ms, zero carregamentos adicionais.');
  });

  test('Um cálculo antigo não substitui uma atualização que terminou primeiro',
      () async {
    final desbloquear = Completer<void>();
    final service = _Service({
      'ana': [
        _dia('ana', 1, ['08:00', '10:00'])
      ]
    })
      ..suspender = desbloquear.future
      ..iniciados = Completer<void>();
    final antigo = service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    await service.iniciados!.future;
    service.suspender = null;
    service.versao = '2';
    service.disponibilidades['ana'] = [
      _dia('ana', 1, ['08:00', '12:00'])
    ];
    final novo = await service.calcular(
        unidade: unidade,
        inicio: inicio,
        fim: fim,
        medicoIds: {'ana'},
        forcarServidor: true);
    expect(novo.totalHorasConsultaClinica, 4);
    desbloquear.complete();
    expect((await antigo).totalHorasConsultaClinica, 2);
    final reutilizado = await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    expect(reutilizado.totalHorasConsultaClinica, 4);
    expect(service.carregados.length, 6);
  });

  test('Semanas, médicos e especialidades reutilizam o mês entre sessões',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = FakeFirebaseFirestore();
    await db
        .doc('unidades/${unidade.id}/cache_control/global')
        .set({'seriesVersion': 1});
    _Service sessao(Map<String, List<Disponibilidade>> dados) => _Service(dados)
      ..versao = '1_0_0_0'
      ..persistencia = RelatorioHorasCacheService(firestore: db);
    final primeira = sessao({
      'ana': [
        _dia('ana', 1, ['08:00', '10:00']),
        _dia('ana', 10, ['08:00', '11:00'])
      ],
      'rui': [
        _dia('rui', 10, ['08:00', '17:00'])
      ],
    });
    final semana1 = await primeira.calcular(
        unidade: unidade,
        inicio: inicio,
        fim: DateTime(2026, 11, 7),
        medicoIds: {'ana'});
    expect(semana1.totalHorasConsultaClinica, 2);
    expect(primeira.carregados.length, 3);
    expect(primeira.periodos.toSet(), {(inicio, fim)});

    // Outra instância, sem disponibilidades disponíveis, depende da cache local.
    final segunda = sessao({});
    final semana2 = await segunda.calcular(
        unidade: unidade,
        inicio: DateTime(2026, 11, 8),
        fim: DateTime(2026, 11, 14),
        medicoIds: {'ana'});
    expect(semana2.medicos.single.horasConsulta, 3);
    expect(semana2.totalHorasConsultaClinica, 12);
    expect(semana2.especialidadesClinica['MGF']!.horasConsulta, 3);
    expect(semana2.especialidadesClinica['ORL']!.horasConsulta, 9);
    expect(semana2.especialidadesClinica['ORL']!.mediaHorasPorMedicoAtivo, 4.5);
    expect(semana2.medicos.single.percentagemContribuicao(12), 25);
    expect(segunda.carregados, isEmpty);
    expect(segunda.configuracoes, 0);

    // Sem a cópia local, simula outro dispositivo a reutilizar o resumo partilhado.
    await (await SharedPreferences.getInstance()).clear();
    final terceira = sessao({});
    final especialidade = await terceira.calcular(
        unidade: unidade, inicio: inicio, fim: fim, especialidades: {'MGF'});
    expect(especialidade.linhas.single.horasConsulta, 5);
    expect(especialidade.totalHorasConsultaClinica, 14);
    expect(terceira.carregados, isEmpty);
    expect(terceira.configuracoes, 0);

    // Alteração relevante: a sessão seguinte reconstrói o resumo.
    await db
        .doc('unidades/${unidade.id}/cache_control/global')
        .update({'seriesVersion': 2});
    terceira.versao = '2_0_0_0';
    terceira.disponibilidades['ana'] = [
      _dia('ana', 1, ['08:00', '12:00'])
    ];
    final atualizado = await terceira.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'ana'});
    expect(atualizado.totalHorasConsultaClinica, 4);
    expect(terceira.carregados.length, 3);
  });

  test(
      'Primeiro relatório anual agrupa meses; só meses em falta são carregados',
      () async {
    final service = _Service({
      'ana': [
        _dia('ana', 1, ['08:00', '10:00'])
      ],
    });
    final de = DateTime(2026), ate = DateTime(2026, 12, 31);
    final anual = await service
        .calcular(unidade: unidade, inicio: de, fim: ate, medicoIds: {'ana'});
    expect(anual.totalHorasConsultaClinica, 2);
    expect(service.carregados.length, 3);
    expect(service.configuracoes, 1);
    expect(service.periodos.toSet(), {(de, ate)});
    final mensal = await service.calcular(
        unidade: unidade, inicio: inicio, fim: fim, medicoIds: {'rui'});
    expect(mensal.totalHorasConsultaClinica, 2);
    expect(service.carregados.length, 3);
    await service.calcular(
        unidade: unidade,
        inicio: DateTime(2026, 12, 25),
        fim: DateTime(2027, 1, 7),
        medicoIds: {'ana'});
    expect(service.carregados.length, 6);
    expect(service.periodos.last, (DateTime(2027), DateTime(2027, 1, 31)));
  });
}
