import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';

import '../models/grafico_relatorio_exportacao.dart';
import '../models/relatorio_horas_especialidade.dart';
import '../utils/app_theme.dart';

class ImagemGraficoRelatorio {
  final Uint8List bytes;
  final int largura, altura;

  const ImagemGraficoRelatorio(this.bytes,
      {required this.largura, required this.altura});
}

/// Renderiza os gráficos completos, sem depender da área visível do ecrã.
class RelatorioGraficosExportacaoService {
  static const _escuro = ui.Color(0xff17343c);
  static const _cinzento = ui.Color(0xff60737a);
  static const _linha = ui.Color(0xffdbe5e7);

  static Future<List<ImagemGraficoRelatorio>> gerar(
      List<GraficoRelatorioExportacao> graficos,
      {Future<void> Function(int)? onImagemGerada,
      int largura = 1504,
      int diasPorPainel = 12}) async {
    final imagens = <ImagemGraficoRelatorio>[];
    var geradas = 0;
    Future<ImagemGraficoRelatorio> renderizar(
        int largura, int altura, void Function(ui.Canvas) desenhar) async {
      final imagem = await _imagem(largura, altura, desenhar);
      await onImagemGerada?.call(++geradas);
      return imagem;
    }

    for (final grafico in graficos) {
      switch (grafico) {
        case GraficoHorasMedicoExportacao(:final relatorio):
          for (var inicio = 0; inicio < relatorio.medicos.length; inicio += 5) {
            final parte = relatorio.medicos.sublist(
                inicio, math.min(inicio + 5, relatorio.medicos.length));
            const larguraBase = 1504.0;
            final alturaBase = 60 + parte.length * 280;
            final escala = largura / larguraBase;
            imagens.add(await renderizar(largura, (alturaBase * escala).ceil(),
                (canvas) {
              canvas.scale(escala);
              _texto(canvas, 'Contribuição e comparação de horas por médico', 0,
                  0, larguraBase,
                  tamanho: 30, negrito: true);
              for (var i = 0; i < parte.length; i++) {
                _horasMedico(
                    canvas, parte[i], relatorio, 60 + i * 280.0, larguraBase);
              }
            }));
          }
        case GraficoHorasEspecialidadeExportacao():
          const larguraBase = 1504.0;
          final escala = largura / larguraBase;
          for (var inicio = 0;
              inicio < math.max(grafico.linhas.length, 1);
              inicio += 9) {
            final parte = grafico.linhas
                .sublist(inicio, math.min(inicio + 9, grafico.linhas.length));
            final filas = math.max(1, (parte.length / 3).ceil());
            imagens.add(await renderizar(
                largura, ((60 + filas * 480) * escala).ceil(), (canvas) {
              canvas.scale(escala);
              _texto(canvas, 'Horas por especialidade', 0, 0, larguraBase,
                  tamanho: 32, negrito: true);
              if (parte.isEmpty) {
                _texto(canvas, 'Sem disponibilidade no período selecionado.', 0,
                    280, larguraBase,
                    centrado: true);
              }
              for (var i = 0; i < parte.length; i++) {
                final linha = parte[i];
                final proporcao = grafico.totalMedicosAtivosClinica > 0
                    ? (linha.medicosComDisponibilidade /
                            grafico.totalMedicosAtivosClinica)
                        .clamp(0.0, 1.0)
                    : 0.0;
                canvas.save();
                canvas.translate(0, (i ~/ 3) * 480.0);
                _horasEspecialidade(canvas,
                    x: (i % 3) * (larguraBase / 3),
                    largura: larguraBase / 3,
                    nome: linha.especialidade,
                    medicos: linha.medicosComDisponibilidade,
                    totalMedicos: grafico.totalMedicosAtivosClinica,
                    proporcao: proporcao,
                    horas: linha.horasConsulta,
                    media: linha.mediaHorasPorMedico);
                canvas.restore();
              }
            }));
          }
        case GraficoTaxasExportacao(:final taxas):
          // Três colunas e até três filas por página vertical.
          for (var inicio = 0; inicio < taxas.length; inicio += 9) {
            final parte =
                taxas.sublist(inicio, math.min(inicio + 9, taxas.length));
            final filas = (parte.length / 3).ceil();
            const larguraBase = 1504.0;
            final escala = largura / larguraBase;
            imagens.add(await renderizar(
                largura, ((60 + filas * 480) * escala).ceil(), (canvas) {
              canvas.scale(escala);
              _texto(canvas, 'Taxas de ocupação', 0, 0, larguraBase,
                  tamanho: 32, negrito: true);
              for (var i = 0; i < parte.length; i++) {
                canvas.save();
                canvas.translate(0, (i ~/ 3) * 480.0);
                _taxa(canvas, parte[i], (i % 3) * (larguraBase / 3),
                    larguraBase.toInt());
                canvas.restore();
              }
            }));
          }
        case GraficoOcupacaoExportacao():
          // O PDF conserva doze dias; a imagem horizontal aproveita mais largura.
          for (var inicio = 0;
              inicio < math.max(grafico.dias.length, 1);
              inicio += diasPorPainel) {
            final dias = grafico.dias.sublist(
                inicio, math.min(inicio + diasPorPainel, grafico.dias.length));
            imagens.add(await renderizar(largura, 640,
                (canvas) => _ocupacao(canvas, grafico, dias, largura)));
          }
      }
    }
    return imagens;
  }

