import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/serie_recorrencia.dart';
import 'package:mapa_gabinetes/utils/serie_numeracao_utils.dart';

void main() {
  test('migra séries antigas pela ordem estável do ID dentro de cada tipo', () {
    final semanalIII = _serie('serie_300', 'Semanal');
    final mensalI = _serie('serie_150', 'Mensal');
    final semanalI = _serie('serie_100', 'Semanal');
    final semanalII = _serie('serie_200', 'Semanal');
    final series = [semanalIII, mensalI, semanalI, semanalII];

    final alteradas = SerieNumeracaoUtils.numerarSeriesSemNumero(series);

    expect(alteradas, hasLength(4));
    expect(semanalI.numeroNoTipo, 1);
    expect(semanalII.numeroNoTipo, 2);
    expect(semanalIII.numeroNoTipo, 3);
    expect(mensalI.numeroNoTipo, 1);
  });

  test('preserva números existentes e usa o seguinte sem renumerar', () {
    final existente = _serie('serie_100', 'Semanal')..numeroNoTipo = 2;
    final antigaSemNumero = _serie('serie_200', 'Semanal');

    final alteradas = SerieNumeracaoUtils.numerarSeriesSemNumero(
      [existente, antigaSemNumero],
    );

    expect(existente.numeroNoTipo, 2);
    expect(antigaSemNumero.numeroNoTipo, 3);
    expect(alteradas, [antigaSemNumero]);
    expect(
      SerieNumeracaoUtils.proximoNumero(
        'Semanal',
        [existente, antigaSemNumero],
      ),
      4,
    );
  });

  test('mostra numeral apenas quando há várias séries do mesmo tipo', () {
    final semanalI = _serie('serie_100', 'Semanal')..numeroNoTipo = 1;
    final semanalII = _serie('serie_200', 'Semanal')..numeroNoTipo = 2;
    final mensalI = _serie('serie_300', 'Mensal')..numeroNoTipo = 1;
    final series = [semanalI, semanalII, mensalI];

    expect(SerieNumeracaoUtils.rotulo(semanalI, series), 'Semanal I');
    expect(SerieNumeracaoUtils.rotulo(semanalII, series), 'Semanal II');
    expect(SerieNumeracaoUtils.rotulo(mensalI, series), 'Mensal');
  });

  test('serialização mantém a numeração dentro dos parâmetros', () {
    final original = _serie('serie_100', 'Semanal')..numeroNoTipo = 4;

    final recarregada = SerieRecorrencia.fromMap(original.toMap());

    expect(recarregada.numeroNoTipo, 4);
    expect(SerieNumeracaoUtils.paraRomano(4), 'IV');
  });
}

SerieRecorrencia _serie(String id, String tipo) {
  return SerieRecorrencia(
    id: id,
    medicoId: 'medico-1',
    dataInicio: DateTime(2026, 1, 1),
    tipo: tipo,
    horarios: ['08:00', '20:00'],
  );
}
