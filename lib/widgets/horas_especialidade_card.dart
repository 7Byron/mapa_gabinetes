import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/relatorio_horas_especialidade.dart';
import '../utils/app_theme.dart';

class HorasEspecialidadeCard extends StatelessWidget {
  final RelatorioHorasEspecialidadeLinha linha;
  final int totalMedicosAtivosClinica;

  const HorasEspecialidadeCard({
    super.key,
    required this.linha,
    required this.totalMedicosAtivosClinica,
  });

  @override
  Widget build(BuildContext context) {
    final proporcao = totalMedicosAtivosClinica > 0
        ? (linha.medicosComDisponibilidade / totalMedicosAtivosClinica)
            .clamp(0.0, 1.0)
        : 0.0;
    final percentagem = NumberFormat('0.#', 'pt_PT').format(proporcao * 100);
    final horas = NumberFormat('#,##0.##', 'pt_PT');
    final cor = MyAppTheme.corOcupacao(proporcao * 100);
    final texto = Theme.of(context).textTheme;

    final grafico = Semantics(
      label:
          '${linha.medicosComDisponibilidade} médicos com disponibilidade, $percentagem% dos $totalMedicosAtivosClinica médicos ativos da clínica',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 108,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: proporcao,
                strokeWidth: 9,
                strokeCap: StrokeCap.round,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: cor,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${linha.medicosComDisponibilidade}',
                  style: texto.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: cor)),
              Text('médicos', style: texto.bodySmall),
            ]),
          ]),
        ),
      ),
    );

    Widget metrica(String titulo, String valor, IconData icone) => Container(
          constraints: const BoxConstraints(minWidth: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cor.withValues(alpha: 0.15)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Text(titulo, style: texto.bodySmall),
            ]),
            const SizedBox(height: 8),
            Text(valor,
                style: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );

    final detalhes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(linha.especialidade,
            style: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            '$percentagem% dos $totalMedicosAtivosClinica médicos ativos da clínica',
            style: texto.bodyMedium?.copyWith(color: cor)),
        const SizedBox(height: 4),
        Text('Disponibilidade efetiva no período', style: texto.bodySmall),
      ],
    );
    final metricas = Wrap(spacing: 12, runSpacing: 12, children: [
      metrica('Total de horas', '${horas.format(linha.horasConsulta)} h',
          Icons.schedule_outlined),
      metrica('Média por médico',
          '${horas.format(linha.mediaHorasPorMedico)} h', Icons.person_outline),
    ]);

    return Card(
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  detalhes,
                  const SizedBox(height: 24),
                  Center(child: grafico),
                  const SizedBox(height: 24),
                  metricas,
                ]);
          }
          return Row(children: [
            grafico,
            const SizedBox(width: 28),
            Expanded(child: detalhes),
            const SizedBox(width: 20),
            metricas,
          ]);
        }),
      ),
    );
  }
}
