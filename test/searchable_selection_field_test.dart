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

Widget _appMultipla({
  Set<String> values = const {},
  required ValueChanged<Set<String>> onChanged,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SearchableSelectionField<String>.multiple(
          values: values,
          label: 'Médicos',
          hint: 'Selecionar médicos...',
          dialogTitle: 'Selecionar médicos',
          searchHint: 'Pesquisar por nome ou especialidade',
          suffixIcon: Icons.person_outline,
          options: const [
            SearchableSelectionOption(value: 'ana', label: 'Ana · Cardiologia'),
            SearchableSelectionOption(value: 'rui', label: 'Rui · ORL'),
          ],
          onSelectionChanged: onChanged,
        ),
      ),
    );

void main() {
  testWidgets('mantém várias escolhas entre pesquisas e só aplica ao confirmar',
      (tester) async {
    Set<String>? resultado;
    await tester.pumpWidget(_appMultipla(onChanged: (v) => resultado = v));
    await tester.tap(find.text('Selecionar médicos...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cardiologia');
    await tester.pump();
    await tester.tap(find.text('Ana · Cardiologia'));
    await tester.pump();
    expect(resultado, isNull);
    await tester.enterText(find.byType(TextField), 'rui');
    await tester.pump();
    await tester.tap(find.text('Rui · ORL'));
    await tester.pump();
    expect(find.text('2 selecionados'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(resultado, {'ana', 'rui'});
  });

  testWidgets('cancelar descarta alterações sem modificar a seleção original',
      (tester) async {
    final original = {'ana'};
    var chamadas = 0;
    await tester.pumpWidget(
        _appMultipla(values: original, onChanged: (_) => chamadas++));
    await tester.tap(find.text('Ana · Cardiologia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar seleção'));
    await tester.pump();
    await tester.tap(find.text('Rui · ORL'));
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(original, {'ana'});
    expect(chamadas, 0);
  });

  testWidgets('permite desmarcar um médico e limpar todas as escolhas',
      (tester) async {
    Set<String>? resultado;
    await tester.pumpWidget(
        _appMultipla(values: {'ana', 'rui'}, onChanged: (v) => resultado = v));
    await tester.tap(find.text('Ana · Cardiologia, Rui · ORL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana · Cardiologia'));
    await tester.pump();
    expect(find.text('1 selecionado'), findsOneWidget);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Ana · Cardiologia'))
            .value,
        isFalse);
    await tester.tap(find.text('Limpar seleção'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(resultado, isEmpty);
  });

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
