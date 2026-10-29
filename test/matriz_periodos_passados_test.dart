import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';

void main() {
  for (final livres in [false, true]) {
    testWidgets('Períodos passados a cinzento: livres=$livres', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MatrizDistribuicaoGrid(
            dataReferencia: DateTime(2026, 10, 29, 15),
            mostrarLivres: livres,
            gabinetes: [
              Gabinete(
                  id: '1',
                  nome: '1',
                  setor: 'Piso 1',
                  especialidadesPermitidas: []),
            ],
            itens: [
              for (final dia in [28, 29, 30])
                MatrizDistribuicaoItem(
                  serieId: '$dia',
                  medicoId: '$dia',
                  medicoNome: 'Médico $dia',
                  especialidade: 'Especialidade',
                  gabineteId: '1',
                  tipo: 'Semanal',
                  ciclo: 'Período $dia',
                  dia: 1,
                  inicioMinutos: 480 + (dia - 28) * 60,
                  fimMinutos: 540 + (dia - 28) * 60,
                  ocorrencias: {DateTime.utc(2026, 10, dia)},
                ),
            ],
          ),
        ),
      ));
      for (final dia in [28, 29, 30]) {
        final texto = find.text(livres ? 'Livre' : 'Médico $dia');
        final alvo = livres
            ? find.byWidgetPredicate(
                (w) => w is Text && w.textSpan?.toPlainText() == 'Período $dia')
            : texto;
        expect(find.ancestor(of: alvo, matching: find.byType(ColorFiltered)),
            dia < 29 ? findsOneWidget : findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
