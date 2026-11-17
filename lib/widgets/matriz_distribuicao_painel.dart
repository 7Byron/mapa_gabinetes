import 'package:flutter/material.dart';
import 'exportacao_progresso.dart';
import '../services/matriz_gabinetes_exportacao_service.dart';
import '../services/relatorio_exportacao_service.dart';
import 'relatorio_exportacao_menu.dart';
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
  final ValueChanged<bool>? onMostrarLivresChanged;
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
    this.onMostrarLivresChanged,
    this.onEditarMedico,
  });

  @override
  State<MatrizDistribuicaoPainel> createState() =>
      _MatrizDistribuicaoPainelState();
}

class _MatrizDistribuicaoPainelState extends State<MatrizDistribuicaoPainel> {
  static const _corLateral = MatrizColors.lateral;
  final Set<String> _pisosExpandidos = {};
  String _pesquisa = '';
  bool _exportando = false;

  Future<void> _exportar() async {
    final escolha = await escolherExportacaoRelatorio(context,
        mostrarGrafico: false,
        descricaoTabela: 'PNG (Em pasta ZIP se muito conteúdo)');
    if (escolha == null || !mounted) return;
    setState(() => _exportando = true);
    try {
      await executarComProgressoExportacao(context, (informar) async {
        final dados = MatrizGabinetesExportacaoService.documento(
          gabinetes: widget.gabinetes
              .where((g) => !widget.gabinetesOcultos.contains(g.id))
              .toList(),
          itens: widget.itens,
          ano: widget.ano,
          livres: widget.mostrarLivres,
          pesquisa: _pesquisa,
        );
        if (escolha.formato == FormatoExportacaoRelatorio.imagem) {
          await MatrizGabinetesExportacaoService.guardarImagens(dados,
              'matriz_gabinetes_${widget.ano}_${widget.mostrarLivres ? 'livres' : 'ocupacao'}',
              onProgresso: informar);
        } else {
          await RelatorioExportacaoService.guardar(
            onProgresso: informar,
            formato: escolha.formato,
            conteudoImagem: escolha.conteudoImagem,
            dados: dados,
            nome:
                'matriz_gabinetes_${widget.ano}_${widget.mostrarLivres ? 'livres' : 'ocupacao'}',
            imagemHorizontal: false,
            centrarCelulas: true,
            gerarPdfPersonalizado: () =>
                MatrizGabinetesExportacaoService.gerarPdf(dados,
                    onProgresso: informar),
            dividirImagemEmPaineis: false,
            gerarExcel: () =>
                MatrizGabinetesExportacaoService.gerarExcelProgressivo(dados,
                    onProgresso: informar),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Matriz exportada.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível exportar a matriz.')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

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
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(children: [
                              for (final livre in [false, true])
                                Expanded(
                                    child: OutlinedButton(
                                  key: ValueKey('modo_matriz_$livre'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    backgroundColor:
                                        widget.mostrarLivres == livre
                                            ? Colors.white12
                                            : Colors.transparent,
                                  ),
                                  onPressed: widget.onMostrarLivresChanged ==
                                          null
                                      ? null
                                      : () =>
                                          widget.onMostrarLivresChanged!(livre),
                                  child: Text(livre ? 'Livre' : 'Ocupado',
                                      style: const TextStyle(fontSize: 11)),
                                )),
                            ]),
                          ),
                          const SizedBox(height: 12),
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
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: _exportando || visiveis.isEmpty
                                ? null
                                : _exportar,
                            icon:
                                const Icon(Icons.ios_share_outlined, size: 18),
                            label:
                                Text(_exportando ? 'A exportar…' : 'Exportar'),
                          ),
                        ),
                      ),
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
                  pesquisa: _pesquisa,
                  onPesquisaChanged: (valor) =>
                      setState(() => _pesquisa = valor.trim().toLowerCase()),
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
