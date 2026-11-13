import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/relatorio_horas_especialidade.dart';
import '../utils/app_theme.dart';

String _horas(double valor) =>
    '${NumberFormat('#,##0.##', 'pt_PT').format(valor)} h';

class HorasMedicoCard extends StatelessWidget {
  final RelatorioHorasMedicoLinha medico;
  final RelatorioHorasEspecialidade relatorio;

  const HorasMedicoCard(
      {super.key, required this.medico, required this.relatorio});

  @override
  Widget build(BuildContext context) {
    final especialidade = relatorio.especialidadesClinica[medico.especialidade];
    final tema = Theme.of(context);
    final texto = tema.textTheme;
    final corClinica = MyAppTheme.corOcupacao(
        medico.percentagemContribuicao(relatorio.totalHorasConsultaClinica));
    final corEspecialidade = tema.brightness == Brightness.dark
        ? const Color(0xff7bcebe)
        : const Color(0xff287c70);

    return Card(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: tema.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_horas(medico.horasConsulta),
                    key: ValueKey('horas-medico-${medico.medicoId}'),
                    style: texto.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tema.colorScheme.onPrimaryContainer)),
              ),
              Text(medico.nome,
                  style:
                      texto.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(medico.especialidade, style: texto.bodyLarge),
            ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final colunas = [
            _ColunaContribuicao(
                grupo: medico.especialidade,
                especialidade: true,
                medico: medico,
                total: especialidade?.horasConsulta,
                quantidade: especialidade?.medicosAtivos,
                media: especialidade?.mediaHorasPorMedicoAtivo,
                limite: relatorio.limiteComparacaoHoras,
                cor: corEspecialidade),
            _ColunaContribuicao(
                grupo: 'todos os médicos',
                especialidade: false,
                medico: medico,
                total: relatorio.totalHorasConsultaClinica,
                quantidade: relatorio.totalMedicosAtivosClinica,
                media: relatorio.mediaHorasPorMedicoClinica,
                limite: relatorio.limiteComparacaoHoras,
                cor: corClinica),
          ];
          if (constraints.maxWidth >= 760) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: colunas[0]),
              const SizedBox(width: 24),
              Expanded(child: colunas[1]),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [colunas[0], const SizedBox(height: 16), colunas[1]]);
        }),
        if (relatorio.totalHorasConsultaClinica == 0) ...[
          const SizedBox(height: 12),
          const Text(
              'Sem horas de consulta na clínica no período selecionado.'),
        ],
        if (medico.horasConsulta == 0) ...[
          const SizedBox(height: 12),
          const Text('Sem disponibilidade no período selecionado.'),
        ],
      ]),
    ));
  }
}

class _ColunaContribuicao extends StatelessWidget {
  final String grupo;
  final bool especialidade;
  final RelatorioHorasMedicoLinha medico;
  final double? total;
  final int? quantidade;
  final double? media;
  final double limite;
  final Color cor;

  const _ColunaContribuicao(
      {required this.grupo,
      required this.especialidade,
      required this.medico,
      required this.total,
      required this.quantidade,
      required this.media,
      required this.limite,
      required this.cor});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final escalaTexto = MediaQuery.textScalerOf(context);
        final ladoALado = constraints.maxWidth >= 480 ||
            (constraints.maxWidth >= 260 && escalaTexto.scale(1) <= 1.25);
        final dimensao = math.min(
            constraints.maxWidth,
            math.max(constraints.maxWidth >= 400 ? 144.0 : 128.0,
                escalaTexto.scale(120)));
        final circulo = _ContribuicaoCircular(
            grupo: grupo,
            destacarGrupo: especialidade,
            horas: medico.horasConsulta,
            total: total,
            cor: cor,
            dimensao: dimensao);
        final comparacao = _ComparacaoMedia(
            especialidade: especialidade,
            nomeEspecialidade: medico.especialidade,
            quantidade: quantidade,
            horas: medico.horasConsulta,
            total: total,
            media: media,
            limite: limite,
            cor: cor);
        if (ladoALado) {
          return Row(children: [
            circulo,
            const SizedBox(width: 16),
            Expanded(child: comparacao),
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: circulo),
              const SizedBox(height: 12),
              comparacao,
            ]);
      });
}

class _ContribuicaoCircular extends StatelessWidget {
  final double dimensao;
  final String grupo;
  final bool destacarGrupo;
  final double horas;
  final double? total;
  final Color cor;

  const _ContribuicaoCircular(
      {required this.grupo,
      required this.dimensao,
      this.destacarGrupo = false,
      required this.horas,
      required this.total,
      required this.cor});

