import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/utils/alocacao_disponibilidade_validacao_utils.dart';

Disponibilidade _disponibilidade({
  required String id,
  required String inicio,
  required String fim,
  String medicoId = 'graca-santos',
  String tipo = 'Única',
}) {
  return Disponibilidade(
    id: id,
    medicoId: medicoId,
    data: DateTime(2026, 9, 15),
    horarios: [inicio, fim],
    tipo: tipo,
  );
}

Alocacao _alocacao({
  required String id,
  required String inicio,
  required String fim,
  required String gabineteId,
  String medicoId = 'graca-santos',
}) {
  return Alocacao(
    id: id,
    medicoId: medicoId,
    gabineteId: gabineteId,
    data: DateTime(2026, 9, 15),
    horarioInicio: inicio,
    horarioFim: fim,
  );
}

void main() {
  test('remove o cartão órfão e preserva a alocação correspondente', () {
    final orfas = <Alocacao>[];
    final resultado =
        AlocacaoDisponibilidadeValidacaoUtils.filtrarOrfasConfirmadas(
      disponibilidades: [
        _disponibilidade(id: 'disp-correta', inicio: '09:00', fim: '14:00'),
      ],
      alocacoes: [
        _alocacao(
          id: 'aloc-correta',
          inicio: '09:00',
          fim: '14:00',
          gabineteId: '8',
        ),
        _alocacao(
          id: 'aloc-fantasma',
          inicio: '08:00',
          fim: '15:00',
          gabineteId: '15',
        ),
      ],
      onOrfaEncontrada: orfas.add,
    );

    expect(resultado.map((a) => a.id), ['aloc-correta']);
    expect(orfas.map((a) => a.id), ['aloc-fantasma']);
  });

  test('preserva vários cartões válidos do mesmo médico e dia', () {
    final resultado =
        AlocacaoDisponibilidadeValidacaoUtils.filtrarOrfasConfirmadas(
      disponibilidades: [
        _disponibilidade(id: 'disp-1', inicio: '09:00', fim: '14:00'),
        _disponibilidade(id: 'disp-2', inicio: '16:00', fim: '20:00'),
      ],
      alocacoes: [
        _alocacao(
          id: 'aloc-1',
          inicio: '09:00',
          fim: '14:00',
          gabineteId: '8',
        ),
        _alocacao(
          id: 'aloc-2',
          inicio: '16:00',
          fim: '20:00',
          gabineteId: '15',
        ),
      ],
    );

    expect(resultado, hasLength(2));
  });

  test('preserva conservadoramente alocação quando o médico não foi carregado',
      () {
    final resultado =
        AlocacaoDisponibilidadeValidacaoUtils.filtrarOrfasConfirmadas(
      disponibilidades: [
        _disponibilidade(
          id: 'outro-medico',
          inicio: '09:00',
          fim: '14:00',
          medicoId: 'outro',
        ),
      ],
      alocacoes: [
        _alocacao(
          id: 'aloc-sem-leitura',
          inicio: '08:00',
          fim: '15:00',
          gabineteId: '15',
        ),
      ],
    );

    expect(resultado.map((a) => a.id), ['aloc-sem-leitura']);
  });

  test('normaliza horas equivalentes antes de comparar', () {
    final resultado =
        AlocacaoDisponibilidadeValidacaoUtils.filtrarOrfasConfirmadas(
      disponibilidades: [
        _disponibilidade(id: 'disp', inicio: '9:00', fim: '14:00'),
      ],
      alocacoes: [
        _alocacao(
          id: 'aloc',
          inicio: '09:00',
          fim: '14:00',
          gabineteId: '8',
        ),
      ],
    );

    expect(resultado, hasLength(1));
  });

  test('reconcilia um único cartão mantendo id e gabinete da alocação', () {
    final correcoes = AlocacaoDisponibilidadeValidacaoUtils
        .encontrarCorrecoesInequivocasDeCartoesUnicos(
      disponibilidades: [
        _disponibilidade(id: 'disp-luisa', inicio: '08:00', fim: '13:30'),
      ],
      alocacoes: [
        _alocacao(
          id: 'aloc-luisa',
          inicio: '08:00',
          fim: '13:00',
          gabineteId: '4',
        ),
      ],
    );

    expect(correcoes, hasLength(1));
    expect(correcoes.single.atualizada.id, 'aloc-luisa');
    expect(correcoes.single.atualizada.gabineteId, '4');
    expect(correcoes.single.atualizada.horarioInicio, '08:00');
    expect(correcoes.single.atualizada.horarioFim, '13:30');
  });

  test('não tenta reconciliar quando existem várias alocações no dia', () {
    final correcoes = AlocacaoDisponibilidadeValidacaoUtils
        .encontrarCorrecoesInequivocasDeCartoesUnicos(
      disponibilidades: [
        _disponibilidade(id: 'disp', inicio: '09:00', fim: '14:00'),
      ],
      alocacoes: [
        _alocacao(
          id: 'correta',
          inicio: '09:00',
          fim: '14:00',
          gabineteId: '8',
        ),
        _alocacao(
          id: 'fantasma',
          inicio: '08:00',
          fim: '15:00',
          gabineteId: '15',
        ),
      ],
    );

    expect(correcoes, isEmpty);
  });

  test('deteta também uma série de ocorrência única sombreada', () {
    final correcoes = AlocacaoDisponibilidadeValidacaoUtils
        .encontrarCorrecoesInequivocasDeCartoesUnicos(
      disponibilidades: [
        _disponibilidade(
          id: 'serie_1_2026-09-15',
          inicio: '08:00',
          fim: '13:30',
          tipo: 'Única',
        ),
      ],
      alocacoes: [
        _alocacao(
          id: 'serie_serie_1_2026-09-15',
          inicio: '08:00',
          fim: '13:00',
          gabineteId: '4',
        ),
      ],
    );

    expect(correcoes, hasLength(1));
    expect(correcoes.single.atualizada.horarioFim, '13:30');
  });
}
