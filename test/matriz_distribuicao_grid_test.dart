import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';

void main() {
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
