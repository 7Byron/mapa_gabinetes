import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';
import 'package:mapa_gabinetes/widgets/horario_abertura_quadro.dart';

void main() {
  for (final (largura, escala) in [(390.0, 1.0), (875.0, 1.0), (390.0, 1.8)]) {
    testWidgets('Horários completos sem overflow a $largura / $escala',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(largura, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? diaEscolhido;
      bool? abertura;
      int? apagado;
      bool? feriados;
      bool? nunca;
      await tester.pumpWidget(MaterialApp(
        theme: MyAppTheme.claro,
        home: Scaffold(
            body: MediaQuery(
          data: MediaQueryData(
              size: Size(largura, 1000), textScaler: TextScaler.linear(escala)),
          child: SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: HorarioAberturaQuadro(
              horarios: {
                for (var dia = 1; dia <= 7; dia++) dia: ['08:00', '20:00']
              },
              diasSemana: const [
                '2ª feira',
                '3ª feira',
                '4ª feira',
                '5ª feira',
                '6ª feira',
                'Sábado',
                'Domingo'
              ],
              nuncaEncerra: false,
              encerraDias: const {},
              encerraFeriados: false,
              onNuncaEncerraChanged: (v) => nunca = v,
              onFeriadosChanged: (v) => feriados = v,
              onEncerradoChanged: (_, __) {},
              onEscolherHora: (dia, inicio) {
                diaEscolhido = dia;
                abertura = inicio;
              },
              onApagar: (dia) => apagado = dia,
            ),
          )),
        )),
      ));
      await tester.pumpAndSettle();
      for (final texto in ['08:00', '20:00']) {
        for (final finder in find.text(texto).evaluate()) {
          final paragrafo = tester.renderObject<RenderParagraph>(find
              .descendant(
                  of: find.byWidget(finder.widget),
                  matching: find.byType(RichText))
              .first);
          expect(paragrafo.didExceedMaxLines, false);
          final caixas = paragrafo.getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 5));
          expect(caixas.map((c) => c.top).toSet().length, 1);
        }
      }
      await tester.tap(find.text('08:00').first);
      expect((diaEscolhido, abertura), (1, true));
      final horizontal = find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
      await tester.drag(horizontal, const Offset(-900, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpar horários de 2ª feira'));
      expect(apagado, 1);
      final checkboxFeriados = find.byWidgetPredicate(
          (w) => w is Checkbox && w.semanticLabel == 'Feriados encerrados');
      await tester.ensureVisible(checkboxFeriados);
      await tester.tap(checkboxFeriados);
      expect(feriados, true);
      await tester.ensureVisible(find.text('Nunca encerra'));
      await tester.tap(find.text('Nunca encerra'));
      expect(nunca, true);
      expect(tester.takeException(), isNull);
    });
  }
}
