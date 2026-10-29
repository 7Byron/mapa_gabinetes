import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/unidade.dart';
import 'package:mapa_gabinetes/screens/configuracoes_screen.dart';
import 'package:mapa_gabinetes/widgets/custom_drawer.dart';

void main() {
  final unidade = Unidade(
    id: 'teste',
    nome: 'Unidade',
    tipo: 'Clínica',
    endereco: '',
    dataCriacao: DateTime(2026),
    nomeOcupantes: 'Médicos',
    nomeAlocacao: 'Gabinetes',
  );

  testWidgets('Configurações abre a página com as três opções aninhadas',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: CustomDrawer(
        unidade: unidade,
        isAdmin: true,
        onRefresh: () {},
      )),
    ));
    expect(find.text('Configurar Unidade'), findsNothing);
    expect(find.text('Configurar Horários'), findsNothing);
    expect(find.text('Dias de Encerramento'), findsNothing);
    await tester.scrollUntilVisible(find.text('Configurações'), 250);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfiguracoesScreen), findsOneWidget);
    for (final titulo in [
      'Configurar Unidade',
      'Configurar Horários',
      'Dias de Encerramento',
    ]) {
      expect(find.text(titulo), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Configurações continua reservada ao administrador',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CustomDrawer(unidade: unidade, onRefresh: () {})),
    ));
    await tester.scrollUntilVisible(find.text('Configurações'), 250);
    final item = tester.widget<ListTile>(find.ancestor(
      of: find.text('Configurações'),
      matching: find.byType(ListTile),
    ));
    expect(item.enabled, isFalse);
    expect(item.onTap, isNull);
  });

  for (final largura in [390.0, 1400.0]) {
    testWidgets('Menu à esquerda sem overflow a $largura', (tester) async {
      tester.view.physicalSize = Size(largura, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: ConfiguracoesScreen(unidade: unidade),
      ));
      final menu =
          tester.getRect(find.byKey(const ValueKey('configuracoes_opcao_0')));
      final conteudo =
          tester.getRect(find.text('Selecione uma opção no menu à esquerda.'));
      expect(menu.right, lessThanOrEqualTo(conteudo.left));
      expect(tester.takeException(), isNull);
    });
  }
}