  @override
  Widget build(BuildContext context) {
    final percentagem = (total ?? 0) > 0 ? horas / total! * 100 : 0.0;
    final percentual = '${NumberFormat('0.#', 'pt_PT').format(percentagem)}%';
    final texto = Theme.of(context).textTheme;
    return Semantics(
      label: total == null
          ? 'Dados da especialidade indisponíveis'
          : '$percentual de ${_horas(total!)} $grupo',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: dimensao,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
                child: CircularProgressIndicator(
              value: (percentagem / 100).clamp(0.0, 1.0),
              strokeWidth: 10,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: cor,
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: total == null
                  ? const Text('Dados indisponíveis',
                      textAlign: TextAlign.center)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(percentual,
                              style: texto.titleLarge?.copyWith(
                                  color: cor, fontWeight: FontWeight.w800))),
                      const SizedBox(height: 3),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('de ${_horas(total!)}',
                              style: texto.bodySmall)),
                      Text(grupo,
                          textAlign: TextAlign.center,
                          style: texto.labelSmall?.copyWith(
                              fontWeight:
                                  destacarGrupo ? FontWeight.w700 : null)),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ComparacaoMedia extends StatelessWidget {
  final bool especialidade;
  final String nomeEspecialidade;
  final int? quantidade;
  final double horas;
  final double? total;
  final double? media;
  final double limite;
  final Color cor;

  const _ComparacaoMedia(
      {required this.especialidade,
      required this.nomeEspecialidade,
      required this.quantidade,
      required this.horas,
      required this.total,
      required this.media,
      required this.limite,
      required this.cor});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final grupo = especialidade ? 'Especialidade' : 'Clínica';
    final diferenca = horas - (media ?? 0);
    final estado = media == null
        ? 'Média indisponível'
        : diferenca.abs() < 1e-9
            ? 'Na média'
            : '${_horas(diferenca.abs())} ${diferenca > 0 ? 'acima' : 'abaixo'} da média';
    final numeroMedicos = quantidade == null
        ? 'Médicos de $nomeEspecialidade'
        : '$quantidade ${quantidade == 1 ? 'médico' : 'médicos'}${especialidade ? ' de $nomeEspecialidade' : ''}';
    return Semantics(
      label:
          '$numeroMedicos. Total: ${total == null ? 'indisponível' : _horas(total!)}. '
          '${media == null ? '' : 'Média: ${_horas(media!)}. '}$estado.',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(numeroMedicos, style: texto.bodyMedium),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, constraints) {
            final ponta =
                constraints.maxWidth * ((media ?? 0) / limite).clamp(0.0, 1.0);
            final larguraPin = math.min(constraints.maxWidth,
                math.max(92.0, MediaQuery.textScalerOf(context).scale(84)));
            final alturaCorpo =
                math.max(40.0, MediaQuery.textScalerOf(context).scale(34));
            final alturaPin = alturaCorpo + 14;
            final esquerda = (ponta - larguraPin / 2)
                .clamp(0.0, constraints.maxWidth - larguraPin);
            return SizedBox(
              height: alturaPin + 5,
              child: Stack(alignment: Alignment.bottomLeft, children: [
                Container(
                    key: ValueKey('trilho-$grupo'),
                    height: 10,
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6))),
                FractionallySizedBox(
                    widthFactor: (horas / limite).clamp(0.0, 1.0),
                    child: Container(
                        key: ValueKey('barra-$grupo'),
                        height: 10,
                        decoration: BoxDecoration(
                            color: cor,
                            borderRadius: BorderRadius.circular(6)))),
                if (media != null)
                  Positioned(
                      left: esquerda,
                      top: 0,
                      child: CustomPaint(
                        key: ValueKey('media-$grupo'),
                        size: Size(larguraPin, alturaPin),
                        painter: _PinMediaPainter(
                            ponta: ponta - esquerda,
                            alturaCorpo: alturaCorpo,
                            cor: especialidade
                                ? const Color(0xff23665c)
                                : const Color(0xff315769)),
                        child: SizedBox(
                            width: larguraPin,
                            height: alturaPin,
                            child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                    height: alturaCorpo,
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Média',
                                              style: texto.labelSmall?.copyWith(
                                                  color: Colors.white)),
                                          FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(_horas(media!),
                                                  style: texto.bodySmall
                                                      ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight
                                                              .w700))),
                                        ])))),
                      )),
              ]),
            );
          }),
          const SizedBox(height: 6),
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: total == null
                        ? 'Total indisponível'
                        : 'Total: ${_horas(total!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' ($estado)'),
              ]),
              style: texto.bodySmall),
        ]),
      ),
    );
  }
}

/// O corpo fica dentro da coluna; a ponta mantém a posição exata da média,
/// incluindo quando a média é zero e o pin encosta à margem esquerda.
class _PinMediaPainter extends CustomPainter {
  final double ponta;
  final double alturaCorpo;
  final Color cor;
  const _PinMediaPainter(
      {required this.ponta, required this.alturaCorpo, required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    final base = ponta.clamp(14.0, size.width - 14);
    final caminho = Path()
      ..moveTo(base - 8, alturaCorpo - 1)
      ..lineTo(ponta, size.height)
      ..lineTo(base + 8, alturaCorpo - 1)
      ..close();
    final tinta = Paint()..color = cor;
    canvas.drawPath(caminho, tinta);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, alturaCorpo),
            const Radius.circular(12)),
        tinta);
  }

  @override
  bool shouldRepaint(_PinMediaPainter oldDelegate) =>
      ponta != oldDelegate.ponta ||
      alturaCorpo != oldDelegate.alturaCorpo ||
      cor != oldDelegate.cor;
}
