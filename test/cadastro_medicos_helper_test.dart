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
}
