import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/relatorio_exportacao_service.dart';
import '../widgets/relatorio_exportacao_menu.dart';
import '../models/medico.dart';
import '../services/relatorio_horas_exportacao_service.dart';
import '../widgets/searchable_selection_field.dart';
import '../services/relatorio_horas_excel_service.dart';
import '../utils/matriz_colors.dart';
import '../widgets/relatorio_layout.dart';

import '../models/relatorio_horas_especialidade.dart';
import '../models/unidade.dart';
import '../services/cache_version_service.dart';
import '../services/relatorio_horas_especialidade_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/horas_especialidade_card.dart';
import '../widgets/horas_medico_card.dart';

enum _ConsultaHoras { especialidade, medico }

enum PeriodoHorasEspecialidade {
  dia,
  semana,
  mes,
  trimestre,
  semestre,
  ano,
  personalizado
}

class IntervaloHorasEspecialidade {
  final DateTime inicio;
  final DateTime fim;

  const IntervaloHorasEspecialidade({
    required this.inicio,
    required this.fim,
  });
}

class _CacheRelatorioHorasEspecialidade {
  final RelatorioHorasEspecialidade relatorio;
  final String versao;
  final DateTime criadoEm;

  const _CacheRelatorioHorasEspecialidade({
    required this.relatorio,
    required this.versao,
    required this.criadoEm,
  });
}

class RelatorioHorasEspecialidadeScreen extends StatefulWidget {
  final Unidade unidade;
  final RelatorioHorasEspecialidadeService service;

  const RelatorioHorasEspecialidadeScreen({
    super.key,
    required this.unidade,
    this.service = const RelatorioHorasEspecialidadeService(),
  });

  @override
  State<RelatorioHorasEspecialidadeScreen> createState() =>
      _RelatorioHorasEspecialidadeScreenState();
}