  static Future<ImagemGraficoRelatorio> _imagem(
      int largura, int altura, void Function(ui.Canvas) desenhar) async {
    final gravador = ui.PictureRecorder();
    final canvas = ui.Canvas(gravador);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    desenhar(canvas);
    final desenho = gravador.endRecording();
    final imagem = await desenho.toImage(largura, altura);
    try {
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null) throw StateError('Não foi possível criar o gráfico.');
      return ImagemGraficoRelatorio(
          dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
          largura: largura,
          altura: altura);
    } finally {
      imagem.dispose();
      desenho.dispose();
    }
  }

  static void _texto(
      ui.Canvas canvas, String texto, double x, double y, double limite,
      {double tamanho = 22,
      bool negrito = false,
      bool centrado = false,
      ui.Color cor = _escuro,
      int? maxLinhas}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: 'Montserrat',
      fontSize: tamanho,
      fontWeight: negrito ? ui.FontWeight.w700 : ui.FontWeight.w400,
      textAlign: centrado ? ui.TextAlign.center : ui.TextAlign.left,
      maxLines: maxLinhas,
      ellipsis: maxLinhas == null ? null : '…',
    ))
      ..pushStyle(ui.TextStyle(color: cor));
    builder.addText(texto);
    final paragrafo = builder.build()
      ..layout(ui.ParagraphConstraints(width: limite));
    canvas.drawParagraph(paragrafo, ui.Offset(x, y));
    paragrafo.dispose();
  }

  static String _numero(double valor) =>
      NumberFormat('#,##0.##', 'pt_PT').format(valor);

  static String _percentagem(double valor) =>
      '${valor.toStringAsFixed(1).replaceAll('.', ',')}%';

  static double _larguraTexto(String texto, double tamanho,
      {bool negrito = false}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: 'Montserrat',
        fontSize: tamanho,
        fontWeight: negrito ? ui.FontWeight.w700 : ui.FontWeight.w400))
      ..addText(texto);
    final paragrafo = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 10000));
    final largura = paragrafo.maxIntrinsicWidth;
    paragrafo.dispose();
    return largura;
  }

  static void _horasMedico(ui.Canvas canvas, RelatorioHorasMedicoLinha medico,
      RelatorioHorasEspecialidade relatorio, double y, double largura) {
    final especialidade = relatorio.especialidadesClinica[medico.especialidade];
    final percentual =
        medico.percentagemContribuicao(relatorio.totalHorasConsultaClinica);
    final corClinica = MyAppTheme.corOcupacao(percentual);
    const corEspecialidade = ui.Color(0xff287c70);
    final caixa = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(18, y, largura - 36, 264),
        const ui.Radius.circular(18));
    canvas.drawRRect(
        caixa, ui.Paint()..color = corClinica.withValues(alpha: 0.04));
    canvas.drawRRect(
        caixa,
        ui.Paint()
          ..color = _linha
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2);
    final nomeLargura =
        math.min(_larguraTexto(medico.nome, 25, negrito: true), largura * 0.45);
    final especialidadeLargura =
        math.min(_larguraTexto(medico.especialidade, 20), largura * 0.28);
    const xHoras = 42.0;
    const xNome = xHoras + 150 + 24;
    _texto(canvas, medico.nome, xNome, y + 23, nomeLargura + 1,
        tamanho: 25, negrito: true, maxLinhas: 1);
    final xEspecialidade = xNome + nomeLargura + 20;
    _texto(canvas, medico.especialidade, xEspecialidade, y + 28,
        especialidadeLargura + 1,
        tamanho: 20, cor: _cinzento, maxLinhas: 1);
    canvas.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(xHoras, y + 13, 150, 53),
            const ui.Radius.circular(12)),
        ui.Paint()..color = const ui.Color(0xffdfedf2));
    _texto(
        canvas, '${_numero(medico.horasConsulta)} h', xHoras + 8, y + 21, 134,
        tamanho: 29, negrito: true, centrado: true, maxLinhas: 1);

    final coluna = (largura - 124) / 2;
    for (final (x, grupo, total, quantidade, media, cor, daEspecialidade) in [
      (
        42.0,
        medico.especialidade,
        especialidade?.horasConsulta,
        especialidade?.medicosAtivos,
        especialidade?.mediaHorasPorMedicoAtivo,
        corEspecialidade,
        true
      ),
      (
        82 + coluna,
        'todos os médicos',
        relatorio.totalHorasConsultaClinica,
        relatorio.totalMedicosAtivosClinica,
        relatorio.mediaHorasPorMedicoClinica,
        corClinica,
        false
      ),
    ]) {
      _contribuicaoMedico(canvas,
          x: x,
          y: y + 84,
          largura: 144,
          grupo: grupo,
          destacarGrupo: daEspecialidade,
          horas: medico.horasConsulta,
          total: total,
          cor: cor);
      _comparacaoMedia(canvas,
          x: x + 164,
          y: y + 84,
          largura: coluna - 164,
          especialidade: daEspecialidade,
          nomeEspecialidade: medico.especialidade,
          quantidade: quantidade,
          horas: medico.horasConsulta,
          total: total,
          media: media,
          limite: relatorio.limiteComparacaoHoras,
          cor: cor);
    }
  }

  static void _contribuicaoMedico(ui.Canvas canvas,
      {required double x,
      required double y,
      required double largura,
      required String grupo,
      bool destacarGrupo = false,
      required double horas,
      required double? total,
      required ui.Color cor}) {
    final percentual = (total ?? 0) > 0 ? horas / total! * 100 : 0.0;
    final centro = ui.Offset(x + largura / 2, y + 72);
    canvas.drawCircle(
        centro,
        64,
        ui.Paint()
          ..color = _linha
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 12);
    canvas.drawArc(
        ui.Rect.fromCircle(center: centro, radius: 64),
        -math.pi / 2,
        2 * math.pi * (percentual / 100).clamp(0, 1),
        false,
        ui.Paint()
          ..color = cor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 12);
    if (total == null) {
      _texto(canvas, 'Dados indisponíveis', centro.dx - 54, y + 52, 108,
          tamanho: 18, centrado: true, maxLinhas: 2);
      return;
    }
    _texto(canvas, '${NumberFormat('0.#', 'pt_PT').format(percentual)}%',
        centro.dx - 60, y + 32, 120,
        tamanho: 26, negrito: true, centrado: true, cor: cor);
    _texto(canvas, 'de ${_numero(total)} h', centro.dx - 60, y + 65, 120,
        tamanho: 16, centrado: true, maxLinhas: 1);
    _texto(canvas, grupo, centro.dx - 60, y + 85, 120,
        tamanho: 11,
        negrito: destacarGrupo,
        centrado: true,
        cor: _cinzento,
        maxLinhas: 2);
  }

  static void _comparacaoMedia(ui.Canvas canvas,
      {required double x,
      required double y,
      required double largura,
      required bool especialidade,
      required String nomeEspecialidade,
      required int? quantidade,
      required double horas,
      required double? total,
      required double? media,
      required double limite,
      required ui.Color cor}) {
    final numeroMedicos = quantidade == null
        ? 'Médicos de $nomeEspecialidade'
        : '$quantidade ${quantidade == 1 ? 'médico' : 'médicos'}${especialidade ? ' de $nomeEspecialidade' : ''}';
    _texto(canvas, numeroMedicos, x, y, largura, tamanho: 18);
    canvas.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(x, y + 97, largura, 12),
            const ui.Radius.circular(6)),
        ui.Paint()..color = _linha);
    final preenchida = largura * (horas / limite).clamp(0, 1);
    if (preenchida > 0) {
      canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(x, y + 97, preenchida, 12),
              const ui.Radius.circular(6)),
          ui.Paint()..color = cor);
    }
    if (media != null) {
      final ponta = x + largura * (media / limite).clamp(0, 1);
      final esquerda = (ponta - 52).clamp(x, x + largura - 104);
      final base = ponta.clamp(esquerda + 14, esquerda + 90);
      final tinta = ui.Paint()
        ..color = especialidade
            ? const ui.Color(0xff23665c)
            : const ui.Color(0xff315769);
      final seta = ui.Path()
        ..moveTo(base - 8, y + 82)
        ..lineTo(ponta, y + 103)
        ..lineTo(base + 8, y + 82)
        ..close();
      canvas.drawPath(seta, tinta);
      canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              ui.Rect.fromLTWH(esquerda, y + 35, 104, 48),
              const ui.Radius.circular(12)),
          tinta);
      _texto(canvas, 'Média', esquerda + 6, y + 40, 92,
          tamanho: 14, centrado: true, cor: const ui.Color(0xffffffff));
      _texto(canvas, '${_numero(media)} h', esquerda + 6, y + 58, 92,
          tamanho: 18,
          negrito: true,
          centrado: true,
          cor: const ui.Color(0xffffffff),
          maxLinhas: 1);
    }
    final diferenca = horas - (media ?? 0);
    final estado = media == null
        ? 'Média indisponível'
        : diferenca.abs() < 1e-9
            ? 'Na média'
            : '${_numero(diferenca.abs())} h ${diferenca > 0 ? 'acima' : 'abaixo'} da média';
    _texto(
        canvas,
        '${total == null ? 'Total indisponível' : 'Total: ${_numero(total)} h'} ($estado)',
        x,
        y + 127,
        largura,
        tamanho: 17,
        maxLinhas: 2);
  }

  static void _horasEspecialidade(ui.Canvas canvas,
      {required double x,
      required double largura,
      required String nome,
      required int medicos,
      required int totalMedicos,
      required double proporcao,
      required double horas,
      required double media}) {
    const margem = 18.0;
    final util = largura - margem * 2;
    final cor = MyAppTheme.corOcupacao(proporcao * 100);
    final caixa = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(x + margem, 60, util, 460),
        const ui.Radius.circular(18));
    canvas.drawRRect(caixa, ui.Paint()..color = cor.withValues(alpha: 0.04));
    canvas.drawRRect(
        caixa,
        ui.Paint()
          ..color = cor.withValues(alpha: 0.2)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2);
    _texto(canvas, nome, x + margem + 16, 80, util - 32,
        tamanho: 25, negrito: true, centrado: true, maxLinhas: 2);
    _texto(
        canvas,
        '${_percentagem(proporcao * 100)} dos $totalMedicos médicos ativos da clínica',
        x + margem + 16,
        150,
        util - 32,
        tamanho: 19,
        centrado: true,
        maxLinhas: 2,
        cor: cor);
    final centro = ui.Offset(x + largura / 2, 270);
    const raio = 70.0;
    canvas.drawCircle(
        centro,
        raio,
        ui.Paint()
          ..color = _linha
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 20);
    canvas.drawArc(
        ui.Rect.fromCircle(center: centro, radius: raio),
        -math.pi / 2,
        2 * math.pi * proporcao,
        false,
        ui.Paint()
          ..color = cor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = ui.StrokeCap.round);
    _texto(canvas, '$medicos', x + margem, 237, util,
        tamanho: 38, negrito: true, centrado: true, cor: cor);
    _texto(canvas, 'médicos', x + margem, 288, util,
        tamanho: 20, centrado: true, cor: _cinzento);
    final metade = util / 2;
    for (final (indice, titulo, valor) in [
      (0, 'Total de horas', horas),
      (1, 'Média por médico', media),
    ]) {
      _texto(canvas, titulo, x + margem + indice * metade, 368, metade,
          tamanho: 19, centrado: true, cor: _cinzento);
      _texto(canvas, '${_numero(valor)} h', x + margem + indice * metade, 405,
          metade,
          tamanho: 30, negrito: true, centrado: true);
    }
    _texto(canvas, 'Disponibilidade efetiva no período', x + margem + 8, 470,
        util - 16,
        tamanho: 18, centrado: true, cor: _cinzento);
  }

  static void _taxa(
      ui.Canvas canvas, TaxaGraficoExportacao taxa, double x, int largura) {
    const espaco = 18.0;
    final util = largura / 3 - espaco * 2;
    final caixa = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(x + espaco, 60, util, 460),
        const ui.Radius.circular(16));
    canvas.drawRRect(caixa, ui.Paint()..color = MyAppTheme.gabineteOcupado);
    canvas.drawRRect(
        caixa,
        ui.Paint()
          ..color = MyAppTheme.bordaGabineteOcupado
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2);
    _texto(canvas, taxa.titulo, x + espaco + 16, 80, util - 32,
        negrito: true, centrado: true, maxLinhas: 2);
    _texto(canvas, taxa.descricao, x + espaco + 16, 140, util - 32,
        tamanho: 19, centrado: true, maxLinhas: 2, cor: _cinzento);
    final centro = ui.Offset(x + largura / 6, 310);
    const raio = 86.0;
    canvas.drawCircle(
        centro,
        raio,
        ui.Paint()
          ..color = MyAppTheme.bordaGabineteOcupado
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 26);
    canvas.drawArc(
        ui.Rect.fromCircle(center: centro, radius: raio),
        -math.pi / 2,
        2 * math.pi * (taxa.percentagem / 100).clamp(0, 1),
        false,
        ui.Paint()
          ..color = MyAppTheme.corOcupacao(taxa.percentagem)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 26);
    _texto(canvas, _percentagem(taxa.percentagem), x + espaco, 290, util,
        tamanho: 32, negrito: true, centrado: true);
    _texto(
        canvas,
        '${_numero(taxa.horasOcupadas)} h de ${_numero(taxa.horasDisponiveis)} h',
        x + espaco + 8,
        430,
        util - 16,
        centrado: true);
    _texto(
        canvas,
        taxa.horasDisponiveis > 0
            ? 'Horas ocupadas / disponíveis'
            : 'Sem horas disponíveis',
        x + espaco + 8,
        470,
        util - 16,
        tamanho: 18,
        centrado: true,
        cor: _cinzento);
  }

  static void _ocupacao(ui.Canvas canvas, GraficoOcupacaoExportacao grafico,
      List<DiaGraficoExportacao> dias, int largura) {
    _texto(
        canvas,
        grafico.porHora ? 'Ocupação por dia e hora' : 'Ocupação por dia',
        0,
        0,
        largura.toDouble(),
        tamanho: 32,
        negrito: true);
    if (dias.isEmpty) {
      _texto(canvas, 'Sem dados úteis no período selecionado.', 0, 260,
          largura.toDouble(),
          centrado: true);
      return;
    }
    final ocupadas =
        grafico.dias.fold(0.0, (total, dia) => total + dia.horasOcupadas);
    final disponiveis =
        grafico.dias.fold(0.0, (total, dia) => total + dia.horasDisponiveis);
    _texto(
        canvas,
        '${_percentagem(disponiveis > 0 ? ocupadas / disponiveis * 100 : 0)} de ocupação no período · '
        'Horas ocupadas / disponíveis',
        0,
        54,
        largura.toDouble(),
        tamanho: 21,
        cor: _cinzento);
    const esquerda = 92.0;
    const topo = 150.0;
    const altura = 350.0;
    const fundo = topo + altura;
    final util = largura - esquerda - 16;
    final passo = util / math.max(dias.length, 7);
    final inicio =
        grafico.dias.map((dia) => dia.inicioMinutos).reduce(math.min);
    final fim = grafico.dias.map((dia) => dia.fimMinutos).reduce(math.max);
    final totalMinutos = math.max(fim - inicio, 1);

    void linha(double y, String legenda) {
      canvas.drawLine(const ui.Offset(esquerda, 0).translate(0, y),
          ui.Offset(largura - 16, y), ui.Paint()..color = _linha);
      _texto(canvas, legenda, 0, y - 12, esquerda - 14,
          tamanho: 18, centrado: true, cor: _cinzento);
    }

    if (grafico.porHora) {
      final passoHora = totalMinutos > 12 * 60 ? 120 : 60;
      final marcas = <int>{inicio, fim};
      for (var m = ((inicio ~/ passoHora) + 1) * passoHora;
          m < fim;
          m += passoHora) {
        if (m - inicio >= 30 && fim - m >= 30) marcas.add(m);
      }
      for (final m in marcas) {
        linha(topo + (m - inicio) / totalMinutos * altura,
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
      }
    } else {
      for (var p = 0; p <= 100; p += 20) {
        linha(fundo - p / 100 * altura, '$p%');
      }
    }

    for (var i = 0; i < dias.length; i++) {
      final dia = dias[i];
      final x = esquerda + i * passo;
      final larguraBarra = passo * 0.65;
      final centro = x + passo / 2;
      final cor = MyAppTheme.corOcupacao(dia.percentagem);
      void barra(double y, double h) {
        final rect =
            ui.Rect.fromLTWH(centro - larguraBarra / 2, y, larguraBarra, h);
        canvas.drawRRect(
            ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(5)),
            ui.Paint()..color = cor);
      }

      if (grafico.porHora) {
        for (final intervalo in dia.intervalos) {
          final de = intervalo.inicio.clamp(inicio, fim);
          final ate = intervalo.fim.clamp(inicio, fim);
          if (ate <= de) continue;
          barra(topo + (de - inicio) / totalMinutos * altura,
              (ate - de) / totalMinutos * altura);
        }
      } else {
        final h = dia.percentagem.clamp(0, 100) / 100 * altura;
        if (h > 0) barra(fundo - h, h);
      }
      _texto(canvas, _percentagem(dia.percentagem), x, 112, passo,
          tamanho: 19, negrito: true, centrado: true);
      _texto(canvas, DateFormat('dd/MM').format(dia.data), x, fundo + 14, passo,
          tamanho: 20, centrado: true);
      _texto(
          canvas,
          const [
            'Seg',
            'Ter',
            'Qua',
            'Qui',
            'Sex',
            'Sáb',
            'Dom'
          ][dia.data.weekday - 1],
          x,
          fundo + 44,
          passo,
          tamanho: 18,
          centrado: true,
          cor: _cinzento);
      _texto(
          canvas,
          '${_numero(dia.horasOcupadas)}h / ${_numero(dia.horasDisponiveis)}h',
          x,
          fundo + 76,
          passo,
          tamanho: 18,
          centrado: true,
          cor: _cinzento);
    }
  }
}
