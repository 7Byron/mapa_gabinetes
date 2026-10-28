import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../models/matriz_distribuicao.dart';
import '../utils/app_theme.dart';
import '../utils/matriz_colors.dart';
import '../utils/app_colors.dart';
import '../utils/serie_tipo_colors.dart';

/// Uma linha por gabinete, agrupada por piso, e sete colunas de uma semana, com a rotação em cada cartão.
class MatrizDistribuicaoGrid extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<MatrizDistribuicaoItem> itens;
  final double zoom;
  final int? ano;
  final bool mostrarLivres;
  final ValueChanged<MatrizDistribuicaoItem>? onEditarMedico;
  final ValueChanged<Gabinete>? onOcultarGabinete;

  const MatrizDistribuicaoGrid({
    super.key,
    required this.gabinetes,
    required this.itens,
    this.zoom = 1.0,
    this.ano,
    this.mostrarLivres = false,
    this.onEditarMedico,
    this.onOcultarGabinete,
  }) : assert(zoom > 0);

  @override
  State<MatrizDistribuicaoGrid> createState() => _MatrizDistribuicaoGridState();
}

class _MatrizDistribuicaoGridState extends State<MatrizDistribuicaoGrid> {
  final _cabecalhoHorizontal = ScrollController();
  final _corpoHorizontal = ScrollController();
  final _identificacaoVertical = ScrollController();
  final _corpoVertical = ScrollController();
  bool _sincronizando = false;
  final _celulas = <String, List<MatrizDistribuicaoItem>>{};
  final _alturasCartoes = <(MatrizDistribuicaoItem, double), double>{};
  final _alturasIdentificacao = <(Gabinete, double, bool), double>{};
  double? _larguraLivre;
  (TextStyle, TextScaler, TextDirection)? _contextoMedidas;
  int _medicoesTexto = 0;

  @visibleForTesting
  int get medicoesTexto => _medicoesTexto;

  // O filtro só muda a lista de linhas. Os dados e as medidas mantêm-se
  // válidos até mudar o conteúdo ou as dependências de apresentação.
  void _agruparItens() {
    _celulas.clear();
    final unicos = <(String, String, int, int, int, DateTime?, DateTime?),
        MatrizDistribuicaoItem>{};
    for (final item in widget.itens) {
      final chave = (
        item.serieId,
        item.gabineteId,
        (item.dia - 1) % 7 + 1,
        item.inicioMinutos,
        item.fimMinutos,
        item.validadeInicio,
        item.validadeFim
      );
      if (!unicos.containsKey(chave) || item.conflito) unicos[chave] = item;
    }
    for (final item in unicos.values) {
      _celulas
          .putIfAbsent('${item.gabineteId}_${(item.dia - 1) % 7 + 1}', () => [])
          .add(item);
    }
    for (final celula in _celulas.values) {
      celula.sort((a, b) {
        final dia = a.dia.compareTo(b.dia);
        return dia != 0 ? dia : a.inicioMinutos.compareTo(b.inicioMinutos);
      });
    }
  }

  void _limparMedidas() {
    _alturasCartoes.clear();
    _alturasIdentificacao.clear();
    _larguraLivre = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _limparMedidas();
  }

