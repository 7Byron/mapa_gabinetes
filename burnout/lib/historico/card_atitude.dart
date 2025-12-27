import 'package:flutter/material.dart';
import '../historico/teste_model.dart';
import '../funcoes/variaveis_globais.dart';
import '../relatorios_teste_reutilizaveis/relatorio_teste_atitude.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../funcoes/theme_tokens.dart';

class CardAtitude extends StatelessWidget {
  final TesteModel teste;

  const CardAtitude({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;

    final RegExp exp = RegExp(r'\d+');
    final Iterable<Match> matches = exp.allMatches(teste.historico);
    final List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();

    if (numbers.length < 4) {
      return const Text('Invalid data');
    }

    final int pas = numbers[0];
    final int agr = numbers[1];
    final int man = numbers[2];
    final int ase = numbers[3];

    return Container(
      decoration: Reuse.mySombraContainer,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(
            children: [
              Text(
                data,
                style: TextStyle(
                  fontSize: MyG.to.margens['margem085'],
                  color: Colors.brown,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              GraficoAtitude(
                sumPassiva: pas ~/ 6.5,
                sumAgressiva: agr ~/ 6.5,
                sumManipuladora: man ~/ 6.5,
                sumAssertiva: ase ~/ 6.5,
              ),
              Reuse.myWidthBox050,
            ],
          ),
        ),
      ),
    );
  }
}
