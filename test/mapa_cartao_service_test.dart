import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/mapa_cartao_service.dart';
import 'package:mapa_gabinetes/services/mapa_ausencias_service.dart';
import 'package:mapa_gabinetes/services/serie_generator.dart';

void main() {
  final dia = DateTime(2026, 10, 15);
  final series = [
    for (final id in ['s1', 's2'])
      SerieRecorrencia(
          id: id,
          medicoId: 'm',
          dataInicio: dia,
          tipo: 'Semanal',
          horarios: ['09:00', '13:00'],
          gabineteId: 'g1'),
  ];
  test('Inativar uma ocorrência preserva outra série e a semana seguinte', () {
    final cancelada = MapaCartaoService.alterarExcecao(
        excecao: ExcecaoSerie(id: 'e', serieId: 's1', data: dia),
        ausente: true)!;
    final alocacoes = SerieGenerator.gerarAlocacoes(
        series: series,
        excecoes: [cancelada],
        dataInicio: dia,
        dataFim: dia.add(const Duration(days: 7)));
    expect(alocacoes.length, 3);
    expect(alocacoes.where((a) => a.data == dia).length, 1);
    expect(
        alocacoes
            .where((a) => a.data == dia.add(const Duration(days: 7)))
            .length,
        2);
    expect(
        MapaAusenciasService.gerar(
                series: series, excecoes: [cancelada], data: dia)
            .length,
        1);
    expect(MapaCartaoService.alterarExcecao(excecao: cancelada, ausente: false),
        isNull);
  });

  test(
      'Apagar uma ausência mantém o cancelamento mas retira os cartões visuais',
      () {
    final apagada = MapaCartaoService.alterarExcecao(
        excecao:
            ExcecaoSerie(id: 'e', serieId: 's1', data: dia, cancelada: true),
        ausente: true,
        ocultarCartao: true)!;
    final guardada = ExcecaoSerie.fromMap(apagada.toMap());
    expect(guardada.cancelada, isTrue);
    expect(guardada.ocultarCartao, isTrue);
    expect(
        ExcecaoSerie.fromMap({'id': 'antiga', 'data': dia.toIso8601String()})
            .ocultarCartao,
        isFalse);
    expect(
        MapaAusenciasService.gerar(
            series: series, excecoes: [guardada], data: dia),
        isEmpty);
    expect(
        MapaAusenciasService.projetarCartoesAusentes(
            series: series, excecoes: [guardada]).disponibilidades,
        isEmpty);
    final ativas = SerieGenerator.gerarAlocacoes(
        series: series,
        excecoes: [guardada],
        dataInicio: dia,
        dataFim: dia.add(const Duration(days: 7)));
    expect(ativas.where((a) => a.data == dia).length, 1);
    expect(
        ativas.where((a) => a.data == dia.add(const Duration(days: 7))).length,
        2);
  });

  test('Ausência e reativação preservam gabinete e horas da exceção', () {
    final original = ExcecaoSerie(
        id: 'e',
        serieId: 's1',
        data: dia,
        horarios: ['14:40', '18:00'],
        gabineteId: 'g2');
    final cancelada =
        MapaCartaoService.alterarExcecao(excecao: original, ausente: true)!;
    expect(original.cancelada, isFalse);
    final ausente = MapaAusenciasService.gerar(
            series: series, excecoes: [cancelada], data: dia)
        .single;
    expect(ausente.gabineteId, 'g2');
    expect(ausente.horarioInicio, '14:40');
    expect(ausente.horarioFim, '18:00');
    final reativada =
        MapaCartaoService.alterarExcecao(excecao: cancelada, ausente: false)!;
    expect(reativada.cancelada, isFalse);
    final ativas = SerieGenerator.gerarAlocacoes(
        series: [series.first],
        excecoes: [reativada],
        dataInicio: dia,
        dataFim: dia);
    expect(ativas.single.gabineteId, 'g2');
    expect(ativas.single.horarioInicio, '14:40');
    expect(ativas.single.horarioFim, '18:00');
  });
}
