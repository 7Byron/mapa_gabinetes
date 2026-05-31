import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/utils/text_search_utils.dart';

void main() {
  group('TextSearchUtils.matchesAllTerms', () {
    test('encontra nome pelo segundo nome', () {
      expect(
        TextSearchUtils.matchesAllTerms(
          'Rita',
          ['Ana Rita Fradinho', 'Medicina Dentaria'],
        ),
        isTrue,
      );
    });

    test('encontra nome por multiplas palavras fora do inicio', () {
      expect(
        TextSearchUtils.matchesAllTerms(
          'Rita Fradinho',
          ['Ana Rita Fradinho Silva', 'Medicina Dentaria'],
        ),
        isTrue,
      );
    });

    test('aceita termos parciais e ignora acentos', () {
      expect(
        TextSearchUtils.matchesAllTerms(
          'rita dent',
          ['Ana Rita Fradinho', 'Medicina Dentária'],
        ),
        isTrue,
      );
    });

    test('exige que todos os termos existam', () {
      expect(
        TextSearchUtils.matchesAllTerms(
          'Rita Cardiologia',
          ['Ana Rita Fradinho', 'Medicina Dentaria'],
        ),
        isFalse,
      );
    });
  });
}
