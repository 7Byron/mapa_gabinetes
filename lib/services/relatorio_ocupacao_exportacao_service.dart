import 'package:intl/intl.dart';

import '../models/dados_relatorio_exportacao.dart';
import '../models/gabinete.dart';
import '../models/grafico_relatorio_exportacao.dart';
import '../models/taxa_ocupacao.dart';
import 'relatorio_ocupacao_excel_service.dart';

class RelatorioOcupacaoExportacaoService {
  static DadosRelatorioExportacao taxas({
    required String unidade,
    required DateTime inicio,
    required DateTime fim,
    required List<Gabinete> gabinetes,
    required Map<String, TaxaOcupacao> taxas,
  }) {
    final selecionados =
        gabinetes.where((g) => taxas.containsKey(g.id)).toList();
    final geral = taxas.values.fold(const TaxaOcupacao(), (a, b) => a.somar(b));
    List<Object> linha(
            String nome, String piso, String descricao, TaxaOcupacao taxa) =>
        [
          nome,
          piso,
          descricao,
          taxa.horasOcupadas,
          taxa.horasDisponiveis,
          taxa.percentagem / 100,
        ];
    return DadosRelatorioExportacao(
      titulo: 'Taxas de Ocupação',
      unidade: unidade,
      inicio: inicio,
      fim: fim,
      detalhes: [
        'Gabinetes: ${selecionados.map((g) => '${g.nome} (${g.setor})').join(', ')}'
      ],
      cabecalhos: const [
        'Gabinete',
        'Piso',
        'Descrição',
        'Horas ocupadas',
        'Horas disponíveis',
        'Taxa de ocupação'
      ],
      linhas: [
        if (selecionados.length > 1) linha('Geral', '', '', geral),
        for (final gabinete in selecionados)
          linha(
              gabinete.nome,
              gabinete.setor,
              gabinete.especialidadesPermitidas.join(', '),
              taxas[gabinete.id]!),
      ],
      colunasPercentagem: const {5},
      linhasDestaque: selecionados.length > 1 ? const {0} : const {},
      proporcoes: const [0.12, 0.13, 0.27, 0.16, 0.16, 0.16],
      graficos: [
        GraficoTaxasExportacao([
          if (selecionados.length > 1)
            TaxaGraficoExportacao(
              titulo: 'Geral',
              descricao: 'Todos os gabinetes selecionados',
              horasOcupadas: geral.horasOcupadas,
              horasDisponiveis: geral.horasDisponiveis,
            ),
          for (final gabinete in selecionados)
            TaxaGraficoExportacao(
              titulo: '${gabinete.nome} · ${gabinete.setor}',
              descricao: gabinete.especialidadesPermitidas.isEmpty
                  ? 'Sem descrição'
                  : gabinete.especialidadesPermitidas.join(', '),
              horasOcupadas: taxas[gabinete.id]!.horasOcupadas,
              horasDisponiveis: taxas[gabinete.id]!.horasDisponiveis,
            ),
        ]),
      ],
    );
  }

  static DadosRelatorioExportacao gabinete({
    required String unidade,
    required String gabinete,
    required String descricao,
    required DateTime inicio,
    required DateTime fim,
    required String filtroDias,
    required bool porHora,
    required List<LinhaOcupacaoExcel> linhas,
    Map<DateTime, ({int inicio, int fim})> horarios = const {},
  }) {
    final data = DateFormat('dd/MM/yyyy');
    return DadosRelatorioExportacao(
      titulo: 'Ocupação por Gabinete',
      unidade: unidade,
      inicio: inicio,
      fim: fim,
      detalhes: [
        'Gabinete: $gabinete · $descricao',
        'Dias da semana: $filtroDias',
        porHora ? 'Ocupação por dia e hora' : 'Ocupação por dia',
      ],
      cabecalhos: [
        'Data',
        if (porHora) ...['Início ocupado', 'Fim ocupado', 'Horas do intervalo'],
        'Horas ocupadas no dia',
        'Horas disponíveis no dia',
        'Taxa de ocupação do dia',
        'Estado',
      ],
      linhas: [
        for (final linha in linhas)
          [
            data.format(linha.data),
            if (porHora) ...[
              linha.inicio ?? '',
              linha.fim ?? '',
              linha.horasIntervalo ?? 0
            ],
            linha.horasOcupadas,
            linha.horasDisponiveis,
            linha.horasDisponiveis > 0
                ? linha.horasOcupadas / linha.horasDisponiveis
                : 0,
            linha.fechado ? (linha.motivo ?? 'Encerrado') : 'Aberto',
          ],
      ],
      colunasPercentagem: {porHora ? 6 : 3},
      proporcoes: porHora
          ? const [0.14, 0.10, 0.10, 0.12, 0.14, 0.14, 0.14, 0.12]
          : const [0.18, 0.20, 0.20, 0.20, 0.22],
      graficos: [
        _graficoGabinete(porHora: porHora, linhas: linhas, horarios: horarios),
      ],
    );
  }

  static GraficoOcupacaoExportacao _graficoGabinete({
    required bool porHora,
    required List<LinhaOcupacaoExcel> linhas,
    required Map<DateTime, ({int inicio, int fim})> horarios,
  }) {
    final porDia = <DateTime, List<LinhaOcupacaoExcel>>{};
    for (final linha in linhas.where((linha) => !linha.fechado)) {
      final data = DateTime(linha.data.year, linha.data.month, linha.data.day);
      porDia.putIfAbsent(data, () => []).add(linha);
    }
    final datas = porDia.keys.toList()..sort();
    int minutos(String hora) {
      final partes = hora.split(':');
      return int.parse(partes[0]) * 60 + int.parse(partes[1]);
    }

    return GraficoOcupacaoExportacao(
      porHora: porHora,
      dias: [
        for (final data in datas)
          DiaGraficoExportacao(
            data: data,
            // As linhas por intervalo repetem os totais do dia.
            horasOcupadas: porDia[data]!.first.horasOcupadas,
            horasDisponiveis: porDia[data]!.first.horasDisponiveis,
            inicioMinutos: horarios[data]?.inicio ?? 0,
            fimMinutos: horarios[data]?.fim ?? 24 * 60,
            intervalos: [
              if (porHora)
                for (final linha in porDia[data]!)
                  if (linha.inicio != null && linha.fim != null)
                    IntervaloGraficoExportacao(
                        minutos(linha.inicio!), minutos(linha.fim!)),
            ],
          ),
      ],
    );
  }
}
