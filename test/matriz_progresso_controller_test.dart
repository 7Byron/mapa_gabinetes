import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_gabinetes/services/matriz_progresso_controller.dart';

void main() {
  testWidgets('Verificação de cache avança sem ficar nos 0%', (tester) async {
    final progresso = MatrizProgressoController();
    addTearDown(progresso.dispose);
    progresso.iniciar();
    await tester.pump(const Duration(milliseconds: 300));
    expect(progresso.value, greaterThan(0.01));
    final antes = progresso.value;
    await tester.pump(const Duration(seconds: 2));
    expect(progresso.value, greaterThan(antes));
    expect(progresso.value, lessThan(1));
    progresso.parar();
  });

  testWidgets('Etapas não recuam e apenas concluir permite 100%',
      (tester) async {
    final progresso = MatrizProgressoController();
    addTearDown(progresso.dispose);
    final valores = <double>[];
    progresso.addListener(() => valores.add(progresso.value));
    progresso.iniciar();
    progresso.etapa(0.8, limiteEspera: 0.94);
    await tester.pump(const Duration(seconds: 3));
    final organizacao = progresso.value;
    await tester.pump(const Duration(seconds: 3));
    expect(progresso.value, greaterThan(organizacao));
    progresso.etapa(0.3, limiteEspera: 0.4);
    await tester.pump(const Duration(seconds: 2));
    expect(progresso.value, greaterThanOrEqualTo(organizacao));
    expect(progresso.value, lessThan(1));
    var terminou = false;
    progresso.concluir().then((_) => terminou = true);
    await tester.pump(const Duration(seconds: 1));
    expect(terminou, isTrue);
    expect(progresso.value, 1);
    for (var i = 1; i < valores.length; i++) {
      expect(valores[i], greaterThanOrEqualTo(valores[i - 1]));
    }
  });

  testWidgets('Erro ou saída interrompe o timer; nova carga reinicia',
      (tester) async {
    final progresso = MatrizProgressoController();
    addTearDown(progresso.dispose);
    progresso.iniciar();
    await tester.pump(const Duration(seconds: 1));
    progresso.parar();
    final parado = progresso.value;
    await tester.pump(const Duration(seconds: 2));
    expect(progresso.value, parado);
    progresso.iniciar();
    expect(progresso.value, 0);
    await tester.pump(const Duration(milliseconds: 120));
    expect(progresso.value, greaterThan(0));
    progresso.parar();
  });
}
