import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/guardar_antes_de_sair.dart';

Future<void> abrirEditor(
  WidgetTester tester,
  Future<bool> Function() guardar,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (context) => GuardarAntesDeSair(
              onGuardar: guardar,
              child: Scaffold(
                appBar: AppBar(
                  leading: BackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                body: const Text('Editor'),
              ),
            ),
          )),
          child: const Text('Abrir'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seta aguarda a gravação e ignora toques repetidos',
      (tester) async {
    final gravacao = Completer<bool>();
    var chamadas = 0;
    await abrirEditor(tester, () {
      chamadas++;
      return gravacao.future;
    });

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(find.text('Editor'), findsOneWidget);
    expect(chamadas, 1);

    gravacao.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('erro mantém a página e permite tentar novamente',
      (tester) async {
    var sucesso = false;
    await abrirEditor(tester, () async => sucesso);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);

    sucesso = true;
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
  });

  testWidgets('voltar do sistema também aguarda antes de sair', (tester) async {
    final gravacao = Completer<bool>();
    await abrirEditor(tester, () => gravacao.future);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Editor'), findsOneWidget);
    gravacao.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
  });
}
