import '../services/cache_version_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import '../services/relatorio_taxas_excel_service.dart';
import '../models/gabinete.dart';
import '../models/taxa_ocupacao.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/relatorio_taxas_ocupacao_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/relatorio_layout.dart';
import '../utils/matriz_colors.dart';
import '../utils/app_theme.dart';

enum PeriodoTaxas { semana, mes, trimestre, semestre, ano, personalizado }

class RelatorioTaxasOcupacaoScreen extends StatefulWidget {
  final Unidade unidade;
  const RelatorioTaxasOcupacaoScreen({super.key, required this.unidade});

  @override
  State<RelatorioTaxasOcupacaoScreen> createState() =>
      _RelatorioTaxasOcupacaoScreenState();
}

class _RelatorioTaxasOcupacaoScreenState
    extends State<RelatorioTaxasOcupacaoScreen> {
  final _formato = DateFormat('dd/MM/yyyy');
  List<Gabinete> _gabinetes = [];
  final _selecionados = <String>{};
  Map<String, TaxaOcupacao> _taxas = {};
  PeriodoTaxas _periodo = PeriodoTaxas.semana;
  late DateTime _inicio;
  late DateTime _fim;
  bool _carregandoGabinetes = true;
  bool _calculando = false;
  bool _exportando = false;
  String? _erro;
  int _pedido = 0;
  DateTime? _inicioRelatorio;
  DateTime? _fimRelatorio;
  bool get _alterado =>
      _inicioRelatorio != null &&
      (_inicio != _inicioRelatorio ||
          _fim != _fimRelatorio ||
          _selecionados.length != _taxas.length ||
          !_selecionados.every(_taxas.containsKey));

  @override
  void initState() {
    super.initState();
    _definirPeriodo(DateTime.now());
    _carregarGabinetes();
  }

  void _definirPeriodo(DateTime referencia) {
    final dia = DateTime(referencia.year, referencia.month, referencia.day);
    if (_periodo == PeriodoTaxas.semana) {
      _inicio = DateTime(dia.year, dia.month, dia.day - dia.weekday + 1);
      _fim = DateTime(_inicio.year, _inicio.month, _inicio.day + 6);
    } else {
      final meses = switch (_periodo) {
        PeriodoTaxas.mes => 1,
        PeriodoTaxas.trimestre => 3,
        PeriodoTaxas.semestre => 6,
        _ => 12,
      };
      final mes = ((dia.month - 1) ~/ meses) * meses + 1;
      _inicio = DateTime(dia.year, mes);
      _fim = DateTime(dia.year, mes + meses, 0);
    }
  }

  Future<void> _carregarGabinetes() async {
    setState(() {
      _carregandoGabinetes = true;
      _erro = null;
    });
    try {
      final gabinetes = await buscarGabinetes(unidade: widget.unidade);
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
      setState(() {
        _gabinetes = gabinetes;
        _selecionados.addAll(gabinetes.map((g) => g.id));
        _carregandoGabinetes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoGabinetes = false;
        _erro = 'Não foi possível carregar os gabinetes.';
      });
    }
  }

  Future<void> _calcular() =>
      CacheVersionService.comVersoesPartilhadas(_calcularInterno);

  Future<void> _calcularInterno() async {
    if (_selecionados.isEmpty || _calculando) return;
    final pedido = ++_pedido;
    final inicio = _inicio;
    final fim = _fim;
    final ids = _selecionados.toList();
    setState(() {
      _calculando = true;
      _erro = null;
      _taxas = {};
    });
    try {
      final taxas = await RelatorioTaxasOcupacaoService.carregar(
        unidade: widget.unidade,
        inicio: inicio,
        fim: fim,
        gabineteIds: ids,
      );
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _taxas = taxas;
        _inicioRelatorio = inicio;
        _fimRelatorio = fim;
        _calculando = false;
      });
    } catch (_) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _calculando = false;
        _erro = 'Não foi possível calcular as taxas. Tente novamente.';
      });
    }
  }

  Future<void> _exportarExcel() async {
    if (_inicioRelatorio == null ||
        _taxas.isEmpty ||
        _exportando ||
        _calculando) {
      return;
    }
    setState(() => _exportando = true);
    try {
      final bytes = RelatorioTaxasExcelService.gerar(
        unidade: widget.unidade.nome,
        inicio: _inicioRelatorio!,
        fim: _fimRelatorio!,
        gabinetes: _gabinetes,
        taxas: _taxas,
      );
      final formato = DateFormat('yyyy-MM-dd');
      await FileSaver.instance.saveFile(
        name:
            'taxas_ocupacao_${formato.format(_inicioRelatorio!)}_${formato.format(_fimRelatorio!)}',
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Excel exportado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível exportar o Excel. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _escolherData({required bool inicial}) async {
    final data = await showDatePicker(
      context: context,
      firstDate: inicial ? DateTime(2000) : _inicio,
      lastDate: inicial ? _fim : DateTime(2100, 12, 31),
      initialDate: inicial ? _inicio : _fim,
      helpText: inicial ? 'Data inicial' : 'Data final',
    );
    if (data == null || !mounted) return;
    setState(() {
      _periodo = PeriodoTaxas.personalizado;
      if (inicial) {
        _inicio = data;
      } else {
        _fim = data;
      }
    });
  }

  Widget _botaoData({required bool inicial}) => OutlinedButton.icon(
        onPressed: () => _escolherData(inicial: inicial),
        icon: const Icon(Icons.calendar_month_outlined, size: 20),
        label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inicial ? 'Data inicial' : 'Data final',
              style: const TextStyle(fontSize: 11)),
          Text(_formato.format(inicial ? _inicio : _fim)),
        ]),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      );

  String _percentagem(TaxaOcupacao taxa) =>
      '${taxa.percentagem.toStringAsFixed(1).replaceAll('.', ',')}%';
  String _horas(double horas) => horas.toStringAsFixed(1).replaceAll('.', ',');

  String _descricao(Gabinete gabinete) =>
      gabinete.especialidadesPermitidas.isEmpty
          ? 'Sem descrição'
          : gabinete.especialidadesPermitidas.join(', ');

  Widget _cartaoResultado(TaxaOcupacao taxa,
      {required String titulo, required String descricao}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: MyAppTheme.gabineteOcupado,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            const BorderSide(color: MyAppTheme.bordaGabineteOcupado, width: 2),
      ),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(
                height: 40,
                child: Center(
                    child: Text(descricao,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis))),
            const SizedBox(height: 12),
            SizedBox(
                width: 132,
                height: 132,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(
                      child: CircularProgressIndicator(
                    value: (taxa.percentagem / 100).clamp(0, 1),
                    strokeWidth: 20,
                    backgroundColor: MyAppTheme.bordaGabineteOcupado,
                    color: MyAppTheme.corOcupacao(taxa.percentagem),
                  )),
                  Text(_percentagem(taxa),
                      style: Theme.of(context).textTheme.titleLarge),
                ])),
            const SizedBox(height: 16),
            Text(
                '${_horas(taxa.horasOcupadas)} h de ${_horas(taxa.horasDisponiveis)} h',
                textAlign: TextAlign.center),
          ])),
    );
  }

  Widget _quadro(Widget child) => Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: MatrizColors.borda)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MatrizColors.fundo,
        appBar: const CustomAppBar(title: 'Taxas de Ocupação'),
        body: _carregandoGabinetes
            ? const Center(child: CircularProgressIndicator())
            : RelatorioLayout(
                ocupado: _calculando || _exportando,
                filtros: [
                  RelatorioPeriodoFiltros<PeriodoTaxas>(
                    opcoes: [
                      for (final p in PeriodoTaxas.values
                          .where((p) => p != PeriodoTaxas.personalizado))
                        (
                          p,
                          switch (p) {
                            PeriodoTaxas.semana => 'Semana',
                            PeriodoTaxas.mes => 'Mês',
                            PeriodoTaxas.trimestre => 'Trimestre',
                            PeriodoTaxas.semestre => 'Semestre',
                            PeriodoTaxas.ano => 'Ano',
                            PeriodoTaxas.personalizado => 'Personalizado',
                          }
                        )
                    ],
                    selecionado: _periodo,
                    onChanged: (p) => setState(() {
                      _periodo = p;
                      _definirPeriodo(_inicio);
                    }),
                    inicio: _botaoData(inicial: true),
                    fim: _botaoData(inicial: false),
                  ),
                  const Divider(),
                  RelatorioSelecaoGabinetes(
                      gabinetes: _gabinetes,
                      selecionados: _selecionados,
                      onChanged: (ids) => setState(() {
                            _selecionados.clear();
                            _selecionados.addAll(ids);
                          })),
                ],
                acoes: RelatorioAcoes(
                  onGerar:
                      _selecionados.isEmpty || _calculando ? null : _calcular,
                  onExportar: _inicioRelatorio == null ||
                          _taxas.isEmpty ||
                          _calculando ||
                          _exportando
                      ? null
                      : _exportarExcel,
                  gerando: _calculando,
                  exportando: _exportando,
                ),
                resultado: _inicioRelatorio == null &&
                        !_calculando &&
                        _erro == null &&
                        _selecionados.isNotEmpty
                    ? const RelatorioEstadoVazio()
                    : _resultados(),
              ),
      );

  Widget _resultados() {
    final geral =
        _taxas.values.fold(const TaxaOcupacao(), (a, b) => a.somar(b));
    return ListView(children: [
      if (_alterado && !_calculando)
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Seleção alterada. Clique em “Gerar relatório” para atualizar os resultados.')),
      if (_erro != null)
        _quadro(Column(children: [
          Text(_erro!),
          TextButton(
              onPressed: _gabinetes.isEmpty ? _carregarGabinetes : _calcular,
              child: const Text('Tentar novamente')),
        ]))
      else if (_selecionados.isEmpty)
        _quadro(const Text(
            'Selecione pelo menos um gabinete para consultar as taxas.'))
      else if (_calculando)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()))
      else if (_inicioRelatorio != null) ...[
        _quadro(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Taxa de ocupação geral',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: _cartaoResultado(
              geral,
              titulo: 'Geral',
              descricao:
                  '${_formato.format(_inicioRelatorio!)} — ${_formato.format(_fimRelatorio!)}',
            ),
          )),
          const SizedBox(height: 8),
          if (geral.horasDisponiveis == 0)
            const Text('Sem horas disponíveis neste período.'),
        ])),
        _quadro(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ocupação por gabinete',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final largura =
                constraints.maxWidth < 190 ? constraints.maxWidth : 190.0;
            return SizedBox(
                width: constraints.maxWidth,
                child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final g
                          in _gabinetes.where((g) => _taxas.containsKey(g.id)))
                        SizedBox(
                            width: largura,
                            child: _cartaoResultado(_taxas[g.id]!,
                                titulo: g.nome, descricao: _descricao(g))),
                    ]));
          }),
        ])),
      ],
    ]);
  }
}
