import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/models/medico.dart';
import 'package:mapa_gabinetes/screens/cadastro_medicos.dart';
import 'package:mapa_gabinetes/widgets/guardar_antes_de_sair.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));
  Future<CadastroMedicoState> abrirEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final editorKey = GlobalKey<CadastroMedicoState>();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => CadastroMedico(
                                key: editorKey,
                                medico: Medico(
                                    id: 'apagado',
                                    nome: 'Cartao Teste',
                                    especialidade: 'Teste',
                                    observacoes: 'Antes',
                                    ativo: false,
                                    disponibilidades: [])))),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    final state = editorKey.currentState!;
    state.reiniciarFormulario();
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
      'após limpar o médico apagado, voltar não tenta guardar o formulário vazio',
      (tester) async {
    final state = await abrirEditor(tester);
    // O mesmo reset é executado quando a eliminação no Firestore termina.
    state.reiniciarFormulario();
    await tester.pumpAndSettle();
    expect(find.text('Novo Médico'), findsOneWidget);
    final guardar = tester
        .widget<GuardarAntesDeSair>(find.byType(GuardarAntesDeSair))
        .onGuardar;
    expect(await guardar(), isTrue);
    expect(find.text('Introduza o nome do médico'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byType(CadastroMedico), findsNothing);
  });

  testWidgets(
      'novo formulário continua a validar alterações introduzidas depois do reset',
      (tester) async {
    final state = await abrirEditor(tester);
    state.reiniciarFormulario();
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(state.context).clearSnackBars();
    await tester.pumpAndSettle();
    state.observacoesController.text = 'Novo trabalho sem nome';
    final guardar = tester
        .widget<GuardarAntesDeSair>(find.byType(GuardarAntesDeSair))
        .onGuardar;
    expect(await guardar(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Introduza o nome do médico'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
