import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/services/mapa_ausencias_service.dart';
import 'package:mapa_gabinetes/services/serie_generator.dart';
import 'package:mapa_gabinetes/widgets/medico_card.dart';

void main() {
  test('Ausência preserva o cartão previsto sem reativar a consulta', () {
    final dia = DateTime(2026, 10, 15);
    final series = [
      SerieRecorrencia(
          id: 's1',
          medicoId: 'm1',
          dataInicio: dia,
          tipo: 'Semanal',
          horarios: ['09:00', '13:00'],
          gabineteId: 'g1'),
      SerieRecorrencia(
          id: 's2',
          medicoId: 'm1',
          dataInicio: dia,
          tipo: 'Semanal',
          horarios: ['14:00', '18:00'],
          gabineteId: 'g2'),
    ];
    final excecoes = [
      ExcecaoSerie(id: 'e1', serieId: 's1', data: dia, cancelada: true)
    ];
    final ausencias = MapaAusenciasService.gerar(
        series: series, excecoes: excecoes, data: dia);
    expect(ausencias.single.gabineteId, 'g1');
    expect(ausencias.single.horarioInicio, '09:00');
    final ativas = SerieGenerator.gerarAlocacoes(
        series: series, excecoes: excecoes, dataInicio: dia, dataFim: dia);
    expect(ativas.single.gabineteId, 'g2');
    expect(
        MapaAusenciasService.gerar(
            series: series, excecoes: excecoes, data: DateTime(2026, 10, 16)),
        isEmpty);
  });

  test(
      'Ausência substitui cópia ativa durante o refresh sem afetar outros cartões',
      () {
    Alocacao cartao(String id, {int dia = 15, String gabinete = 'g1'}) =>
        Alocacao(
            id: id,
            medicoId: 'm1',
            gabineteId: gabinete,
            data: DateTime(2026, 10, dia),
            horarioInicio: '08:00',
            horarioFim: '15:00');
    final ativoAntigo = cartao('s1');
    final ausente = cartao('s1', gabinete: 'g2');
    final outraSerie = cartao('s2');
    final outroDia = cartao('s1', dia: 22);
    final duranteRefresh = MapaAusenciasService.conciliar(
      alocacoes: [ativoAntigo, outraSerie, outroDia],
      ausencias: [ausente, ausente],
    );
    expect(duranteRefresh.ativas, [outraSerie, outroDia]);
    expect(duranteRefresh.ausencias, [ausente]);
    // A cópia ativa também deixa de participar nos conflitos do gabinete.
    expect(duranteRefresh.ativas.contains(ativoAntigo), isFalse);
    final depoisRefresh = MapaAusenciasService.conciliar(
      alocacoes: [outraSerie, outroDia],
      ausencias: [ausente],
    );
    expect(depoisRefresh.ativas, duranteRefresh.ativas);
    expect(depoisRefresh.ausencias, duranteRefresh.ausencias);
    final reativado = MapaAusenciasService.conciliar(
      alocacoes: [ativoAntigo, outraSerie, outroDia],
      ausencias: [],
    );
    expect(reativado.ativas, [ativoAntigo, outraSerie, outroDia]);
    expect(reativado.ausencias, isEmpty);
  });

  testWidgets('Cartão de ausência apresenta indicação e cor própria',
      (tester) async {
    final medico = Medico(
        id: 'm1',
        nome: 'Dra. Ana',
        especialidade: 'Clínica Geral',
        disponibilidades: [],
        ativo: true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 200,
      child: MedicoCard.buildSmallMedicoCard(
          medico, '09:00 - 13:00', Colors.white,
          ausente: true),
    ))));
    expect(find.text('Ausente'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Ausente')).style?.color,
        Colors.orange.shade800);
    expect(find.text('Dra. Ana'), findsOneWidget);
    final container = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) => c.decoration is BoxDecoration);
    expect((container.decoration as BoxDecoration).color, Colors.grey.shade200);
  });
}
