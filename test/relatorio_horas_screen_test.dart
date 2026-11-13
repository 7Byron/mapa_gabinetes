import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/screens/relatorio_horas_especialidade_screen.dart';
import 'package:mapa_gabinetes/services/relatorio_horas_especialidade_service.dart';

class _Service extends RelatorioHorasEspecialidadeService {
  final chamadas = <({
    Set<String>? medicoIds,
    Set<String>? especialidades,
    DateTime inicio,
    DateTime fim
  })>[];

  @override
  Future<List<Medico>> carregarMedicos(
          {required Unidade unidade, bool forcarServidor = false}) async =>
      [
        Medico(
            id: 'ana',
            nome: 'Ana João',
            especialidade: 'Cardiologia',
            disponibilidades: []),
        Medico(
            id: 'rui',
            nome: 'Rui Silva',
            especialidade: 'ORL',
            disponibilidades: []),
        Medico(
            id: 'inativo',
            nome: 'Inativo',
            especialidade: 'ORL',
            disponibilidades: [],
            ativo: false),
      ];

  @override
  Future<String> obterVersaoCache({required Unidade unidade}) async => '1';

  @override
  Future<RelatorioHorasEspecialidade> calcular({
    required Unidade unidade,
    required DateTime inicio,
    required DateTime fim,
    bool forcarServidor = false,
    Set<String>? especialidades,
    Set<String>? medicoIds,
    void Function(double, String)? onProgress,
  }) async {
    chamadas.add((
      medicoIds: medicoIds,
      especialidades: especialidades,
      inicio: inicio,
      fim: fim
    ));
    return RelatorioHorasEspecialidade(
      inicio: inicio,
      fim: fim,
      totalHorasConsultaClinica: 7.5,
      totalMedicosAtivosClinica: 2,
      especialidadesClinica: const {
        'Cardiologia': RelatorioHorasEspecialidadeLinha(
            especialidade: 'Cardiologia',
            medicosAtivos: 1,
            medicosComDisponibilidade: 1,
            horasConsulta: 7.5),
        'ORL': RelatorioHorasEspecialidadeLinha(
            especialidade: 'ORL',
            medicosAtivos: 1,
            medicosComDisponibilidade: 0,
            horasConsulta: 0),
      },
      linhas: medicoIds != null
          ? []
          : [
              for (final especialidade in especialidades!)
                RelatorioHorasEspecialidadeLinha(
                    especialidade: especialidade,
                    medicosAtivos: 1,
                    medicosComDisponibilidade: 1,
                    horasConsulta: 4),
            ],
      medicos: [
        for (final medicoId in medicoIds ?? <String>{})
          RelatorioHorasMedicoLinha(
            medicoId: medicoId,
            nome: medicoId == 'ana' ? 'Ana João' : 'Rui Silva',
            especialidade: medicoId == 'ana' ? 'Cardiologia' : 'ORL',
            horasConsulta: medicoId == 'ana' ? 7.5 : 0,
          ),
      ],
    );
  }
}

