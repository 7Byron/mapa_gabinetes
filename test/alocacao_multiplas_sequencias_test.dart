import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/utils/alocacao_alocacoes_merge_utils.dart';
import 'package:mapa_gabinetes/utils/conflict_utils.dart';
import 'package:mapa_gabinetes/services/relatorios_service.dart';
import 'package:mapa_gabinetes/utils/alocacao_medicos_search_utils.dart';
import 'package:mapa_gabinetes/widgets/pesquisa_section.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/services/alocacao_serie_otimista_service.dart';
import 'package:mapa_gabinetes/services/alocacao_realocacao_otimista_service.dart';

Alocacao _alocacao({
  required String id,
  required String inicio,
  required String fim,
  String gabineteId = 'gab-1',
}) {
  return Alocacao(
    id: id,
    medicoId: 'medico-1',
    gabineteId: gabineteId,
    data: DateTime(2026, 7, 3),
    horarioInicio: inicio,
    horarioFim: fim,
  );
}

void main() {
  test('preserva duas sequências do mesmo médico no mesmo gabinete e dia', () {
    final resultado = AlocacaoAlocacoesMergeUtils.mesclarServidorComOtimistas(
      alocacoesServidor: [
        _alocacao(id: 'serie-a', inicio: '09:00', fim: '14:00'),
        _alocacao(id: 'serie-b', inicio: '16:00', fim: '20:00'),
      ],
      alocacoesLocais: const [],
      data: DateTime(2026, 7, 3),
    );

    expect(resultado, hasLength(2));
  });

  test('intervalos não sobrepostos no mesmo gabinete não criam conflito', () {
    final alocacoes = [
      _alocacao(id: 'serie-a', inicio: '09:00', fim: '14:00'),
      _alocacao(id: 'serie-b', inicio: '16:00', fim: '20:00'),
    ];

    expect(ConflictUtils.temConflitoGabinete(alocacoes), isFalse);
  });

  test('relatório de ocupação soma os dois cartões separados', () {
    final horas = RelatoriosService.calcularHorasOcupadasUnicas(
      [
        _alocacao(id: 'serie-a', inicio: '09:00', fim: '14:00'),
        _alocacao(id: 'serie-b', inicio: '16:00', fim: '20:00'),
      ],
      abertura: '08:00',
      fecho: '20:00',
    );

    expect(horas, 9.0);
  });

  test('relatório de ocupação não duplica horas sobrepostas', () {
    final horas = RelatoriosService.calcularHorasOcupadasUnicas(
      [
        _alocacao(id: 'serie-a', inicio: '09:00', fim: '14:00'),
        _alocacao(id: 'serie-b', inicio: '12:00', fim: '17:00'),
      ],
      abertura: '08:00',
      fecho: '20:00',
    );

    expect(horas, 8.0);
  });

  test('contador de destaque inclui os dois cartões do mesmo médico', () {
    final quantidade = AlocacaoMedicosSearchUtils.contarCartoesDestacados(
      alocacoes: [
        _alocacao(id: 'serie-a', inicio: '09:00', fim: '14:00'),
        _alocacao(id: 'serie-b', inicio: '16:00', fim: '20:00'),
      ],
      medicosDestacados: {'medico-1'},
      data: DateTime(2026, 7, 3),
    );

    expect(quantidade, 2);
  });

  test('alocação otimista de série usa apenas o horário arrastado', () {
    final alocacoes = <Alocacao>[];
    final medico = Medico(
      id: 'medico-1',
      nome: 'Teste',
      especialidade: 'Teste',
      disponibilidades: const [],
    );
    final disponibilidades = [
      Disponibilidade(
        id: 'serie_serie-a_2026-07-03',
        medicoId: medico.id,
        data: DateTime(2026, 7, 3),
        horarios: ['09:00', '12:00'],
        tipo: 'Semanal',
      ),
      Disponibilidade(
        id: 'serie_serie-b_2026-07-03',
        medicoId: medico.id,
        data: DateTime(2026, 7, 3),
        horarios: ['14:00', '20:00'],
        tipo: 'Semanal',
      ),
    ];

    AlocacaoSerieOtimistaService.aplicar(
      medicoId: medico.id,
      gabineteId: 'gab-1',
      data: DateTime(2026, 7, 3),
      horarios: const ['14:00', '20:00'],
      serieId: 'serie-b',
      medicos: [medico],
      medicosDisponiveis: [medico],
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
    );

    expect(alocacoes, hasLength(1));
    expect(alocacoes.single.horarioInicio, '14:00');
    expect(alocacoes.single.horarioFim, '20:00');
  });

  test('não fabrica alocação otimista 08:00-15:00 sem disponibilidade', () {
    final resultado = AlocacaoRealocacaoOtimistaService.atualizar(
      alocacoes: const [],
      disponibilidades: const [],
      medicoId: 'medico-1',
      gabineteOrigem: 'gab-origem',
      gabineteDestino: 'gab-destino',
      data: DateTime(2026, 9, 15),
    );

    expect(resultado.ignorar, isTrue);
    expect(resultado.alocacoesAtualizadas, isEmpty);
  });

  testWidgets('secção mostra terminologia e contador de destaque',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PesquisaSection(
              pesquisaNome: 'Florença Sepulveda',
              pesquisaEspecialidade: null,
              opcoesNome: const ['Florença Sepulveda'],
              opcoesEspecialidade: const ['Ginecologia'],
              cartoesDestacados: 2,
              onPesquisaNomeChanged: (_) {},
              onPesquisaEspecialidadeChanged: (_) {},
              onLimparPesquisa: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Destacar'), findsOneWidget);
    expect(find.text('Cartões destacados: 2'), findsOneWidget);
    expect(find.text('Limpar Destaque'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
