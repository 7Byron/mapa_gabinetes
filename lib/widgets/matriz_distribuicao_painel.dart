import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../utils/matriz_colors.dart';
import '../utils/app_colors.dart';
import '../models/matriz_distribuicao.dart';
import 'matriz_distribuicao_grid.dart';
import 'painel_lateral_tema.dart';

/// Controlos fixos à esquerda; a matriz tem rolagem independente à direita.
class MatrizDistribuicaoPainel extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<MatrizDistribuicaoItem> itens;
  final Set<String> gabinetesOcultos;
  final ValueChanged<Set<String>> onOcultosChanged;
  final VoidCallback onEscolherAno;
  final int ano;
  final double zoom;
  final bool mostrarLivres;
  final ValueChanged<MatrizDistribuicaoItem>? onEditarMedico;
  final List<String> regrasSemGabinete;

  const MatrizDistribuicaoPainel({
    super.key,
    required this.gabinetes,
    required this.itens,
    required this.gabinetesOcultos,
    required this.onOcultosChanged,
    required this.onEscolherAno,
    required this.ano,
    this.regrasSemGabinete = const [],
    this.zoom = 1,
    this.mostrarLivres = false,
    this.onEditarMedico,
  });

  @override
  State<MatrizDistribuicaoPainel> createState() =>
      _MatrizDistribuicaoPainelState();
}

class _MatrizDistribuicaoPainelState extends State<MatrizDistribuicaoPainel> {
  static const _corLateral = MatrizColors.lateral;
  final Set<String> _pisosExpandidos = {};

  void _selecionar(Gabinete gabinete, bool selecionado) {
    final ocultos = {...widget.gabinetesOcultos};
    if (selecionado) {
      ocultos.remove(gabinete.id);
    } else {
      ocultos.add(gabinete.id);
    }
    widget.onOcultosChanged(ocultos);
  }

  Widget _tituloSecao(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
        child: Text(texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _selecaoPiso(String setor) {
    final ids = widget.gabinetes
        .where((g) => g.setor == setor)
        .map((g) => g.id)
        .toSet();
    final selecionados =
        ids.where((id) => !widget.gabinetesOcultos.contains(id)).length;
    final todos = selecionados == ids.length;
    return CheckboxListTile(
      key: ValueKey('matriz_piso_$setor'),
      value: todos
          ? true
          : selecionados == 0
              ? false
              : null,
      tristate: true,
      onChanged: (_) {
        final ocultos = {...widget.gabinetesOcultos};
        if (todos) {
          ocultos.addAll(ids);
        } else {
          ocultos.removeAll(ids);
        }
        widget.onOcultosChanged(ocultos);
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      secondary: IconButton(
        key: ValueKey('expandir_piso_$setor'),
        tooltip: _pisosExpandidos.contains(setor)
            ? 'Recolher gabinetes'
            : 'Mostrar gabinetes',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(
            _pisosExpandidos.contains(setor)
                ? Icons.expand_less
                : Icons.expand_more,
            color: Colors.white,
            size: 20),
        onPressed: () => setState(() {
          if (!_pisosExpandidos.add(setor)) _pisosExpandidos.remove(setor);
        }),
      ),
      title: Text(setor.isEmpty ? 'Sem piso' : setor,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compacto = constraints.maxWidth < 700;
        final selecionados = widget.gabinetes
            .where((g) => !widget.gabinetesOcultos.contains(g.id))
            .length;
        final visiveis = widget.gabinetes
            .where((g) => !widget.gabinetesOcultos.contains(g.id))
            .toList();
        final pisos = widget.gabinetes.map((g) => g.setor).toSet();
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            key: const ValueKey('matriz_painel_lateral'),
            width: compacto ? 144 : 224,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: MatrizColors.borda)),
            ),
            child: Theme(
              data: temaPainelLateral(context),
              child: Material(
                color: _corLateral,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Ano da matriz',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const ValueKey('matriz_selecionar_ano'),
                                onPressed: widget.onEscolherAno,
                                icon: const Icon(Icons.calendar_month_outlined,
                                    size: 18),
                                label: Text('${widget.ano}'),
                                style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.navegacaoElevada,
                                    foregroundColor: AppColors.textoNavegacao),
                              ),
                            ]),
                      ),
                      const Divider(height: 1),
                      Expanded(
                          child: ListView(
                        key: const ValueKey('matriz_lista_gabinetes'),
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                            child: Text(
                                'Gabinetes · $selecionados/${widget.gabinetes.length}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          for (final setor in pisos) ...[
                            _selecaoPiso(setor),
                            if (_pisosExpandidos.contains(setor))
                              for (final gabinete in widget.gabinetes
                                  .where((g) => g.setor == setor))
                                CheckboxListTile(
                                  key: ValueKey(
                                      'mostrar_gabinete_${gabinete.id}'),
                                  value: !widget.gabinetesOcultos
                                      .contains(gabinete.id),
                                  onChanged: (valor) =>
                                      _selecionar(gabinete, valor ?? false),
                                  selected: !widget.gabinetesOcultos
                                      .contains(gabinete.id),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding:
                                      const EdgeInsets.only(left: 24, right: 8),
                                  dense: true,
                                  title: Text(gabinete.nome,
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle:
                                      gabinete.especialidadesPermitidas.isEmpty
                                          ? null
                                          : Text(
                                              gabinete.especialidadesPermitidas
                                                  .join(', '),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70)),
                                ),
                          ],
                          const Divider(height: 1),
                          CheckboxListTile(
                            key: const ValueKey('matriz_todos_gabinetes'),
                            value: selecionados == widget.gabinetes.length
                                ? true
                                : selecionados == 0
                                    ? false
                                    : null,
                            tristate: true,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            title: const Text('Todos',
                                style: TextStyle(fontSize: 13)),
                            onChanged: (_) => widget.onOcultosChanged(
                                selecionados == widget.gabinetes.length
                                    ? widget.gabinetes.map((g) => g.id).toSet()
                                    : <String>{}),
                          ),
                          const Divider(height: 1),
                          _tituloSecao('Informação'),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Períodos sem gabinete',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  if (widget.regrasSemGabinete.isEmpty)
                                    const Text(
                                        'Todas as regras têm gabinete atribuído.',
                                        style: TextStyle(fontSize: 12))
                                  else
                                    for (final regra
                                        in widget.regrasSemGabinete)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Text(regra,
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                ]),
                          ),
                        ],
                      )),
                    ]),
              ),
            ),
          ),
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Offstage(
                offstage: visiveis.isEmpty,
                child: MatrizDistribuicaoGrid(
                  gabinetes: visiveis,
                  itens: widget.itens,
                  onEditarMedico: widget.onEditarMedico,
                  zoom: widget.zoom,
                  ano: widget.ano,
                  mostrarLivres: widget.mostrarLivres,
                  onOcultarGabinete: (gabinete) => _selecionar(gabinete, false),
                ),
              ),
              if (visiveis.isEmpty)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      widget.gabinetes.isEmpty
                          ? 'Sem gabinetes para apresentar.'
                          : 'Selecione os gabinetes na lista à esquerda.',
                      textAlign: TextAlign.center),
                )),
            ]),
          ),
        ]);
      });
}
