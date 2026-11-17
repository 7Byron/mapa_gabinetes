import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/dados_relatorio_exportacao.dart';
import 'relatorio_graficos_exportacao_service.dart';
import 'pdf_grafico_codec.dart';

class RelatorioExportacaoService {
  static Future<void> guardar({
    ProgressoExportacao? onProgresso,
    required FormatoExportacaoRelatorio formato,
    required DadosRelatorioExportacao dados,
    required String nome,
    required FutureOr<Uint8List> Function() gerarExcel,
    Future<Uint8List> Function()? gerarPdfPersonalizado,
    ConteudoImagemRelatorio conteudoImagem = ConteudoImagemRelatorio.completo,
    bool imagemHorizontal = false,
    bool pdfPortrait = false,
    bool centrarCelulas = false,
    bool dividirImagemEmPaineis = true,
  }) async {
    if (formato == FormatoExportacaoRelatorio.imagem &&
        dividirImagemEmPaineis) {
      final imagens = await gerarImagensPaginadas(dados,
          conteudo: conteudoImagem, onProgresso: onProgresso);
      await guardarImagens(imagens, nome, onProgresso: onProgresso);
      return;
    }
    await onProgresso?.call(0.06, 'A preparar o ficheiro…');
    final bytes = switch (formato) {
      FormatoExportacaoRelatorio.excel => await gerarExcel(),
      FormatoExportacaoRelatorio.imagem => await gerarImagem(
          dados: dados,
          conteudo: conteudoImagem,
          horizontal: imagemHorizontal,
          dividirEmPaineis: dividirImagemEmPaineis,
          centrarCelulas: centrarCelulas),
      FormatoExportacaoRelatorio.pdf => gerarPdfPersonalizado != null
          ? await gerarPdfPersonalizado()
          : await gerarPdf(
              dados: dados,
              portrait: pdfPortrait,
              onProgresso: onProgresso,
              centrarCelulas: centrarCelulas),
    };
    final (extensao, mime) = switch (formato) {
      FormatoExportacaoRelatorio.excel => ('xlsx', MimeType.microsoftExcel),
      FormatoExportacaoRelatorio.imagem => ('png', MimeType.png),
      FormatoExportacaoRelatorio.pdf => ('pdf', MimeType.pdf),
    };
    await onProgresso?.call(0.99, 'A iniciar o download…');
    await FileSaver.instance.saveFile(
      name: nome,
      bytes: bytes,
      fileExtension: extensao,
      mimeType: mime,
    );
  }

  static Future<List<Uint8List>> gerarImagensPaginadas(
      DadosRelatorioExportacao dados,
      {ConteudoImagemRelatorio conteudo = ConteudoImagemRelatorio.completo,
      ProgressoExportacao? onProgresso}) async {
    final graficos = conteudo == ConteudoImagemRelatorio.tabela
        ? <ImagemGraficoRelatorio>[]
        : await RelatorioGraficosExportacaoService.gerar(dados.graficos,
            onImagemGerada: (n) async {
            await onProgresso?.call(
                0.06 + 0.2 * n / (n + 1), 'A preparar gráfico $n…');
          });
    final paginas = conteudo == ConteudoImagemRelatorio.grafico
        ? <List<List<Object>>>[]
        : dividirLinhasImagemVertical(dados);
    final paginasGraficos = dividirGraficosImagemVertical(dados, graficos);
    final total = paginasGraficos.length + paginas.length;
    final imagens = <Uint8List>[];
    for (var i = 0; i < total; i++) {
      await onProgresso?.call(
          0.28 + 0.62 * i / total, 'A gerar imagem ${i + 1} de $total…');
      final grafico = i < paginasGraficos.length;
      final linhas =
          grafico ? <List<Object>>[] : paginas[i - paginasGraficos.length];
      // Índices de destaque são relativos à página exportada.
      final inicio = grafico
          ? 0
          : paginas
              .take(i - paginasGraficos.length)
              .fold<int>(0, (n, p) => n + p.length);
      imagens.add(await gerarImagem(
        dados: DadosRelatorioExportacao(
          titulo: '${dados.titulo} · Parte ${i + 1} de $total',
          unidade: dados.unidade,
          inicio: dados.inicio,
          fim: dados.fim,
          detalhes: dados.detalhes,
          cabecalhos: dados.cabecalhos,
          linhas: linhas,
          proporcoes: dados.proporcoes,
          colunasPercentagem: dados.colunasPercentagem,
          colunasCentradas: dados.colunasCentradas,
          colunasNegrito: dados.colunasNegrito,
          tamanhoFonteImagem: dados.tamanhoFonteImagem,
          grelhaImagem: dados.grelhaImagem,
          linhasDestaque: {
            for (var l = 0; l < linhas.length; l++)
              if (dados.linhasDestaque.contains(inicio + l)) l
          },
        ),
        conteudo: grafico
            ? ConteudoImagemRelatorio.grafico
            : ConteudoImagemRelatorio.tabela,
        imagensGraficos: grafico ? paginasGraficos[i] : [],
        dividirEmPaineis: false,
        paginaVertical: true,
        centrarCelulas: true,
      ));
    }
    return imagens;
  }

