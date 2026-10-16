import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/excecao_serie.dart';

void main() {
  final inicio = DateTime(2026, 10, 28, 14);
  bool substituir(ExcecaoSerie e) => e.deveSubstituirGabineteNaRealocacao(
        serieId: 'semanal',
        dataRef: inicio,
        gabineteDestino: '28',
      );
  ExcecaoSerie excecao(DateTime data,
          {String serie = 'semanal', String? gabinete = '23'}) =>
      ExcecaoSerie(
          id: 'excecao', serieId: serie, data: data, gabineteId: gabinete);

  test('inclui o próprio dia, novembro, dezembro e anos seguintes', () {
    for (final data in [
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 4),
      DateTime(2026, 12, 2),
      DateTime(2027, 1, 6)
    ]) {
      expect(substituir(excecao(data)), isTrue);
    }
  });
  test('preserva datas anteriores e outras séries do mesmo médico', () {
    expect(substituir(excecao(DateTime(2026, 10, 21))), isFalse);
    expect(substituir(excecao(inicio, serie: 'quinzenal')), isFalse);
  });
  test('inclui exceções sem gabinete e ignora gabinetes já corretos', () {
    expect(substituir(excecao(inicio, gabinete: null)), isTrue);
    expect(substituir(excecao(inicio, gabinete: '28')), isFalse);
  });
  test('a ausência e o horário não impedem a atualização do gabinete', () {
    final ausente = excecao(DateTime(2026, 12, 16))
      ..cancelada = true
      ..ocultarCartao = true
      ..horarios = ['15:00', '17:00'];
    expect(substituir(ausente), isTrue);
    expect(ausente.cancelada, isTrue);
    expect(ausente.ocultarCartao, isTrue);
    expect(ausente.horarios, ['15:00', '17:00']);
  });
}
