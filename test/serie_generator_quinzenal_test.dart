import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/services/serie_generator.dart';
import 'package:mapa_gabinetes/utils/series_helper.dart';

void main() {
  final serie = SerieRecorrencia(
    id: 'quinzenal-2027',
    medicoId: 'medica',
    dataInicio: DateTime(2027, 1, 6),
    tipo: 'Quinzenal',
    horarios: ['09:00', '13:20'],
    gabineteId: '53',
  );
  final esperadas = [
    for (var dia = 6; dia <= 365; dia += 14) DateTime(2027, 1, dia),
  ];

  test('gera as 26 quartas-feiras de 2027 incluindo o horário de verão', () {
    final disponibilidades = SerieGenerator.gerarDisponibilidades(
      series: [serie],
      excecoes: [],
      dataInicio: DateTime(2027),
      dataFim: DateTime(2027, 12, 31),
    );
    expect(disponibilidades.map((d) => d.data), esperadas);
    final alocacoes = SerieGenerator.gerarAlocacoes(
      series: [serie],
      excecoes: [],
      dataInicio: DateTime(2027),
      dataFim: DateTime(2027, 12, 31),
    );
    expect(alocacoes.map((a) => a.data), esperadas);
  });

  test('consulta iniciada no verão mantém a primeira ocorrência', () {
    final disponibilidades = SerieGenerator.gerarDisponibilidades(
      series: [serie],
      excecoes: [],
      dataInicio: DateTime(2027, 3, 31),
      dataFim: DateTime(2027, 11, 10),
    );
    expect(
        disponibilidades.map((d) => d.data),
        esperadas.where((d) =>
            !d.isBefore(DateTime(2027, 3, 31)) &&
            !d.isAfter(DateTime(2027, 11, 10))));
  });

  test('validação da série usa dias de calendário e ignora horas', () {
    for (final data in esperadas) {
      expect(
          SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
              DateTime(data.year, data.month, data.day, 18), serie),
          isTrue);
    }
    expect(
        SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
            DateTime(2027, 4, 1), serie),
        isFalse);
  });
}
