import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/widgets/cartao_mapa_interativo.dart';

void main() {
  final medico = Medico(
      id: 'm',
      nome: 'Dra. Rita',
      especialidade: 'Gastrenterologia',
      disponibilidades: []);
  Widget app(
          {bool ausente = false,
          Alignment alinhamento = Alignment.center,
          VoidCallback? editar,
          Future<void> Function()? alternar}) =>
      MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: alinhamento,
                child: SizedBox(
                  width: 220,
                  child: CartaoMapaInterativo(
                    medico: medico,
                    horarios: '14:40 - 18:00',
                    dragData: 'm|||alocacao:a',
                    ausente: ausente,
                    onEditar: editar ?? () {},
                    onAlternarAusencia: alternar ?? () async {},
                  ),
                ))),
      );
  Future<void> abrir(WidgetTester tester) async {
    await tester.tap(find.text('Dra. Rita').first);
    await tester.pumpAndSettle();
  }

  testWidgets('Toque abre menu; só Editar navega para gerir médico',
      (tester) async {
    var edicoes = 0;
    await tester.pumpWidget(app(editar: () => edicoes++));
    expect(find.byType(Draggable<String>), findsNothing);
    final cartao = tester.getRect(find.byType(CartaoMapaInterativo));
    await abrir(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final opcao = tester.getRect(find.byType(PopupMenuItem<String>).first);
    expect(opcao.top, closeTo(cartao.bottom + 8, 1));
    expect(opcao.left, closeTo(cartao.left, 1));
    expect(edicoes, 0);
    expect(find.text('Editar disponibilidade'), findsOneWidget);
    expect(find.text('Inativar este cartão'), findsOneWidget);
    expect(find.text('Mover cartão'), findsOneWidget);
    expect(find.text('Ativar este cartão'), findsNothing);
    await tester.tap(find.text('Editar disponibilidade'));
    await tester.pumpAndSettle();
    expect(edicoes, 1);
  });

  testWidgets('Menu junto à borda cabe num ecrã estreito e fecha ao tocar fora',
      (tester) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var alteracoes = 0;
    await tester.pumpWidget(app(
      alinhamento: Alignment.bottomRight,
      alternar: () async {
        alteracoes++;
      },
    ));
    await abrir(tester);
    for (final elemento in find.byType(PopupMenuItem<String>).evaluate()) {
      final rect = tester.getRect(find.byWidget(elemento.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(500));
    }
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(alteracoes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mover desbloqueia só até terminar o arrasto', (tester) async {
    await tester.pumpWidget(app());
    await abrir(tester);
    await tester.tap(find.text('Mover cartão'));
    await tester.pumpAndSettle();
    expect(find.byType(Draggable<String>), findsOneWidget);
    expect(
        tester.widget<Draggable<String>>(find.byType(Draggable<String>)).data,
        'm|||alocacao:a');
    await tester.drag(find.text('Dra. Rita'), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Draggable<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final ausente in [false, true]) {
    testWidgets('Alterna apenas o cartão selecionado (ausente=$ausente)',
        (tester) async {
      var alteracoes = 0;
      final terminar = Completer<void>();
      await tester.pumpWidget(app(
          ausente: ausente,
          alternar: () {
            alteracoes++;
            return terminar.future;
          }));
      await abrir(tester);
      if (ausente) {
        expect(find.text('Mover cartão'), findsNothing);
        expect(find.text('Inativar este cartão'), findsNothing);
      }
      await tester.tap(
          find.text(ausente ? 'Ativar este cartão' : 'Inativar este cartão'));
      await tester.pumpAndSettle();
      expect(alteracoes, 1);
      await tester.tapAt(tester.getCenter(find.byType(CartaoMapaInterativo)));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      terminar.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Draggable<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
