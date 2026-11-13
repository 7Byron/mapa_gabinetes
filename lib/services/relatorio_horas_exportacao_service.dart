import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/dados_relatorio_exportacao.dart';
import '../models/grafico_relatorio_exportacao.dart';
import '../models/relatorio_horas_especialidade.dart';
import 'relatorio_exportacao_service.dart';

/// Conteúdo comum aos três formatos, sempre a partir do relatório calculado.
class RelatorioHorasExportacaoDados {
  static const titulo = 'Horas Médico/Especialidade';
  final RelatorioHorasEspecialidade relatorio;

  const RelatorioHorasExportacaoDados(this.relatorio);

  String get consulta =>
      relatorio.porMedico ? 'Por médico' : 'Por especialidade';

  String get filtros => relatorio.porMedico
      ? relatorio.medicos
          .map((medico) => '${medico.nome} · ${medico.especialidade}')
          .join(', ')
      : relatorio.especialidadesSelecionadas.isNotEmpty
          ? (relatorio.especialidadesSelecionadas.toList()..sort()).join(', ')
          : relatorio.linhas.map((linha) => linha.especialidade).join(', ');

  List<String> get cabecalhos => relatorio.porMedico
      ? ['Médico', 'Especialidade', 'Horas de consulta']
      : [
          'Especialidade',
          'Médicos ativos',
          'Médicos com disponibilidade',
          'Horas de consulta',
          'Média de horas por médico com disponibilidade',
        ];

  List<List<Object>> get linhas => [
        if (relatorio.porMedico)
          for (final medico in relatorio.medicos)
            [medico.nome, medico.especialidade, medico.horasConsulta]
        else
          for (final linha in relatorio.linhas)
            [
              linha.especialidade,
              linha.medicosAtivos,
              linha.medicosComDisponibilidade,
              linha.horasConsulta,
              linha.mediaHorasPorMedico,
            ],
        if (relatorio.porMedico)
          ['Total', '', relatorio.totalHorasConsulta]
        else
          [
            'Total',
            relatorio.totalMedicosAtivos,
            relatorio.totalMedicosComDisponibilidade,
            relatorio.totalHorasConsulta,
            '',
          ],
      ];

  DadosRelatorioExportacao documento(String unidade,
          {bool incluirGraficos = false}) =>
      DadosRelatorioExportacao(
        titulo: titulo,
        unidade: unidade,
        inicio: relatorio.inicio,
        fim: relatorio.fim,
        detalhes: [
          consulta,
          'Seleção: $filtros',
          if (relatorio.porMedico) ...[
            'Total de horas da clínica: ${NumberFormat('#,##0.##', 'pt_PT').format(relatorio.totalHorasConsultaClinica)} h',
            'Média dos ${relatorio.totalMedicosAtivosClinica} médicos ativos (incluindo zero horas): '
                '${NumberFormat('#,##0.##', 'pt_PT').format(relatorio.mediaHorasPorMedicoClinica)} h',
          ],
        ],
        cabecalhos: cabecalhos,
        linhas: linhas,
        proporcoes: relatorio.porMedico
            ? [0.42, 0.38, 0.20]
            : [0.32, 0.14, 0.18, 0.16, 0.20],
        linhasDestaque: {linhas.length - 1},
        graficos: [
          if (incluirGraficos && relatorio.porMedico)
            GraficoHorasMedicoExportacao(relatorio),
          if (incluirGraficos && !relatorio.porMedico)
            GraficoHorasEspecialidadeExportacao(
              linhas: relatorio.linhas,
              totalMedicosAtivosClinica: relatorio.totalMedicosAtivosClinica,
            ),
        ],
      );

  List<List<String>> get linhasFormatadas => documento('').linhasFormatadas;
}

class RelatorioHorasExportacaoService {
  static Future<Uint8List> gerarPdf(
          {required String unidade,
          required RelatorioHorasEspecialidade relatorio}) =>
      RelatorioExportacaoService.gerarPdf(
          dados: RelatorioHorasExportacaoDados(relatorio).documento(unidade));

  static Future<Uint8List> gerarImagem(
          {required String unidade,
          required RelatorioHorasEspecialidade relatorio,
          ConteudoImagemRelatorio conteudo = ConteudoImagemRelatorio.tabela,
          bool horizontal = false}) =>
      RelatorioExportacaoService.gerarImagem(
          dados: RelatorioHorasExportacaoDados(relatorio).documento(unidade,
              incluirGraficos: conteudo != ConteudoImagemRelatorio.tabela),
          conteudo: conteudo,
          horizontal: horizontal);
}
