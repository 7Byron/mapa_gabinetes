import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/utils/app_theme.dart';
import 'package:mapa_gabinetes/widgets/horas_especialidade_card.dart';

void main() {
  for (final largura in [320.0, 1100.0]) {
    testWidgets('mostra proporção e média sem overflow a $largura px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(largura, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HorasEspecialidadeCard(
              linha: RelatorioHorasEspecialidadeLinha(
                especialidade: 'MGF',
                medicosAtivos: 15,
                medicosComDisponibilidade: 15,
                horasConsulta: 103.5,
              ),
              totalMedicosAtivosClinica: 60,
            ),
          ),
        ),
      ));
      expect(find.text('15'), findsOneWidget);
      expect(find.text('25% dos 60 médicos ativos da clínica'), findsOneWidget);
      expect(find.text('103,5 h'), findsOneWidget);
      expect(find.text('6,9 h'), findsOneWidget);
      final grafico = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(grafico.value, 0.25);
      expect(grafico.color, MyAppTheme.corOcupacao(25));
      expect(tester.takeException(), isNull);
    });
  }
}