class _RelatorioHorasEspecialidadeScreenState
    extends State<RelatorioHorasEspecialidadeScreen> {
  static const _informacaoMedias =
      'Médias por médico ativo, incluindo quem tem zero horas no período.';
  static final Map<String, _CacheRelatorioHorasEspecialidade> _cache = {};

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'pt_PT');

  bool _carregando = true;
  bool _exportando = false;
  bool _opcoesCarregadas = false;
  List<String> _especialidades = [];
  List<Medico> _medicos = [];
  final Set<String> _medicosSelecionados = {};
  _ConsultaHoras _consulta = _ConsultaHoras.medico;

  bool get _porMedico => _consulta == _ConsultaHoras.medico;
  bool get _selecaoValida =>
      _porMedico ? _medicosSelecionados.isNotEmpty : _selecionadas.isNotEmpty;
  final Set<String> _selecionadas = {};
  String? _erro;
  double _progresso = 0.0;
  String _mensagemProgresso = 'A iniciar...';

  PeriodoHorasEspecialidade _periodoSelecionado =
      PeriodoHorasEspecialidade.semana;
  late DateTime _dataReferencia;
  late DateTime _inicioRelatorio;
  late DateTime _fimRelatorio;
  RelatorioHorasEspecialidade? _relatorio;

  @override
  void initState() {
    super.initState();
    _dataReferencia = _normalizarData(DateTime.now());
    _atualizarIntervalo();
    unawaited(_carregarEspecialidades());
  }

  Future<void> _carregarEspecialidades({bool forcarServidor = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
      _mensagemProgresso = 'A carregar médicos e especialidades...';
    });
    try {
      final medicos = await widget.service.carregarMedicos(
          unidade: widget.unidade, forcarServidor: forcarServidor);
      final especialidades = medicos
          .where((m) => m.ativo)
          .map((m) {
            final nome = m.especialidade.trim();
            return nome.isEmpty ? 'Sem especialidade' : nome;
          })
          .toSet()
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _medicos = medicos.where((m) => m.ativo).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
        _especialidades = especialidades;
        if (_opcoesCarregadas) {
          _selecionadas.retainAll(especialidades);
        } else {
          _selecionadas.addAll(especialidades);
        }
        _medicosSelecionados.retainAll(_medicos.map((medico) => medico.id));
        _opcoesCarregadas = true;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar os médicos e as especialidades.';
      });
    }
  }

  void _selecionarEspecialidades(
      Iterable<String> especialidades, bool selecionar) {
    setState(() {
      if (selecionar) {
        _selecionadas.addAll(especialidades);
      } else {
        _selecionadas.removeAll(especialidades);
      }
      _relatorio = null;
      _erro = null;
    });
  }

  Future<void> _carregarRelatorio({bool forcarServidor = false}) =>
      CacheVersionService.comVersoesPartilhadas(
          () => _carregarRelatorioInterno(forcarServidor: forcarServidor));

  Future<void> _carregarRelatorioInterno({bool forcarServidor = false}) async {
    if (!_selecaoValida || _carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
      _progresso = 0.0;
      _mensagemProgresso = 'A iniciar...';
    });

    try {
      _atualizarProgresso(0.04, 'A validar cache...');
      final versao =
          await widget.service.obterVersaoCache(unidade: widget.unidade);
      final cacheKey = _montarCacheKey();
      final cache = _cache[cacheKey];
      if (!forcarServidor && cache != null && cache.versao == versao) {
        if (!mounted) return;
        setState(() {
          _relatorio = cache.relatorio;
          _carregando = false;
          _progresso = 1.0;
          _mensagemProgresso = 'Concluído';
        });
        return;
      }

      final relatorio = await widget.service.calcular(
        unidade: widget.unidade,
        inicio: _inicioRelatorio,
        fim: _fimRelatorio,
        forcarServidor: forcarServidor,
        especialidades: _porMedico ? null : Set.of(_selecionadas),
        medicoIds: _porMedico ? Set.of(_medicosSelecionados) : null,
        onProgress: _atualizarProgresso,
      );

      if (!mounted) return;
      setState(() {
        _relatorio = relatorio;
        _carregando = false;
        _progresso = 1.0;
        _mensagemProgresso = 'Concluído';
      });

      _cache[cacheKey] = _CacheRelatorioHorasEspecialidade(
        relatorio: relatorio,
        versao: versao,
        criadoEm: DateTime.now(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível calcular o relatório.';
        _carregando = false;
      });
    }
  }

  Future<void> _forcarAtualizacao() async {
    if (_carregando || _exportando) return;
    final tinhaRelatorio = _relatorio != null;
    _cache.removeWhere((key, _) => key.startsWith('${widget.unidade.id}|'));
    setState(() => _relatorio = null);
    await _carregarEspecialidades(forcarServidor: true);
    if (mounted && _erro == null && tinhaRelatorio && _selecaoValida) {
      await _carregarRelatorio(forcarServidor: true);
    }
  }

  void _atualizarProgresso(double valor, String mensagem) {
    if (!mounted) return;
    setState(() {
      _progresso = valor.clamp(0.0, 1.0);
      _mensagemProgresso = mensagem;
    });
  }

  String _montarCacheKey() {
    return [
      widget.unidade.id,
      _inicioRelatorio.millisecondsSinceEpoch,
      _fimRelatorio.millisecondsSinceEpoch,
      _periodoSelecionado.name,
      _consulta.name,
      if (_porMedico)
        (_medicosSelecionados.toList()..sort())
            .map(Uri.encodeComponent)
            .join(','),
      if (!_porMedico)
        (_selecionadas.toList()..sort()).map(Uri.encodeComponent).join(','),
    ].join('|');
  }

  void _atualizarIntervalo() {
    final intervalo = _calcularIntervalo(_periodoSelecionado, _dataReferencia);
    _inicioRelatorio = intervalo.inicio;
    _fimRelatorio = intervalo.fim;
  }

  DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  IntervaloHorasEspecialidade _calcularIntervalo(
    PeriodoHorasEspecialidade periodo,
    DateTime referencia,
  ) {
    final base = _normalizarData(referencia);
    switch (periodo) {
      case PeriodoHorasEspecialidade.personalizado:
        return IntervaloHorasEspecialidade(
            inicio: _inicioRelatorio, fim: _fimRelatorio);
      case PeriodoHorasEspecialidade.dia:
        return IntervaloHorasEspecialidade(inicio: base, fim: base);
      case PeriodoHorasEspecialidade.semana:
        final diff = base.weekday - DateTime.monday;
        final inicio = base.subtract(Duration(days: diff));
        final fim = inicio.add(const Duration(days: 6));
        return IntervaloHorasEspecialidade(inicio: inicio, fim: fim);
      case PeriodoHorasEspecialidade.mes:
        final inicio = DateTime(base.year, base.month, 1);
        final fim = DateTime(base.year, base.month + 1, 0);
        return IntervaloHorasEspecialidade(inicio: inicio, fim: fim);
      case PeriodoHorasEspecialidade.trimestre:
        final mesInicio = (((base.month - 1) ~/ 3) * 3) + 1;
        final inicio = DateTime(base.year, mesInicio, 1);
        final fim = DateTime(base.year, mesInicio + 3, 0);
        return IntervaloHorasEspecialidade(inicio: inicio, fim: fim);
      case PeriodoHorasEspecialidade.semestre:
        final mesInicio = base.month <= 6 ? 1 : 7;
        final inicio = DateTime(base.year, mesInicio, 1);
        final fim = DateTime(base.year, mesInicio + 6, 0);
        return IntervaloHorasEspecialidade(inicio: inicio, fim: fim);
      case PeriodoHorasEspecialidade.ano:
        final inicio = DateTime(base.year, 1, 1);
        final fim = DateTime(base.year, 12, 31);
        return IntervaloHorasEspecialidade(inicio: inicio, fim: fim);
    }
  }

  String _rotuloPeriodo(PeriodoHorasEspecialidade periodo) {
    switch (periodo) {
      case PeriodoHorasEspecialidade.personalizado:
        return 'Período personalizado';
      case PeriodoHorasEspecialidade.dia:
        return 'Dia';
      case PeriodoHorasEspecialidade.semana:
        return 'Semana';
      case PeriodoHorasEspecialidade.mes:
        return 'Mês';
      case PeriodoHorasEspecialidade.trimestre:
        return 'Trimestre';
      case PeriodoHorasEspecialidade.semestre:
        return 'Semestre';
      case PeriodoHorasEspecialidade.ano:
        return 'Ano';
    }
  }

  Future<void> _selecionarData({required bool inicial}) async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: inicial ? _inicioRelatorio : _fimRelatorio,
      firstDate: inicial ? DateTime(2000) : _inicioRelatorio,
      lastDate: inicial ? _fimRelatorio : DateTime(2100, 12, 31),
      helpText: inicial ? 'Data inicial' : 'Data final',
    );
    if (novaData == null || !mounted) return;
    setState(() {
      _periodoSelecionado = PeriodoHorasEspecialidade.personalizado;
      if (inicial) {
        _inicioRelatorio = _normalizarData(novaData);
      } else {
        _fimRelatorio = _normalizarData(novaData);
      }
      _relatorio = null;
      _erro = null;
    });
  }

  Future<void> _escolherExportacao() async {
    final escolha = await escolherExportacaoRelatorio(context,
        descricaoGrafico: _porMedico
            ? 'Contribuição e médias na clínica e especialidade'
            : 'Médicos e horas de consulta por especialidade',
        descricaoTabela: _porMedico
            ? 'Horas de consulta dos médicos selecionados'
            : 'Horas e médias por especialidade');
    if (escolha != null && mounted) await _exportar(escolha);
  }

  Future<void> _exportar(OpcaoExportacaoRelatorio escolha) async {
    final relatorio = _relatorio;
    if (relatorio == null || _exportando) return;
    final formato = escolha.formato;
    final conteudoImagem = escolha.conteudoImagem;
    final imagem = formato == FormatoExportacaoRelatorio.imagem;
    setState(() => _exportando = true);
    try {
      final data = DateFormat('yyyy-MM-dd');
      await RelatorioExportacaoService.guardar(
        formato: formato,
        conteudoImagem: conteudoImagem,
        imagemHorizontal: imagem,
        dados: RelatorioHorasExportacaoDados(relatorio)
            .documento(widget.unidade.nome, incluirGraficos: imagem),
        nome:
            'horas_${relatorio.porMedico ? 'medico' : 'especialidade'}_${data.format(relatorio.inicio)}_${data.format(relatorio.fim)}'
            '${imagem ? '_${conteudoImagem.name}' : ''}',
        gerarExcel: () => RelatorioHorasExcelService.gerar(
            unidade: widget.unidade.nome, relatorio: relatorio),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Relatório exportado.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível exportar o relatório. Tente novamente.')));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _formatHoras(double valor) => _numberFormat.format(valor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Horas Médico/Especialidade',
        titleWidget: Row(mainAxisSize: MainAxisSize.min, children: [
          const Flexible(
            child: Text('Horas Médico/Especialidade',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: _informacaoMedias,
            onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Médias por médico'),
                      content: const Text(_informacaoMedias),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Fechar')),
                      ],
                    )),
          ),
        ]),
        onRefresh: _forcarAtualizacao,
      ),
      backgroundColor: MatrizColors.fundo,
      body: _carregando && !_opcoesCarregadas
          ? _buildCarregamento()
          : _buildConteudo(),
    );
  }

  Widget _buildCarregamento() {
    final percentual = (_progresso * 100).toInt().clamp(0, 100);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progresso),
            const SizedBox(height: 12),
            Text(
              '$percentual%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _mensagemProgresso,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
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

  Widget _buildConteudo() {
    final relatorio = _relatorio;
    return RelatorioLayout(
      ocupado: _carregando || _exportando,
      filtros: [
        RelatorioFiltroSecao(
          titulo: 'Consultar',
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (consulta, rotulo) in [
              (_ConsultaHoras.especialidade, 'Por especialidade'),
              (_ConsultaHoras.medico, 'Por médico'),
            ])
              ChoiceChip(
                label: Text(rotulo),
                selected: _consulta == consulta,
                onSelected: (_) => setState(() {
                  _consulta = consulta;
                  _relatorio = null;
                  _erro = null;
                }),
              ),
          ]),
        ),
        RelatorioPeriodoFiltros<PeriodoHorasEspecialidade>(
          opcoes: [
            for (final p in PeriodoHorasEspecialidade.values
                .where((p) => p != PeriodoHorasEspecialidade.personalizado))
              (p, _rotuloPeriodo(p))
          ],
          selecionado: _periodoSelecionado,
          onChanged: (p) => setState(() {
            _periodoSelecionado = p;
            _dataReferencia = _inicioRelatorio;
            _atualizarIntervalo();
            _relatorio = null;
            _erro = null;
          }),
          inicio: _buildBotaoData(inicial: true),
          fim: _buildBotaoData(inicial: false),
        ),
        const Divider(),
        if (_porMedico)
          RelatorioFiltroSecao(
            titulo:
                'Médicos · ${_medicosSelecionados.length}/${_medicos.length}',
            child: _medicos.isEmpty
                ? const Text('Esta unidade não tem médicos ativos.')
                : SearchableSelectionField<String>.multiple(
                    key: const ValueKey('relatorio_horas_medico'),
                    values: _medicosSelecionados,
                    label: 'Médicos',
                    hint: 'Selecionar médicos...',
                    showLabel: false,
                    dialogTitle: 'Selecionar médicos',
                    searchHint: 'Pesquisar por nome ou especialidade',
                    suffixIcon: Icons.arrow_drop_down,
                    options: [
                      for (final medico in _medicos)
                        SearchableSelectionOption(
                          value: medico.id,
                          label:
                              '${medico.nome} · ${medico.especialidade.trim().isEmpty ? 'Sem especialidade' : medico.especialidade.trim()}',
                        ),
                    ],
                    onSelectionChanged: (ids) => setState(() {
                      _medicosSelecionados
                        ..clear()
                        ..addAll(ids);
                      _relatorio = null;
                      _erro = null;
                    }),
                  ),
          )
        else
          RelatorioFiltroSecao(
              titulo:
                  'Especialidades · ${_selecionadas.length}/${_especialidades.length}',
              child: Column(children: [
                if (_especialidades.isEmpty)
                  const Text(
                      'Esta unidade não tem especialidades com médicos ativos.'),
                CheckboxListTile(
                    key: const ValueKey('relatorio_todas_especialidades'),
                    title: const Text('Todas', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selecionadas.length == _especialidades.length
                        ? true
                        : _selecionadas.isEmpty
                            ? false
                            : null,
                    tristate: true,
                    onChanged: (_) => _selecionarEspecialidades(_especialidades,
                        _selecionadas.length != _especialidades.length)),
                for (final especialidade in _especialidades)
                  CheckboxListTile(
                      title: Text(especialidade,
                          style: const TextStyle(fontSize: 12)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selecionadas.contains(especialidade),
                      onChanged: (valor) => _selecionarEspecialidades(
                          [especialidade], valor ?? false)),
              ])),
      ],
      acoes: RelatorioAcoes(
        onGerar: !_selecaoValida || _carregando || _exportando
            ? null
            : _carregarRelatorio,
        onExportar: relatorio == null || _exportando || _carregando
            ? null
            : _escolherExportacao,
        textoExportar: 'Exportar',
        iconeExportar: Icons.ios_share_outlined,
        gerando: _carregando,
        exportando: _exportando,
      ),
      resultado: _carregando
          ? _buildCarregamento()
          : _erro != null
              ? Center(
                  child:
                      _quadro(Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_erro!),
                  TextButton(
                      onPressed: !_opcoesCarregadas
                          ? _carregarEspecialidades
                          : _carregarRelatorio,
                      child: const Text('Tentar novamente')),
                ])))
              : !_selecaoValida
                  ? RelatorioEstadoVazio(
                      texto: _porMedico
                          ? 'Selecione um ou mais médicos para gerar o relatório.'
                          : 'Selecione pelo menos uma especialidade para gerar o relatório.')
                  : relatorio == null
                      ? const RelatorioEstadoVazio()
                      : ListView(children: [
                          _buildResumoCard(relatorio),
                          const SizedBox(height: 12),
                          if (relatorio.porMedico)
                            ...relatorio.medicos.map((medico) =>
                                HorasMedicoCard(
                                    medico: medico, relatorio: relatorio))
                          else
                            _buildListaEspecialidades(relatorio),
                        ]),
    );
  }

  Widget _buildBotaoData({required bool inicial}) => OutlinedButton.icon(
        onPressed: () => _selecionarData(inicial: inicial),
        icon: const Icon(Icons.calendar_month_outlined, size: 20),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inicial ? 'Data inicial' : 'Data final',
              style: const TextStyle(fontSize: 11)),
          Text(_dateFormat.format(inicial ? _inicioRelatorio : _fimRelatorio)),
        ]),
      );

  Widget _buildResumoCard(RelatorioHorasEspecialidade relatorio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo — ${_dateFormat.format(relatorio.inicio)} a ${_dateFormat.format(relatorio.fim)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildChipResumo(
                  titulo: 'Especialidades',
                  valor: '${relatorio.totalEspecialidades}',
                ),
                _buildChipResumo(
                  titulo: 'Médicos',
                  valor: '${relatorio.totalMedicosAtivos}',
                ),
                _buildChipResumo(
                  titulo: 'Horas de consulta',
                  valor: '${_formatHoras(relatorio.totalHorasConsulta)} h',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipResumo({
    required String titulo,
    required String valor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MatrizColors.identificacao,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MatrizColors.borda),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: MatrizColors.texto,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: MatrizColors.iconeClaro,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaEspecialidades(RelatorioHorasEspecialidade relatorio) {
    if (relatorio.linhas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sem disponibilidade no período selecionado.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Por especialidade',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...relatorio.linhas.map((linha) => HorasEspecialidadeCard(
              linha: linha,
              totalMedicosAtivosClinica: relatorio.totalMedicosAtivosClinica,
            )),
      ],
    );
  }
}
