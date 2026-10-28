import 'package:flutter/material.dart';

class MatrizDistribuicaoAjuda extends StatelessWidget {
  final bool mostrarLivres;
  const MatrizDistribuicaoAjuda({super.key, this.mostrarLivres = false});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Como funciona a matriz',
        icon: const Icon(Icons.help_outline),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Como funciona a matriz'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Text(
                  mostrarLivres
                      ? 'Mostra os intervalos livres entre as regras habituais de ocupação do ano, dentro dos horários de funcionamento. Exclui os dias de encerramento e os feriados em que a unidade encerra. Dias sem horário configurado não apresentam disponibilidade.\n\nObservações: os períodos livres com duração igual ou inferior a 2 horas são ignorados, por não permitirem uma alocação útil. Apenas são apresentados intervalos superiores a 2 horas. Também são ignoradas disponibilidades limitadas a um ou dois meses consecutivos. Cada intervalo livre deve existir em pelo menos três meses consecutivos; períodos separados por meses sem disponibilidade são avaliados individualmente. As 5.as ocorrências do dia da semana no mês são ignoradas quando esporádicas; mantêm-se quando integram disponibilidade todas as semanas ou de 15 em 15 dias.\n\nO cartão indica os meses e o padrão de disponibilidade: todas as semanas, 15 em 15 dias ou as ocorrências do dia da semana no mês (por exemplo, 1.ª, 2.ª e 4.ª terça-feira). O padrão de 15 em 15 dias segue intervalos reais de 14 dias, mesmo que a posição do dia da semana mude de um mês para o outro. É reconhecido por período, podendo coexistir com meses livres todas as semanas. Os encerramentos não alteram o padrão habitual, mas essas datas são excluídas. Padrões mensais semelhantes podem ser agrupados quando existam até três exceções num período de pelo menos três meses. As datas sem disponibilidade nesse horário aparecem no próprio cartão como “Exceto”. Os encerramentos continuam excluídos pelas regras gerais. Quando há mais exceções, ou muda a frequência semanal ou quinzenal, apresenta períodos separados. Toque num subcartão para consultar apenas as datas exatas do período nele indicado. As rotações semanais, quinzenais e mensais e as mudanças de gabinete são consideradas.\n\nTal como a matriz de ocupação, não inclui cartões únicos, alterações pontuais, ausências ou férias. Para confirmar a disponibilidade efetiva num dia, consulte o mapa geral.'
                      : 'A matriz apresenta o panorama habitual da distribuição de médicos pelos gabinetes ao longo do ano selecionado.\n\n'
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
