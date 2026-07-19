import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/utils/proxima_consulta_utils.dart';

void main() {
  final medicos = [
    Medico(
      id: '1',
      nome: 'Dr. Francisco',
      especialidade: 'MGF',
      disponibilidades: const [],
    ),
    Medico(
      id: '2',
      nome: 'Dra. Marlene',
      especialidade: 'MGF',
      disponibilidades: const [],
    ),
  ];

  Alocacao alocacao(String id, String medicoId, DateTime data, String inicio) {
    return Alocacao(
      id: id,
      medicoId: medicoId,
      gabineteId: 'gab-1',
      data: data,
      horarioInicio: inicio,
      horarioFim: '20:00',
    );
  }

  test('encontra e ordena as próximas cinco consultas da especialidade', () {
    final resultado = ProximaConsultaUtils.encontrar(
      medicos: medicos,
      desde: DateTime(2026, 7, 19, 15),
      especialidade: 'MGF',
      alocacoes: [
        alocacao('6', '1', DateTime(2026, 7, 25), '09:00'),
        alocacao('2', '2', DateTime(2026, 7, 20), '14:00'),
        alocacao('1', '1', DateTime(2026, 7, 19), '10:40'),
        alocacao('3', '1', DateTime(2026, 7, 21), '08:00'),
        alocacao('4', '2', DateTime(2026, 7, 22), '08:00'),
        alocacao('5', '1', DateTime(2026, 7, 23), '08:00'),
        alocacao('antiga', '1', DateTime(2026, 7, 18), '08:00'),
      ],
    );

    expect(resultado, hasLength(5));
    expect(resultado.first.alocacao.id, '1');
    expect(resultado.last.alocacao.id, '5');
  });

  test('filtra pelo médico escolhido', () {
    final resultado = ProximaConsultaUtils.encontrar(
      medicos: medicos,
      desde: DateTime(2026, 7, 19),
      medicoId: '2',
      alocacoes: [
        alocacao('francisco', '1', DateTime(2026, 7, 20), '09:00'),
        alocacao('marlene', '2', DateTime(2026, 7, 21), '09:00'),
      ],
    );

    expect(resultado.single.medico.nome, 'Dra. Marlene');
  });
}
