import '../widgets/matriz_distribuicao_ajuda.dart';
import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../utils/matriz_colors.dart';
import '../models/matriz_distribuicao.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/alocacao_clinica_config_service.dart';
import '../services/matriz_gabinetes_livres_service.dart';
import '../services/matriz_distribuicao_cache_service.dart';
import '../services/cache_version_service.dart';
import '../services/matriz_progresso_controller.dart';
import '../services/medico_salvar_service.dart';
import '../services/serie_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/carregamento_overlay.dart';
import '../widgets/matriz_distribuicao_painel.dart';

class MatrizDistribuicaoScreen extends StatefulWidget {
  final Unidade unidade;
  final bool mostrarLivres;
  const MatrizDistribuicaoScreen(
      {super.key, required this.unidade, this.mostrarLivres = false});

  @override
  State<MatrizDistribuicaoScreen> createState() =>
      _MatrizDistribuicaoScreenState();
}

class _MatrizDistribuicaoScreenState extends State<MatrizDistribuicaoScreen> {
  String get _titulo =>
      widget.mostrarLivres ? 'Matriz Livre' : 'Matriz de ocupação';
  ClinicaConfiguracoes? _config;
  Set<DateTime> _encerramentos = {};
  List<Gabinete> _gabinetes = [];
  MatrizDistribuicaoDados? _dados;
  MatrizDistribuicao _matriz =
      const MatrizDistribuicao(itens: [], regrasSemGabinete: []);
  DateTime _referencia = DateTime.now();
  Set<String> _gabinetesOcultos = {};
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

  Future<void> _carregar({bool atualizar = false}) =>
      CacheVersionService.comVersoesPartilhadas(
          () => _carregarInterno(atualizar: atualizar));

  Future<void> _carregarInterno({bool atualizar = false}) async {
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
      if (widget.mostrarLivres) await _carregarFuncionamento(atualizar);
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
    _recalcular();
  }

  void _recalcular() {
    if (_dados == null) return;
    final ocupacao = _dados!.matrizPara(_referencia);
    _matriz = widget.mostrarLivres && _config != null
        ? MatrizGabinetesLivresService.gerar(
            gabinetes: _gabinetes,
            ocupacao: ocupacao,
            ano: _referencia.year,
            config: _config!,
            encerramentos: _encerramentos)
        : ocupacao;
  }

  Future<void> _carregarFuncionamento(bool atualizar) async {
    final id = widget.unidade.id;
    await AlocacaoClinicaConfigService.sincronizarVersao(id);
    _config = await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
        unidadeId: id, forcarServidor: atualizar, verificarVersao: false);
    final encerramentos =
        await AlocacaoClinicaConfigService.carregarDiasEncerramento(
            unidadeId: id,
            anoSelecionado: _referencia.year,
            forcarServidor: atualizar,
            verificarVersao: false);
    final feriados = _config!.encerraFeriados && !_config!.nuncaEncerra
        ? await AlocacaoClinicaConfigService.carregarFeriados(
            unidadeId: id,
            anoSelecionado: _referencia.year,
            forcarServidor: atualizar,
            verificarVersao: false)
        : <Map<String, String>>[];
    _encerramentos = [...encerramentos, ...feriados]
        .map((r) => DateTime.tryParse(r['data'] as String? ?? ''))
        .whereType<DateTime>()
        .toSet();
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
    if (widget.mostrarLivres) {
      _referencia = DateTime(ano);
      await _carregar();
      return;
    }
    setState(() {
      _referencia = DateTime(ano);
      _recalcular();
    });
  }

  Widget _tituloAppBar() => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(_titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        MatrizDistribuicaoAjuda(mostrarLivres: widget.mostrarLivres),
      ]);

  Widget _grelha() => MatrizDistribuicaoPainel(
        gabinetes: _gabinetes,
        itens: _matriz.itens,
        gabinetesOcultos: _gabinetesOcultos,
        onOcultosChanged: (ocultos) =>
            setState(() => _gabinetesOcultos = ocultos),
        onEscolherAno: _escolherReferencia,
        ano: _referencia.year,
        zoom: _zoom,
        regrasSemGabinete: _matriz.regrasSemGabinete,
        mostrarLivres: widget.mostrarLivres,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MatrizColors.fundo,
        appBar: CustomAppBar(
            backgroundColor: MatrizColors.barra,
            refreshColor: MatrizColors.iconeClaro,
            title: _titulo,
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
