import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/alocacao.dart';
import 'package:mapa_gabinetes/models/disponibilidade.dart';
import 'package:mapa_gabinetes/models/estatisticas_alocacao.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';
import 'package:mapa_gabinetes/widgets/estatisticas_alocacao_card.dart';
import 'package:mapa_gabinetes/widgets/medicos_disponiveis_container.dart';

void main() {
  final dia = DateTime(2026, 10, 28);
  for (final (largura, escala) in [(1400.0, 1.0), (390.0, 1.0), (390.0, 1.8)]) {
    testWidgets('Resumo compacto e fila horizontal a $largura / $escala',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(largura, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var lista = 0;
      var alertas = 0;
      String? editado;
      String? desalocado;
      var vazio = false;
      late StateSetter atualizar;
      final medicos = [
        for (var i = 0; i < 12; i++)
          Medico(
              id: '$i',
              nome: 'Médico $i',
              especialidade: 'Ortopedia',
              disponibilidades: [])
      ];
      final disponibilidades = [
        for (var i = 0; i < 12; i++)
          Disponibilidade(
              id: 'disp$i',
              medicoId: '$i',
              data: dia,
              horarios: ['08:00', '14:00'],
              tipo: 'Única')
      ];
      await tester.pumpWidget(MaterialApp(
          theme: MyAppTheme.claro,
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
            atualizar = setState;
            return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(escala)),
                child: Column(children: [
                  MedicosDisponiveisContainer(
                    resumo: const EstatisticasAlocacaoCard(
                        data: EstatisticasAlocacaoData(
                            numMedicosAlocados: 35,
                            numMedicosPorAlocar: 12,
                            numGabinetesOcupados: 23,
                            numGabinetesLivres: 14)),
                    medicosDisponiveis: vazio ? [] : medicos,
                    disponibilidades: disponibilidades,
                    alocacoes: [
                      Alocacao(
                          id: 'aloc',
                          medicoId: 'ocupado',
                          gabineteId: '101',
                          data: dia,
                          horarioInicio: '08:00',
                          horarioFim: '14:00')
                    ],
                    cartoesEmAlocacao: {},
                    selectedDate: dia,
                    onDesalocarMedicoComPergunta: (id, {alocacaoId}) async =>
                        desalocado = '$id/$alocacaoId',
                    onEditarMedico: (m) => editado = m.id,
                    onMostrarMedicosNaoAlocadosAno: () => lista++,
                    onMostrarConflitosAno: () => alertas++,
                  ),
                  const Text('Mapa'),
                  const Draggable<String>(
                      data: 'ocupado|||alocacao:aloc',
                      feedback: Text('A mover'),
                      child: Text('Médico no gabinete'))
                ]));
          }))));
      await tester.pumpAndSettle();
      if (largura > 1000) {
        expect(tester.getSize(find.byType(MedicosDisponiveisContainer)).height,
            lessThanOrEqualTo(132));
      }
      expect(
          tester
              .getSize(find.byKey(const ValueKey('faixa_medicos_por_alocar')))
              .height,
          lessThanOrEqualTo(76 * escala + 2));
      final drag = tester
          .widgetList<Draggable<String>>(find.byType(Draggable<String>))
          .first;
      expect(drag.data, '0|||disp0');
      await tester.tap(find.text('Médico 0'));
      expect(editado, '0');
      final scroll = find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
      await tester.drag(scroll, const Offset(-3000, 0));
      await tester.pumpAndSettle();
      expect(
          tester
              .state<ScrollableState>(find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first)
              .position
              .pixels,
          greaterThan(0));
      await tester.tap(find.byTooltip('Médicos não alocados no ano'));
      await tester.tap(find.byTooltip('Conflitos de gabinete no ano'));
      expect((lista, alertas), (1, 1));
      atualizar(() => vazio = true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('faixa_medicos_por_alocar')),
          findsOneWidget);
      expect(find.byTooltip('Médicos não alocados no ano'), findsOneWidget);
      final gesto = await tester
          .startGesture(tester.getCenter(find.text('Médico no gabinete')));
      await gesto.moveTo(
          tester.getCenter(find.text('Arraste um médico para desalocar')));
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();
      expect(desalocado, 'ocupado/aloc');
      expect(tester.takeException(), isNull);
    });
  }
}
