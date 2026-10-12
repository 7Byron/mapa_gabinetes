import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';

void main() {
  for (final zoom in [0.5, 1.0, 2.0]) {
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
                especialidadesPermitidas: []),
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
        expect(find.text('Piso 1'), findsOneWidget);
        expect(find.text('Piso 2'), findsOneWidget);
        for (var semana = 1; semana <= 5; semana++) {
          expect(find.text('Semana $semana'), findsOneWidget);
        }
        for (final dia in ['2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom']) {
          expect(find.text(dia), findsNWidgets(5));
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
        final cabecalhoAntes = tester.getTopLeft(find.text('Semana 1'));
        await tester.dragFrom(
            tester.getCenter(
                find.byKey(const ValueKey('matriz_corpo_horizontal'))),
            const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('Semana 1')), cabecalhoAntes);
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
