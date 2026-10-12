import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/carregamento_overlay.dart';

void main() {
  testWidgets('Barra anima durante a espera e mantém o progresso por etapas',
      (tester) async {
    for (final indeterminado in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Stack(children: [
        CarregamentoOverlay(
          isRefreshing: false,
          mensagem: 'A carregar regras de rotação...',
          progresso: 0.3,
          progressoIndeterminado: indeterminado,
        ),
      ]))));
      final indicador = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicador.value, indeterminado ? isNull : equals(0.3));
      expect(find.text('A carregar regras de rotação...'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
  });
}
