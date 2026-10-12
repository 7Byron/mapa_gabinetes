import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import '../services/medico_salvar_service.dart';
import '../services/relatorio_horas_excel_service.dart';
import '../utils/app_theme.dart';

import '../models/relatorio_horas_especialidade.dart';
import '../models/unidade.dart';
import '../services/cache_version_service.dart';
import '../services/relatorio_horas_especialidade_service.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/horas_especialidade_card.dart';

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

  const RelatorioHorasEspecialidadeScreen({
    super.key,
    required this.unidade,
  });

  @override
  State<RelatorioHorasEspecialidadeScreen> createState() =>
      _RelatorioHorasEspecialidadeScreenState();
}

class _RelatorioHorasEspecialidadeScreenState
    extends State<RelatorioHorasEspecialidadeScreen> {
  static final Map<String, _CacheRelatorioHorasEspecialidade> _cache = {};

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _numberFormat = NumberFormat('#,##0.##', 'pt_PT');

  bool _carregando = true;
  bool _exportando = false;
  List<String> _especialidades = [];
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

  Future<void> _carregarEspecialidades() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _mensagemProgresso = 'A carregar especialidades...';
    });
    try {
      final medicos = await buscarMedicos(unidade: widget.unidade);
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
        _especialidades = especialidades;
        _selecionadas.clear();
        _selecionadas.addAll(especialidades);
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as especialidades.';
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

  Future<void> _carregarRelatorio({bool forcarServidor = false}) async {
    if (_selecionadas.isEmpty || _carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
      _progresso = 0.0;
      _mensagemProgresso = 'A iniciar...';
    });

    try {
      _atualizarProgresso(0.04, 'A validar cache...');
      final versao = await _obterVersaoCache();
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

      final relatorio = await RelatorioHorasEspecialidadeService.calcular(
        unidade: widget.unidade,
        inicio: _inicioRelatorio,
        fim: _fimRelatorio,
        forcarServidor: forcarServidor,
        especialidades: Set.of(_selecionadas),
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
    _cache.removeWhere((key, _) => key.startsWith('${widget.unidade.id}|'));
    if (_especialidades.isEmpty) {
      await _carregarEspecialidades();
    } else {
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
      (_selecionadas.toList()..sort()).map(Uri.encodeComponent).join(','),
    ].join('|');
  }

  Future<String> _obterVersaoCache() async {
    final versoes =
        await CacheVersionService.fetchVersions(unidadeId: widget.unidade.id);
    return [
      versoes[CacheVersionService.fieldSeries] ?? 0,
      versoes[CacheVersionService.fieldDisponibilidades] ?? 0,
      versoes[CacheVersionService.fieldMedicos] ?? 0,
      versoes[CacheVersionService.fieldClinicaConfig] ?? 0,
    ].join('_');
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

  Future<void> _exportarExcel() async {
    final relatorio = _relatorio;
    if (relatorio == null || _exportando) return;
    setState(() => _exportando = true);
    try {
      final bytes = RelatorioHorasExcelService.gerar(
          unidade: widget.unidade.nome, relatorio: relatorio);
      final formato = DateFormat('yyyy-MM-dd');
      await FileSaver.instance.saveFile(
        name:
            'horas_especialidade_${formato.format(relatorio.inicio)}_${formato.format(relatorio.fim)}',
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

  String _formatHoras(double valor) => _numberFormat.format(valor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Horas de Especialidade',
        onRefresh: _forcarAtualizacao,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _carregando ? _buildCarregamento() : _buildConteudo(),
          ),
        ),
      ),
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
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _buildConteudo() {
    final relatorio = _relatorio;
    return ListView(children: [
      _buildSelecaoCard(),
      _buildFiltrosCard(),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
              child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(280, 60),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _selecionadas.isEmpty || _carregando || _exportando
                    ? null
                    : _carregarRelatorio,
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Gerar relatório'),
              ),
              OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(180, 60)),
                onPressed:
                    relatorio == null || _exportando ? null : _exportarExcel,
                icon: const Icon(Icons.download_outlined),
                label: Text(_exportando ? 'A exportar…' : 'Exportar Excel'),
              ),
            ],
          ))),
      if (_erro != null)
        _quadro(Column(children: [
          Text(_erro!),
          TextButton(
              onPressed: _especialidades.isEmpty
                  ? _carregarEspecialidades
                  : _carregarRelatorio,
              child: const Text('Tentar novamente')),
        ]))
      else if (_selecionadas.isEmpty)
        _quadro(const Text(
            'Selecione pelo menos uma especialidade para gerar o relatório.'))
      else if (relatorio != null) ...[
        _buildResumoCard(relatorio),
        const SizedBox(height: 12),
        _buildListaEspecialidades(relatorio),
      ],
    ]);
  }

  Widget _buildSelecaoCard() =>
      _quadro(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final titulo = Text('1. Selecionar especialidades',
              style: Theme.of(context).textTheme.titleLarge);
          final acoes = Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                    '${_selecionadas.length} de ${_especialidades.length} selecionadas'),
                TextButton(
                    onPressed: () =>
                        _selecionarEspecialidades(_especialidades, true),
                    child: const Text('Selecionar todas')),
                TextButton(
                    onPressed: () =>
                        _selecionarEspecialidades(_especialidades, false),
                    child: const Text('Desselecionar todas')),
              ]);
          if (constraints.maxWidth >= 860) {
            return Row(children: [titulo, const Spacer(), acoes]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                Align(alignment: Alignment.centerRight, child: acoes)
              ]);
        }),
        const SizedBox(height: 12),
        if (_especialidades.isEmpty)
          const Text('Esta unidade não tem especialidades com médicos ativos.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final especialidade in _especialidades)
            FilterChip(
              label: Text(especialidade),
              selected: _selecionadas.contains(especialidade),
              backgroundColor: MyAppTheme.gabineteLivre,
              selectedColor: MyAppTheme.gabineteOcupado,
              side: const BorderSide(color: MyAppTheme.bordaGabineteOcupado),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (valor) =>
                  _selecionarEspecialidades([especialidade], valor),
            ),
        ]),
      ]));

  Widget _buildFiltrosCard() =>
      _quadro(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('2. Escolher período',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final periodo in PeriodoHorasEspecialidade.values
              .where((p) => p != PeriodoHorasEspecialidade.personalizado))
            ChoiceChip(
                label: Text(_rotuloPeriodo(periodo)),
                selected: _periodoSelecionado == periodo,
                onSelected: (_) => setState(() {
                      _periodoSelecionado = periodo;
                      _dataReferencia = _inicioRelatorio;
                      _atualizarIntervalo();
                      _relatorio = null;
                      _erro = null;
                    })),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 10, children: [
          _buildBotaoData(inicial: true),
          _buildBotaoData(inicial: false)
        ]),
      ]));

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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              color: Colors.blue.shade900,
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