  /// PNG já é comprimido. Guardar sem voltar a comprimir evita um custo
  /// elevado em JavaScript; cada entrada permite atualizar o progresso.
  static Future<Uint8List> gerarZipImagens(List<Uint8List> imagens, String nome,
      {ProgressoExportacao? onProgresso}) async {
    final saida = OutputStream();
    final encoder = ZipEncoder()..startEncode(saida);
    for (var i = 0; i < imagens.length; i++) {
      await onProgresso?.call(0.92 + 0.06 * i / imagens.length,
          'A juntar imagem ${i + 1} de ${imagens.length} no ZIP…');
      final ficheiro = ArchiveFile(
          '${nome}_${(i + 1).toString().padLeft(3, '0')}.png',
          imagens[i].length,
          imagens[i])
        ..compress = false;
      encoder.addFile(ficheiro);
      // Também cede o controlo quando não há um indicador ligado.
      await Future<void>.delayed(Duration.zero);
    }
    encoder.endEncode();
    return Uint8List.fromList(saida.getBytes());
  }

  static Future<void> guardarImagens(List<Uint8List> imagens, String nome,
      {ProgressoExportacao? onProgresso}) async {
    if (imagens.isEmpty) throw StateError('Sem dados para exportar.');
    final unica = imagens.length == 1;
    final bytes = unica
        ? imagens.single
        : await gerarZipImagens(imagens, nome, onProgresso: onProgresso);
    await onProgresso?.call(0.99, 'A iniciar o download…');
    await FileSaver.instance.saveFile(
        name: nome,
        bytes: bytes,
        fileExtension: unica ? 'png' : 'zip',
        mimeType: unica ? MimeType.png : MimeType.zip);
  }

