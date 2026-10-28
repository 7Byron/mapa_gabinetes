import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/gabinete.dart';
import 'package:mapa_gabinetes/models/matriz_distribuicao.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_grid.dart';
import 'package:mapa_gabinetes/widgets/matriz_distribuicao_painel.dart';

void main() {
  for (final livres in [true, false]) {
    testWidgets(
        'Filtro reutiliza medidas e invalida com novos dados (livres=$livres)',
        (tester) async {
      final gabinetes = [
        for (var i = 1; i <= 3; i++)
          Gabinete(
              id: '$i',
              nome: '10$i',
              setor: 'Piso 1',
              especialidadesPermitidas: ['Psicologia'])
      ];
      MatrizDistribuicaoItem item(String nome) => MatrizDistribuicaoItem(
          serieId: 'serie',
          medicoId: 'medico',
          medicoNome: nome,
          especialidade: 'Psicologia',
          gabineteId: '1',
          tipo: 'Semanal',
          ciclo: 'Jan a Dez · Todas as semanas',
          dia: 1,
          inicioMinutos: 480,
          fimMinutos: 1200);
      var itens = [item('Médico')];
      var ocultos = <String>{};
      var escala = 1.0;
      late StateSetter atualizar;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        atualizar = setState;
        return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: MatrizDistribuicaoPainel(
                gabinetes: gabinetes,
                itens: itens,
                gabinetesOcultos: ocultos,
                onOcultosChanged: (v) => setState(() => ocultos = v),
                onEscolherAno: () {},
                ano: 2026,
                mostrarLivres: livres));
      }))));
      await tester.pumpAndSettle();
      final dynamic estado = tester
          .state(find.byType(MatrizDistribuicaoGrid, skipOffstage: false));
      int medidas() => estado.medicoesTexto as int;
      final inicial = medidas();
      expect(inicial, greaterThan(0));
      for (final ids in [
        <String>{'1'},
        <String>{},
        <String>{'1', '2', '3'},
        <String>{}
      ]) {
        atualizar(() => ocultos = ids);
        await tester.pumpAndSettle();
        expect(
            tester.state(
                find.byType(MatrizDistribuicaoGrid, skipOffstage: false)),
            same(estado));
        expect(medidas(), inicial,
            reason: 'Filtrar não deve repetir medições de texto');
      }
      atualizar(() => itens = [item('Novo médico com dados atualizados')]);
      await tester.pumpAndSettle();
      expect(medidas(), greaterThan(inicial));
      expect(find.text('Novo médico com dados atualizados'),
          livres ? findsNothing : findsOneWidget);
      final antesEscala = medidas();
      atualizar(() => escala = 1.5);
      await tester.pumpAndSettle();
      expect(medidas(), greaterThan(antesEscala));
      expect(tester.takeException(), isNull);
    });
  }
}
