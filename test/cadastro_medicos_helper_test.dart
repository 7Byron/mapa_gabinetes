import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/services/disponibilidade_data_gestao_service.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/utils/cadastro_medicos_helper.dart';

void main() {
  test(
      'grava apenas cartões novos ou alterados, incluindo horários incompletos',
      () {
    Disponibilidade cartao(String id) => Disponibilidade(
          id: id,
          medicoId: 'luisa',
          data: DateTime(2026, 9, 23),
          horarios: ['08:00', '13:00'],
          tipo: 'Única',
        );
    final atuais = [cartao('inalterado'), cartao('alterado')];
    final originais =
        CadastroMedicosHelper.criarCopiaProfundaDisponibilidades(atuais);
    atuais[1].horarios[0] = '09:00';
    atuais.add(cartao('novo')..horarios = []);
    expect(
      CadastroMedicosHelper.disponibilidadesPendentes(atuais, originais)
          .map((d) => d.id),
      ['alterado', 'novo'],
    );
    expect(originais[1].horarios[0], '08:00');
    final guardados =
        CadastroMedicosHelper.criarCopiaProfundaDisponibilidades(atuais);
    expect(CadastroMedicosHelper.disponibilidadesPendentes(atuais, guardados),
        isEmpty);
  });

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

  test('cria e prepara três cartões do mesmo médico no mesmo dia', () {
    final cartoes = List.generate(
      3,
      (_) => DisponibilidadeDataGestaoService.criarDisponibilidadesUnicas(
        DateTime(2026, 9, 23),
        'Única',
        'luisa',
      ).single,
    );
    expect(cartoes.map((d) => d.id).toSet(), hasLength(3));
    final primeira =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
            cartoes, 'luisa');
    final segunda =
        CadastroMedicosHelper.prepararDisponibilidadesUnicasParaSalvar(
            cartoes, 'luisa');
    expect(primeira.map((d) => d.id).toSet(), hasLength(3));
    expect(segunda.map((d) => d.id), primeira.map((d) => d.id));
  });

  for (final modo in ['com séries', 'por ano', 'sem séries']) {
    test('recarregamento $modo preserva cartões distintos no mesmo dia', () {
      Disponibilidade cartao(String id, {String tipo = 'Única'}) =>
          Disponibilidade(
            id: id,
            medicoId: 'luisa',
            data: DateTime(2026, 9, 23),
            horarios: ['08:00', '13:00'],
            tipo: tipo,
          );
      final locais = [
        cartao('temp_novo'),
        cartao('guardado_1'),
        cartao('serie_semanal', tipo: 'Semanal')
      ];
      final remotos = [cartao('guardado_1'), cartao('guardado_2')];
      final resultado = switch (modo) {
        'com séries' =>
          CadastroMedicosHelper.mesclarDisponibilidadesPreservandoUnicas(
                  locais, remotos, 'luisa')
              .values
              .toList(),
        'por ano' => CadastroMedicosHelper.mesclarDisponibilidadesComAno(
                locais, [...remotos, locais.last], 'luisa', 2026)
            .values
            .toList(),
        _ =>
          CadastroMedicosHelper.mesclarApenasUnicas(locais, remotos, 'luisa'),
      };
      expect(
          resultado.map((d) => d.id),
          unorderedEquals(
              ['temp_novo', 'guardado_1', 'guardado_2', 'serie_semanal']));
      expect(
          resultado.firstWhere((d) => d.id == 'temp_novo'), same(locais.first));
    });
  }
}
