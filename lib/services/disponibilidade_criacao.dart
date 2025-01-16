// lib/services/disponibilidade_criacao.dart

import '../class/disponibilidade.dart';

List<Disponibilidade> criarDisponibilidadesSerie(
    DateTime dataInicial,
    String tipo, {
      bool limitarAoAno = true,
    }) {
  final List<Disponibilidade> lista = [];

  switch (tipo) {
    case 'Única':
    // Mesmo em "Única", garanta um ID único
      final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-0';
      lista.add(
        Disponibilidade(
          id: uniqueId,
          data: dataInicial,
          horarios: [],
          tipo: 'Única',
        ),
      );
      break;

    case 'Semanal':
      for (var i = 0; i < 52; i++) {
        final novaData = dataInicial.add(Duration(days: i * 7));
        if (!limitarAoAno || novaData.year == dataInicial.year) {
          final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
          lista.add(
            Disponibilidade(
              id: uniqueId,
              data: novaData,
              horarios: [],
              tipo: 'Semanal',
            ),
          );
        }
      }
      break;

    case 'Quinzenal':
      for (var i = 0; i < 26; i++) {
        final novaData = dataInicial.add(Duration(days: i * 14));
        if (!limitarAoAno || novaData.year == dataInicial.year) {
          final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
          lista.add(
            Disponibilidade(
              id: uniqueId,
              data: novaData,
              horarios: [],
              tipo: 'Quinzenal',
            ),
          );
        }
      }
      break;

    case 'Mensal':
    // -- NOVA lógica: nth weekday do mês --
      final weekdayDesejado = dataInicial.weekday; // segunda=1, domingo=7
      final anoInicial = dataInicial.year;
      final mesInicial = dataInicial.month;

      // Descobre qual é a "ocorrência" de dataInicial no seu próprio mês
      // Ex.: se dataInicial é 8 de agosto, e dia 1 de agosto também era terça,
      // então dataInicial é a 2ª terça do mês
      final n = _descobrirOcorrenciaNoMes(dataInicial);

      // Geramos até 12 meses
      for (int i = 0; i < 12; i++) {
        // Descobre o ano e mês-alvo
        final mesAlvo = mesInicial + i;
        final anoAlvo = anoInicial + ((mesAlvo - 1) ~/ 12);
        final mesCorreto = ((mesAlvo - 1) % 12) + 1;

        if (limitarAoAno && anoAlvo != anoInicial) {
          // se quer limitar ao mesmo ano e esse já mudou, paramos
          break;
        }

        // Tenta descobrir qual é a data que corresponde à mesma nth
        // ocorrência do weekdayDesejado neste novo mês
        final novaData = _pegarNthWeekdayDoMes(anoAlvo, mesCorreto, weekdayDesejado, n);

        if (novaData != null) {
          // Gera um ID único
          final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
          lista.add(
            Disponibilidade(
              id: uniqueId,
              data: novaData,
              horarios: [],
              tipo: 'Mensal',
            ),
          );
        }
      }
      break;
  }

  return lista;
}

/// Função auxiliar que descobre "qual ocorrência" do mês é a data.
/// Ex.: Se [data] é 8 de agosto de 2023 (terça),
/// e 1 de agosto de 2023 foi terça => data é a 2ª terça do mês.
/// Retorna [1..5], por ex.
int _descobrirOcorrenciaNoMes(DateTime data) {
  final ano = data.year;
  final mes = data.month;
  final dia = data.day;
  final weekday = data.weekday;

  // Descobre que dia da semana era o dia 1 desse mês
  final weekdayDia1 = DateTime(ano, mes, 1).weekday;

  // offset: quantos dias até chegar no [weekday] da data?
  // É basicamente "qual foi a 1ª vez que weekday apareceu nesse mês?"
  final offset = (weekday - weekdayDia1 + 7) % 7;
  final primeiroDesteMes = 1 + offset; // Ex.: se offset=0 => 1

  // Se dia = 8 e o primeiro é 1, a cada 7 dias temos outra ocorrência
  // n = 1 + ( (dia - primeiroDesteMes) / 7 )
  final dif = dia - primeiroDesteMes;  // ex.: 8 - 1 = 7
  final n = 1 + (dif ~/ 7);           // ex.: 1 + (7/7) = 2 => 2ª vez
  return n;
}

/// Função que retorna a data do [n]-ésimo [weekday] do mês [ano, mes].
/// Se não existir (por ex., "5ª terça" e o mês só tem 4 terças), retorna null.
DateTime? _pegarNthWeekdayDoMes(int ano, int mes, int weekdayDesejado, int n) {
  // 1) Descobre o weekday do dia 1
  final weekdayDia1 = DateTime(ano, mes, 1).weekday;

  // 2) offset para chegar no weekdayDesejado
  final offset = (weekdayDesejado - weekdayDia1 + 7) % 7;
  final primeiroNoMes = 1 + offset; // ex.: se offset=2 => primeiroNoMes=3

  // 3) Data do nth => "primeiroNoMes + 7*(n-1)"
  final dia = primeiroNoMes + 7 * (n - 1);

  // 4) Ver se [dia] não ultrapassa o número de dias do mês
  //    Se ultrapassar, não existe esse nth
  final ultimoDiaMes = _ultimoDiaDoMes(ano, mes);
  if (dia > ultimoDiaMes) {
    return null; // não existe nth
  }

  return DateTime(ano, mes, dia);
}

/// Descobre quantos dias tem o mês [ano, mes].
/// ex.: jan=31, fev=28/29, etc.
int _ultimoDiaDoMes(int ano, int mes) {
  // Truque: criar data do dia 0 do mês seguinte => subtrai 1
  // ex.: 0 de março => 28/29 de fevereiro
  final mesSeguinte = (mes == 12) ? 1 : (mes + 1);
  final anoSeguinte = (mes == 12) ? (ano + 1) : ano;
  final primeiroMesSeguinte = DateTime(anoSeguinte, mesSeguinte, 1);
  final ultimoDoMes = primeiroMesSeguinte.subtract(Duration(days: 1));
  return ultimoDoMes.day;
}
