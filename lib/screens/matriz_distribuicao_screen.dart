import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../models/matriz_distribuicao.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/matriz_distribuicao_cache_service.dart';
import '../services/cache_version_service.dart';
import '../services/matriz_progresso_controller.dart';
import '../services/medico_salvar_service.dart';
import '../services/serie_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/carregamento_overlay.dart';
import '../widgets/matriz_distribuicao_grid.dart';

class MatrizDistribuicaoScreen extends StatefulWidget {
  final Unidade unidade;
  const MatrizDistribuicaoScreen({super.key, required this.unidade});

  @override
  State<MatrizDistribuicaoScreen> createState() =>
      _MatrizDistribuicaoScreenState();
}

class _MatrizDistribuicaoScreenState extends State<MatrizDistribuicaoScreen> {
  List<Gabinete> _gabinetes = [];
  MatrizDistribuicaoDados? _dados;
  MatrizDistribuicao _matriz =
      const MatrizDistribuicao(itens: [], regrasSemGabinete: []);
  DateTime _referencia = DateTime.now();
  String? _piso;
  double _zoom = 1.0;
  bool _carregando = true;
  final _progresso = MatrizProgressoController();
  bool _grelhaPreparada = false;
  String _mensagemCarregamento = 'A verificar alterações...';
  String? _erro;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _carregar();
    });
  }

  @override
  void dispose() {
    _progresso.dispose();
    super.dispose();
  }

  void _atualizarProgresso(double progresso, String mensagem,
      {double? limiteEspera}) {
    if (!mounted) return;
    _progresso.etapa(progresso, limiteEspera: limiteEspera ?? progresso + 0.04);
    if (_mensagemCarregamento != mensagem) {
      setState(() => _mensagemCarregamento = mensagem);
    }
  }

  Future<void> _apresentarDados(MatrizDistribuicaoDados dados) async {
    await dados.matrizParaProgressiva(_referencia, onProgresso: (valor) {
      _atualizarProgresso(0.65 + valor * 0.27, 'A organizar a matriz...');
    });
    if (!mounted) return;
    _atualizarProgresso(0.94, 'A preparar a grelha...', limiteEspera: 0.99);
    setState(() {
      _usarDados(dados);
      _grelhaPreparada = true;
    });
    // Renderizar a grelha por baixo do indicador antes de chegar aos 100%.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _progresso.concluir();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _carregando = false);
  }

  Future<void> _carregar({bool atualizar = false}) async {
    _progresso.iniciar();
    setState(() {
      _carregando = true;
      _grelhaPreparada = false;
      _mensagemCarregamento = 'A verificar alterações...';
      _erro = null;
    });
    try {
      // Mostrar a barra antes de iniciar trabalho, mesmo com dados em cache.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (atualizar) {
        MatrizDistribuicaoCacheService.invalidar(unidadeId: widget.unidade.id);
      }
      final revisaoAntesVerificacao =
          MatrizDistribuicaoCacheService.revisao(widget.unidade.id);
      final versoes =
          await CacheVersionService.fetchVersions(unidadeId: widget.unidade.id);
      if (!mounted) return;
      final MatrizVersoes versaoMatriz = (
        versoes[CacheVersionService.fieldMedicos] ?? 0,
        versoes[CacheVersionService.fieldGabinetes] ?? 0,
        versoes[CacheVersionService.fieldSeries] ?? 0,
      );
      final cached = revisaoAntesVerificacao ==
              MatrizDistribuicaoCacheService.revisao(widget.unidade.id)
          ? MatrizDistribuicaoCacheService.buscar(
              widget.unidade.id, versaoMatriz)
          : null;
      if (cached != null) {
        await _apresentarDados(cached);
        return;
      }
      final revisaoInicial =
          MatrizDistribuicaoCacheService.revisao(widget.unidade.id);
      // Uma cache ausente ou invalidada requer dados atuais, incluindo os serviços base.
      var fontesCarregadas = 0;
      void fonteConcluida() {
        fontesCarregadas++;
        _atualizarProgresso(
            0.14 + fontesCarregadas * 0.1, 'A carregar gabinetes e médicos...');
      }

      _atualizarProgresso(0.14, 'A carregar gabinetes e médicos...',
          limiteEspera: 0.34);
      final dados = await Future.wait([
        buscarGabinetes(unidade: widget.unidade, forcarAtualizacao: true)
            .then((dados) {
          fonteConcluida();
          return dados;
        }),
        buscarMedicos(unidade: widget.unidade, forcarAtualizacao: true)
            .then((dados) {
          fonteConcluida();
          return dados;
        }),
      ]);
      if (!mounted) return;
      _atualizarProgresso(0.36, 'A carregar regras de rotação...',
          limiteEspera: 0.64);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final gabinetes = dados[0] as List<Gabinete>;
      final medicos = (dados[1] as List<Medico>).where((m) => m.ativo).toList();
      final series = await SerieService.carregarSeriesDeMedicos(
        medicos.map((m) => m.id).toList(),
        unidade: widget.unidade,
        forcarServidor: true,
      );
      if (!mounted) return;
      _atualizarProgresso(0.65, 'A organizar a matriz...');
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      gabinetes.sort((a, b) {
        final piso = a.setor.compareTo(b.setor);
        if (piso != 0) return piso;
        final numeroA =
            int.tryParse(RegExp(r'\d+').firstMatch(a.nome)?.group(0) ?? '');
        final numeroB =
            int.tryParse(RegExp(r'\d+').firstMatch(b.nome)?.group(0) ?? '');
        if (numeroA != null && numeroB != null && numeroA != numeroB) {
          return numeroA.compareTo(numeroB);
        }
        return a.nome.compareTo(b.nome);
      });
      if (!mounted) return;
      final dadosMatriz = MatrizDistribuicaoDados(
        gabinetes: gabinetes,
        medicos: medicos,
        series: series.values.expand((s) => s).toList(),
      );
      await dadosMatriz.matrizParaProgressiva(_referencia,
          onProgresso: (valor) {
        _atualizarProgresso(0.65 + valor * 0.27, 'A organizar a matriz...');
      });
      if (!mounted) return;
      MatrizDistribuicaoCacheService.guardar(
          widget.unidade.id, versaoMatriz, dadosMatriz,
          revisaoInicial: revisaoInicial);
      await _apresentarDados(dadosMatriz);
    } catch (_) {
      if (!mounted) return;
      _progresso.parar();
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar a matriz.';
      });
    }
  }

  void _usarDados(MatrizDistribuicaoDados dados) {
    _dados = dados;
    _gabinetes = dados.gabinetes;
    if (_piso != null && !_gabinetes.any((g) => g.setor == _piso)) _piso = null;
    _recalcular();
  }

  void _recalcular() {
    if (_dados != null) _matriz = _dados!.matrizPara(_referencia);
  }

  Future<void> _escolherReferencia() async {
    final ano = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ano da matriz'),
        content: SizedBox(
          width: 300,
          height: 350,
          child: YearPicker(
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            selectedDate: _referencia,
            onChanged: (data) => Navigator.of(context).pop(data.year),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'))
        ],
      ),
    );
    if (ano == null || !mounted) return;
    setState(() {
      _referencia = DateTime(ano);
      _recalcular();
    });
  }

  Widget _tituloAppBar() => LayoutBuilder(builder: (context, constraints) {
        final compacto = constraints.maxWidth < 600;
        final ano = _referencia.year;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Flexible(
            child: Text('Matriz de Distribuição',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          if (compacto)
            IconButton(
              onPressed: _escolherReferencia,
              tooltip: 'Ano da matriz: $ano',
              icon: const Icon(Icons.calendar_month_outlined),
            )
          else
            OutlinedButton.icon(
              onPressed: _escolherReferencia,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.onPrimary)),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text('Ano da matriz: $ano'),
            ),
          PopupMenuButton<String>(
            tooltip: _piso == null ? 'Todos os pisos' : 'Filtrar: $_piso',
            icon: Icon(
                _piso == null ? Icons.filter_alt_outlined : Icons.filter_alt),
            onSelected: (piso) =>
                setState(() => _piso = piso == '__todos__' ? null : piso),
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: '__todos__', child: Text('Todos os pisos')),
              for (final piso in _gabinetes.map((g) => g.setor).toSet())
                PopupMenuItem(
                    value: piso, child: Text(piso.isEmpty ? 'Sem piso' : piso)),
            ],
          ),
          if (_matriz.regrasSemGabinete.isNotEmpty)
            Tooltip(
              message:
                  'Períodos sem gabinete: ${_matriz.regrasSemGabinete.join('; ')}.',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.info_outline, size: 20),
              ),
            ),
        ]);
      });

  Widget _grelha() => MatrizDistribuicaoGrid(
        gabinetes:
            _gabinetes.where((g) => _piso == null || g.setor == _piso).toList(),
        itens: _matriz.itens,
        zoom: _zoom,
        ano: _referencia.year,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: CustomAppBar(
            title: 'Matriz de Distribuição',
            titleWidget: _tituloAppBar(),
            currentZoom: _zoom,
            onZoomIn: () => setState(
                () => _zoom = ((_zoom * 10).round() + 1).clamp(5, 20) / 10),
            onZoomOut: () => setState(
                () => _zoom = ((_zoom * 10).round() - 1).clamp(5, 20) / 10),
            onRefresh: _carregando ? null : () => _carregar(atualizar: true)),
        body: Stack(children: [
          Positioned.fill(
            child: _erro != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_erro!),
                    TextButton(
                        onPressed: _carregar,
                        child: const Text('Tentar novamente')),
                  ]))
                : _grelhaPreparada
                    ? _grelha()
                    : const SizedBox.expand(),
          ),
          if (_carregando)
            ValueListenableBuilder<double>(
              valueListenable: _progresso,
              builder: (context, valor, child) => CarregamentoOverlay(
                isRefreshing: false,
                mensagem: _mensagemCarregamento,
                progresso: valor,
              ),
            ),
        ]),
      );
}
