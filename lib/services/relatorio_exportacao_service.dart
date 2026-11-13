import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/dados_relatorio_exportacao.dart';
import 'relatorio_graficos_exportacao_service.dart';

class RelatorioExportacaoService {
  static Future<void> guardar({
    required FormatoExportacaoRelatorio formato,
    required DadosRelatorioExportacao dados,
    required String nome,
    required Uint8List Function() gerarExcel,
    ConteudoImagemRelatorio conteudoImagem = ConteudoImagemRelatorio.completo,
    bool imagemHorizontal = false,
  }) async {
    final bytes = switch (formato) {
      FormatoExportacaoRelatorio.excel => gerarExcel(),
      FormatoExportacaoRelatorio.imagem => await gerarImagem(
          dados: dados, conteudo: conteudoImagem, horizontal: imagemHorizontal),
      FormatoExportacaoRelatorio.pdf => await gerarPdf(dados: dados),
    };
    final (extensao, mime) = switch (formato) {
      FormatoExportacaoRelatorio.excel => ('xlsx', MimeType.microsoftExcel),
      FormatoExportacaoRelatorio.imagem => ('png', MimeType.png),
      FormatoExportacaoRelatorio.pdf => ('pdf', MimeType.pdf),
    };
    await FileSaver.instance.saveFile(
      name: nome,
      bytes: bytes,
      fileExtension: extensao,
      mimeType: mime,
    );
  }

  static Future<Uint8List> gerarPdf({
    required DadosRelatorioExportacao dados,
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
    final graficos =
        await RelatorioGraficosExportacaoService.gerar(dados.graficos);
    documento.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
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
        for (final detalhe in dados.detalhes) pw.Text(detalhe),
        pw.SizedBox(height: 12),
        for (final grafico in graficos)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Image(pw.MemoryImage(grafico.bytes),
                width: PdfPageFormat.a4.landscape.width - 60),
          ),
        pw.TableHelper.fromTextArray(
          headers: dados.cabecalhos,
          data: dados.linhasFormatadas,
          columnWidths: dados.proporcoes == null
              ? null
              : {
                  for (var i = 0; i < dados.proporcoes!.length; i++)
                    i: pw.FlexColumnWidth(dados.proporcoes![i]),
                },
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xff17343c)),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.all(8),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    ));
    return documento.save();
  }

  /// Desenha todas as linhas, incluindo as que estão fora da área visível.
  static Future<Uint8List> gerarImagem({
    required DadosRelatorioExportacao dados,
    ConteudoImagemRelatorio conteudo = ConteudoImagemRelatorio.completo,
    bool horizontal = false,
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
        {double tamanho = 22, bool negrito = false, ui.Color cor = escuro}) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
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
              negrito: i == 0 || dados.linhasDestaque.contains(i - 1),
              cor: i == 0 ? branco : escuro),
      ];
      paragrafos.add(celulas);
      alturas.add(celulas.map((p) => p.height).reduce(math.max) + 32);
    }
    final graficos = <ui.Image>[];
    try {
      for (final grafico in await RelatorioGraficosExportacaoService.gerar(
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
        if (alturasPaineis.last + bloco.altura > limitePainel &&
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
      final alturaPainel = alturasPaineis.reduce(math.max).ceil();
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
                paragrafos[i][coluna], ui.Offset(x + 12, y + 16));
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
