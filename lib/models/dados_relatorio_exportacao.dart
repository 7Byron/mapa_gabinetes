import 'package:intl/intl.dart';
import 'grafico_relatorio_exportacao.dart';

enum FormatoExportacaoRelatorio { excel, imagem, pdf }

enum ConteudoImagemRelatorio { completo, grafico, tabela }

enum OpcaoExportacaoRelatorio {
  excel(FormatoExportacaoRelatorio.excel),
  imagemGrafico(FormatoExportacaoRelatorio.imagem,
      conteudoImagem: ConteudoImagemRelatorio.grafico),
  imagemTabela(FormatoExportacaoRelatorio.imagem,
      conteudoImagem: ConteudoImagemRelatorio.tabela),
  pdf(FormatoExportacaoRelatorio.pdf);

  final FormatoExportacaoRelatorio formato;
  final ConteudoImagemRelatorio conteudoImagem;

  const OpcaoExportacaoRelatorio(this.formato,
      {this.conteudoImagem = ConteudoImagemRelatorio.completo});
}

/// Uma fotografia dos dados calculados, comum aos formatos de exportação.
class DadosRelatorioExportacao {
  final String titulo;
  final String unidade;
  final DateTime inicio;
  final DateTime fim;
  final List<String> detalhes;
  final List<String> cabecalhos;
  final List<List<Object>> linhas;
  final Set<int> colunasPercentagem;
  final Set<int> linhasDestaque;
  final List<double>? proporcoes;
  final List<GraficoRelatorioExportacao> graficos;

  const DadosRelatorioExportacao({
    required this.titulo,
    required this.unidade,
    required this.inicio,
    required this.fim,
    required this.cabecalhos,
    required this.linhas,
    this.detalhes = const [],
    this.colunasPercentagem = const {},
    this.linhasDestaque = const {},
    this.proporcoes,
    this.graficos = const [],
  });

  List<List<String>> get linhasFormatadas {
    final numero = NumberFormat('#,##0.##', 'pt_PT');
    final percentagem = NumberFormat('0.0%', 'pt_PT');
    return [
      for (final linha in linhas)
        [
          for (var coluna = 0; coluna < linha.length; coluna++)
            if (linha[coluna] case final num valor)
              (colunasPercentagem.contains(coluna) ? percentagem : numero)
                  .format(valor)
            else
              '${linha[coluna]}',
        ],
    ];
  }
}
