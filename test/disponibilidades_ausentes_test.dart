import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/services/mapa_ausencias_service.dart';
import 'package:mapa_gabinetes/services/serie_generator.dart';
import 'package:mapa_gabinetes/widgets/disponibilidades_grid.dart';
import 'package:mapa_gabinetes/widgets/alocacao_card.dart';

void main() {
  final dia = DateTime(2026, 12, 16);
  final serie = SerieRecorrencia(
      id: 'serie_teste',
      medicoId: 'm',
      dataInicio: dia,
      tipo: 'Quinzenal',
      horarios: ['08:00', '15:00'],
      gabineteId: '50');
  final excecao = ExcecaoSerie(
      id: 'e',
      serieId: serie.id,
      data: dia,
      cancelada: true,
      gabineteId: '54',
      horarios: ['09:00', '14:00']);

  test(
      'Projeção recupera só as ocorrências canceladas e não altera os dados ativos',
      () {
    final outraExcecao = ExcecaoSerie(
        id: 'e2',
        serieId: serie.id,
        data: DateTime(2026, 12, 30),
        cancelada: true);
    final projecao = MapaAusenciasService.projetarCartoesAusentes(
        series: [serie], excecoes: [excecao, outraExcecao]);
    expect(projecao.disponibilidades.map((d) => d.data),
        [dia, DateTime(2026, 12, 30)]);
    expect(projecao.disponibilidades.first.horarios, ['09:00', '14:00']);
    expect(projecao.alocacoes.first.gabineteId, '54');
    expect(projecao.alocacoes.last.gabineteId, '50');
    expect(excecao.cancelada, isTrue);
    expect(
        SerieGenerator.gerarDisponibilidades(
            series: [serie],
            excecoes: [excecao],
            dataInicio: dia,
            dataFim: dia),
        isEmpty);
  });

  test('Ocorrência sem gabinete também fica visível como ausente', () {
    final semGabinete = SerieRecorrencia(
        id: 's',
        medicoId: 'm',
        dataInicio: dia,
        tipo: 'Única',
        horarios: ['08:00', '15:00']);
    final projecao = MapaAusenciasService.projetarCartoesAusentes(series: [
      semGabinete
    ], excecoes: [
      ExcecaoSerie(id: 'e', serieId: 's', data: dia, cancelada: true)
    ]);
    expect(projecao.disponibilidades.single.data, dia);
    expect(projecao.alocacoes, isEmpty);
  });

  testWidgets(
      'Ativo tem inativação no topo e remoção no canto inferior direito',
      (tester) async {
    final cartoes = SerieGenerator.gerarDisponibilidades(
        series: [serie], excecoes: [], dataInicio: dia, dataFim: dia);
    var inativacoes = 0;
    final terminar = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 399,
      child: DisponibilidadesGrid(
        disponibilidades: cartoes,
        series: [serie],
        onRemoverData: (_, __) => fail('Inativar não deve remover'),
        onAtualizarDataSerie: (_, __) async =>
            throw StateError('Não deve editar'),
        onInativar: (d) {
          expect(d.id, cartoes.single.id);
          inativacoes++;
          return terminar.future;
        },
      ),
    ))));
    expect(find.byTooltip('Inativar este cartão'), findsOneWidget);
    expect(find.byTooltip('Remover cartão'), findsOneWidget);
    final inativar = tester.getCenter(find.byTooltip('Inativar este cartão'));
    final remover = tester.getCenter(find.byTooltip('Remover cartão'));
    expect(remover.dy, greaterThan(inativar.dy));
    expect(remover.dx, closeTo(inativar.dx, 1));
    final card = tester.getRect(find.byType(Card));
    expect(card.right - remover.dx, lessThan(45));
    expect(card.bottom - remover.dy, lessThan(45));
    await tester.tap(find.byTooltip('Inativar este cartão'));
    await tester.pump();
    await tester.tap(find.byTooltip('Inativar este cartão'));
    expect(inativacoes, 1);
    terminar.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Ausente tem remoção independente da ativação e apagado não reaparece',
      (tester) async {
    var apagados = 0;
    final antigas = SerieGenerator.gerarDisponibilidades(
        series: [serie], excecoes: [], dataInicio: dia, dataFim: dia);
    Widget app(ExcecaoSerie excecao) => MaterialApp(
            home: Scaffold(
                body: SizedBox(
          width: 399,
          child: DisponibilidadesGrid(
            disponibilidades: antigas,
            series: [serie],
            excecoes: [excecao],
            onRemoverData: (_, __) => fail('Não deve alterar a série'),
            onAtualizarDataSerie: (_, __) async =>
                throw StateError('Não deve editar'),
            onReativar: (_) async => fail('Apagar não deve reativar'),
            onApagarAusente: (d) async {
              expect(d.id, antigas.single.id);
              apagados++;
            },
          ),
        )));
    await tester.pumpWidget(app(excecao));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ativar este cartão'), findsOneWidget);
    expect(find.byTooltip('Remover cartão'), findsOneWidget);
    expect(tester.getCenter(find.byTooltip('Remover cartão')).dy,
        greaterThan(tester.getCenter(find.byTooltip('Ativar este cartão')).dy));
    await tester.tap(find.byTooltip('Remover cartão'));
    await tester.pumpAndSettle();
    expect(apagados, 1);
    final apagada =
        ExcecaoSerie.fromMap({...excecao.toMap(), 'ocultarCartao': true});
    await tester.pumpWidget(app(apagada));
    await tester.pumpAndSettle();
    expect(find.byType(AlocacaoCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cartão cancelado fica cinzento e permite reativar sem duplicar',
      (tester) async {
    var reativacoes = 0;
    final terminar = Completer<void>();
    // Simula a cópia ativa ainda presente durante o refresh.
    final antigas = SerieGenerator.gerarDisponibilidades(
        series: [serie], excecoes: [], dataInicio: dia, dataFim: dia);
    final chave = GlobalKey();
    Widget app(List<ExcecaoSerie> excecoes) => MaterialApp(
            home: Scaffold(
          body: SizedBox(
              width: 399,
              child: DisponibilidadesGrid(
                key: chave,
                disponibilidades: antigas,
                series: [serie],
                excecoes: excecoes,
                gabinetes: [
                  Gabinete(
                      id: '54',
                      nome: '54',
                      setor: 'Piso 1',
                      especialidadesPermitidas: [])
                ],
                onRemoverData: (_, __) => fail('Não deve remover uma ausência'),
                onAtualizarDataSerie: (_, __) async =>
                    throw StateError('Não deve editar horas'),
                onReativar: (d) {
                  expect(d.id, antigas.single.id);
                  reativacoes++;
                  return terminar.future;
                },
              )),
        ));
    await tester.pumpWidget(app([excecao]));
    await tester.pumpAndSettle();
    expect(find.byType(AlocacaoCard), findsOneWidget);
    expect(find.textContaining('Ausente'), findsOneWidget);
    expect(find.text('Gab: 54'), findsOneWidget);
    expect(tester.widget<Card>(find.byType(Card)).color, Colors.grey.shade200);
    await tester.tap(find.textContaining('Ausente'));
    await tester.pump();
    await tester.tap(find.textContaining('Ausente'));
    expect(reativacoes, 1);
    terminar.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(app([]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ausente'), findsNothing);
    expect(find.byType(AlocacaoCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
