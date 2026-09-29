import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/cartoes_gabinete_layout.dart';

void main() {
  Future<void> montar(WidgetTester tester, String horario,
      {int quantidade = 1, double alturaCartao = 60}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 180,
          height: 180,
          child: CartoesGabineteLayout(
            horarioInicio: horario,
            children: List.generate(
              quantidade,
              (i) => SizedBox(key: ValueKey('cartao$i'), height: alturaCartao),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('posiciona por horário e mantém o cartão dentro do gabinete',
      (tester) async {
    for (final exemplo in {
      '06:00': 0.0,
      '08:00': 0.0,
      '14:00': 60.0,
      '16:00': 80.0,
      '20:00': 120.0,
      '23:00': 120.0,
      '': 0.0,
    }.entries) {
      await montar(tester, exemplo.key);
      final cartao = tester.getRect(find.byKey(const ValueKey('cartao0')));
      expect(cartao.top, closeTo(exemplo.value, 0.01));
      expect(cartao.bottom, lessThanOrEqualTo(180));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('vários cartões ficam seguidos e podem ser percorridos',
      (tester) async {
    await montar(tester, '16:00', quantidade: 4);
    for (var i = 0; i < 4; i++) {
      expect(tester.getTopLeft(find.byKey(ValueKey('cartao$i'))).dy, i * 60);
    }
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('cartao3'))).dy,
      lessThanOrEqualTo(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartão alto permanece acessível sem overflow', (tester) async {
    await montar(tester, '20:00', alturaCartao: 240);
    expect(tester.getTopLeft(find.byKey(const ValueKey('cartao0'))).dy, 0);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('cartao0'))).dy,
      lessThanOrEqualTo(180),
    );
    expect(tester.takeException(), isNull);
  });
}
