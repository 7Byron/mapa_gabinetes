import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';

void main() {
  testWidgets('Cada subcartão abre apenas as datas do respetivo período',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MatrizDistribuicaoGrid(
      mostrarLivres: true,
      ano: 2026,
      gabinetes: [
        Gabinete(
            id: '1', setor: 'Piso 1', nome: '1', especialidadesPermitidas: [])
      ],
      itens: [
        MatrizDistribuicaoItem(
            serieId: 'livre',
            medicoId: '',
            medicoNome: 'Livre',
            especialidade: 'Disponibilidade habitual',
            gabineteId: '1',
            tipo: 'Livre',
            ciclo:
                'Jan a Set · Todas as semanas\nOut · 2.ª, 3.ª, 4.ª segunda-feira do mês\nNov a Dez · Todas as semanas',
            dia: 1,
            inicioMinutos: 480,
            fimMinutos: 600,
            ocorrencias: {
              DateTime.utc(2026, 1, 5),
              DateTime.utc(2026, 1, 19),
              DateTime.utc(2026, 10, 12),
              DateTime.utc(2026, 11, 2),
              DateTime.utc(2026, 12, 7),
            },
            disponibilidades: [
              MatrizDisponibilidadePeriodo(
                  descricao: 'Jan a Set · Todas as semanas',
                  datas: {DateTime.utc(2026, 1, 5), DateTime.utc(2026, 1, 19)}),
              MatrizDisponibilidadePeriodo(
                  descricao: 'Out · 2.ª, 3.ª, 4.ª segunda-feira do mês',
                  datas: {DateTime.utc(2026, 10, 12)}),
              MatrizDisponibilidadePeriodo(
                  descricao: 'Nov a Dez · Todas as semanas',
                  excecoes: {
                    DateTime.utc(2026, 11, 9)
                  },
                  datas: {
                    DateTime.utc(2026, 11, 2),
                    DateTime.utc(2026, 12, 7)
                  }),
            ])
      ],
    ))));
    expect(find.text('Disponibilidade habitual'), findsNothing);
    expect(find.text('Exceto: 09/11'), findsOneWidget);
    expect(find.text('08:00 - 10:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('disponibilidade_periodo')),
        findsNWidgets(3));
    final horario = tester.getRect(find.text('08:00 - 10:00'));
    final livre = tester.getRect(find.text('Livre'));
    expect(horario.right, greaterThan(livre.right));
    for (final (meses, descricao) in [
      ('Jan a Set', 'Todas as semanas'),
      ('Out', '2.ª, 3.ª, 4.ª segunda-feira do mês'),
      ('Nov a Dez', 'Todas as semanas'),
    ]) {
      final finder = find.byWidgetPredicate((w) =>
          w is Text && w.textSpan?.toPlainText() == '$meses\n$descricao');
      final texto = tester.widget<Text>(finder);
      expect(texto.textAlign, TextAlign.center);
      expect(texto.style?.fontWeight, FontWeight.normal);
      expect(texto.maxLines, 2);
      final paragrafo = tester.renderObject<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(RichText)).first);
      final linhas = paragrafo
          .getBoxesForSelection(TextSelection(
              baseOffset: 0,
              extentOffset: texto.textSpan!.toPlainText().length))
          .map((caixa) => caixa.top)
          .toSet();
      expect(linhas.length, 2);
      expect(paragrafo.didExceedMaxLines, isFalse);
      final spans = (texto.textSpan! as TextSpan).children!;
      expect((spans.first as TextSpan).style?.fontWeight, FontWeight.bold);
      expect(tester.getSize(finder).height, greaterThan(20));
    }
    await tester.tap(find.text('Livre'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final cartoes = find.byKey(const ValueKey('disponibilidade_periodo'));
    final listasEsperadas = [
      '05/01/2026\n19/01/2026',
      '12/10/2026',
      '02/11/2026\n07/12/2026',
    ];
    for (var i = 0; i < 3; i++) {
      await tester.tap(cartoes.at(i));
      await tester.pumpAndSettle();
      expect(find.text('Livre · 08:00 – 10:00'), findsOneWidget);
      expect(find.text(listasEsperadas[i]), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Exceto: 09/11')),
          i == 2 ? findsOneWidget : findsNothing);
      expect(find.text('09/11/2026'), findsNothing);
      for (var outro = 0; outro < 3; outro++) {
        if (outro != i) expect(find.text(listasEsperadas[outro]), findsNothing);
      }
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
