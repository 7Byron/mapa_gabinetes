import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/widgets/relatorio_exportacao_menu.dart';
import 'package:mapa_gabinetes/widgets/relatorio_layout.dart';

void main() {
  Future<void> abrir(WidgetTester tester,
      ValueChanged<OpcaoExportacaoRelatorio?> onEscolha) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => RelatorioAcoes(onExportar: () async {
        onEscolha(await escolherExportacaoRelatorio(context));
      }),
    ))));
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
  }

  for (final (rotulo, escolha, formato, conteudo) in [
    (
      'Excel',
      OpcaoExportacaoRelatorio.excel,
      FormatoExportacaoRelatorio.excel,
      ConteudoImagemRelatorio.completo
    ),
    (
      'Gráfico',
      OpcaoExportacaoRelatorio.imagemGrafico,
      FormatoExportacaoRelatorio.imagem,
      ConteudoImagemRelatorio.grafico
    ),
    (
      'Tabela',
      OpcaoExportacaoRelatorio.imagemTabela,
      FormatoExportacaoRelatorio.imagem,
      ConteudoImagemRelatorio.tabela
    ),
    (
      'PDF',
      OpcaoExportacaoRelatorio.pdf,
      FormatoExportacaoRelatorio.pdf,
      ConteudoImagemRelatorio.completo
    ),
  ]) {
    testWidgets('Escolhe $rotulo diretamente no primeiro diálogo',
        (tester) async {
      OpcaoExportacaoRelatorio? resultado;
      await abrir(tester, (valor) => resultado = valor);
      expect(find.byType(SimpleDialog), findsOneWidget);
      final rotulos = ['Excel', 'Imagem', 'Gráfico', 'Tabela', 'PDF'];
      for (var i = 0; i < rotulos.length; i++) {
        expect(find.text(rotulos[i]), findsOneWidget);
        if (i > 0) {
          expect(tester.getTopLeft(find.text(rotulos[i])).dy,
              greaterThan(tester.getTopLeft(find.text(rotulos[i - 1])).dy));
        }
      }
      expect(tester.getTopLeft(find.text('Gráfico')).dx,
          greaterThan(tester.getTopLeft(find.text('Imagem')).dx));
      await tester.tap(find.text(rotulo));
      await tester.pumpAndSettle();
      expect(resultado, escolha);
      expect(resultado!.formato, formato);
      expect(resultado!.conteudoImagem, conteudo);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.text('Exportar imagem'), findsNothing);
    });
  }

  testWidgets('Imagem é apenas o título da secção e não inicia exportação',
      (tester) async {
    var chamadas = 0;
    await abrir(tester, (_) => chamadas++);
    await tester.tap(find.text('Imagem'));
    await tester.pumpAndSettle();
    expect(chamadas, 0);
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Imagem')).onTap,
        isNull);
  });

  testWidgets('Fechar o menu cancela a exportação', (tester) async {
    var terminou = false;
    OpcaoExportacaoRelatorio? resultado;
    await abrir(tester, (valor) {
      resultado = valor;
      terminou = true;
    });
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(terminou, isTrue);
    expect(resultado, isNull);
  });
}
