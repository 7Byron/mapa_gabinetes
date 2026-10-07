import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/models/taxa_ocupacao.dart';
import 'package:mapa_gabinetes/services/relatorios_service.dart';

void main() {
  Alocacao alocacao(String inicio, String fim) => Alocacao(
        id: inicio,
        medicoId: inicio,
        gabineteId: '1',
        data: DateTime(2026, 10, 5),
        horarioInicio: inicio,
        horarioFim: fim,
      );

  test('Ocupação conta a união e limita ao horário de abertura', () {
    final horas = RelatoriosService.calcularHorasOcupadasUnicas(
      [
        alocacao('07:00', '10:00'),
        alocacao('09:00', '12:00'),
        alocacao('19:00', '22:00')
      ],
      abertura: '08:00',
      fecho: '20:00',
    );
    expect(horas, 5);
    expect(TaxaOcupacao(horasOcupadas: horas, horasDisponiveis: 12).percentagem,
        closeTo(41.6667, 0.0001));
  });

  test('Preserva intervalos separados e o horário reduzido de sábado', () {
    expect(
        RelatoriosService.calcularHorasOcupadasUnicas(
          [alocacao('08:00,10:00,11:00,14:00', '')],
          abertura: '08:00',
          fecho: '13:00',
        ),
        4);
  });

  test('Geral divide horas ocupadas pela capacidade de todos os gabinetes', () {
    const ocupado = TaxaOcupacao(horasOcupadas: 12, horasDisponiveis: 12);
    const vazio = TaxaOcupacao(horasDisponiveis: 12);
    expect(ocupado.somar(vazio).percentagem, 50);
    expect(const TaxaOcupacao().percentagem, 0);
  });
}
