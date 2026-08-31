import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/searchable_selection_field.dart';

Widget _app({
  String? value,
  required ValueChanged<String?> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          child: SearchableSelectionField<String>(
            value: value,
            label: 'Médico',
            hint: 'Selecionar médico...',
            dialogTitle: 'Médico',
            searchHint: 'Pesquisar médico',
            suffixIcon: Icons.person_outline,
            options: const [
              SearchableSelectionOption(value: 'z', label: 'Zulmira'),
              SearchableSelectionOption(value: 'm', label: 'Maria Santos'),
              SearchableSelectionOption(value: 'a2', label: 'Ana'),
              SearchableSelectionOption(value: 'a1', label: 'Ágata'),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mantém legenda flutuante sem sobrepor o placeholder',
      (tester) async {
    await tester.pumpWidget(_app(onChanged: (_) {}));

    final legenda = tester.getRect(find.text('Médico'));
    final placeholder = tester.getRect(find.text('Selecionar médico...'));

    expect(legenda.bottom, lessThan(placeholder.top));
  });

  testWidgets('abre lista ordenada alfabeticamente ignorando acentos',
      (tester) async {
    await tester.pumpWidget(_app(onChanged: (_) {}));

    await tester.tap(find.text('Selecionar médico...'));
    await tester.pumpAndSettle();

    final yAgata = tester.getTopLeft(find.text('Ágata')).dy;
    final yAna = tester.getTopLeft(find.text('Ana')).dy;
    final yMaria = tester.getTopLeft(find.text('Maria Santos')).dy;
    final yZulmira = tester.getTopLeft(find.text('Zulmira')).dy;

    expect(yAgata, lessThan(yAna));
    expect(yAna, lessThan(yMaria));
    expect(yMaria, lessThan(yZulmira));
  });

  testWidgets('filtra enquanto o utilizador escreve e ignora acentos',
      (tester) async {
    await tester.pumpWidget(_app(onChanged: (_) {}));

    await tester.tap(find.text('Selecionar médico...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'agata');
    await tester.pump();

    expect(find.text('Ágata'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Maria Santos'), findsNothing);
  });

  testWidgets('devolve a opção escolhida', (tester) async {
    String? selecionado;
    await tester.pumpWidget(_app(onChanged: (value) => selecionado = value));

    await tester.tap(find.text('Selecionar médico...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Maria');
    await tester.pump();
    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();

    expect(selecionado, 'm');
    expect(find.text('Médico'), findsOneWidget);
  });

  testWidgets('permite limpar uma seleção atual', (tester) async {
    String? selecionado = 'm';
    await tester.pumpWidget(
      _app(value: selecionado, onChanged: (value) => selecionado = value),
    );

    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar seleção'));
    await tester.pumpAndSettle();

    expect(selecionado, isNull);
  });
}
