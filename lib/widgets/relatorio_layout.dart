import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../utils/matriz_colors.dart';
import '../utils/app_colors.dart';
import 'painel_lateral_tema.dart';

/// Filtros fixos à esquerda e resultados com rolagem independente.
class RelatorioLayout extends StatelessWidget {
  final List<Widget> filtros;
  final Widget resultado;
  final bool ocupado;
  final Widget? acoes;
  const RelatorioLayout(
      {super.key,
      required this.filtros,
      required this.resultado,
      this.ocupado = false,
      this.acoes});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final largura = constraints.maxWidth < 700 ? 220.0 : 288.0;
        final tema = temaPainelLateral(context);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: largura,
              child: Theme(
                data: tema.copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.acao,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white70,
                          minimumSize: const Size(0, 44))),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white54,
                          side:
                              const BorderSide(color: AppColors.bordaNavegacao),
                          minimumSize: const Size(0, 44))),
                  chipTheme: tema.chipTheme.copyWith(
                    backgroundColor: MatrizColors.lateral,
                    selectedColor: AppColors.navegacaoElevada,
                    color: WidgetStateProperty.resolveWith((estados) =>
                        estados.contains(WidgetState.selected)
                            ? AppColors.navegacaoElevada
                            : MatrizColors.lateral),
                    checkmarkColor: AppColors.menta,
                    side: const BorderSide(color: AppColors.bordaNavegacao),
                    labelStyle: tema.textTheme.labelLarge
                        ?.copyWith(color: Colors.white, fontSize: 12),
                    secondaryLabelStyle: tema.textTheme.labelLarge
                        ?.copyWith(color: AppColors.menta, fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.navegacaoElevada,
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.bordaNavegacao)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.menta)),
                    isDense: true,
                  ),
                ),
                child: Material(
                    color: MatrizColors.lateral,
                    child: Column(children: [
                      Expanded(
                          child: IgnorePointer(
                              ignoring: ocupado,
                              child: ListView(
                                  key: const ValueKey('relatorio_filtros'),
                                  primary: false,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  children: filtros))),
                      if (acoes != null) ...[
                        const Divider(height: 1),
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: IgnorePointer(
                                ignoring: ocupado, child: acoes!)),
                      ],
                    ])),
              )),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
                builder: (context, area) => area.maxWidth < 360
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                            width: 600,
                            height: area.maxHeight,
                            child: resultado))
                    : resultado),
          )),
        ]);
      });
}

class RelatorioFiltroSecao extends StatelessWidget {
  final String titulo;
  final Widget child;
  const RelatorioFiltroSecao(
      {super.key, required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class RelatorioPeriodoFiltros<T> extends StatelessWidget {
  final List<(T, String)> opcoes;
  final T selecionado;
  final ValueChanged<T> onChanged;
  final Widget inicio;
  final Widget fim;
  final Widget? extra;
  const RelatorioPeriodoFiltros(
      {super.key,
      required this.opcoes,
      required this.selecionado,
      required this.onChanged,
      required this.inicio,
      required this.fim,
      this.extra});
  @override
  Widget build(BuildContext context) => RelatorioFiltroSecao(
      titulo: 'Período',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (valor, texto) in opcoes)
            ChoiceChip(
                label: Text(texto),
                selected: selecionado == valor,
                onSelected: (_) => onChanged(valor)),
        ]),
        const SizedBox(height: 12),
        inicio,
        const SizedBox(height: 8),
        fim,
        if (extra != null) ...[const SizedBox(height: 12), extra!],
      ]));
}

class RelatorioSelecaoGabinetes extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final Set<String> selecionados;
  final ValueChanged<Set<String>> onChanged;
  final bool multipla;
  const RelatorioSelecaoGabinetes(
      {super.key,
      required this.gabinetes,
      required this.selecionados,
      required this.onChanged,
      this.multipla = true});
  @override
  State<RelatorioSelecaoGabinetes> createState() =>
      _RelatorioSelecaoGabinetesState();
}

