import 'package:flutter/material.dart';

class MatrizDistribuicaoAjuda extends StatelessWidget {
  const MatrizDistribuicaoAjuda({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Como funciona a matriz',
        icon: const Icon(Icons.help_outline),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Como funciona a matriz'),
            content: const SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Text(
                  'A matriz apresenta o panorama habitual da distribuição de médicos pelos gabinetes ao longo do ano selecionado.\n\n'
                  'Mostra as séries semanais, quinzenais e mensais, com os horários e os dias da semana. As rotações quinzenais e mensais não significam presença em todas as semanas.\n\n'
                  'As mudanças de gabinete da série a partir de uma data são consideradas. Por exemplo, uma série no gabinete 21 até junho e no 28 a partir de julho aparece nos dois gabinetes, com os respetivos períodos.\n\n'
                  'Sem datas: o cartão abrange todo o ano selecionado. “Até…” indica que termina durante o ano; “A partir de…” indica que começa durante o ano. Quando começa e termina dentro do ano, mostra o intervalo completo.\n\n'
                  'Não inclui cartões únicos, mudanças pontuais de gabinete num dia, ausências ou férias. Por isso, não representa a ocupação efetiva de cada dia. Para essa consulta, utiliza o mapa geral.\n\n'
                  'Os avisos de coincidência assinalam sobreposições entre as séries representadas. O filtro de piso permite limitar os gabinetes apresentados.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      );
}
