import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/searchable_dropdown_field.dart';

void main() {
  testWidgets('ordena, pesquisa sem acentos e seleciona uma opção',
      (tester) async {
    String? selected;
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableDropdownField<String>(
            value: selected,
            labelText: 'Médico',
            hintText: 'Selecionar médico...',
            searchHintText: 'Pesquisar médico',
            icon: Icons.person,
            items: const ['Rui', 'Álvaro', 'Ana'],
            itemLabel: (item) => item,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Selecionar médico...'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Álvaro')).dy,
        lessThan(tester.getTopLeft(find.text('Ana')).dy));
    expect(tester.getTopLeft(find.text('Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Rui')).dy));

    await tester.enterText(find.byType(TextField), 'alv');
    await tester.pump();

    expect(find.text('Álvaro'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Rui'), findsNothing);

    await tester.tap(find.text('Álvaro'));
    await tester.pumpAndSettle();
    expect(selected, 'Álvaro');
  });
}