  static Future<Uint8List> gerarPdf({
    required DadosRelatorioExportacao dados,
    ProgressoExportacao? onProgresso,
    bool portrait = false,
    bool centrarCelulas = false,
  }) async {
    final fonteRegular = await rootBundle.load('fonts/Montserrat-Regular.ttf');
    final fonteNegrito = await rootBundle.load('fonts/Montserrat-Bold.ttf');
    final documento = pw.Document(
      title: dados.titulo,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(fonteRegular),
        bold: pw.Font.ttf(fonteNegrito),
      ),
    );
    final data = DateFormat('dd/MM/yyyy');
    final graficos = await RelatorioGraficosExportacaoService.gerar(
        dados.graficos, onImagemGerada: (n) async {
      await onProgresso?.call(
          0.05 + 0.02 * n / (n + 1), 'A preparar gráfico $n do PDF…');
    });
    // PNG exigia descodificar e recomprimir todos os píxeis ao guardar o
    // documento. JPEG pode ser incorporado diretamente, sem essa segunda fase.
    final imagensPdf = <pw.ImageProvider>[];
    for (var i = 0; i < graficos.length; i++) {
      await onProgresso?.call(0.08 + 0.58 * i / graficos.length,
          'A preparar gráfico ${i + 1} de ${graficos.length} para o PDF…');
      final jpeg = await prepararGraficoPdf(graficos[i].bytes);
      imagensPdf
          .add(pw.ImageProxy(PdfImage.jpeg(documento.document, image: jpeg)));
      await Future<void>.delayed(Duration.zero);
    }
    final formato = portrait ? PdfPageFormat.a4 : PdfPageFormat.a4.landscape;
    final margem = portrait ? 24.0 : 30.0;
    final linhas = <List<String>>[];
    // Prepara os dados por blocos, mas deixa a tabela paginar naturalmente.
    for (final linha in dados.formatarLinhas()) {
      linhas.add(linha);
      if (linhas.length % 12 == 0) {
        await onProgresso?.call(
            (graficos.isEmpty ? 0.08 : 0.66) +
                (graficos.isEmpty ? 0.62 : 0.04) *
                    linhas.length /
                    dados.linhas.length,
            'A preparar PDF · ${linhas.length} de ${dados.linhas.length} linhas…');
      }
    }
    await onProgresso?.call(0.76, 'A compor as páginas do PDF…');
    documento.addPage(pw.MultiPage(
      pageFormat: formato,
      margin: pw.EdgeInsets.all(margem),
      maxPages: 200,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(dados.titulo,
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(dados.unidade),
          pw.Text('${data.format(dados.inicio)} a ${data.format(dados.fim)}'),
        ]),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (_) => [
        for (final detalhe in dados.detalhes)
          pw.Text(detalhe, style: pw.TextStyle(fontSize: portrait ? 9 : 12)),
        pw.SizedBox(height: 12),
        for (final grafico in imagensPdf)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Image(grafico, width: formato.width - margem * 2),
          ),
        pw.TableHelper.fromTextArray(
          cellAlignment:
              centrarCelulas ? pw.Alignment.centerLeft : pw.Alignment.topLeft,
          cellAlignments: {
            for (final coluna in dados.colunasCentradas)
              coluna: pw.Alignment.center
          },
          headers: dados.cabecalhos,
          data: linhas,
          columnWidths: dados.proporcoes == null
              ? null
              : {
                  for (var i = 0; i < dados.proporcoes!.length; i++)
                    i: pw.FlexColumnWidth(dados.proporcoes![i]),
                },
          cellStyle: pw.TextStyle(fontSize: portrait ? 7.5 : 10),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: portrait ? 8 : 12),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xff17343c)),
          cellPadding: pw.EdgeInsets.all(portrait ? 4 : 8),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    ));
    await onProgresso?.call(0.94, 'A finalizar o PDF…');
    return documento.save(enableEventLoopBalancing: true);
  }

  /// Preenche páginas verticais pela altura real do texto, incluindo títulos
  /// e cabeçalho repetido, em vez de limitar a um número fixo de linhas.
  static double _medirTextoImagem(
      String texto, double largura, double tamanho, bool negrito) {
    final paragrafo = (ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'Montserrat',
      fontSize: tamanho,
      fontWeight: negrito ? ui.FontWeight.w700 : ui.FontWeight.w400,
    ))
          ..addText(texto))
        .build()
      ..layout(ui.ParagraphConstraints(width: largura));
    final altura = paragrafo.height;
    paragrafo.dispose();
    return altura;
  }

  static double _alturaBaseImagem(DadosRelatorioExportacao dados) {
    const largura = 1504.0;
    final data = DateFormat('dd/MM/yyyy');
    final alturas = [
      _medirTextoImagem(
          '${dados.titulo} · Parte 999 de 999', largura, 36, true),
      _medirTextoImagem(dados.unidade, largura, 26, false),
      _medirTextoImagem(
          '${data.format(dados.inicio)} a ${data.format(dados.fim)}',
          largura,
          22,
          false),
      for (final detalhe in dados.detalhes)
        _medirTextoImagem(detalhe, largura, 22, false),
    ];
    return 96 + alturas.fold<double>(0, (s, h) => s + h + 16) + 16;
  }

  static List<List<ImagemGraficoRelatorio>> dividirGraficosImagemVertical(
      DadosRelatorioExportacao dados, List<ImagemGraficoRelatorio> graficos) {
    final base = _alturaBaseImagem(dados);
    var alturaAtual = base;
    final paginas = <List<ImagemGraficoRelatorio>>[];
    for (final grafico in graficos) {
      final altura = grafico.altura * 1504 / grafico.largura + 24;
      if (paginas.isEmpty ||
          (alturaAtual + altura > 1600 * math.sqrt2 &&
              paginas.last.isNotEmpty)) {
        paginas.add([]);
        alturaAtual = base;
      }
      paginas.last.add(grafico);
      alturaAtual += altura;
    }
    return paginas;
  }

  static List<List<List<Object>>> dividirLinhasImagemVertical(
      DadosRelatorioExportacao dados) {
    const larguraUtil = 1600.0 - 96;
    final proporcoes = dados.proporcoes ??
        List.filled(dados.cabecalhos.length, 1 / dados.cabecalhos.length);
    double alturaLinha(List<String> linha, bool cabecalho) {
      var maior = 0.0;
      for (var c = 0; c < proporcoes.length; c++) {
        maior = math.max(
            maior,
            _medirTextoImagem(
                linha[c],
                larguraUtil * proporcoes[c] - 24,
                dados.tamanhoFonteImagem,
                cabecalho || dados.colunasNegrito.contains(c)));
      }
      return maior + 32;
    }

    final base = _alturaBaseImagem(dados) + alturaLinha(dados.cabecalhos, true);
    final paginas = <List<List<Object>>>[];
    var alturaAtual = base;
    final formatadas = dados.linhasFormatadas;
    for (var i = 0; i < dados.linhas.length; i++) {
      final altura =
          alturaLinha(formatadas[i], dados.linhasDestaque.contains(i));
      if (paginas.isEmpty ||
          (alturaAtual + altura > 1600 * math.sqrt2 &&
              paginas.last.isNotEmpty)) {
        paginas.add([]);
        alturaAtual = base;
      }
      paginas.last.add(dados.linhas[i]);
      alturaAtual += altura;
    }
    return paginas;
  }

  /// Desenha todas as linhas, incluindo as que estão fora da área visível.
  static Future<Uint8List> gerarImagem({
    required DadosRelatorioExportacao dados,
    ConteudoImagemRelatorio conteudo = ConteudoImagemRelatorio.completo,
    bool horizontal = false,
    bool dividirEmPaineis = true,
    List<ImagemGraficoRelatorio>? imagensGraficos,
    bool paginaVertical = false,
    bool centrarCelulas = false,
  }) async {
    final data = DateFormat('dd/MM/yyyy');
    final largura = horizontal ? 2400 : 1600;
    const margem = 48.0;
    final util = largura - margem * 2;
    const escuro = ui.Color(0xff17343c);
    const branco = ui.Color(0xffffffff);
    final proporcoes = dados.proporcoes ??
        List.filled(dados.cabecalhos.length, 1 / dados.cabecalhos.length);

    ui.Paragraph texto(String valor, double limite,
        {double tamanho = 22,
        bool negrito = false,
        bool centrar = false,
        ui.Color cor = escuro}) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: centrar ? ui.TextAlign.center : ui.TextAlign.left,
        fontFamily: 'Montserrat',
        fontSize: tamanho,
        fontWeight: negrito ? ui.FontWeight.w700 : ui.FontWeight.w400,
      ))
        ..pushStyle(ui.TextStyle(color: cor));
      builder.addText(valor);
      return builder.build()..layout(ui.ParagraphConstraints(width: limite));
    }

    final introducao = [
      texto(dados.titulo, util, tamanho: 36, negrito: true),
      texto(dados.unidade, util, tamanho: 26),
      texto('${data.format(dados.inicio)} a ${data.format(dados.fim)}', util),
      for (final detalhe in dados.detalhes) texto(detalhe, util),
    ];
    final linhas = [
      if (conteudo != ConteudoImagemRelatorio.grafico) ...[
        dados.cabecalhos,
        ...dados.linhasFormatadas,
      ],
    ];
    final paragrafos = <List<ui.Paragraph>>[];
    final alturas = <double>[];
    for (var i = 0; i < linhas.length; i++) {
      final celulas = [
        for (var coluna = 0; coluna < proporcoes.length; coluna++)
          texto(linhas[i][coluna], util * proporcoes[coluna] - 24,
              tamanho: dados.tamanhoFonteImagem,
              centrar: dados.colunasCentradas.contains(coluna),
              negrito: i == 0 ||
                  dados.linhasDestaque.contains(i - 1) ||
                  dados.colunasNegrito.contains(coluna),
              cor: i == 0 ? branco : escuro),
      ];
      paragrafos.add(celulas);
      alturas.add(celulas.map((p) => p.height).reduce(math.max) + 32);
    }
    final graficos = <ui.Image>[];
    try {
      for (final grafico in imagensGraficos ??
          await RelatorioGraficosExportacaoService.gerar(
              conteudo == ConteudoImagemRelatorio.tabela ? [] : dados.graficos,
              largura: util.toInt(),
              diasPorPainel: horizontal ? 24 : 12)) {
        final codec = await ui.instantiateImageCodec(grafico.bytes);
        try {
          graficos.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
      final alturaIntroducao =
          introducao.fold(0.0, (total, p) => total + p.height + 16) + 16;
      final alturaBase = margem * 2 + alturaIntroducao;
      // Períodos longos são distribuídos em painéis na mesma imagem, com o
      // cabeçalho repetido. Evita criar uma textura excessivamente alta.
      final alturaCabecalho = alturas.firstOrNull ?? 0;
      final limitePainel = math.max(horizontal ? 1350.0 : 6000.0,
          alturaBase + alturaCabecalho + alturas.fold(0.0, math.max));
      final blocos = [
        for (final grafico in graficos)
          _BlocoImagemRelatorio(
            grafico: grafico,
            altura: grafico.height * util / grafico.width + 24,
          ),
        for (var i = 0; i < paragrafos.length; i++)
          _BlocoImagemRelatorio(linha: i, altura: alturas[i]),
      ];
      final paineis = <List<_BlocoImagemRelatorio>>[[]];
      final alturasPaineis = <double>[alturaBase];
      for (final bloco in blocos) {
        if (dividirEmPaineis &&
            alturasPaineis.last + bloco.altura > limitePainel &&
            paineis.last.isNotEmpty) {
          paineis.add([]);
          alturasPaineis.add(alturaBase);
          if (bloco.linha != null && bloco.linha != 0) {
            paineis.last
                .add(_BlocoImagemRelatorio(linha: 0, altura: alturas.first));
            alturasPaineis[alturasPaineis.length - 1] += alturas.first;
          }
        }
        paineis.last.add(bloco);
        alturasPaineis[alturasPaineis.length - 1] += bloco.altura;
      }
      final alturaPainel = math
          .max(alturasPaineis.reduce(math.max),
              paginaVertical ? largura * math.sqrt2 : 0)
          .ceil();
      final colunas = math.min(
          paineis.length,
          math
              .sqrt(paineis.length *
                  alturaPainel /
                  largura *
                  (horizontal ? 16 / 9 : 1))
              .ceil());
      final filas = (paineis.length / colunas).ceil();
      final gravador = ui.PictureRecorder();
      final canvas = ui.Canvas(gravador);
      canvas.drawColor(branco, ui.BlendMode.src);
      for (var painel = 0; painel < paineis.length; painel++) {
        final origemX = (painel % colunas) * largura.toDouble();
        final origemY = (painel ~/ colunas) * alturaPainel.toDouble();
        var y = origemY + margem;
        for (final paragrafo in introducao) {
          canvas.drawParagraph(paragrafo, ui.Offset(origemX + margem, y));
          y += paragrafo.height + 16;
        }
        y += 16;
        for (final bloco in paineis[painel]) {
          final grafico = bloco.grafico;
          if (grafico != null) {
            canvas.drawImageRect(
              grafico,
              ui.Rect.fromLTWH(
                  0, 0, grafico.width.toDouble(), grafico.height.toDouble()),
              ui.Rect.fromLTWH(origemX + margem, y, util, bloco.altura - 24),
              ui.Paint()..filterQuality = ui.FilterQuality.high,
            );
            y += bloco.altura;
            continue;
          }
          final i = bloco.linha!;
          canvas.drawRect(
            ui.Rect.fromLTWH(origemX + margem, y, util, alturas[i]),
            ui.Paint()
              ..color = i == 0
                  ? escuro
                  : (i.isOdd ? const ui.Color(0xfff0f5f5) : branco),
          );
          var x = origemX + margem;
          for (var coluna = 0; coluna < proporcoes.length; coluna++) {
            canvas.drawParagraph(
                paragrafos[i][coluna],
                ui.Offset(
                    x + 12,
                    centrarCelulas
                        ? y + (alturas[i] - paragrafos[i][coluna].height) / 2
                        : y + 16));
            if (dados.grelhaImagem) {
              canvas.drawRect(
                ui.Rect.fromLTWH(x, y, util * proporcoes[coluna], alturas[i]),
                ui.Paint()
                  ..color = escuro
                  ..style = ui.PaintingStyle.stroke
                  ..strokeWidth = 1.2,
              );
            }
            x += util * proporcoes[coluna];
          }
          y += alturas[i];
        }
        if (paineis.length > 1) {
          canvas.drawParagraph(
            texto('Parte ${painel + 1} de ${paineis.length}', util,
                tamanho: 16),
            ui.Offset(origemX + margem, origemY + alturaPainel - 32),
          );
        }
      }
      final desenho = gravador.endRecording();
      final imagem =
          await desenho.toImage(largura * colunas, alturaPainel * filas);
      try {
        final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Não foi possível criar a imagem.');
        return bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      } finally {
        imagem.dispose();
        desenho.dispose();
      }
    } finally {
      for (final grafico in graficos) {
        grafico.dispose();
      }
    }
  }
}

class _BlocoImagemRelatorio {
  final int? linha;
  final ui.Image? grafico;
  final double altura;

  const _BlocoImagemRelatorio({this.linha, this.grafico, required this.altura});
}