class _RelatorioSelecaoGabinetesState extends State<RelatorioSelecaoGabinetes> {
  final _abertos = <String>{};
  void _alternar(Set<String> ids) {
    final selecionados = {...widget.selecionados};
    if (ids.every(selecionados.contains)) {
      selecionados.removeAll(ids);
    } else {
      selecionados.addAll(ids);
    }
    widget.onChanged(selecionados);
  }

  bool? _estado(Set<String> ids) => ids.every(widget.selecionados.contains)
      ? true
      : ids.any(widget.selecionados.contains)
          ? null
          : false;
  @override
  Widget build(BuildContext context) {
    final pisos = widget.gabinetes.map((g) => g.setor).toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text(
              'Gabinetes · ${widget.selecionados.length}/${widget.gabinetes.length}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
      if (widget.gabinetes.isEmpty)
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Esta unidade não tem gabinetes cadastrados.')),
      for (final piso in pisos) ...[
        Builder(builder: (context) {
          final ids = widget.gabinetes
              .where((g) => g.setor == piso)
              .map((g) => g.id)
              .toSet();
          final titulo = Text(piso.isEmpty ? 'Sem piso' : piso,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
          final seta = IconButton(
              key: ValueKey('relatorio_expandir_$piso'),
              tooltip: _abertos.contains(piso)
                  ? 'Recolher gabinetes'
                  : 'Mostrar gabinetes',
              icon: Icon(
                  _abertos.contains(piso)
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white),
              onPressed: () => setState(() {
                    if (!_abertos.add(piso)) _abertos.remove(piso);
                  }));
          return widget.multipla
              ? CheckboxListTile(
                  key: ValueKey('relatorio_piso_$piso'),
                  value: _estado(ids),
                  tristate: true,
                  onChanged: (_) => _alternar(ids),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: titulo,
                  secondary: seta)
              : ListTile(title: titulo, trailing: seta, dense: true);
        }),
        if (_abertos.contains(piso))
          for (final g in widget.gabinetes.where((g) => g.setor == piso))
            CheckboxListTile(
                key: ValueKey('relatorio_gabinete_${g.id}'),
                value: widget.selecionados.contains(g.id),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 24, right: 8),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(g.nome, style: const TextStyle(fontSize: 13)),
                subtitle: g.especialidadesPermitidas.isEmpty
                    ? null
                    : Text(g.especialidadesPermitidas.join(', '),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                onChanged: (valor) => widget.multipla
                    ? _alternar({g.id})
                    : widget.onChanged(valor == true ? {g.id} : {})),
      ],
      if (widget.multipla && widget.gabinetes.isNotEmpty)
        CheckboxListTile(
            key: const ValueKey('relatorio_todos_gabinetes'),
            value: _estado(widget.gabinetes.map((g) => g.id).toSet()),
            tristate: true,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text('Todos', style: TextStyle(fontSize: 13)),
            onChanged: (_) =>
                _alternar(widget.gabinetes.map((g) => g.id).toSet())),
      const Divider(),
    ]);
  }
}

class RelatorioEstadoVazio extends StatelessWidget {
  final String texto;
  const RelatorioEstadoVazio(
      {super.key,
      this.texto = 'Escolha os filtros e clique em “Gerar relatório”.'});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.assessment_outlined,
            size: 40, color: MatrizColors.lateral),
        const SizedBox(height: 12),
        Text(texto, textAlign: TextAlign.center),
      ]));
}

class RelatorioAcoes extends StatelessWidget {
  final VoidCallback? onGerar;
  final VoidCallback? onExportar;
  final bool gerando;
  final bool exportando;
  const RelatorioAcoes(
      {super.key,
      this.onGerar,
      this.onExportar,
      this.gerando = false,
      this.exportando = false});
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
                key: const ValueKey('relatorio_gerar'),
                onPressed: onGerar,
                icon: const Icon(Icons.assessment_outlined, size: 18),
                label: Text(gerando ? 'A gerar relatório…' : 'Gerar relatório',
                    style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                key: const ValueKey('relatorio_exportar'),
                onPressed: onExportar,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(exportando ? 'A exportar…' : 'Exportar Excel',
                    style: const TextStyle(fontSize: 13))),
          ]);
}
