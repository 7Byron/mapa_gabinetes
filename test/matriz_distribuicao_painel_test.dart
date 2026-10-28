import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_painel.dart';

void main() {
  final gabinetes = [
    Gabinete(
        id: '101',
        setor: 'Piso 1',
        nome: '101',
        especialidadesPermitidas: ['Psicologia']),
    Gabinete(
        id: '102', setor: 'Piso 1', nome: '102', especialidadesPermitidas: []),
    Gabinete(
        id: '201', setor: 'Piso 2', nome: '201', especialidadesPermitidas: []),
  ];

  Future<void> montar(WidgetTester tester,
      {double escala = 1, bool abrirPisos = true}) async {
    var ocultos = <String>{};
    var ano = 2026;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: MatrizDistribuicaoPainel(
          gabinetes: gabinetes,
          itens: const [],
          ano: ano,
          mostrarLivres: true,
          gabinetesOcultos: ocultos,
          regrasSemGabinete: const ['Regra sem gabinete · Semanal · Jan a Dez'],
          onOcultosChanged: (valor) => setState(() => ocultos = valor),
          onEscolherAno: () => setState(() => ano++),
        ),
      ),
    ))));
    await tester.pumpAndSettle();
    if (abrirPisos) {
      for (final piso in ['Piso 1', 'Piso 2']) {
        final seta = find.byKey(ValueKey('expandir_piso_$piso'));
        await tester.ensureVisible(seta);
        await tester.pumpAndSettle();
        await tester.tap(seta);
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> clicar(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    final scrollable = find
        .descendant(
            of: find.byKey(const ValueKey('matriz_lista_gabinetes')),
            matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> visiveis(WidgetTester tester) => tester
      .widget<MatrizDistribuicaoGrid>(find.byType(MatrizDistribuicaoGrid))
      .gabinetes
      .map((g) => g.id)
      .toList();

  testWidgets('Pisos começam recolhidos e a seta não altera a seleção',
      (tester) async {
    await montar(tester, abrirPisos: false);
    expect(find.byKey(const ValueKey('mostrar_gabinete_101')), findsNothing);
    expect(find.byKey(const ValueKey('mostrar_gabinete_201')), findsNothing);
    expect(visiveis(tester), ['101', '102', '201']);
    expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
    await clicar(tester, 'expandir_piso_Piso 1');
    expect(find.byKey(const ValueKey('mostrar_gabinete_101')), findsOneWidget);
    expect(find.byKey(const ValueKey('mostrar_gabinete_102')), findsOneWidget);
    expect(find.byKey(const ValueKey('mostrar_gabinete_201')), findsNothing);
    expect(visiveis(tester), ['101', '102', '201']);
    await clicar(tester, 'matriz_piso_Piso 1');
    expect(visiveis(tester), ['201']);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('mostrar_gabinete_101')))
            .value,
        isFalse);
    await clicar(tester, 'expandir_piso_Piso 1');
    expect(find.byKey(const ValueKey('mostrar_gabinete_101')), findsNothing);
    expect(visiveis(tester), ['201']);
    await clicar(tester, 'expandir_piso_Piso 2');
    expect(find.byKey(const ValueKey('mostrar_gabinete_201')), findsOneWidget);
    expect(visiveis(tester), ['201']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Lista lateral mantém gabinetes ocultos e permite voltar a selecioná-los',
      (tester) async {
    await montar(tester);
    expect(visiveis(tester), ['101', '102', '201']);
    await clicar(tester, 'mostrar_gabinete_101');
    expect(visiveis(tester), ['102', '201']);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('mostrar_gabinete_101')))
            .value,
        isFalse);
    expect(find.byKey(const ValueKey('celula_101_1')), findsNothing);
    await clicar(tester, 'mostrar_gabinete_101');
    expect(visiveis(tester), ['101', '102', '201']);
    expect(
        find.descendant(
            of: find.byType(MatrizDistribuicaoGrid),
            matching: find.byType(Checkbox)),
        findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Checkbox da grelha atualiza a lista e a seleção do piso',
      (tester) async {
    await montar(tester);
    final lateral = find.byKey(const ValueKey('mostrar_gabinete_101'));
    expect(tester.widget<CheckboxListTile>(lateral).subtitle, isNotNull);
    expect(find.descendant(of: lateral, matching: find.text('Psicologia')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grelha_mostrar_gabinete_101')));
    await tester.pumpAndSettle();
    expect(visiveis(tester), ['102', '201']);
    expect(tester.widget<CheckboxListTile>(lateral).value, isFalse);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('matriz_piso_Piso 1')))
            .value,
        isNull);
    await clicar(tester, 'mostrar_gabinete_101');
    expect(visiveis(tester), ['101', '102', '201']);
    expect(
        tester
            .widget<Checkbox>(
                find.byKey(const ValueKey('grelha_mostrar_gabinete_101')))
            .value,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Piso controla os seus gabinetes e reflete seleção parcial',
      (tester) async {
    await montar(tester);
    bool? estadoPiso() => tester
        .widget<CheckboxListTile>(
            find.byKey(const ValueKey('matriz_piso_Piso 1')))
        .value;
    expect(estadoPiso(), isTrue);
    expect(find.text('Todos os pisos'), findsNothing);
    await clicar(tester, 'matriz_piso_Piso 1');
    expect(visiveis(tester), ['201']);
    expect(estadoPiso(), isFalse);
    await clicar(tester, 'matriz_piso_Piso 1');
    expect(visiveis(tester), ['101', '102', '201']);
    await clicar(tester, 'mostrar_gabinete_101');
    expect(visiveis(tester), ['102', '201']);
    expect(estadoPiso(), isNull);
    await clicar(tester, 'matriz_piso_Piso 1');
    expect(visiveis(tester), ['101', '102', '201']);
    expect(estadoPiso(), isTrue);
    await clicar(tester, 'matriz_piso_Piso 2');
    expect(visiveis(tester), ['101', '102']);
    await clicar(tester, 'matriz_todos_gabinetes');
    expect(visiveis(tester), ['101', '102', '201']);
    await clicar(tester, 'matriz_todos_gabinetes');
    expect(find.text('Selecione os gabinetes na lista à esquerda.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('matriz_selecionar_ano')));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);
    await clicar(tester, 'matriz_piso_Piso 1');
    expect(visiveis(tester), ['101', '102']);
    expect(
        tester
            .widget<MatrizDistribuicaoGrid>(find.byType(MatrizDistribuicaoGrid))
            .ano,
        2027);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Grelha tem margem superior e espaço entre pisos; Todos fica no fim',
      (tester) async {
    await montar(tester);
    final grelha = find.byType(MatrizDistribuicaoGrid);
    final cabecalho = find.text('Piso / Gabinete');
    expect(tester.getRect(cabecalho).top,
        greaterThan(tester.getRect(grelha).top + 12));
    final anterior = find.byKey(const ValueKey('celula_102_1'));
    final seguinte = find.byKey(const ValueKey('celula_201_1'));
    // A margem faz parte do Container da célula: o conteúdo é que começa depois da folga.
    final container = tester.widget<Container>(seguinte);
    expect(container.margin, const EdgeInsets.only(top: 14));
    expect(tester.getRect(seguinte).top,
        closeTo(tester.getRect(anterior).bottom, 0.1));
    final todos = find.byKey(const ValueKey('matriz_todos_gabinetes'));
    final ultimo = find.byKey(const ValueKey('mostrar_gabinete_201'));
    expect(
        tester.getRect(todos).top, greaterThan(tester.getRect(ultimo).bottom));
    expect(tester.getSize(ultimo).height, lessThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Grelha fica à esquerda com margens iguais num ecrã largo',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(2200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await montar(tester);
    final lateral =
        tester.getRect(find.byKey(const ValueKey('matriz_painel_lateral')));
    final titulo = find.text('Piso / Gabinete');
    final celulaTitulo =
        find.ancestor(of: titulo, matching: find.byType(SizedBox)).first;
    final area = tester.getRect(celulaTitulo);
    expect(area.left - lateral.right, closeTo(12, 0.1));
    expect(area.top, closeTo(12, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Informação aparece por extenso sem abrir menus', (tester) async {
    await montar(tester);
    final texto = find.text('Regra sem gabinete · Semanal · Jan a Dez');
    await tester.ensureVisible(texto);
    expect(texto, findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final largura in [390.0, 1400.0]) {
    for (final escala in [1.0, 1.8]) {
      testWidgets('Painel fixo sem overflow a $largura e texto $escala',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(largura, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await montar(tester, escala: escala);
        final painel =
            tester.getRect(find.byKey(const ValueKey('matriz_painel_lateral')));
        final ano =
            tester.getRect(find.byKey(const ValueKey('matriz_selecionar_ano')));
        await tester.drag(find.byKey(const ValueKey('matriz_corpo_horizontal')),
            const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(
            tester.getRect(find.byKey(const ValueKey('matriz_painel_lateral'))),
            painel);
        expect(
            tester.getRect(find.byKey(const ValueKey('matriz_selecionar_ano'))),
            ano);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
