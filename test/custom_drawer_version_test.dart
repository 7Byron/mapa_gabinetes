import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/custom_drawer.dart';

void main() {
  testWidgets('mostra a versão da aplicação por baixo do logótipo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomDrawer(onRefresh: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026.08.31+2'), findsOneWidget);
  });
}
