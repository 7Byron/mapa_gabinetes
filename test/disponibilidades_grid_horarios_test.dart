import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/utils/horarios_disponibilidade_utils.dart';
import 'package:mapa_gabinetes/widgets/disponibilidades_grid.dart';

void main() {
  test('prepara horário por copy-on-write sem alterar a lista recebida', () {
    final horariosDaSerie = ['08:00', '20:00'];

    final inicioEditado = HorariosDisponibilidadeUtils.comHorarioAlterado(
      horariosAtuais: horariosDaSerie,
      novoHorario: '09:00',
      isInicio: true,
    );
    final fimEditado = HorariosDisponibilidadeUtils.comHorarioAlterado(
      horariosAtuais: horariosDaSerie,
      novoHorario: '18:00',
      isInicio: false,
    );

    expect(horariosDaSerie, ['08:00', '20:00']);
    expect(inicioEditado, ['09:00', '20:00']);
    expect(fimEditado, ['08:00', '18:00']);
    expect(identical(inicioEditado, horariosDaSerie), isFalse);
    expect(identical(fimEditado, horariosDaSerie), isFalse);
  });

  testWidgets('Apenas este dia não altera a série nem os cartões seguintes',
      (tester) async {
    final cenario = _CenarioSerie();
    ExcecaoSerie? excecaoGuardada;
    var atualizacoesDaSerie = 0;

    await _mostrarGrid(
      tester,
      cenario,
      onAtualizarSerie: (_, __) => atualizacoesDaSerie++,
      onAtualizarDataSerie: (disponibilidade, horarios) async {
        excecaoGuardada = ExcecaoSerie(
          id: 'excecao_1-9',
          serieId: cenario.serie.id,
          data: disponibilidade.data,
          horarios: horarios,
        );
        return excecaoGuardada!;
      },
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '08:00').first);
    await tester.pumpAndSettle();

    // A seleção da hora ainda não pode modificar a lista-base antes da escolha.
    expect(cenario.serie.horarios, ['08:00', '20:00']);
    expect(cenario.cartoes[1].horarios, ['08:00', '20:00']);

    await tester.tap(find.text('Apenas este dia'));
    await tester.pumpAndSettle();

    expect(cenario.cartoes[0].horarios, ['09:00', '20:00']);
    expect(cenario.cartoes[1].horarios, ['08:00', '20:00']);
    expect(cenario.serie.horarios, ['08:00', '20:00']);
    expect(identical(cenario.cartoes[0].horarios, excecaoGuardada!.horarios),
        isTrue);
    expect(atualizacoesDaSerie, 0);
  });

  testWidgets('Toda a série mantém uma única lista-base partilhada',
      (tester) async {
    final cenario = _CenarioSerie();
    var atualizacoesPontuais = 0;

    await _mostrarGrid(
      tester,
      cenario,
      onAtualizarSerie: (_, horarios) {
        cenario.serie.horarios = horarios;
      },
      onAtualizarDataSerie: (disponibilidade, horarios) async {
        atualizacoesPontuais++;
        return ExcecaoSerie(
          id: 'nao-deveria-ser-criada',
          serieId: cenario.serie.id,
          data: disponibilidade.data,
          horarios: horarios,
        );
      },
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '08:00').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toda a série'));
    await tester.pumpAndSettle();

    expect(cenario.serie.horarios, ['09:00', '20:00']);
    expect(cenario.cartoes[0].horarios, ['09:00', '20:00']);
    expect(cenario.cartoes[1].horarios, ['09:00', '20:00']);
    expect(
        identical(cenario.cartoes[0].horarios, cenario.serie.horarios), isTrue);
    expect(
        identical(cenario.cartoes[1].horarios, cenario.serie.horarios), isTrue);
    expect(atualizacoesPontuais, 0);
  });

  testWidgets('cartões distinguem várias séries do mesmo tipo pelo numeral',
      (tester) async {
    final serieI = SerieRecorrencia(
      id: 'serie_100',
      medicoId: 'medico_raquel',
      dataInicio: DateTime(2026, 9, 1),
      tipo: 'Semanal',
      horarios: ['08:00', '14:00'],
    )..numeroNoTipo = 1;
    final serieII = SerieRecorrencia(
      id: 'serie_200',
      medicoId: 'medico_raquel',
      dataInicio: DateTime(2026, 9, 4),
      tipo: 'Semanal',
      horarios: ['09:00', '18:00'],
    )..numeroNoTipo = 2;
    final cartoes = [
      Disponibilidade(
        id: 'serie_serie_100_2026-09-01',
        medicoId: serieI.medicoId,
        data: DateTime(2026, 9, 1),
        horarios: serieI.horarios,
        tipo: serieI.tipo,
      ),
      Disponibilidade(
        id: 'serie_serie_200_2026-09-04',
        medicoId: serieII.medicoId,
        data: DateTime(2026, 9, 4),
        horarios: serieII.horarios,
        tipo: serieII.tipo,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 399,
              height: 500,
              child: DisponibilidadesGrid(
                disponibilidades: cartoes,
                series: [serieI, serieII],
                onRemoverData: (_, __) {},
                onAtualizarDataSerie: (disponibilidade, horarios) async {
                  return ExcecaoSerie(
                    id: 'excecao-teste',
                    serieId: serieI.id,
                    data: disponibilidade.data,
                    horarios: horarios,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Série: Semanal I'), findsOneWidget);
    expect(find.text('Série: Semanal II'), findsOneWidget);
  });

  testWidgets('fechar a escolha de âmbito não altera cartão nem série',
      (tester) async {
    final cenario = _CenarioSerie();
    var gravacoes = 0;

    await _mostrarGrid(
      tester,
      cenario,
      onAtualizarSerie: (_, __) => gravacoes++,
      onAtualizarDataSerie: (disponibilidade, horarios) async {
        gravacoes++;
        return ExcecaoSerie(
          id: 'nao-deveria-ser-criada',
          serieId: cenario.serie.id,
          data: disponibilidade.data,
          horarios: horarios,
        );
      },
    );

    await tester.tap(find.widgetWithText(ElevatedButton, '08:00').first);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    expect(cenario.serie.horarios, ['08:00', '20:00']);
    expect(cenario.cartoes[0].horarios, ['08:00', '20:00']);
    expect(cenario.cartoes[1].horarios, ['08:00', '20:00']);
    expect(gravacoes, 0);
  });

  testWidgets('cartão único entrega horário anterior intacto à sincronização',
      (tester) async {
    final cartao = Disponibilidade(
      id: 'unica-luisa-2026-09-30',
      medicoId: 'luisa',
      data: DateTime(2026, 9, 30),
      horarios: ['08:00', '13:00'],
      tipo: 'Única',
    );
    List<String>? horarioAnteriorRecebido;
    List<String>? novoHorarioRecebido;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 399,
            height: 500,
            child: DisponibilidadesGrid(
              disponibilidades: [cartao],
              onRemoverData: (_, __) {},
              onAtualizarSerie: (disponibilidade, horarios) async {
                horarioAnteriorRecebido =
                    List<String>.from(disponibilidade.horarios);
                novoHorarioRecebido = List<String>.from(horarios);
              },
              onAtualizarDataSerie: (disponibilidade, horarios) async {
                throw StateError('Não deve criar exceção para cartão único');
              },
              mostrarSeletorHorario: (_) async =>
                  const TimeOfDay(hour: 13, minute: 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, '13:00'));
    await tester.pumpAndSettle();

    expect(horarioAnteriorRecebido, ['08:00', '13:00']);
    expect(novoHorarioRecebido, ['08:00', '13:30']);
    expect(cartao.horarios, ['08:00', '13:00']);
  });
}

class _CenarioSerie {
  _CenarioSerie()
      : serie = SerieRecorrencia(
          id: 'serie_raquel',
          medicoId: 'medico_raquel',
          dataInicio: DateTime(2026, 9, 1),
          tipo: 'Semanal',
          horarios: ['08:00', '20:00'],
        ) {
    cartoes = [
      Disponibilidade(
        id: 'serie_serie_raquel_2026-09-01',
        medicoId: serie.medicoId,
        data: DateTime(2026, 9, 1),
        horarios: serie.horarios,
        tipo: serie.tipo,
      ),
      Disponibilidade(
        id: 'serie_serie_raquel_2026-09-08',
        medicoId: serie.medicoId,
        data: DateTime(2026, 9, 8),
        horarios: serie.horarios,
        tipo: serie.tipo,
      ),
    ];
  }

  final SerieRecorrencia serie;
  late final List<Disponibilidade> cartoes;
}

Future<void> _mostrarGrid(
  WidgetTester tester,
  _CenarioSerie cenario, {
  required void Function(Disponibilidade, List<String>) onAtualizarSerie,
  required Future<ExcecaoSerie> Function(Disponibilidade, List<String>)
      onAtualizarDataSerie,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 399,
            height: 500,
            child: DisponibilidadesGrid(
              disponibilidades: cenario.cartoes,
              series: [cenario.serie],
              onRemoverData: (_, __) {},
              onAtualizarSerie: onAtualizarSerie,
              onAtualizarDataSerie: onAtualizarDataSerie,
              mostrarSeletorHorario: (_) async =>
                  const TimeOfDay(hour: 9, minute: 0),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
