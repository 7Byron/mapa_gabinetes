import '../class/disponibilidade.dart';

/// Cria uma lista de disponibilidades, podendo ser únicas, semanais,
/// quinzenais ou mensais. Todas associadas ao [medicoId].
///
/// [dataInicial] é a primeira data escolhida,
/// [tipo] pode ser: 'Única', 'Semanal', 'Quinzenal', 'Mensal',
/// [limitarAoAno] define se vamos criar apenas até o final do mesmo ano ou não.
List<Disponibilidade> criarDisponibilidadesSerie(
    DateTime dataInicial,
    String tipo, {
      required String medicoId,      // <--- agora exigimos medicoId
      bool limitarAoAno = true,
    }) {
  final List<Disponibilidade> lista = [];

  switch (tipo) {
    case 'Única':
      {
        // Mesmo em "Única", geramos um ID único
        final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-0';
        lista.add(
          Disponibilidade(
            id: uniqueId,
            medicoId: medicoId, // <--- Associar ao médico
            data: dataInicial,
            horarios: [],
            tipo: 'Única',
          ),
        );
      }
      break;

    case 'Semanal':
      {
        // Gera 52 semanas a partir de dataInicial (aprox. 1 ano)
        for (var i = 0; i < 52; i++) {
          final novaData = dataInicial.add(Duration(days: i * 7));
          if (!limitarAoAno || novaData.year == dataInicial.year) {
            final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
            lista.add(
              Disponibilidade(
                id: uniqueId,
                medicoId: medicoId, // <---
                data: novaData,
                horarios: [],
                tipo: 'Semanal',
              ),
            );
          }
        }
      }
      break;

    case 'Quinzenal':
      {
        // Gera 26 quinzenais (52 semanas / 2)
        for (var i = 0; i < 26; i++) {
          final novaData = dataInicial.add(Duration(days: i * 14));
          if (!limitarAoAno || novaData.year == dataInicial.year) {
            final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
            lista.add(
              Disponibilidade(
                id: uniqueId,
                medicoId: medicoId,
                data: novaData,
                horarios: [],
                tipo: 'Quinzenal',
              ),
            );
          }
        }
      }
      break;

    case 'Mensal':
      {
        // Lógica: repete a mesma "ocorrência" no mês.
        // Ex: se dataInicial é a 2ª terça do mês, gerar também a 2ª terça
        // dos próximos meses, até 12 vezes (ou até acabar o ano se limitarAoAno=true)
        final weekdayDesejado = dataInicial.weekday;
        final anoInicial = dataInicial.year;
        final mesInicial = dataInicial.month;

        // Descobre "qual ocorrência" do weekday no mês (ex.: 2ª terça).
        final n = _descobrirOcorrenciaNoMes(dataInicial);

        for (int i = 0; i < 12; i++) {
          // Calcula o mês alvo
          final mesAlvo = mesInicial + i;
          final anoAlvo = anoInicial + ((mesAlvo - 1) ~/ 12);
          final mesCorreto = ((mesAlvo - 1) % 12) + 1;

          // Se for para limitar ao mesmo ano e mudou de ano, paramos
          if (limitarAoAno && anoAlvo != anoInicial) break;

          // Tenta descobrir a data exata do n-ésimo weekday
          final novaData = _pegarNthWeekdayDoMes(
            anoAlvo,
            mesCorreto,
            weekdayDesejado,
            n,
          );

          if (novaData != null) {
            final uniqueId = '${DateTime.now().microsecondsSinceEpoch}-$i';
            lista.add(
              Disponibilidade(
                id: uniqueId,
                medicoId: medicoId, // <---
                data: novaData,
                horarios: [],
                tipo: 'Mensal',
              ),
            );
          }
        }
      }
      break;
  }

  return lista;
}

/// Descobre em qual ocorrência do mês (1ª, 2ª, 3ª, 4ª, 5ª) está [data].
int _descobrirOcorrenciaNoMes(DateTime data) {
  final ano = data.year;
  final mes = data.month;
  final dia = data.day;
  final weekday = data.weekday;

  // Dia da semana do dia 1
  final weekdayDia1 = DateTime(ano, mes, 1).weekday;

  // offset: quantos dias do 1 até chegar em "weekday"?
  final offset = (weekday - weekdayDia1 + 7) % 7;
  final primeiroDesteMes = 1 + offset; // ex.: se offset=0 => dia 1

  // Ex.: data=8, primeiroDesteMes=1 => difference=7 => 7/7=1 => n=2 => 2ª
  final dif = dia - primeiroDesteMes;
  final n = 1 + (dif ~/ 7);
  return n;
}

/// Retorna a data do n-ésimo [weekdayDesejado] do mês [ano, mes].
/// Se não existir (ex.: 5ª terça), retorna null.
DateTime? _pegarNthWeekdayDoMes(
    int ano,
    int mes,
    int weekdayDesejado,
    int n,
    ) {
  final weekdayDia1 = DateTime(ano, mes, 1).weekday;
  final offset = (weekdayDesejado - weekdayDia1 + 7) % 7;
  final primeiroNoMes = 1 + offset;
  final dia = primeiroNoMes + 7 * (n - 1);

  final ultimoDiaMes = _ultimoDiaDoMes(ano, mes);
  if (dia > ultimoDiaMes) {
    return null;
  }

  return DateTime(ano, mes, dia);
}

/// Quantos dias tem o mês [ano, mes]?
int _ultimoDiaDoMes(int ano, int mes) {
  final mesSeguinte = (mes == 12) ? 1 : mes + 1;
  final anoSeguinte = (mes == 12) ? ano + 1 : ano;
  final primeiroDoMesSeguinte = DateTime(anoSeguinte, mesSeguinte, 1);
  final ultimoDoMes = primeiroDoMesSeguinte.subtract(Duration(days: 1));
  return ultimoDoMes.day;
}
