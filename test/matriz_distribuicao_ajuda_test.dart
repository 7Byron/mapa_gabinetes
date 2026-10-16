import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_ajuda.dart';

void main() {
  MatrizDistribuicaoItem item(DateTime inicio, DateTime fim) =>
      MatrizDistribuicaoItem(
          serieId: 's',
          medicoId: 'm',
          medicoNome: 'Teste',
          especialidade: 'Teste',
          gabineteId: '21',
          tipo: 'Semanal',
          ciclo: 'Semanal',
          dia: 1,
          inicioMinutos: 540,
          fimMinutos: 720,
          validadeInicio: inicio,
          validadeFim: fim);

  test(
      'períodos anuais, iniciais, finais e interiores usam a indicação adequada',
      () {
    expect(item(DateTime(2027), DateTime(2027, 12, 31)).periodo, isNull);
    expect(
        item(DateTime(2027), DateTime(2027, 2, 3)).periodo, 'Até 03/02/2027');
    expect(item(DateTime(2027, 6, 5), DateTime(2027, 12, 31)).periodo,
        'A partir de 05/06/2027');
    expect(item(DateTime(2027, 6, 5), DateTime(2027, 9, 20)).periodo,
        'De 05/06/2027 a 20/09/2027');
    expect(item(DateTime(2027), DateTime(2028, 12, 31)).periodo,
        'De 01/01/2027 a 31/12/2028');
  });
  for (final tamanho in [const Size(1200, 900), const Size(390, 600)]) {
    testWidgets('abre e fecha ajuda com conteúdo acessível a ${tamanho.width}',
        (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              appBar: AppBar(
                  title: const Text('Matriz de Distribuição'),
                  actions: const [MatrizDistribuicaoAjuda()]))));
      await tester.tap(find.byTooltip('Como funciona a matriz'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Não inclui cartões únicos'), findsOneWidget);
      expect(find.textContaining('As mudanças de gabinete da série'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