void main() {
  Future<_Service> montar(WidgetTester tester, String id) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _Service();
    await tester.pumpWidget(MaterialApp(
        home: RelatorioHorasEspecialidadeScreen(
      unidade: Unidade(
          id: id,
          nome: 'Clínica',
          tipo: 'Clínica',
          endereco: '',
          dataCriacao: DateTime(2026),
          nomeOcupantes: 'Médicos',
          nomeAlocacao: 'Gabinetes'),
      service: service,
    )));
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> escolherMedico(
      WidgetTester tester, String pesquisa, String nome) async {
    final campo = find.byKey(const ValueKey('relatorio_horas_medico'));
    await tester.ensureVisible(campo);
    await tester.tap(campo);
    await tester.pumpAndSettle();
    expect(find.text('Inativo · ORL'), findsNothing);
    if (find.text('Limpar seleção').evaluate().isNotEmpty) {
      await tester.tap(find.text('Limpar seleção'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), pesquisa);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nome));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Imagem por especialidade oferece gráfico ou tabela e permite cancelar',
      (tester) async {
    await montar(tester, 'imagem_especialidades');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Por especialidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(find.text('Imagem'), findsOneWidget);
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('Gráfico'), findsOneWidget);
    expect(find.text('Tabela'), findsOneWidget);
    expect(find.text('Médicos e horas de consulta por especialidade'),
        findsOneWidget);
    expect(find.text('Horas e médias por especialidade'), findsOneWidget);
    expect(find.text('Ocupação ao longo do período'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Exportar relatório'), findsNothing);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('relatorio_exportar')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Consulta por médico envia os IDs escolhidos e oferece os três formatos',
      (tester) async {
    final service = await montar(tester, 'medico');
    expect(find.text('Horas Médico/Especialidade'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Por médico'))
            .selected,
        isTrue);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('relatorio_gerar')))
            .onPressed,
        isNull);
    await escolherMedico(tester, 'ana', 'Ana João · Cardiologia');
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(service.chamadas.single.medicoIds, {'ana'});
    expect(service.chamadas.single.especialidades, isNull);
    expect(find.text('7,5 h'), findsNWidgets(3));
    expect(find.text('100%'), findsNWidgets(2));
    expect(find.text('de 7,5 h'), findsNWidgets(2));
    expect(find.text('3,75 h'), findsOneWidget);
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    for (final formato in ['Excel', 'Imagem', 'PDF']) {
      expect(find.text(formato), findsOneWidget);
    }
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('Gráfico'), findsOneWidget);
    expect(find.text('Tabela'), findsOneWidget);
    expect(find.text('Contribuição e médias na clínica e especialidade'),
        findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mudar médico invalida o resultado e apresenta zero horas',
      (tester) async {
    final service = await montar(tester, 'mudar_medico');
    await tester.tap(find.text('Por médico'));
    await tester.pumpAndSettle();
    await escolherMedico(tester, 'ana', 'Ana João · Cardiologia');
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    await escolherMedico(tester, 'rui', 'Rui Silva · ORL');
    expect(find.text('7,5 h'), findsNothing);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('relatorio_exportar')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(service.chamadas.last.medicoIds, {'rui'});
    expect(find.text('0 h'), findsNWidgets(3));
    expect(find.text('Sem disponibilidade no período selecionado.'),
        findsOneWidget);
  });

  testWidgets('Vários médicos têm resultado conjunto e cache por seleção',
      (tester) async {
    final service = await montar(tester, 'varios_medicos');
    await tester.tap(find.text('Por médico'));
    await tester.pumpAndSettle();
    await escolherMedico(tester, 'ana', 'Ana João · Cardiologia');
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();

    final campo = find.byKey(const ValueKey('relatorio_horas_medico'));
    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rui Silva · ORL'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('7,5 h'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(service.chamadas.length, 2);
    expect(service.chamadas.last.medicoIds, {'ana', 'rui'});
    expect(service.chamadas.last.especialidades, isNull);
    expect(find.text('Ana João'), findsOneWidget);
    expect(find.text('Rui Silva'), findsOneWidget);
    expect(find.text('7,5 h'), findsNWidgets(3));
    expect(find.text('0 h'), findsNWidgets(2));

    // A mesma seleção em ordem inversa reutiliza o relatório calculado.
    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar seleção'));
    await tester.pump();
    await tester.tap(find.text('Rui Silva · ORL'));
    await tester.pump();
    await tester.tap(find.text('Ana João · Cardiologia'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(service.chamadas.length, 2);

    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar seleção'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('relatorio_gerar')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Consulta por especialidade mantém os filtros ao alternar o modo',
      (tester) async {
    final service = await montar(tester, 'especialidade');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Por especialidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORL'));
    await tester.tap(find.text('Mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(service.chamadas.single.especialidades, {'Cardiologia'});
    expect(service.chamadas.single.medicoIds, isNull);
    final inicio = service.chamadas.single.inicio;
    final fim = service.chamadas.single.fim;
    expect(inicio.day, 1);
    expect(fim.add(const Duration(days: 1)).day, 1);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Por médico'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Por especialidade'));
    await tester.pumpAndSettle();
    final cardiologia = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Cardiologia'));
    final orl = tester
        .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'ORL'));
    expect(cardiologia.value, isTrue);
    expect(orl.value, isFalse);
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    // Reutiliza o resultado apenas quando todos os filtros coincidem.
    expect(service.chamadas.length, 1);
    expect(find.text('4 h'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
