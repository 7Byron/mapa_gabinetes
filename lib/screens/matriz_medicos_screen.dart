import 'package:flutter/material.dart';
import '../widgets/exportacao_progresso.dart';
import '../models/unidade.dart';
import '../models/medico.dart';
import '../services/cache_version_service.dart';
import '../services/alocacao_clinica_config_service.dart';
import '../services/alocacao_clinica_status_service.dart';
import '../services/matriz_medicos_exportacao_service.dart';
import '../services/relatorio_exportacao_service.dart';
import '../widgets/relatorio_exportacao_menu.dart';
import '../services/medico_salvar_service.dart';
import '../services/serie_service.dart';
import '../services/matriz_medicos_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/relatorio_layout.dart';

class MatrizMedicosScreen extends StatefulWidget {
  final Unidade unidade;
  final DateTime? referenciaInicial;
  final Future<List<MatrizMedicoLinha>> Function(DateTime)? carregarLinhas;
  const MatrizMedicosScreen(
      {super.key,
      required this.unidade,
      this.carregarLinhas,
      this.referenciaInicial});
  @override
  State<MatrizMedicosScreen> createState() => _MatrizMedicosScreenState();
}

class _MatrizMedicosScreenState extends State<MatrizMedicosScreen> {
  late DateTime _referencia = widget.referenciaInicial ?? DateTime.now();
  late DateTime _semanaReferencia = _referencia;
  final _descontar = [false, false, false];
  List<MatrizMedicoLinha> _liquidas = [];
  bool _carregando = true, _exportando = false;
  int _ordenacao = 0;
  final _pesquisaController = TextEditingController();
  String _pesquisa = '';

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _escolherAno() async {
    if (_carregando) return;
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
                      onChanged: (data) => Navigator.pop(context, data.year))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'))
              ],
            ));
    if (ano == null || !mounted || ano == _referencia.year) return;
    setState(
        () => _referencia = DateTime(ano, _referencia.month, _referencia.day));
    _semanaReferencia = _referencia;
    await _carregar();
  }

  Future<void> _escolherSemana() async {
    if (_carregando) return;
    final data = await showDatePicker(
        context: context,
        initialDate: _semanaReferencia,
        firstDate: DateTime(_referencia.year),
        lastDate: DateTime(_referencia.year, 12, 31),
        helpText: 'Escolher um dia da semana');
    if (data == null || !mounted) return;
    setState(() => _semanaReferencia = data);
    await _carregar();
  }

  String? _erro;
  List<MatrizMedicoLinha> _linhas = [];
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Map<String, int>? _versoesCarregadas;
  List<Medico>? _medicosCarregados;

  Future<void> _carregar({bool atualizar = false}) =>
      CacheVersionService.comVersoesPartilhadas(
          () => _carregarInterno(atualizar: atualizar));

  Future<void> _carregarInterno({required bool atualizar}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (widget.carregarLinhas != null) {
        final linhas = await widget.carregarLinhas!(_referencia);
        if (mounted) {
          setState(() {
            _linhas = linhas;
            _liquidas = linhas;
          });
        }
        return;
      }
      final versoes =
          await CacheVersionService.fetchVersions(unidadeId: widget.unidade.id);
      final relerMedicos = atualizar ||
          _medicosCarregados == null ||
          _versoesCarregadas?[CacheVersionService.fieldMedicos] !=
              versoes[CacheVersionService.fieldMedicos];
      final relerSeries = atualizar ||
          _versoesCarregadas == null ||
          _versoesCarregadas?[CacheVersionService.fieldSeries] !=
              versoes[CacheVersionService.fieldSeries];
      if (relerSeries) SerieService.invalidateCacheSeries(widget.unidade.id);
      final medicos = relerMedicos
          ? await buscarMedicos(
              unidade: widget.unidade, forcarAtualizacao: true)
          : _medicosCarregados!;
      final series = await SerieService.carregarSeriesDeMedicos(
          medicos.where((m) => m.ativo).map((m) => m.id).toList(),
          unidade: widget.unidade,
          forcarServidor: relerSeries);
      final regras = series.values.expand((s) => s).toList();
      final linhas = MatrizMedicosService.gerar(medicos, regras, _referencia,
          semanaReferencia: _semanaReferencia);
      final segunda = _semanaReferencia
          .subtract(Duration(days: _semanaReferencia.weekday - 1));
      final domingo = segunda.add(const Duration(days: 6));
      final inicio = segunda.isBefore(DateTime(_referencia.year))
          ? segunda
          : DateTime(_referencia.year);
      final fimAno = DateTime(_referencia.year, 12, 31);
      final fim = domingo.isAfter(fimAno) ? domingo : fimAno;
      final excecoes = await Future.wait(medicos.where((m) => m.ativo).map(
          (m) => SerieService.carregarExcecoes(m.id,
              unidade: widget.unidade,
              dataInicio: inicio,
              dataFim: fim,
              forcarServidor: relerSeries)));
      final config =
          await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
              unidadeId: widget.unidade.id, forcarServidor: atualizar);
      final fechados = <DateTime>{};
      for (var ano = inicio.year; ano <= fim.year; ano++) {
        final feriados = await AlocacaoClinicaConfigService.carregarFeriados(
            unidadeId: widget.unidade.id,
            anoSelecionado: ano,
            forcarServidor: atualizar);
        final encerramentos =
            await AlocacaoClinicaConfigService.carregarDiasEncerramento(
                unidadeId: widget.unidade.id,
                anoSelecionado: ano,
                forcarServidor: atualizar);
        for (var dia = DateTime(ano);
            dia.year == ano;
            dia = dia.add(const Duration(days: 1))) {
          if (AlocacaoClinicaStatusService.verificar(
                  data: dia,
                  nuncaEncerra: config.nuncaEncerra,
                  encerraFeriados: config.encerraFeriados,
                  encerraDias: config.encerraDias,
                  horariosClinica: config.horariosClinica,
                  diasEncerramento: encerramentos,
                  feriados: feriados)
              .fechada) {
            fechados.add(dia);
          }
        }
      }
      final liquidas = MatrizMedicosService.gerar(medicos, regras, _referencia,
          semanaReferencia: _semanaReferencia,
          excecoes: excecoes.expand((e) => e).toList(),
          encerramentos: fechados);
      if (mounted) {
        setState(() {
          _linhas = linhas;
          _liquidas = liquidas;
          _versoesCarregadas = versoes;
          _medicosCarregados = medicos;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _erro = 'Não foi possível carregar a matriz. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _totalHoras(int minutos, {bool anual = false}) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: anual ? cores.primaryContainer : cores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(MatrizMedicosService.horas(minutos),
          style: TextStyle(
            color: anual ? cores.onPrimaryContainer : cores.onSurface,
            fontWeight: anual ? FontWeight.w700 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
    );
  }

  String _percentagem(MatrizMedicoLinha linha) {
    final valor = _dadosExportacao.percentagem(linha) * 100;
    return '${valor.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  Widget _horario(String horario) {
    final partes = horario.split(' · ');
    return Text.rich(TextSpan(children: [
      TextSpan(text: partes.take(2).join(' · ')),
      if (partes.length > 2)
        TextSpan(
            text: ' · ${partes.skip(2).join(' · ')}',
            style: const TextStyle(fontSize: 11)),
    ]));
  }

  Widget _tabela(List<MatrizMedicoLinha> linhas) =>
      LayoutBuilder(builder: (context, area) {
        final largura = area.maxWidth < 960 ? 960.0 : area.maxWidth;
        final colunas = <int, TableColumnWidth>{
          0: const FlexColumnWidth(3),
          1: const FlexColumnWidth(4),
          2: const FixedColumnWidth(100),
          3: const FixedColumnWidth(100),
          4: const FixedColumnWidth(108),
          5: const FixedColumnWidth(96),
        };
        Widget celula(Widget child) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: child);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: largura - 24,
              height: area.maxHeight - 16,
              child: Column(children: [
                ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Table(
                    columnWidths: colunas,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(children: [
                        celula(const Text('Médico / Especialidade')),
                        celula(const Text('Horário habitual')),
                        for (final titulo in [
                          'Total\nSemana',
                          'Total\nMês',
                          'Total\nAno'
                        ])
                          celula(Text(titulo, textAlign: TextAlign.center)),
                        celula(const Tooltip(
                            message:
                                'Percentagem das horas de todos os médicos da clínica; mantém o total mesmo ao pesquisar.',
                            child: Text('% Clínica'))),
                      ])
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('matriz_medicos_linhas'),
                    itemCount: linhas.length,
                    itemBuilder: (context, index) {
                      final l = linhas[index];
                      final liquida = _liquidas
                              .where((r) => r.medico.id == l.medico.id)
                              .firstOrNull ??
                          l;
                      return Table(
                        columnWidths: colunas,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        border: TableBorder(
                            bottom: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.15))),
                        children: [
                          TableRow(children: [
                            celula(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.medico.nome,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(l.medico.especialidade),
                              ],
                            )),
                            celula(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: l.horarios.isEmpty
                                  ? [const Text('Sem horário recorrente')]
                                  : l.horarios.map(_horario).toList(),
                            )),
                            celula(_totalHoras(
                                _descontar[0] ? liquida.semana : l.semana)),
                            celula(_totalHoras(
                                _descontar[1] ? liquida.mes : l.mes)),
                            celula(_totalHoras(
                                _descontar[2] ? liquida.ano : l.ano,
                                anual: true)),
                            celula(Text(_percentagem(l),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                          ])
                        ],
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      });

  MatrizMedicosExportacaoDados get _dadosExportacao =>
      MatrizMedicosExportacaoDados(
          linhas: _linhas,
          reais: _liquidas,
          descontos: _descontar,
          pesquisa: _pesquisa,
          ordenacao: _ordenacao,
          periodoPercentagem: 2,
          referencia: _referencia,
          semanaReferencia: _semanaReferencia);

  Future<void> _exportar() async {
    if (_carregando || _exportando || _dadosExportacao.visiveis.isEmpty) return;
    final escolha = await escolherExportacaoRelatorio(context,
        mostrarGrafico: false,
        descricaoTabela: 'PNG (Em pasta ZIP se muito conteúdo)');
    if (escolha == null || !mounted) return;
    setState(() => _exportando = true);
    try {
      await executarComProgressoExportacao(context, (informar) async {
        final dados = _dadosExportacao.documento(widget.unidade.nome);
        if (escolha.formato == FormatoExportacaoRelatorio.imagem) {
          await MatrizMedicosExportacaoDados.guardarImagens(
              dados, 'matriz_medicos_${_referencia.year}_${_referencia.month}',
              onProgresso: informar);
        } else {
          await RelatorioExportacaoService.guardar(
              onProgresso: informar,
              formato: escolha.formato,
              conteudoImagem: escolha.conteudoImagem,
              imagemHorizontal: true,
              pdfPortrait: true,
              centrarCelulas: true,
              dividirImagemEmPaineis: false,
              dados: dados,
              nome: 'matriz_medicos_${_referencia.year}_${_referencia.month}',
              gerarExcel: () =>
                  MatrizMedicosExportacaoDados.gerarExcelProgressivo(dados,
                      onProgresso: informar));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Relatório exportado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível exportar o relatório. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linhas = _dadosExportacao.visiveis;
    final segunda = _semanaReferencia
        .subtract(Duration(days: _semanaReferencia.weekday - 1));
    final domingo = segunda.add(const Duration(days: 6));
    String dia(DateTime d) => '${d.day}/${d.month}/${d.year}';
    return Scaffold(
      appBar: CustomAppBar(
          title: 'Matriz de Médicos',
          titleWidget: Row(mainAxisSize: MainAxisSize.min, children: [
            const Flexible(
              child: Text('Matriz de Médicos',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Previsto')),
                ButtonSegment(value: true, label: Text('Real')),
              ],
              selected: {_descontar.every((v) => v)},
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (valores) =>
                  setState(() => _descontar.fillRange(0, 3, valores.single)),
            ),
          ]),
          onRefresh: _carregando ? null : () => _carregar(atualizar: true)),
      body: RelatorioLayout(
          ocupado: _exportando,
          acoes: FilledButton.icon(
            key: const ValueKey('matriz_medicos_exportar'),
            onPressed:
                _carregando || _exportando || _erro != null || linhas.isEmpty
                    ? null
                    : _exportar,
            icon: const Icon(Icons.ios_share_outlined),
            label: Text(_exportando ? 'A exportar…' : 'Exportar'),
          ),
          filtros: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Matriz de Médicos',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      const Text('Ano da matriz'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          key: const ValueKey('matriz_medicos_ano'),
                          icon: const Icon(Icons.calendar_month),
                          label: Text('${_referencia.year}'),
                          onPressed: _carregando ? null : _escolherAno),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                            'mes_${_referencia.year}_${_referencia.month}'),
                        initialValue: _referencia.month,
                        decoration:
                            const InputDecoration(labelText: 'Mês dos totais'),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                                value: m,
                                child: Text(const [
                                  'Janeiro',
                                  'Fevereiro',
                                  'Março',
                                  'Abril',
                                  'Maio',
                                  'Junho',
                                  'Julho',
                                  'Agosto',
                                  'Setembro',
                                  'Outubro',
                                  'Novembro',
                                  'Dezembro'
                                ][m - 1]))
                        ],
                        onChanged: _carregando
                            ? null
                            : (m) async {
                                if (m == null) return;
                                setState(() {
                                  _referencia = DateTime(_referencia.year, m);
                                  _semanaReferencia = _referencia;
                                });
                                await _carregar();
                              },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text('${dia(segunda)} – ${dia(domingo)}',
                            style: const TextStyle(fontSize: 12)),
                        onPressed: _carregando ? null : _escolherSemana,
                      ),
                      const SizedBox(height: 12),
                      Text(
                          'Semana: ${dia(segunda)} – ${dia(domingo)}\nMês: ${_referencia.month}/${_referencia.year}\nAno: ${_referencia.year}'),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Ordenar por',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        key: const ValueKey('matriz_ordenacao'),
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final opcao in const [
                            (0, 'Nome'),
                            (1, 'Especialidade'),
                            (2, 'Horas')
                          ])
                            ChoiceChip(
                              label: Text(opcao.$2),
                              selected: _ordenacao == opcao.$1,
                              onSelected: (_) =>
                                  setState(() => _ordenacao = opcao.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Totais',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final desconto in [false, true])
                          Expanded(
                              child: Tooltip(
                            message: desconto
                                ? 'Real · com desconto de ausências e encerramentos'
                                : 'Previsto · sem descontos',
                            child: OutlinedButton.icon(
                              key: ValueKey(desconto
                                  ? 'matriz_todos_real'
                                  : 'matriz_todos_previsto'),
                              style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      _descontar.every((v) => v == desconto)
                                          ? Colors.white12
                                          : Colors.transparent),
                              icon: Icon(
                                  desconto
                                      ? Icons.event_available
                                      : Icons.event_note,
                                  size: 18),
                              label: Text(desconto ? 'Real' : 'Previsto',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () => setState(() {
                                _descontar.fillRange(0, 3, desconto);
                              }),
                            ),
                          )),
                      ]),
                    ]))
          ],
          resultado: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: TextField(
                                controller: _pesquisaController,
                                decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText:
                                        'Pesquisar por nome ou especialidade',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    isDense: true,
                                    suffixIcon: _pesquisa.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Limpar pesquisa',
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _pesquisaController.clear();
                                              setState(() => _pesquisa = '');
                                            })),
                                onChanged: (valor) =>
                                    setState(() => _pesquisa = valor))),
                        Expanded(
                            child: _carregando
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _erro != null
                                    ? Center(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                            Text(_erro!),
                                            TextButton(
                                                onPressed: _carregar,
                                                child: const Text(
                                                    'Tentar novamente'))
                                          ]))
                                    : linhas.isEmpty
                                        ? const Center(
                                            child: Text(
                                                'Nenhum médico encontrado.'))
                                        : _tabela(linhas))
                      ])))),
    );
  }
}
