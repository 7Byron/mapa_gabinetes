import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/utils/matriz_colors.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:mapa_gabinetes/widgets/relatorio_layout.dart';

void main() {
  final gabinetes = [
    Gabinete(
        id: '101',
        setor: 'Piso 1',
        nome: '101',
        especialidadesPermitidas: ['Psicologia']),
    Gabinete(
        id: '102',
        setor: 'Piso 1',
        nome: '102',
        especialidadesPermitidas: ['Geral']),
    Gabinete(
        id: '201',
        setor: 'Piso 2',
        nome: '201',
        especialidadesPermitidas: ['Geral']),
  ];
  Future<void> montar(WidgetTester tester,
      {bool multipla = true, double escala = 1}) async {
    var selecionados = multipla ? {'101', '102', '201'} : <String>{};
    var periodo = 'Semana';
    var gerado = false;
    var exportado = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      appBar: const CustomAppBar(title: 'Relatório'),
      body: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(escala)),
                child: RelatorioLayout(
                  filtros: [
                    RelatorioPeriodoFiltros<String>(
                        opcoes: const [
                          ('Semana', 'Semana'),
                          ('Mês', 'Mês'),
                          ('Trimestre', 'Trimestre'),
                          ('Semestre', 'Semestre'),
                          ('Ano', 'Ano')
                        ],
                        selecionado: periodo,
                        onChanged: (p) => setState(() => periodo = p),
                        inicio: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Data inicial: 26/10/2026')),
                        fim: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Data final: 01/11/2026'))),
                    RelatorioSelecaoGabinetes(
                        gabinetes: gabinetes,
                        multipla: multipla,
                        selecionados: selecionados,
                        onChanged: (ids) => setState(() => selecionados = ids)),
                  ],
                  acoes: RelatorioAcoes(
                      onGerar: selecionados.isEmpty
                          ? null
                          : () => setState(() => gerado = true),
                      onExportar: gerado
                          ? () => setState(() => exportado = true)
                          : null),
                  resultado: gerado
                      ? ListView(children: [
                          Text(
                              'Resultado: $periodo · ${selecionados.length} gabinetes'),
                          if (exportado) const Text('Exportado')
                        ])
                      : const RelatorioEstadoVazio(),
                ),
              )),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> clicarFiltro(WidgetTester tester, Finder alvo) async {
    final scroll = find
        .descendant(
            of: find.byKey(const ValueKey('relatorio_filtros')),
            matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(alvo, 100, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.tap(alvo);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Pisos expansíveis, seleção parcial e ações usam os filtros escolhidos',
      (tester) async {
    await montar(tester);
    expect(find.byKey(const ValueKey('relatorio_gabinete_101')), findsNothing);
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_expandir_Piso 1')));
    expect(find.text('Psicologia'), findsOneWidget);
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_gabinete_101')));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('relatorio_piso_Piso 1')))
            .value,
        isNull);
    await clicarFiltro(tester, find.text('Mês'));
    await tester.tap(find.byKey(const ValueKey('relatorio_gerar')));
    await tester.pumpAndSettle();
    expect(find.text('Resultado: Mês · 2 gabinetes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('relatorio_exportar')));
    await tester.pumpAndSettle();
    expect(find.text('Exportado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Seleção de um gabinete substitui o anterior sem selecionar o piso',
      (tester) async {
    await montar(tester, multipla: false);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('relatorio_gerar')))
            .onPressed,
        isNull);
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_expandir_Piso 1')));
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_gabinete_101')));
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_gabinete_102')));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('relatorio_gabinete_101')))
            .value,
        isFalse);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('relatorio_gabinete_102')))
            .value,
        isTrue);
    expect(
        find.byKey(const ValueKey('relatorio_todos_gabinetes')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ações ficam fixas e o appbar usa a cor comum', (tester) async {
    await montar(tester);
    final gerar = find.byKey(const ValueKey('relatorio_gerar'));
    final posicao = tester.getRect(gerar);
    await clicarFiltro(
        tester, find.byKey(const ValueKey('relatorio_expandir_Piso 1')));
    await tester.drag(
        find.byKey(const ValueKey('relatorio_filtros')), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getRect(gerar), posicao);
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        MatrizColors.barra);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Períodos mantêm texto legível nos estados selecionado e normal',
      (tester) async {
    await montar(tester);
    final tema =
        Theme.of(tester.element(find.byType(ChoiceChip).first)).chipTheme;
    final texto = tema.labelStyle!.color!;
    for (final estados in [
      <WidgetState>{},
      {WidgetState.selected}
    ]) {
      final fundo = tema.color!.resolve(estados)!;
      expect(fundo.a, 1);
      final clara = texto.computeLuminance();
      final escura = fundo.computeLuminance();
      expect((clara + 0.05) / (escura + 0.05), greaterThanOrEqualTo(4.5));
    }
  });

  for (final largura in [390.0, 1440.0]) {
    for (final escala in [1.0, 1.8]) {
      testWidgets('Filtros e resultados sem overflow a $largura / $escala',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(largura, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await montar(tester, escala: escala);
        await clicarFiltro(
            tester, find.byKey(const ValueKey('relatorio_expandir_Piso 1')));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
