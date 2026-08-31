import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/utils/cadastro_medicos_helper.dart';

void main() {
  test('mantém ID permanente entre gravações de uma disponibilidade única', () {
    final disponibilidade = Disponibilidade(
      id: 'temp_cartao_23_9',
      medicoId: 'luisa',
      data: DateTime(2026, 9, 23),
      horarios: ['08:00', '13:30'],
      tipo: 'Única',
    );

    final primeiraPreparacao =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
      [disponibilidade],
      'luisa',
    );
    final idPermanente = primeiraPreparacao.single.id;

    expect(idPermanente, isNot(startsWith('temp_')));
    expect(disponibilidade.id, idPermanente);

    final segundaPreparacao =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
      [disponibilidade],
      'luisa',
    );

    expect(segundaPreparacao.single.id, idPermanente);
    expect(disponibilidade.id, idPermanente);
  });

  test('a cópia preparada não partilha a lista de horários com o ecrã', () {
    final disponibilidade = Disponibilidade(
      id: 'temp_cartao',
      medicoId: 'luisa',
      data: DateTime(2026, 9, 23),
      horarios: ['08:00', '13:30'],
      tipo: 'Única',
    );

    final preparada =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
      [disponibilidade],
      'luisa',
    ).single;
    preparada.horarios[1] = '14:00';

    expect(disponibilidade.horarios, ['08:00', '13:30']);
  });

  test('série semanal no mesmo dia não impede um cartão único', () {
    final disponibilidades = [
      Disponibilidade(
        id: 'serie_semanal_2026-08-31',
        medicoId: 'cristina',
        data: DateTime(2026, 8, 31),
        horarios: ['08:00', '13:00'],
        tipo: 'Semanal',
      ),
    ];

    expect(
      CadastroMedicosHelper.existeDisponibilidadeUnicaNaData(
        disponibilidades,
        'cristina',
        DateTime(2026, 8, 31),
      ),
      isFalse,
    );
  });

  test('outro cartão único do médico no mesmo dia continua bloqueado', () {
    final disponibilidades = [
      Disponibilidade(
        id: 'unica_2026-08-31',
        medicoId: 'cristina',
        data: DateTime(2026, 8, 31),
        horarios: ['16:00', '20:00'],
        tipo: 'Única',
      ),
      Disponibilidade(
        id: 'unica_outro_medico_2026-08-31',
        medicoId: 'raquel',
        data: DateTime(2026, 8, 31),
        horarios: ['09:00', '12:00'],
        tipo: 'Única',
      ),
    ];

    expect(
      CadastroMedicosHelper.existeDisponibilidadeUnicaNaData(
        disponibilidades,
        'cristina',
        DateTime(2026, 8, 31, 18, 30),
      ),
      isTrue,
    );
    expect(
      CadastroMedicosHelper.existeDisponibilidadeUnicaNaData(
        disponibilidades,
        'luisa',
        DateTime(2026, 8, 31),
      ),
      isFalse,
    );
  });
}
