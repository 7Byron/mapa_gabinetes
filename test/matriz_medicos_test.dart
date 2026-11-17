import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/services/matriz_medicos_service.dart';
import 'package:mapa_gabinetes/screens/matriz_medicos_screen.dart';

void main() {
  final medico = Medico(
      id: 'nuno',
      nome: 'Dr. Nuno Florêncio',
      especialidade: 'Medicina Geral e Familiar',
      disponibilidades: []);
  final series = [
    SerieRecorrencia(
        id: 'segunda',
        medicoId: medico.id,
        dataInicio: DateTime(2025, 12, 29),
        tipo: 'Semanal',
        horarios: ['08:00', '16:00']),
    SerieRecorrencia(
        id: 'quarta',
        medicoId: medico.id,
        dataInicio: DateTime(2025, 12, 31),
        tipo: 'Semanal',
        horarios: ['08:00', '14:00']),
  ];
  test('Conta ocorrências reais sem multiplicar o mês por quatro semanas', () {
    final linha =
        MatrizMedicosService.gerar([medico], series, DateTime(2026, 11, 16))
            .single;
    expect(linha.semana, 14 * 60);
    expect(linha.mes, 64 * 60); // Cinco segundas e quatro quartas.
    expect(linha.ano, 728 * 60);
  });
  test('Oculta validade anual e mostra apenas limites dentro do ano', () {
    MatrizMedicoLinha linha(DateTime inicio, DateTime? fim) =>
        MatrizMedicosService.gerar([
          medico
        ], [
          SerieRecorrencia(
              id: 'regra',
              medicoId: medico.id,
              dataInicio: inicio,
              dataFim: fim,
              tipo: 'Semanal',
              horarios: ['08:00', '16:00']),
        ], DateTime(2026, 11, 16))
            .single;
    expect(linha(DateTime(2026), null).horarios.single,
        '5.ª feira · 08:00 – 16:00');
    expect(linha(DateTime(2025), DateTime(2027)).horarios.single,
        isNot(contains('2025')));
    expect(linha(DateTime(2026, 3, 6), null).horarios.single,
        contains('A partir de 06/03/2026'));
    expect(linha(DateTime(2025), DateTime(2026, 10, 25)).horarios.single,
        contains('Até 25/10/2026'));
    expect(linha(DateTime(2026, 1, 16), DateTime(2026, 11, 5)).horarios.single,
        contains('Até 05/11/2026'));
    expect(linha(DateTime(2026, 1, 24), null).horarios.single,
        isNot(contains('A partir de')));
    expect(MatrizMedicosService.horas(510), '8:30');
    expect(MatrizMedicosService.horas(0), '0:00');
    expect(MatrizMedicosService.horas(63005), '1050:05');
  });
  test('Mudança de quinzena mantém uma única descrição e os totais reais', () {
    final regras = [
      SerieRecorrencia(
          id: 'a',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 1, 16),
          dataFim: DateTime(2026, 5, 1),
          tipo: 'Quinzenal',
          horarios: ['09:30', '12:30']),
      SerieRecorrencia(
          id: 'b',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 5, 8),
          tipo: 'Quinzenal',
          horarios: ['09:30', '12:30']),
    ];
    final linha =
        MatrizMedicosService.gerar([medico], regras, DateTime(2026, 11, 16))
            .single;
    expect(linha.horarios, ['6.ª feira · 09:30 – 12:30 · Quinzenal']);
    final separado = regras
        .map((r) =>
            MatrizMedicosService.gerar([medico], [r], DateTime(2026, 11, 16))
                .single
                .ano)
        .reduce((a, b) => a + b);
    expect(linha.ano, separado);
  });
  test('Une sobreposições e respeita o fim da série', () {
    final linha = MatrizMedicosService.gerar([
      medico
    ], [
      ...series,
      SerieRecorrencia(
          id: 'sobreposta',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 11, 16),
          dataFim: DateTime(2026, 11, 16),
          tipo: 'Semanal',
          horarios: ['12:00', '18:00']),
    ], DateTime(2026, 11, 16))
        .single;
    expect(linha.semana, 16 * 60);
    expect(linha.mes, 66 * 60);
    expect(linha.ano, 730 * 60);
  });
  test(
      'Desconta ausências e encerramentos e seleciona semana independente do mês',
      () {
    final linha =
        MatrizMedicosService.gerar([medico], series, DateTime(2026, 10),
                semanaReferencia: DateTime(2026, 11, 16),
                excecoes: [
                  ExcecaoSerie(
                      id: 'ausencia',
                      serieId: 'segunda',
                      data: DateTime(2026, 11, 16),
                      cancelada: true)
                ],
                encerramentos: {DateTime(2026, 11, 18), DateTime(2026, 10, 5)})
            .single;
    expect(linha.semana, 0);
    expect(
        linha.mes,
        48 *
            60); // Outubro: quatro segundas e quatro quartas menos um encerramento.
    expect(linha.ano, (728 - 14 - 8) * 60);
  });
  test('Nova duração no mesmo dia substitui a anterior na data da mudança', () {
    final regras = [
      SerieRecorrencia(
          id: 'antiga',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 1, 8),
          tipo: 'Quinzenal',
          horarios: ['14:00', '18:00']),
      SerieRecorrencia(
          id: 'nova',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 10, 1),
          tipo: 'Quinzenal',
          horarios: ['14:00', '17:30']),
    ];
    final linha =
        MatrizMedicosService.gerar([medico], regras, DateTime(2026, 10, 1))
            .single;
    expect(linha.horarios.first, contains('Até 01/10/2026'));
    expect(linha.horarios.last, contains('A partir de 01/10/2026'));
    expect(linha.semana, 210);
    expect(regras.first.dataFim,
        isNull); // A apresentação não altera os dados guardados.
  });
  test('Horário quinzenal com mudança em abril alterna semanas com e sem horas',
      () {
    final regras = [
      SerieRecorrencia(
          id: 'antes_abril',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 1, 16),
          dataFim: DateTime(2026, 11, 5),
          tipo: 'Quinzenal',
          horarios: ['08:00', '13:00']),
      SerieRecorrencia(
          id: 'desde_abril',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 4, 10),
          tipo: 'Quinzenal',
          horarios: ['08:00', '13:30']),
    ];
    MatrizMedicoLinha semana(int dia) =>
        MatrizMedicosService.gerar([medico], regras, DateTime(2026, 11),
                semanaReferencia: DateTime(2026, 11, dia))
            .single;
    expect(semana(16).semana, 330); // Há ocorrência em 20/11.
    expect(semana(23).semana, 0); // A seguinte ocorre em 04/12.
    expect(semana(16).mes, 660); // 06/11 e 20/11.
    expect(semana(23).mes, 660);
  });

  test('Ausência de 20/11 distingue previsto e real na semana da Ana Almeida',
      () {
    final regras = [
      SerieRecorrencia(
          id: 'antes',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 1, 16),
          dataFim: DateTime(2026, 11, 5),
          tipo: 'Quinzenal',
          horarios: ['08:00', '13:00']),
      SerieRecorrencia(
          id: 'depois',
          medicoId: medico.id,
          dataInicio: DateTime(2026, 4, 10),
          tipo: 'Quinzenal',
          horarios: ['08:00', '13:30']),
    ];
    final referencia = DateTime(2026, 11, 16);
    final previsto =
        MatrizMedicosService.gerar([medico], regras, referencia).single;
    final real = MatrizMedicosService.gerar([medico], regras, referencia,
        excecoes: [
          ExcecaoSerie(
              id: 'ausencia_janeiro',
              serieId: 'antes',
              data: DateTime(2026, 1, 16),
              cancelada: true),
          ExcecaoSerie(
              id: 'ausencia_novembro',
              serieId: 'depois',
              data: DateTime(2026, 11, 20),
              cancelada: true),
        ]).single;
    expect(previsto.semana, 330);
    expect(real.semana, 0);
    expect(previsto.mes, 660);
    expect(real.mes, 330);
    expect(previsto.ano, 134 * 60 + 30);
    expect(real.ano, 124 * 60);
  });

  testWidgets('Pesquisa, ordenação e pré-visualização da matriz',
      (tester) async {
    await tester.runAsync(() async {
      final fonte = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(
            await File('fonts/Montserrat-Regular.ttf').readAsBytes())));
      await fonte.load();
    });
    tester.view.physicalSize = const Size(1720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final unidade =
        Unidade.fromMap({'id': 'demo', 'nome': 'Clínica de exemplo'});
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true, colorSchemeSeed: const Color(0xff17685e)),
        home: MatrizMedicosScreen(
            unidade: unidade,
            referenciaInicial: DateTime(2026, 11, 16),
            carregarLinhas: (_) async => [
                  ...MatrizMedicosService.gerar(
                      [medico], series, DateTime(2026, 11, 16)),
                  MatrizMedicoLinha(
                      Medico(
                          id: 'ana',
                          nome: 'Dra. Ana Silva',
                          especialidade: 'Cardiologia',
                          disponibilidades: []),
                      [
                        '3.ª feira · 09:00 – 13:00',
                        '5.ª feira · 14:00 – 18:00'
                      ],
                      480,
                      1920,
                      24960),
                ])));
    await tester.pumpAndSettle();
    expect(find.text('14:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('previews/matriz_medicos.png'));
    for (final opcao in ['Horas']) {
      await tester.tap(find.text(opcao).last);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Dr. Nuno Florêncio')).dy,
          lessThan(tester.getTopLeft(find.text('Dra. Ana Silva')).dy));
    }
    expect(find.text('63,6%'), findsOneWidget);
    expect(find.text('36,4%'), findsOneWidget);
    expect(find.textContaining('Escolha o mês e a semana'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('matriz_todos_real')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.event_available), findsOneWidget);
    expect(find.byIcon(Icons.event_note), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('matriz_todos_previsto')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('matriz_percentagem_periodo')), findsNothing);
    await tester.enterText(find.byType(TextField), 'Nuno');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Silva'), findsNothing);
    expect(find.text('63,6%'), findsOneWidget);
    expect(find.text('Dr. Nuno Florêncio'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'florencio');
    await tester.pumpAndSettle();
    expect(find.text('Dr. Nuno Florêncio'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cardio');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Ana Silva'), findsOneWidget);
    expect(find.text('Dr. Nuno Florêncio'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('matriz_medicos_exportar')));
    await tester.pumpAndSettle();
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Tabela'), findsOneWidget);
    expect(find.text('Gráfico'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Nuno Florêncio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('matriz_medicos_ano')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);
    expect(find.textContaining('Ano: 2027'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
