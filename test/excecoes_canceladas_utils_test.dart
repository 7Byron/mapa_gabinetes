import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/alocacao_medicos_disponiveis_service.dart';
import 'package:mapa_gabinetes/services/serie_generator.dart';
import 'package:mapa_gabinetes/utils/alocacao_cache_store.dart';
import 'package:mapa_gabinetes/utils/excecoes_canceladas_utils.dart';

void main() {
  final dia = DateTime(2026, 9, 22);
  final cancelamentos = {
    ExcecoesCanceladasUtils.chave('medico-1', 'serie_100', dia),
  };
  final medico = Medico(
    id: 'medico-1',
    nome: 'Médica de teste',
    especialidade: 'Nutrição',
    disponibilidades: [],
  );
  final series = [
    SerieRecorrencia(
      id: 'serie_100',
      medicoId: medico.id,
      dataInicio: dia,
      tipo: 'Semanal',
      horarios: ['09:00', '20:00'],
      gabineteId: '309',
    ),
    SerieRecorrencia(
      id: 'serie_200',
      medicoId: medico.id,
      dataInicio: dia,
      tipo: 'Quinzenal',
      horarios: ['09:00', '13:30'],
      gabineteId: '309',
    ),
  ];
  final excecoes = [
    ExcecaoSerie(
      id: 'cancelamento',
      serieId: 'serie_100',
      data: dia,
      cancelada: true,
    ),
  ];

  tearDown(AlocacaoCacheStore.clearAll);

  test('cancelamento identifica a série, o médico e o dia exatos', () {
    bool cancelada(String id, {String medicoId = 'medico-1', DateTime? data}) =>
        ExcecoesCanceladasUtils.contem(
            cancelamentos, medicoId, id, data ?? dia);

    expect(cancelada('serie_serie_100_2026-09-22'), isTrue);
    expect(cancelada('serie_100_2026-09-22'), isTrue);
    expect(cancelada('serie_serie_200_2026-09-22'), isFalse);
    expect(cancelada('serie_serie_1000_2026-09-22'), isFalse);
    expect(cancelada('unica_2026-09-22'), isFalse);
    expect(cancelada('serie_100_2026-09-22', medicoId: 'outro'), isFalse);
    expect(cancelada('serie_100_2026-09-29', data: DateTime(2026, 9, 29)),
        isFalse);
    expect(cancelada('serie_100_2026-09-22', data: DateTime(2026, 9, 22, 9)),
        isTrue);
  });

  test('cancelar série semanal preserva quinzenal no gabinete 309', () {
    final alocacoes = SerieGenerator.gerarAlocacoes(
      series: series,
      excecoes: excecoes,
      dataInicio: dia,
      dataFim: dia.add(const Duration(days: 1)),
    )
        .where((a) => !ExcecoesCanceladasUtils.contem(
            cancelamentos, a.medicoId, a.id, a.data))
        .toList();

    expect(alocacoes, hasLength(1));
    expect(alocacoes.single.gabineteId, '309');
    expect(alocacoes.single.horarioInicio, '09:00');
    expect(alocacoes.single.horarioFim, '13:30');
  });

  test('série válida sem alocação mantém médica na lista por alocar', () async {
    AlocacaoCacheStore.updateExcecoesCanceladasParaDia(dia, cancelamentos);
    final disponibilidades = SerieGenerator.gerarDisponibilidades(
      series: series,
      excecoes: excecoes,
      dataInicio: dia,
      dataFim: dia.add(const Duration(days: 1)),
    );
    expect(disponibilidades, hasLength(1));
    final resultado = await AlocacaoMedicosDisponiveisService.calcular(
      medicos: [medico],
      disponibilidades: disponibilidades,
      alocacoes: [],
      unidadeId: 'unidade-teste',
      data: dia,
    );
    expect(resultado, [medico]);
  });

  test('série cancelada não reaparece por alocar a partir de cartão antigo',
      () async {
    AlocacaoCacheStore.updateExcecoesCanceladasParaDia(dia, cancelamentos);
    final disponibilidades = SerieGenerator.gerarDisponibilidades(
      series: [series.first],
      excecoes: [],
      dataInicio: dia,
      dataFim: dia.add(const Duration(days: 1)),
    );
    final resultado = await AlocacaoMedicosDisponiveisService.calcular(
      medicos: [medico],
      disponibilidades: disponibilidades,
      alocacoes: [],
      unidadeId: 'unidade-teste',
      data: dia,
    );
    expect(resultado, isEmpty);
  });
}
