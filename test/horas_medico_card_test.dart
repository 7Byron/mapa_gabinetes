import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/relatorio_horas_especialidade.dart';
import 'package:mapa_gabinetes/widgets/horas_medico_card.dart';

void main() {
  setUpAll(() async {
    final fontes = FontLoader('Montserrat')
      ..addFont(rootBundle.load('fonts/Montserrat-Regular.ttf'))
      ..addFont(rootBundle.load('fonts/Montserrat-Bold.ttf'));
    await fontes.load();
  });

  Future<void> montar(WidgetTester tester,
      {double largura = 1500,
      double horas = 4.5,
      bool zero = false,
      bool escuro = false,
      bool segundoMedico = false,
      double escalaTexto = 1}) async {
    await tester.binding.setSurfaceSize(Size(largura, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final medico = RelatorioHorasMedicoLinha(
        medicoId: 'ana',
        nome: 'Alfredo Frade',
        especialidade: 'Psiquiatria',
        horasConsulta: horas);
    final relatorio = RelatorioHorasEspecialidade(
        inicio: DateTime(2026),
        fim: DateTime(2026),
        linhas: const [],
        medicos: [
          medico,
          if (segundoMedico)
            const RelatorioHorasMedicoLinha(
                medicoId: 'rui',
                nome: 'Rui Silva',
                especialidade: 'Psiquiatria',
                horasConsulta: 11),
        ],
        totalHorasConsultaClinica: zero ? 0 : 682.17,
        totalMedicosAtivosClinica: 172,
        especialidadesClinica: {
          'Psiquiatria': RelatorioHorasEspecialidadeLinha(
              especialidade: 'Psiquiatria',
              medicosAtivos: 4,
              medicosComDisponibilidade: zero ? 0 : 3,
              horasConsulta: zero ? 0 : 19.5),
        });
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'Montserrat',
            brightness: escuro ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: Column(children: [
                      for (final linha in relatorio.medicos)
                        HorasMedicoCard(medico: linha, relatorio: relatorio),
                    ]))))));
    await tester.pumpAndSettle();
  }

  for (final largura in [320.0, 720.0, 1100.0, 1500.0]) {
    testWidgets('Dois círculos e comparações sem overflow a $largura px',
        (tester) async {
      await montar(tester, largura: largura);
      expect(find.text('4,5 h'), findsOneWidget);
      expect(find.text('23,1%'), findsOneWidget);
      expect(find.text('de 19,5 h'), findsOneWidget);
      expect(find.text('0,7%'), findsOneWidget);
      expect(find.text('de 682,17 h'), findsOneWidget);
      expect(find.text('4,88 h'), findsOneWidget);
      expect(find.text('3,97 h'), findsOneWidget);
      expect(find.text('Média'), findsNWidgets(2));
      expect(find.text('4 médicos de Psiquiatria'), findsOneWidget);
      expect(find.text('172 médicos'), findsOneWidget);
      expect(
          find.text('Total: 19,5 h (0,38 h abaixo da média)',
              findRichText: true),
          findsOneWidget);
      expect(
          find.text('Total: 682,17 h (0,53 h acima da média)',
              findRichText: true),
          findsOneWidget);
      if (largura >= 720) {
        final nome = tester.getRect(find.text('Alfredo Frade'));
        final especialidade = tester.getRect(find.text('Psiquiatria').first);
        final horas = tester.getRect(find.text('4,5 h'));
        expect(nome.center.dy, closeTo(especialidade.center.dy, 1));
        expect(nome.center.dy, closeTo(horas.center.dy, 1));
      }
      if (largura >= 1100) {
        final titulo =
            tester.getRect(find.byType(CircularProgressIndicator).first);
        final total =
            tester.getRect(find.byType(CircularProgressIndicator).last);
        expect(titulo.center.dx, lessThan(total.center.dx));
        expect(titulo.center.dy, closeTo(total.center.dy, 1));
      }
      final circulos = tester
          .widgetList<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator))
          .toList();
      expect(
          circulos.map((c) => c.value),
          orderedEquals(
              [closeTo(4.5 / 19.5, 1e-12), closeTo(4.5 / 682.17, 1e-12)]));
      // A barra termina depois da média clínica e antes da média da especialidade.
      final barra = tester.getRect(find.byKey(const ValueKey('barra-Clínica')));
      final marca = tester.getRect(find.byKey(const ValueKey('media-Clínica')));
      final barraEspecialidade =
          tester.getRect(find.byKey(const ValueKey('barra-Especialidade')));
      final marcaEspecialidade =
          tester.getRect(find.byKey(const ValueKey('media-Especialidade')));
      if (largura >= 1100) {
        expect(barra.right, greaterThan(marca.center.dx));
        expect(
            barraEspecialidade.right, lessThan(marcaEspecialidade.center.dx));
      }
      for (final grupo in ['Especialidade', 'Clínica']) {
        final pin = tester.getRect(find.byKey(ValueKey('media-$grupo')));
        final trilho = tester.getRect(find.byKey(ValueKey('trilho-$grupo')));
        expect(pin.left, greaterThanOrEqualTo(trilho.left));
        expect(pin.right, lessThanOrEqualTo(trilho.right));
      }
      expect(barra.width, closeTo(barraEspecialidade.width, 0.01),
          reason: 'Mesma escala nas duas barras');
      expect(tester.takeException(), isNull);
      final destino = Platform.environment['RELATORIO_PREVIEW_DIR'];
      if (destino != null && largura == 1500) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('preview')));
          final imagem = await boundary.toImage();
          final dados =
              (await imagem.toByteData(format: ui.ImageByteFormat.png))!;
          await File('$destino/horas_medico_ecra.png')
              .writeAsBytes(dados.buffer.asUint8List());
          imagem.dispose();
        });
      }
    });
  }

  testWidgets('Barras mantêm a mesma escala entre médicos do relatório',
      (tester) async {
    await montar(tester, segundoMedico: true);
    Rect elemento(String id, String chave) => tester.getRect(find.descendant(
        of: find.byWidgetPredicate(
            (w) => w is HorasMedicoCard && w.medico.medicoId == id),
        matching: find.byKey(ValueKey(chave))));
    final ana = elemento('ana', 'barra-Clínica');
    final rui = elemento('rui', 'barra-Clínica');
    expect(ana.width / rui.width, closeTo(4.5 / 11, 0.001));
    expect(elemento('ana', 'media-Clínica').center.dx,
        elemento('rui', 'media-Clínica').center.dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Zero horas não produz divisões inválidas e identifica igualdade',
      (tester) async {
    await montar(tester, horas: 0, zero: true);
    expect(find.text('0%'), findsNWidgets(2));
    expect(find.text('de 0 h'), findsNWidgets(2));
    expect(find.text('Total: 0 h (Na média)', findRichText: true),
        findsNWidgets(2));
    for (final grupo in ['Especialidade', 'Clínica']) {
      final pin = tester.getRect(find.byKey(ValueKey('media-$grupo')));
      final trilho = tester.getRect(find.byKey(ValueKey('trilho-$grupo')));
      expect(pin.left, greaterThanOrEqualTo(trilho.left));
      expect(pin.right, lessThanOrEqualTo(trilho.right));
    }
    for (final circulo in tester.widgetList<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator))) {
      expect(circulo.value, 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tema escuro e texto ampliado mantêm o cartão legível',
      (tester) async {
    await montar(tester, largura: 320, escuro: true, escalaTexto: 1.5);
    expect(find.text('4,5 h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
