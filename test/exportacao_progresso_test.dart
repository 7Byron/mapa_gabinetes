import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/exportacao_progresso.dart';

void main() {
  for (final falhar in [false, true]) {
    testWidgets(
        'Indicador fecha ao ${falhar ? 'falhar' : 'concluir'} a exportação',
        (tester) async {
      final concluir = Completer<void>();
      Object? erro;
      var iniciou = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              try {
                await executarComProgressoExportacao(context, (informar) {
                  iniciou = true;
                  return concluir.future;
                });
              } catch (e) {
                erro = e;
              }
            },
            child: const Text('Exportar')),
      ))));
      await tester.tap(find.text('Exportar'));
      await tester.pump();
      expect(iniciou, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 8 && !iniciou; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      expect(iniciou, isTrue);
      if (falhar) {
        concluir.completeError(StateError('Falha simulada'));
      } else {
        concluir.complete();
      }
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Exportar'), findsOneWidget);
      expect(erro, falhar ? isA<StateError>() : isNull);
    });
  }
}