  @override
  void didUpdateWidget(covariant MatrizDistribuicaoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itens, widget.itens)) {
      _agruparItens();
      _limparMedidas();
    } else if (oldWidget.mostrarLivres != widget.mostrarLivres) {
      _limparMedidas();
    }
  }

  @override
  void initState() {
    super.initState();
    _agruparItens();
    _ligar(_cabecalhoHorizontal, _corpoHorizontal);
    _ligar(_identificacaoVertical, _corpoVertical);
  }

  void _ligar(ScrollController a, ScrollController b) {
    void sincronizar(ScrollController origem, ScrollController destino) {
      if (_sincronizando || !destino.hasClients) return;
      _sincronizando = true;
      destino
          .jumpTo(origem.offset.clamp(0.0, destino.position.maxScrollExtent));
      _sincronizando = false;
    }

    a.addListener(() => sincronizar(a, b));
    b.addListener(() => sincronizar(b, a));
  }

  @override
  void dispose() {
    _cabecalhoHorizontal.dispose();
    _corpoHorizontal.dispose();
    _identificacaoVertical.dispose();
    _corpoVertical.dispose();
    super.dispose();
  }

  static const _dias = ['2ª', '3ª', '4ª', '5ª', '6ª', 'Sáb', 'Dom'];
  static const _estiloPeriodo = TextStyle(
      fontSize: 11, color: MatrizColors.texto, fontWeight: FontWeight.normal);

  static const _estiloExcecoes = TextStyle(
      fontSize: 10, color: AppColors.textoAtencao, fontWeight: FontWeight.w600);

  Widget _cartao(MatrizDistribuicaoItem item) {
    final cartao = Container(
      padding: EdgeInsets.all(widget.mostrarLivres ? 6 : 8),
      decoration: BoxDecoration(
        color: widget.mostrarLivres
            ? MatrizColors.livre
            : item.conflito
                ? MyAppTheme.gabineteConflito
                : MatrizColors.ocupado,
        border: Border.all(
          color: widget.mostrarLivres
              ? MatrizColors.bordaLivre
              : item.conflito
                  ? MyAppTheme.bordaGabineteConflito
                  : MatrizColors.borda,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mostrarLivres) ...[
            Row(children: [
              const Text('Livre',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textoLivre)),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(_horarioLivre(item),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold))),
            ]),
            for (final periodo in _periodosLivres(item))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tooltip(
                  message: 'Consultar datas: ${periodo.descricao}',
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: MatrizColors.bordaLivre),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _mostrarDatas(item, periodo),
                      hoverColor: MatrizColors.identificacao,
                      splashColor: MatrizColors.cabecalho,
                      child: Container(
                        key: const ValueKey('disponibilidade_periodo'),
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 42),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 5),
                        alignment: Alignment.center,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text.rich(
                                      _textoPeriodo(periodo.descricao),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      softWrap: false,
                                      style: _estiloPeriodo)),
                              if (periodo.observacao != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(periodo.observacao!,
                                        textAlign: TextAlign.center,
                                        style: _estiloExcecoes)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ),
          ] else ...[
            Text(item.medicoNome,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(item.especialidade, style: const TextStyle(fontSize: 11)),
            Text(item.horario, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(_rotacao(item),
                style: TextStyle(
                    fontSize: 11,
                    color: SerieTipoColors.para(item.tipo),
                    fontWeight: FontWeight.w600)),
          ],
          if (item.periodo != null)
            Text(item.periodo!, style: const TextStyle(fontSize: 10)),
          if (item.conflito)
            const Text('Possível coincidência',
                style: TextStyle(fontSize: 10, color: MyAppTheme.vermelho)),
        ],
      ),
    );
    if (widget.mostrarLivres || widget.onEditarMedico == null) return cartao;
    return Tooltip(
      message: 'Editar ${item.medicoNome.trim()}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onEditarMedico!(item),
          child: cartao,
        ),
      ),
    );
  }

  void _mostrarDatas(
      MatrizDistribuicaoItem item, MatrizDisponibilidadePeriodo periodo) {
    final datas = periodo.datas.toList()..sort();
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Livre · ${item.horario}'),
              content: SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(periodo.descricao),
                        if (periodo.observacao != null) ...[
                          const SizedBox(height: 6),
                          Text(periodo.observacao!, style: _estiloExcecoes),
                        ],
                        const SizedBox(height: 12),
                        Text(datas
                            .map((d) =>
                                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}')
                            .join('\n')),
                      ],
                    ),
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ],
            ));
  }

  TextSpan _textoPeriodo(String periodo) {
    final separador = periodo.indexOf(' · ');
    if (separador < 0) return TextSpan(text: periodo);
    return TextSpan(children: [
      TextSpan(
          text: periodo.substring(0, separador),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.acaoHover)),
      TextSpan(text: '\n${periodo.substring(separador + 3)}'),
    ]);
  }

  String _horarioLivre(MatrizDistribuicaoItem item) =>
      item.horario.replaceAll(' – ', ' - ');

  List<MatrizDisponibilidadePeriodo> _periodosLivres(
          MatrizDistribuicaoItem item) =>
      item.disponibilidades.isNotEmpty
          ? item.disponibilidades
          : [
              MatrizDisponibilidadePeriodo(
                  descricao: item.ciclo, datas: item.ocorrencias),
            ];

  String _rotacao(MatrizDistribuicaoItem item) {
    if (item.tipo == 'Semanal' || item.tipo == 'Quinzenal') return item.tipo;
    if (item.tipo != 'Mensal') return item.ciclo;
    const dias = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo'
    ];
    final dia = (item.dia - 1) % 7;
    final feminino = dia < 5;
    if (item.ciclo.contains('última')) {
      return '${feminino ? 'Última' : 'Último'} ${dias[dia]} do mês';
    }
    final ocorrencia = int.tryParse(
            RegExp(r'(\d+)\.ª').firstMatch(item.ciclo)?.group(1) ?? '') ??
        (item.dia - 1) ~/ 7 + 1;
    return '$ocorrencia.${feminino ? 'ª' : 'º'} ${dias[dia]} do mês';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gabinetes.isEmpty) {
      return const Center(child: Text('Sem gabinetes para apresentar.'));
    }
    final gabinetes = widget.gabinetes;
    final celulas = _celulas;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        // A largura acompanha o zoom para preservar o espaço das sete colunas.
        constraints: BoxConstraints(maxWidth: 2400 * widget.zoom),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: LayoutBuilder(builder: (context, viewport) {
              return SizedBox(
                width: viewport.maxWidth,
                height: viewport.maxHeight,
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: viewport.maxWidth / widget.zoom,
                    height: viewport.maxHeight / widget.zoom,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final contextoMedidas = (
                        DefaultTextStyle.of(context).style,
                        MediaQuery.textScalerOf(context),
                        Directionality.of(context),
                      );
                      if (_contextoMedidas != contextoMedidas) {
                        _limparMedidas();
                        _contextoMedidas = contextoMedidas;
                      }
                      const larguraIdentificacao = 140.0;
                      var larguraMinimaDia =
                          widget.mostrarLivres ? 180.0 : 200.0;
                      if (widget.mostrarLivres) {
                        larguraMinimaDia =
                            _larguraLivre ??= _medirLarguraLivre(context);
                      }
                      final larguraDia = widget.mostrarLivres
                          ? larguraMinimaDia
                          : math.max(
                              larguraMinimaDia,
                              (constraints.maxWidth - larguraIdentificacao) /
                                  7);
                      final larguraSemana = larguraDia * 7;
                      final larguraCartao =
                          larguraDia - (widget.mostrarLivres ? 10 : 14);
                      double medir(MatrizDistribuicaoItem item) =>
                          _alturasCartoes.putIfAbsent((
                            item,
                            larguraCartao
                          ), () => _alturaCartao(context, item, larguraCartao));
                      final espacosPiso = <String, double>{
                        for (var i = 0; i < gabinetes.length; i++)
                          gabinetes[i].id: i > 0 &&
                                  gabinetes[i - 1].setor != gabinetes[i].setor
                              ? 14
                              : 0,
                      };
                      final alturas = <String, double>{};
                      final posicoes = <String, List<double>>{};
                      for (final gabinete in gabinetes) {
                        var altura = math.max(
                            80.0,
                            _alturasIdentificacao.putIfAbsent(
                                (
                                  gabinete,
                                  larguraIdentificacao,
                                  widget.onOcultarGabinete != null
                                ),
                                () => _alturaIdentificacao(
                                    context, gabinete, larguraIdentificacao)));
                        // Todos os dias do gabinete partilham a mesma altura.
                        for (var dia = 1; dia <= 7; dia++) {
                          final lista = celulas['${gabinete.id}_$dia'] ?? [];
                          var fim = 0.0;
                          final offsets = <double>[];
                          for (final item in lista) {
                            // A partir das 08h, cada hora desloca o cartão 16px para baixo.
                            final horario = math.max(
                                0.0, (item.inicioMinutos - 8 * 60) / 60 * 16);
                            final topo = math.max(horario, fim);
                            offsets.add(topo);
                            fim = topo + medir(item) + 6;
                          }
                          posicoes['${gabinete.id}_$dia'] = offsets;
                          altura = math.max(altura, fim + 14);
                        }
                        alturas[gabinete.id] = altura;
                      }
                      Widget cabecalhos() => Row(children: [
                            for (var semana = 0; semana < 1; semana++)
                              SizedBox(
                                  width: larguraSemana,
                                  child: Column(children: [
                                    Container(
                                        height: 42,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: MatrizColors.cabecalho,
                                            border: Border.symmetric(
                                                vertical: BorderSide(
                                                    color:
                                                        MatrizColors.borda))),
                                        child: Text(
                                            widget.ano == null
                                                ? 'Semana tipo'
                                                : 'Semana tipo · ${widget.ano}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Row(children: [
                                      for (final dia in _dias)
                                        Container(
                                            width: larguraDia,
                                            height: 42,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                                color:
                                                    MatrizColors.identificacao,
                                                border: Border.all(
                                                    color: MatrizColors.borda)),
                                            child: Text(dia,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                    ]),
                                  ])),
                          ]);

                      Widget linha(Gabinete gabinete) => Row(children: [
                            for (var dia = 1; dia <= 7; dia++)
                              Container(
                                key: ValueKey('celula_${gabinete.id}_$dia'),
                                margin: EdgeInsets.only(
                                    top: espacosPiso[gabinete.id]!),
                                height: alturas[gabinete.id],
                                width: larguraDia,
                                padding: EdgeInsets.all(
                                    widget.mostrarLivres ? 4 : 6),
                                decoration: BoxDecoration(
                                    border: Border(
                                        left: BorderSide(
                                            color: (dia - 1) % 7 == 0
                                                ? MatrizColors.borda
                                                : MatrizColors.linha),
                                        right: BorderSide(
                                            color: MatrizColors.linha),
                                        top: BorderSide(
                                            color: MatrizColors.linha),
                                        bottom: BorderSide(
                                            color: MatrizColors.linha))),
                                child: Stack(children: [
                                  for (var i = 0;
                                      i <
                                          (celulas['${gabinete.id}_$dia']
                                                  ?.length ??
                                              0);
                                      i++)
                                    Positioned(
                                        top:
                                            posicoes['${gabinete.id}_$dia']![i],
                                        left: 0,
                                        right: 0,
                                        child: _cartao(celulas[
                                            '${gabinete.id}_$dia']![i])),
                                ]),
                              ),
                          ]);

                      return Column(children: [
                        // Os dois cabeçalhos não participam na rolagem vertical.
                        Row(children: [
                          const SizedBox(
                              width: larguraIdentificacao,
                              height: 84,
                              child: Center(
                                  child: Text('Piso / Gabinete',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)))),
                          Expanded(
                              child: SingleChildScrollView(
                                  key: const ValueKey(
                                      'matriz_cabecalho_horizontal'),
                                  controller: _cabecalhoHorizontal,
                                  scrollDirection: Axis.horizontal,
                                  child: cabecalhos())),
                        ]),
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              SizedBox(
                                  width: larguraIdentificacao,
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: SingleChildScrollView(
                                          controller: _identificacaoVertical,
                                          child: Column(children: [
                                            for (var i = 0;
                                                i < gabinetes.length;
                                                i++)
                                              Container(
                                                  margin: EdgeInsets.only(
                                                      top: espacosPiso[
                                                          gabinetes[i].id]!),
                                                  height:
                                                      alturas[gabinetes[i].id],
                                                  width: larguraIdentificacao,
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: MatrizColors
                                                          .identificacao,
                                                      border: Border.all(
                                                          color: MatrizColors
                                                              .borda)),
                                                  child: Column(
                                                      mainAxisSize:
                                                          widget.onOcultarGabinete == null
                                                              ? MainAxisSize.min
                                                              : MainAxisSize.max,
                                                      children: [
                                                        Text(
                                                            gabinetes[i]
                                                                    .setor
                                                                    .isEmpty
                                                                ? 'Sem piso'
                                                                : gabinetes[i]
                                                                    .setor,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                        Text(gabinetes[i].nome,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                        if (gabinetes[i]
                                                            .especialidadesPermitidas
                                                            .isNotEmpty)
                                                          Text(
                                                            gabinetes[i]
                                                                .especialidadesPermitidas
                                                                .join(', '),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12),
                                                          ),
                                                        if (widget
                                                                .onOcultarGabinete !=
                                                            null)
                                                          Expanded(
                                                              child: Center(
                                                                  child:
                                                                      Tooltip(
                                                            message:
                                                                'Ocultar ${gabinetes[i].nome}',
                                                            child: Checkbox(
                                                              key: ValueKey(
                                                                  'grelha_mostrar_gabinete_${gabinetes[i].id}'),
                                                              activeColor:
                                                                  MatrizColors
                                                                      .lateral,
                                                              value: true,
                                                              onChanged:
                                                                  (valor) {
                                                                if (valor ==
                                                                    false) {
                                                                  widget.onOcultarGabinete!(
                                                                      gabinetes[
                                                                          i]);
                                                                }
                                                              },
                                                            ),
                                                          ))),
                                                      ])),
                                          ])))),
                              Expanded(
                                  child: Scrollbar(
                                      controller: _corpoHorizontal,
                                      thumbVisibility: true,
                                      scrollbarOrientation:
                                          ScrollbarOrientation.bottom,
                                      notificationPredicate: (notification) =>
                                          notification.metrics.axis ==
                                          Axis.horizontal,
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 14),
                                          child: SingleChildScrollView(
                                            key: const ValueKey(
                                                'matriz_corpo_horizontal'),
                                            controller: _corpoHorizontal,
                                            scrollDirection: Axis.horizontal,
                                            child: SizedBox(
                                                width: larguraSemana,
                                                child: Scrollbar(
                                                    controller: _corpoVertical,
                                                    notificationPredicate:
                                                        (notification) =>
                                                            notification
                                                                .metrics.axis ==
                                                            Axis.vertical,
                                                    child: ListView.builder(
                                                      key: const ValueKey(
                                                          'matriz_corpo_vertical'),
                                                      controller:
                                                          _corpoVertical,
                                                      padding: EdgeInsets.zero,
                                                      itemCount:
                                                          gabinetes.length,
                                                      itemExtentBuilder: (index,
                                                              dimensions) =>
                                                          alturas[
                                                              gabinetes[index]
                                                                  .id]! +
                                                          espacosPiso[
                                                              gabinetes[index]
                                                                  .id]!,
                                                      itemBuilder: (context,
                                                              index) =>
                                                          linha(
                                                              gabinetes[index]),
                                                    ))),
                                          )))),
                            ])),
                      ]);
                    }),
                  ),
                ),
              );
            })),
      ),
    );
  }

  double _medirLarguraLivre(BuildContext context) {
    var largura = 180.0;
    // Usar toda a matriz evita voltar a medir e alterar as larguras ao filtrar.
    final descricoes =
        widget.itens.expand(_periodosLivres).map((p) => p.descricao).toSet();
    for (final descricao in descricoes) {
      _medicoesTexto++;
      final painter = TextPainter(
        text: TextSpan(
          style: DefaultTextStyle.of(context)
              .style
              .merge(_estiloPeriodo.copyWith(fontSize: 10)),
          children: [_textoPeriodo(descricao)],
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      largura = math.max(largura, painter.width.ceilToDouble() + 34);
      painter.dispose();
    }
    return largura;
  }

  double _alturaIdentificacao(
      BuildContext context, Gabinete gabinete, double largura) {
    _medicoesTexto++;
    // O Container desconta o padding (10 + 10) e a borda (1 + 1).
    const espacoIdentificacao = 22.0;
    var altura =
        espacoIdentificacao + (widget.onOcultarGabinete == null ? 0 : 48);
    for (final (texto, estilo) in [
      (
        gabinete.setor.isEmpty ? 'Sem piso' : gabinete.setor,
        const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
      ),
      (
        gabinete.nome,
        const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
      ),
      if (gabinete.especialidadesPermitidas.isNotEmpty)
        (
          gabinete.especialidadesPermitidas.join(', '),
          const TextStyle(fontSize: 12)
        ),
    ]) {
      final painter = TextPainter(
        text: TextSpan(
            text: texto,
            style: DefaultTextStyle.of(context).style.merge(estilo)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: largura - espacoIdentificacao);
      altura += painter.height;
      painter.dispose();
    }
    return altura.ceilToDouble();
  }

  double _alturaCartao(
      BuildContext context, MatrizDistribuicaoItem item, double largura) {
    _medicoesTexto++;
    if (widget.mostrarLivres) {
      double medir(String texto, TextStyle estilo, double espaco,
          {bool periodo = false}) {
        final painter = TextPainter(
          text: TextSpan(children: [
            periodo ? _textoPeriodo(texto) : TextSpan(text: texto)
          ], style: DefaultTextStyle.of(context).style.merge(estilo)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: periodo ? double.infinity : espaco);
        final escala =
            periodo && painter.width > espaco ? espaco / painter.width : 1.0;
        final altura = painter.height * escala;
        painter.dispose();
        return altura;
      }

      const titulo = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
      final livre = TextPainter(
        text: TextSpan(
            text: 'Livre',
            style: DefaultTextStyle.of(context).style.merge(titulo)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final alturaCabecalho = math.max(
          livre.height,
          medir(_horarioLivre(item), titulo,
              math.max(1, largura - 14 - livre.width - 6)));
      livre.dispose();
      var altura = 14 + alturaCabecalho;
      for (final periodo in _periodosLivres(item)) {
        final excecoes = periodo.observacao == null
            ? 0.0
            : 4 + medir(periodo.observacao!, _estiloExcecoes, largura - 14 - 8);
        altura += 6 +
            math.max(
                42,
                10 +
                    excecoes +
                    medir(periodo.descricao, _estiloPeriodo, largura - 14 - 8,
                        periodo: true));
      }
      return altura.ceilToDouble();
    }
    final textos = [
      (
        item.medicoNome,
        const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
      ),
      (item.especialidade, const TextStyle(fontSize: 11)),
      (item.horario, const TextStyle(fontSize: 12)),
      (
        _rotacao(item),
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)
      ),
      if (item.periodo != null) (item.periodo!, const TextStyle(fontSize: 10)),
      if (item.conflito)
        ('Possível coincidência', const TextStyle(fontSize: 10)),
    ];
    var altura = 20.0;
    for (final (texto, estilo) in textos) {
      final painter = TextPainter(
        text: TextSpan(
            text: texto,
            style: DefaultTextStyle.of(context).style.merge(estilo)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: largura - 18);
      altura += painter.height;
      painter.dispose();
    }
    return altura.ceilToDouble();
  }
}
