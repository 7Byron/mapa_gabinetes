import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Horários com colunas alinhadas e espaço reservado para horas completas.
class HorarioAberturaQuadro extends StatelessWidget {
  final Map<int, List<String>> horarios;
  final List<String> diasSemana;
  final bool nuncaEncerra;
  final Map<int, bool> encerraDias;
  final bool encerraFeriados;
  final ValueChanged<bool> onNuncaEncerraChanged;
  final ValueChanged<bool> onFeriadosChanged;
  final void Function(int dia, bool encerrado) onEncerradoChanged;
  final void Function(int dia, bool abertura) onEscolherHora;
  final ValueChanged<int> onApagar;

  const HorarioAberturaQuadro({
    super.key,
    required this.horarios,
    required this.diasSemana,
    required this.nuncaEncerra,
    required this.encerraDias,
    required this.encerraFeriados,
    required this.onNuncaEncerraChanged,
    required this.onFeriadosChanged,
    required this.onEncerradoChanged,
    required this.onEscolherHora,
    required this.onApagar,
  });

  @override
  Widget build(BuildContext context) {
    final escala =
        math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14);
    final larguras = [100.0, 104.0, 104.0, 112.0, 48.0]
        .map((valor) => valor * escala)
        .toList();
    final larguraMinima = larguras.reduce((a, b) => a + b);
    const estilo = TextStyle(fontSize: 13, color: AppColors.texto);

    Widget linha(List<Widget> celulas, {bool cabecalho = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cabecalho ? AppColors.marca.withValues(alpha: 0.08) : null,
            border: cabecalho
                ? null
                : const Border(bottom: BorderSide(color: AppColors.linha)),
          ),
          child: Row(children: [
            for (var i = 0; i < celulas.length; i++)
              Expanded(
                  flex: larguras[i].round(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: celulas[i],
                  )),
          ]),
        );

    Widget hora(int dia, bool abertura) {
      final valor = horarios[dia]?[abertura ? 0 : 1] ?? '';
      return Semantics(
        button: true,
        label: '${abertura ? 'Início' : 'Fim'} de ${diasSemana[dia - 1]}',
        child: InkWell(
          onTap: () => onEscolherHora(dia, abertura),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borda)),
            ),
            child: Text(valor.isEmpty ? '—' : valor,
                softWrap: false,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: estilo),
          ),
        ),
      );
    }

    Widget check(bool value, ValueChanged<bool> onChanged, String label) =>
        Center(
          child: Checkbox(
              value: value,
              activeColor: AppColors.marca,
              semanticLabel: label,
              onChanged: (v) => onChanged(v ?? false)),
        );

    return Card(
      color: AppColors.superficie,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nunca encerra',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.marca,
                    fontSize: 16)),
            value: nuncaEncerra,
            activeColor: AppColors.marca,
            onChanged: (v) => onNuncaEncerraChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!nuncaEncerra) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
                builder: (context, constraints) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (constraints.maxWidth < larguraMinima)
                          const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text('Deslize para ver todas as colunas',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secundario))),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width:
                                math.max(larguraMinima, constraints.maxWidth),
                            child: Column(children: [
                              linha([
                                for (final titulo in [
                                  'Dia',
                                  'Início',
                                  'Fim',
                                  'Encerrado',
                                  ''
                                ])
                                  Text(titulo,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.marca)),
                              ], cabecalho: true),
                              for (var dia = 1; dia <= 7; dia++)
                                linha([
                                  Text(diasSemana[dia - 1],
                                      style: estilo,
                                      maxLines: 1,
                                      softWrap: false),
                                  hora(dia, true),
                                  hora(dia, false),
                                  check(
                                      encerraDias[dia] ?? false,
                                      (v) => onEncerradoChanged(dia, v),
                                      '${diasSemana[dia - 1]} encerrado'),
                                  IconButton(
                                      tooltip:
                                          'Limpar horários de ${diasSemana[dia - 1]}',
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20,
                                          color: AppColors.textoConflito),
                                      onPressed: () => onApagar(dia)),
                                ]),
                              linha([
                                const Text('Feriados',
                                    style: estilo, maxLines: 1),
                                const Center(child: Text('—', style: estilo)),
                                const Center(child: Text('—', style: estilo)),
                                check(encerraFeriados, onFeriadosChanged,
                                    'Feriados encerrados'),
                                const SizedBox.shrink(),
                              ]),
                            ]),
                          ),
                        ),
                      ],
                    )),
          ],
        ]),
      ),
    );
  }
}
