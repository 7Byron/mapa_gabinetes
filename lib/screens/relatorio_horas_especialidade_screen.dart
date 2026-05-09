import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/relatorio_horas_especialidade.dart';
import '../models/unidade.dart';
import '../services/cache_version_service.dart';
import '../services/relatorio_horas_especialidade_service.dart';
import '../widgets/custom_appbar.dart';

enum PeriodoHorasEspecialidade { dia, semana, mes, trimestre, semestre, ano }

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
    unawaited(_carregarRelatorio());
  }

  Future<void> _carregarRelatorio({bool forcarServidor = false}) async {
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
    await _carregarRelatorio(forcarServidor: true);
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

  Future<void> _selecionarDataReferencia() async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: _dataReferencia,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (novaData == null) return;

    setState(() {
      _dataReferencia = _normalizarData(novaData);
      _atualizarIntervalo();
    });
    await _carregarRelatorio();
  }

  String _formatHoras(double valor) => _numberFormat.format(valor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Horas por Especialidade',
        onRefresh: _forcarAtualizacao,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _carregando
                ? _buildCarregamento()
                : _erro != null
                    ? _buildErro()
                    : _buildConteudo(),
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

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_erro ?? 'Erro desconhecido'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _carregarRelatorio,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    final relatorio = _relatorio;
    if (relatorio == null) {
      return const Center(child: Text('Sem dados para apresentar.'));
    }

    return ListView(
      children: [
        _buildFiltrosCard(),
        const SizedBox(height: 12),
        _buildResumoCard(relatorio),
        const SizedBox(height: 12),
        _buildListaEspecialidades(relatorio),
      ],
    );
  }

  Widget _buildFiltrosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compacto = constraints.maxWidth < 620;
                final dropdown =
                    DropdownButtonFormField<PeriodoHorasEspecialidade>(
                  initialValue: _periodoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final periodo in PeriodoHorasEspecialidade.values)
                      DropdownMenuItem(
                        value: periodo,
                        child: Text(_rotuloPeriodo(periodo)),
                      ),
                  ],
                  onChanged: (value) async {
                    if (value == null || value == _periodoSelecionado) return;
                    setState(() {
                      _periodoSelecionado = value;
                      _atualizarIntervalo();
                    });
                    await _carregarRelatorio();
                  },
                );

                final botaoData = OutlinedButton.icon(
                  onPressed: _selecionarDataReferencia,
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Data base: ${_dateFormat.format(_dataReferencia)}',
                  ),
                );

                if (compacto) {
                  return Column(
                    children: [
                      dropdown,
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: botaoData,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: dropdown),
                    const SizedBox(width: 12),
                    botaoData,
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Intervalo: ${_dateFormat.format(_inicioRelatorio)}'
              ' - ${_dateFormat.format(_fimRelatorio)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCard(RelatorioHorasEspecialidade relatorio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo (${_rotuloPeriodo(_periodoSelecionado)})',
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
        ...relatorio.linhas.map((linha) {
          final destaque =
              '${linha.medicosComDisponibilidade} médico(s), ${_formatHoras(linha.horasConsulta)} h';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compacto = constraints.maxWidth < 500;
                  if (compacto) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linha.especialidade,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          destaque,
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Disponibilidade efetiva no período',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linha.especialidade,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Disponibilidade efetiva no período',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        destaque,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
