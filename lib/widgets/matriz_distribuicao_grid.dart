import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../models/matriz_distribuicao.dart';
import '../utils/app_theme.dart';
import '../utils/serie_tipo_colors.dart';

/// Uma linha por gabinete, agrupada por piso, e sete colunas de uma semana, com a rotação em cada cartão.
class MatrizDistribuicaoGrid extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<MatrizDistribuicaoItem> itens;
  final double zoom;

  const MatrizDistribuicaoGrid({
    super.key,
    required this.gabinetes,
    required this.itens,
    this.zoom = 1.0,
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

  @override
  void initState() {
    super.initState();
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

  Widget _cartao(MatrizDistribuicaoItem item) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: item.conflito
            ? MyAppTheme.gabineteConflito
            : MyAppTheme.gabineteOcupado,
        border: Border.all(
          color: item.conflito
              ? MyAppTheme.bordaGabineteConflito
              : MyAppTheme.bordaGabineteOcupado,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          if (item.conflito)
            const Text('Possível coincidência',
                style: TextStyle(fontSize: 10, color: MyAppTheme.vermelho)),
        ],
      ),
    );
  }

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
    final ocorrencia = (item.dia - 1) ~/ 7 + 1;
    return '$ocorrencia.${feminino ? 'ª' : 'º'} ${dias[dia]} do mês';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gabinetes.isEmpty) {
      return const Center(child: Text('Sem gabinetes para apresentar.'));
    }
    final gabinetes = widget.gabinetes;
    final porId = {for (final gabinete in gabinetes) gabinete.id: gabinete};
    final celulas = <String, List<MatrizDistribuicaoItem>>{};
    // A projeção mantém as coincidências por semana; a apresentação reúne
    // as ocorrências da mesma regra sem criar conflitos entre quinzenas alternadas.
    final unicos = <(String, String, int, int, int), MatrizDistribuicaoItem>{};
    for (final item in widget.itens) {
      final chave = (
        item.serieId,
        item.gabineteId,
        (item.dia - 1) % 7 + 1,
        item.inicioMinutos,
        item.fimMinutos
      );
      if (!unicos.containsKey(chave) || item.conflito) unicos[chave] = item;
    }
    for (final item in unicos.values) {
      final gabinete = porId[item.gabineteId];
      if (gabinete == null) continue;
      celulas
          .putIfAbsent('${gabinete.id}_${(item.dia - 1) % 7 + 1}', () => [])
          .add(item);
    }
    for (final celula in celulas.values) {
      celula.sort((a, b) {
        final dia = a.dia.compareTo(b.dia);
        if (dia != 0) return dia;
        final gabinete =
            porId[a.gabineteId]!.nome.compareTo(porId[b.gabineteId]!.nome);
        return gabinete != 0
            ? gabinete
            : a.inicioMinutos.compareTo(b.inicioMinutos);
      });
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // A largura acompanha o zoom para preservar o espaço das sete colunas.
        constraints: BoxConstraints(maxWidth: 1320 * widget.zoom),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                      const larguraIdentificacao = 140.0;
                      final larguraDia = math.max(140.0,
                          (constraints.maxWidth - larguraIdentificacao) / 7);
                      final larguraSemana = larguraDia * 7;
                      final larguraCartao = larguraDia - 14;
                      final medidasCartoes =
                          <(String, String, int, int, String, bool), double>{};
                      double medir(MatrizDistribuicaoItem item) =>
                          medidasCartoes.putIfAbsent((
                            item.medicoNome,
                            item.especialidade,
                            item.inicioMinutos,
                            item.fimMinutos,
                            item.ciclo,
                            item.conflito
                          ), () => _alturaCartao(context, item, larguraCartao));
                      final alturas = <String, double>{};
                      final posicoes = <String, List<double>>{};
                      for (final gabinete in gabinetes) {
                        var altura = math.max(
                            80.0,
                            _alturaIdentificacao(
                                context, gabinete, larguraIdentificacao));
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
                                            color: Colors.blue.shade100,
                                            border: Border.symmetric(
                                                vertical: BorderSide(
                                                    color:
                                                        Colors.blue.shade200))),
                                        child: Text('Semana tipo',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Row(children: [
                                      for (final dia in _dias)
                                        Container(
                                            width: larguraDia,
                                            height: 42,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                border: Border.all(
                                                    color:
                                                        Colors.blue.shade100)),
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
                                height: alturas[gabinete.id],
                                width: larguraDia,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    border: Border(
                                        left: BorderSide(
                                            color: (dia - 1) % 7 == 0
                                                ? Colors.blue.shade200
                                                : Colors.grey.shade200),
                                        right: BorderSide(
                                            color: Colors.grey.shade200),
                                        top: BorderSide(
                                            color: Colors.grey.shade200),
                                        bottom: BorderSide(
                                            color: Colors.grey.shade200))),
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
                                                  height:
                                                      alturas[gabinetes[i].id],
                                                  width: larguraIdentificacao,
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade50,
                                                      border: Border.all(
                                                          color: Colors
                                                              .blue.shade100)),
                                                  child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
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

  double _alturaIdentificacao(
      BuildContext context, Gabinete gabinete, double largura) {
    // O Container desconta o padding (10 + 10) e a borda (1 + 1).
    const espacoIdentificacao = 22.0;
    var altura = espacoIdentificacao;
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
