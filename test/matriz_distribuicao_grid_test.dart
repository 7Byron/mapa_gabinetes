import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';

void main() {
  testWidgets('Oculta o período anual e mantém datas dos cartões parciais',
      (tester) async {
    MatrizDistribuicaoItem? selecionado;
    MatrizDistribuicaoItem item(String id, DateTime inicio, DateTime fim) =>
        MatrizDistribuicaoItem(
          serieId: id,
          medicoId: id,
          medicoNome: id,
          especialidade: 'Clínica',
          gabineteId: '21',
          tipo: 'Semanal',
          ciclo: 'Semanal',
          dia: 1,
          inicioMinutos: 540,
          fimMinutos: 600,
          validadeInicio: inicio,
          validadeFim: fim,
        );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MatrizDistribuicaoGrid(
      onEditarMedico: (item) => selecionado = item,
      ano: 2027,
      gabinetes: [
        Gabinete(
            id: '21', setor: 'Piso 1', nome: '21', especialidadesPermitidas: [])
      ],
      itens: [
        item('Ano completo', DateTime.utc(2027), DateTime.utc(2027, 12, 31)),
        item('Primeiro semestre', DateTime.utc(2027), DateTime.utc(2027, 6, 30))
      ],
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Ano completo'), findsOneWidget);
    expect(find.text('De 01/01/2027 a 31/12/2027'), findsNothing);
    expect(find.text('Até 30/06/2027'), findsOneWidget);
    await tester.tap(find.text('Primeiro semestre'));
    expect(selecionado?.medicoId, 'Primeiro semestre');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reúne rotações na semana e mantém o gabinete e os conflitos',
      (tester) async {
    MatrizDistribuicaoItem item(
            String serie, String nome, String tipo, String ciclo, int dia,
            {bool conflito = false}) =>
        MatrizDistribuicaoItem(
          serieId: serie,
          medicoId: serie,
          medicoNome: nome,
          especialidade: 'Clínica',
          gabineteId: '101',
          tipo: tipo,
          ciclo: ciclo,
          dia: dia,
          inicioMinutos: 540,
          fimMinutos: 600,
          conflito: conflito,
        );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MatrizDistribuicaoGrid(gabinetes: [
        Gabinete(
            id: '101',
            setor: 'Piso 1',
            nome: 'Gab 101',
            especialidadesPermitidas: ['Psicologia']),
      ], itens: [
        for (final dia in [1, 8, 15, 22, 29])
          item('x', 'Dr. X', 'Semanal', 'Todas as semanas', dia),
        item('y', 'Dr. Y', 'Quinzenal', '14 dias · semanas 1, 3, 5', 1),
        item('y', 'Dr. Y', 'Quinzenal', '14 dias · semanas 1, 3, 5', 15,
            conflito: true),
        item('w', 'Dr. W', 'Mensal', 'Mensal · 2.ª semana', 8),
      ]),
    )));
    await tester.pumpAndSettle();
    final segunda = find.byKey(const ValueKey('celula_101_1'));
    for (final texto in [
      'Dr. X',
      'Dr. Y',
      'Dr. W',
      'Semanal',
      'Quinzenal',
      '2.ª segunda-feira do mês',
      'Possível coincidência'
    ]) {
      expect(find.descendant(of: segunda, matching: find.text(texto)),
          findsOneWidget);
    }
    expect(find.byKey(const ValueKey('celula_101_8')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Mostra períodos distintos no mesmo gabinete e rotação mensal',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MatrizDistribuicaoGrid(
        ano: 2026,
        gabinetes: [
          Gabinete(
              id: '101',
              setor: 'Piso 1',
              nome: '101',
              especialidadesPermitidas: ['Psicologia'])
        ],
        itens: [
          for (final mes in [2, 11])
            MatrizDistribuicaoItem(
                serieId: 'x',
                medicoId: 'x',
                medicoNome: 'Dr. X',
                especialidade: 'Psicologia',
                gabineteId: '101',
                tipo: 'Mensal',
                ciclo: 'Mensal · 2.ª semana',
                dia: 1,
                inicioMinutos: 540,
                fimMinutos: 600,
                validadeInicio: DateTime.utc(2026, mes),
                validadeFim: DateTime.utc(2026, mes + 1, 0)),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Semana tipo · 2026'), findsOneWidget);
    expect(find.text('Dr. X'), findsNWidgets(2));
    expect(find.text('2.ª segunda-feira do mês'), findsNWidgets(2));
    expect(find.text('De 01/02/2026 a 28/02/2026'), findsOneWidget);
    expect(find.text('De 01/11/2026 a 30/11/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Identificação com várias linhas cabe em gabinetes vazios',
      (tester) async {
    for (final escala in [1.0, 1.8]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: MatrizDistribuicaoGrid(
              gabinetes: [
                for (final numero in ['9', '10', '11'])
                  Gabinete(
                    id: numero,
                    setor: 'Piso 0',
                    nome: numero,
                    especialidadesPermitidas: [
                      numero == '9'
                          ? 'Sala Tratamentos Enfermagem'
                          : 'Técnicas de Oftalmologia',
                    ],
                  ),
              ],
              itens: const [],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  for (final zoom in [0.5, 1.0, 1.4, 2.0]) {
    for (final largura in [390.0, 1400.0]) {
      testWidgets('Grelha a $largura e zoom $zoom sem overflow',
          (tester) async {
        tester.view.physicalSize = Size(largura, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        final gabinetes = [
          for (var i = 0; i < 4; i++)
            Gabinete(
                id: '$i',
                setor: 'Piso ${i ~/ 2 + 1}',
                nome: 'Gabinete $i',
                especialidadesPermitidas: ['Psicologia']),
        ];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child:
              MatrizDistribuicaoGrid(zoom: zoom, gabinetes: gabinetes, itens: [
            for (var i = 0; i < 60; i++)
              MatrizDistribuicaoItem(
                serieId: '$i',
                medicoId: '$i',
                medicoNome:
                    'Nome comprido de um médico para verificar o cartão',
                especialidade: 'Especialidade com nome comprido',
                gabineteId: '${i % 4}',
                tipo: 'Quinzenal',
                ciclo: '14 dias · semanas 1, 3, 5',
                dia: (i % 5) * 7 + 4,
                inicioMinutos: 840,
                fimMinutos: 1155,
                conflito: true,
              ),
          ]),
        ))));
        await tester.pumpAndSettle();
        expect(find.text('Piso 1'), findsNWidgets(2));
        expect(find.text('Piso 2'), findsNWidgets(2));
        expect(find.text('Psicologia'), findsNWidgets(4));
        expect(find.text('Semana tipo'), findsOneWidget);
        expect(find.text('Semana 2'), findsNothing);
        for (final dia in ['2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom']) {
          expect(find.text(dia), findsOneWidget);
        }
        final quinta = find.byKey(const ValueKey('celula_0_4'));
        expect(
            find.descendant(
                of: quinta,
                matching: find.text(
                    'Nome comprido de um médico para verificar o cartão')),
            findsWidgets);
        final segunda = find.byKey(const ValueKey('celula_0_1'));
        expect(
            find.descendant(
                of: segunda,
                matching: find.text(
                    'Nome comprido de um médico para verificar o cartão')),
            findsNothing);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 4; i++) {
          expect(find.text('Gabinete $i'), findsOneWidget);
        }
        final lista = find.byKey(const ValueKey('matriz_corpo_vertical'));
        final cartaoTarde = find
            .descendant(
                of: quinta,
                matching: find
                    .text('Nome comprido de um médico para verificar o cartão'))
            .first;
        expect(tester.getTopLeft(cartaoTarde).dy - tester.getTopLeft(quinta).dy,
            greaterThanOrEqualTo(96 * zoom));
        final cabecalhoAntes = tester.getTopLeft(find.text('Semana tipo'));
        await tester.dragFrom(
            tester.getCenter(
                find.byKey(const ValueKey('matriz_corpo_horizontal'))),
            const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Semana tipo')), cabecalhoAntes);
        final vertical = tester.widget<ListView>(lista);
        expect(vertical.controller!.offset, greaterThan(0));
        final identificacaoAntes = tester.getTopLeft(find.text('Gabinete 0'));
        await tester.drag(find.byKey(const ValueKey('matriz_corpo_horizontal')),
            const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Gabinete 0')), identificacaoAntes);
        final cabecalhoScroll = tester.widget<SingleChildScrollView>(
            find.byKey(const ValueKey('matriz_cabecalho_horizontal')));
        final corpoScroll = tester.widget<SingleChildScrollView>(
            find.byKey(const ValueKey('matriz_corpo_horizontal')));
        expect(
            cabecalhoScroll.controller!.offset, corpoScroll.controller!.offset);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
