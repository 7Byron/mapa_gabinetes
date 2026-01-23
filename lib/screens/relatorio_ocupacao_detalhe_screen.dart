import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gabinete.dart';
import '../models/relatorio_ocupacao_dia.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/relatorios_service.dart';
import '../widgets/custom_appbar.dart';

enum PeriodoRelatorio { hoje, estaSemana, esteMes, esteAno, intervalo }

enum DiaSemanaFiltro {
  todos,
  segunda,
  terca,
  quarta,
  quinta,
  sexta,
  sabado,
  domingo,
}

class IntervaloRelatorio {
  final DateTime inicio;
  final DateTime fim;

  const IntervaloRelatorio({
    required this.inicio,
    required this.fim,
  });
}

class RelatorioOcupacaoDetalheScreen extends StatefulWidget {
  final Unidade unidade;
  final String titulo;
  final String? subtitulo;
  final String periodoLabel;
  final DateTime inicio;
  final DateTime fim;
  final List<String> gabineteIds;

  const RelatorioOcupacaoDetalheScreen({
    super.key,
    required this.unidade,
    required this.titulo,
    this.subtitulo,
    required this.periodoLabel,
    required this.inicio,
    required this.fim,
    required this.gabineteIds,
  });

  @override
  State<RelatorioOcupacaoDetalheScreen> createState() =>
      _RelatorioOcupacaoDetalheScreenState();
}

class _RelatorioOcupacaoDetalheScreenState
    extends State<RelatorioOcupacaoDetalheScreen> {
  static const Duration _tempoLimiteCalculo = Duration(seconds: 30);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateFormatCurto = DateFormat('dd/MM');
  final DateFormat _dateFormatSemana = DateFormat('EEE', 'pt_PT');

  bool _carregando = true;
  String? _erro;
  List<RelatorioOcupacaoDia> _dias = [];
  double _percentualGeral = 0.0;
  final ScrollController _graficoScrollController = ScrollController();
  late PeriodoRelatorio _periodoSelecionado;
  DiaSemanaFiltro _filtroDiaSelecionado = DiaSemanaFiltro.todos;
  List<Gabinete> _gabinetes = [];
  String? _gabineteSelecionadoId;
  late DateTime _dataInicio;
  late DateTime _dataFim;
  late DateTime _inicioRelatorio;
  late DateTime _fimRelatorio;

  @override
  void dispose() {
    _graficoScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _periodoSelecionado = _mapPeriodoInicial(widget.periodoLabel);
    _dataInicio = _normalizarData(widget.inicio);
    _dataFim = _normalizarData(widget.fim);
    _inicioRelatorio = _dataInicio;
    _fimRelatorio = _dataFim;
    if (_periodoSelecionado != PeriodoRelatorio.intervalo) {
      final intervalo = _calcularIntervalo();
      _inicioRelatorio = intervalo.inicio;
      _fimRelatorio = intervalo.fim;
    }
    _carregarGabinetes();
  }

  Future<void> _carregarGabinetes() async {
    try {
      final gabinetes = await buscarGabinetes(unidade: widget.unidade);
      gabinetes.sort((a, b) {
        final setorCmp = a.setor.compareTo(b.setor);
        if (setorCmp != 0) return setorCmp;
        final numA = _extrairNumeroGabinete(a.nome);
        final numB = _extrairNumeroGabinete(b.nome);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        return a.nome.compareTo(b.nome);
      });

      String? selecionado = _gabineteSelecionadoId;
      if (selecionado == null) {
        if (widget.gabineteIds.isNotEmpty) {
          for (final id in widget.gabineteIds) {
            if (gabinetes.any((g) => g.id == id)) {
              selecionado = id;
              break;
            }
          }
        }
        selecionado ??= gabinetes.isNotEmpty ? gabinetes.first.id : null;
      }

      if (!mounted) return;
      setState(() {
        _gabinetes = gabinetes;
        _gabineteSelecionadoId = selecionado;
      });
      await _carregarRelatorio();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os gabinetes.';
        _carregando = false;
      });
    }
  }

  Future<void> _carregarRelatorio() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final ids = _gabineteSelecionadoId != null
          ? [_gabineteSelecionadoId!]
          : widget.gabineteIds;
      if (ids.isEmpty) {
        setState(() {
          _erro = 'Nenhum gabinete selecionado.';
          _carregando = false;
        });
        return;
      }
      final dias = await RelatoriosService.ocupacaoPorGabinetesPorDia(
        inicio: _inicioRelatorio,
        fim: _fimRelatorio,
        unidade: widget.unidade,
        gabineteIds: ids,
      ).timeout(_tempoLimiteCalculo);

      final percentualGeral = _calcularPercentualGeral(dias);

      if (!mounted) return;
      setState(() {
        _dias = dias;
        _percentualGeral = percentualGeral;
        _carregando = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _erro = 'Tempo limite ao calcular o relatório.';
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível calcular o relatório.';
        _carregando = false;
      });
    }
  }

  Color _corParaPercentual(double valor) {
    final t = (valor.clamp(0.0, 100.0) / 100.0);
    return Color.lerp(Colors.blue, Colors.red, t) ?? Colors.blue;
  }

  DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  int? _extrairNumeroGabinete(String nome) {
    final match = RegExp(r'\d+').firstMatch(nome);
    if (match == null) return null;
    return int.tryParse(match.group(0) ?? '');
  }

  String _descricaoGabinete(Gabinete gabinete) {
    if (gabinete.especialidadesPermitidas.isNotEmpty) {
      return gabinete.especialidadesPermitidas.join(', ');
    }
    return 'Sem descrição';
  }

  String _tituloGabinete(Gabinete gabinete) {
    final descricao = _descricaoGabinete(gabinete);
    if (descricao == 'Sem descrição') {
      return gabinete.nome;
    }
    return '${gabinete.nome} ($descricao)';
  }

  PeriodoRelatorio _mapPeriodoInicial(String label) {
    final normalizado = label.trim().toLowerCase();
    switch (normalizado) {
      case 'hoje':
        return PeriodoRelatorio.hoje;
      case 'esta semana':
        return PeriodoRelatorio.estaSemana;
      case 'este mês':
        return PeriodoRelatorio.esteMes;
      case 'este ano':
        return PeriodoRelatorio.esteAno;
      default:
        return PeriodoRelatorio.intervalo;
    }
  }

  IntervaloRelatorio _calcularIntervalo() {
    final hoje = _normalizarData(DateTime.now());
    switch (_periodoSelecionado) {
      case PeriodoRelatorio.hoje:
        return IntervaloRelatorio(inicio: hoje, fim: hoje);
      case PeriodoRelatorio.estaSemana:
        final diff = hoje.weekday - DateTime.monday;
        final inicio = hoje.subtract(Duration(days: diff));
        final fim = inicio.add(const Duration(days: 6));
        return IntervaloRelatorio(inicio: inicio, fim: fim);
      case PeriodoRelatorio.esteMes:
        final inicio = DateTime(hoje.year, hoje.month, 1);
        final fim = DateTime(hoje.year, hoje.month + 1, 0);
        return IntervaloRelatorio(inicio: inicio, fim: fim);
      case PeriodoRelatorio.esteAno:
        final inicio = DateTime(hoje.year, 1, 1);
        final fim = DateTime(hoje.year, 12, 31);
        return IntervaloRelatorio(inicio: inicio, fim: fim);
      case PeriodoRelatorio.intervalo:
        final inicio = _normalizarData(_dataInicio);
        final fim = _normalizarData(_dataFim);
        if (fim.isBefore(inicio)) {
          return IntervaloRelatorio(inicio: fim, fim: inicio);
        }
        return IntervaloRelatorio(inicio: inicio, fim: fim);
    }
  }

  String _rotuloPeriodo(PeriodoRelatorio periodo) {
    switch (periodo) {
      case PeriodoRelatorio.hoje:
        return 'Hoje';
      case PeriodoRelatorio.estaSemana:
        return 'Esta semana';
      case PeriodoRelatorio.esteMes:
        return 'Este mês';
      case PeriodoRelatorio.esteAno:
        return 'Este ano';
      case PeriodoRelatorio.intervalo:
        return 'Intervalo definido';
    }
  }

  String _rotuloPeriodoTitulo(PeriodoRelatorio periodo) {
    switch (periodo) {
      case PeriodoRelatorio.hoje:
        return 'hoje';
      case PeriodoRelatorio.estaSemana:
        return 'esta semana';
      case PeriodoRelatorio.esteMes:
        return 'este mês';
      case PeriodoRelatorio.esteAno:
        return 'este ano';
      case PeriodoRelatorio.intervalo:
        return 'este período';
    }
  }

  String _rotuloFiltroDia(DiaSemanaFiltro filtro) {
    switch (filtro) {
      case DiaSemanaFiltro.todos:
        return 'Todos os dias';
      case DiaSemanaFiltro.segunda:
        return 'Segundas-Feiras';
      case DiaSemanaFiltro.terca:
        return 'Terças-Feiras';
      case DiaSemanaFiltro.quarta:
        return 'Quartas-Feiras';
      case DiaSemanaFiltro.quinta:
        return 'Quintas-Feiras';
      case DiaSemanaFiltro.sexta:
        return 'Sextas-Feiras';
      case DiaSemanaFiltro.sabado:
        return 'Sábados';
      case DiaSemanaFiltro.domingo:
        return 'Domingos';
    }
  }

  bool _matchFiltroDia(DateTime data) {
    switch (_filtroDiaSelecionado) {
      case DiaSemanaFiltro.todos:
        return true;
      case DiaSemanaFiltro.segunda:
        return data.weekday == DateTime.monday;
      case DiaSemanaFiltro.terca:
        return data.weekday == DateTime.tuesday;
      case DiaSemanaFiltro.quarta:
        return data.weekday == DateTime.wednesday;
      case DiaSemanaFiltro.quinta:
        return data.weekday == DateTime.thursday;
      case DiaSemanaFiltro.sexta:
        return data.weekday == DateTime.friday;
      case DiaSemanaFiltro.sabado:
        return data.weekday == DateTime.saturday;
      case DiaSemanaFiltro.domingo:
        return data.weekday == DateTime.sunday;
    }
  }

  double _calcularPercentualGeral(List<RelatorioOcupacaoDia> dias) {
    final filtrados = _filtrarDias(dias);
    double totalHoras = 0.0;
    double totalOcupadas = 0.0;
    for (final dia in filtrados) {
      totalHoras += dia.horasTotais;
      totalOcupadas += dia.horasOcupadas;
    }
    if (totalHoras <= 0) return 0.0;
    return (totalOcupadas / totalHoras) * 100.0;
  }

  List<RelatorioOcupacaoDia> _filtrarDias(
    List<RelatorioOcupacaoDia> dias,
  ) {
    return dias.where((dia) {
      return _matchFiltroDia(dia.data);
    }).toList();
  }

  Future<void> _selecionarDataInicio() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (novo == null) return;
    setState(() {
      _dataInicio = _normalizarData(novo);
      if (_dataFim.isBefore(_dataInicio)) {
        _dataFim = _dataInicio;
      }
    });
    await _recarregarComPeriodo();
  }

  Future<void> _selecionarDataFim() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (novo == null) return;
    setState(() {
      _dataFim = _normalizarData(novo);
      if (_dataFim.isBefore(_dataInicio)) {
        _dataInicio = _dataFim;
      }
    });
    await _recarregarComPeriodo();
  }

  Future<void> _recarregarComPeriodo() async {
    final intervalo = _calcularIntervalo();
    setState(() {
      _inicioRelatorio = intervalo.inicio;
      _fimRelatorio = intervalo.fim;
    });
    await _carregarRelatorio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.titulo,
        titleWidget: _buildAppBarTitle(),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 845),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? _buildErro()
                    : _buildConteudo(),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    const textoStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    if (_gabinetes.isEmpty || _gabineteSelecionadoId == null) {
      return Text(widget.titulo, style: textoStyle);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ocupação do Gabinete ', style: textoStyle),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _gabineteSelecionadoId,
              iconEnabledColor: Colors.white,
              dropdownColor: Colors.blue.shade700,
              style: textoStyle,
              items: _gabinetes.map((gabinete) {
                return DropdownMenuItem(
                  value: gabinete.id,
                  child: Text(_tituloGabinete(gabinete), style: textoStyle),
                );
              }).toList(),
              onChanged: (value) async {
                if (value == null || value == _gabineteSelecionadoId) return;
                setState(() {
                  _gabineteSelecionadoId = value;
                });
                await _carregarRelatorio();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_erro ?? 'Erro desconhecido'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _carregarRelatorio,
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildConteudo() {
    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final paddingHorizontal = constraints.maxWidth * 0.2;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
              child: _buildResumo(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Ocupação por dia',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        _buildGraficoDiasExpansivo(),
      ],
    );
  }

  Widget _buildGraficoDiasExpansivo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraMax = constraints.maxWidth;
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: larguraMax),
            child: _buildGraficoDias(),
          ),
        );
      },
    );
  }

  Widget _buildResumo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<PeriodoRelatorio>(
                    isExpanded: true,
                    value: _periodoSelecionado,
                    alignment: Alignment.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                    iconEnabledColor: Colors.blue.shade800,
                    items: [
                      for (final p in PeriodoRelatorio.values)
                        DropdownMenuItem(
                          value: p,
                          child: Center(child: Text(_rotuloPeriodo(p))),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        _periodoSelecionado = value;
                      });
                      await _recarregarComPeriodo();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<DiaSemanaFiltro>(
                    isExpanded: true,
                    value: _filtroDiaSelecionado,
                    alignment: Alignment.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                    iconEnabledColor: Colors.blue.shade800,
                    items: [
                      for (final f in DiaSemanaFiltro.values)
                        DropdownMenuItem(
                          value: f,
                          child: Center(child: Text(_rotuloFiltroDia(f))),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _filtroDiaSelecionado = value;
                        _percentualGeral = _calcularPercentualGeral(_dias);
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_periodoSelecionado == PeriodoRelatorio.intervalo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selecionarDataInicio,
                      child: Text(
                        'Início: ${_dateFormat.format(_dataInicio)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selecionarDataFim,
                      child: Text(
                        'Fim: ${_dateFormat.format(_dataFim)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Ocupação média, ${_rotuloPeriodoTitulo(_periodoSelecionado)}: '
                '${_textoPeriodo()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final percentual =
                      _percentualGeral.clamp(0.0, 100.0) / 100.0;
                  final largura = (constraints.maxWidth * percentual)
                      .clamp(8.0, double.infinity);
                  final maxLeft = constraints.maxWidth - 48.0;
                  final limiteEsquerda = 8.0;
                  final limiteDireita =
                      maxLeft < limiteEsquerda ? limiteEsquerda : maxLeft;
                  final posicaoEsquerda = (largura + 6.0)
                      .clamp(limiteEsquerda, limiteDireita);
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: largura,
                          decoration: BoxDecoration(
                            color: _corParaPercentual(_percentualGeral),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      Positioned(
                        left: posicaoEsquerda,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 48,
                          child: Center(
                            child: Text(
                              '${_percentualGeral.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _corParaPercentual(_percentualGeral),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoDias() {
    if (_dias.isEmpty) {
      return const Text('Sem dados no período selecionado.');
    }

    const alturaMaximaBarra = 280.0;
    final diasVisiveis = _filtrarDias(_dias);
    if (diasVisiveis.isEmpty) {
      return const Text('Sem dados úteis no período selecionado.');
    }
    final totalItens = diasVisiveis.length;
    double larguraItem = 90.0;
    double intervalo = 3.0;
    if (totalItens > 100) {
      larguraItem = 65.0;
      intervalo = 0.0;
    } else if (totalItens > 25) {
      larguraItem = 70.0;
      intervalo = 1.0;
    } else if (totalItens > 12) {
      larguraItem = 85.0;
      intervalo = 2.0;
    }
    final larguraTotal =
        (totalItens * (larguraItem + intervalo)).toDouble();
    final larguraBarra = intervalo == 0.0
        ? larguraItem
        : (larguraItem * 0.66).clamp(40.0, larguraItem).toDouble();
    return SizedBox(
      height: 440,
      child: Row(
        children: [
          _buildBotaoNavegacao(
            icon: Icons.chevron_left,
            onPressed: () => _moverGrafico(-220),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (!_graficoScrollController.hasClients) return;
                final novoOffset = (_graficoScrollController.offset -
                        details.delta.dx)
                    .clamp(
                        0.0, _graficoScrollController.position.maxScrollExtent);
                _graficoScrollController.jumpTo(novoOffset);
              },
              child: Scrollbar(
                controller: _graficoScrollController,
                thumbVisibility: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final larguraDisponivel = constraints.maxWidth;
                    final larguraFinal = larguraTotal < larguraDisponivel
                        ? larguraDisponivel
                        : larguraTotal;
                    return SingleChildScrollView(
                      controller: _graficoScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        width: larguraFinal,
                        child: Align(
                          alignment: larguraTotal < larguraDisponivel
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: diasVisiveis.map((dia) {
                      final percentual = dia.percentual.clamp(0.0, 100.0);
                      final cor = _corParaPercentual(percentual);
                      final alturaBarra =
                          (percentual / 100.0) * alturaMaximaBarra;
                      final alturaFinal =
                          alturaBarra < 4.0 ? 4.0 : alturaBarra;
                      final textoBarra = '${percentual.toStringAsFixed(0)}%';
                      final textoHoras = (dia.fechado || dia.horasTotais <= 0)
                          ? 'Fechado'
                          : '${_formatHoras(dia.horasOcupadas)}h/'
                              '${_formatHoras(dia.horasTotais)}h';
                      final posicaoTexto = (alturaFinal + 6)
                          .clamp(6.0, alturaMaximaBarra - 18.0);

                      return Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: intervalo / 2),
                        child: SizedBox(
                          width: larguraItem,
                          child: Column(
                            children: [
                              SizedBox(
                                height: alturaMaximaBarra,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Container(
                                      width: larguraBarra,
                                      height: alturaMaximaBarra,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    Container(
                                      width: larguraBarra,
                                      height: alturaFinal,
                                      decoration: BoxDecoration(
                                        color: cor,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: posicaoTexto,
                                      left: 0,
                                      right: 0,
                                      child: Text(
                                        textoBarra,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _dateFormatCurto.format(dia.data),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSemana(dia.data),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                textoHoras,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildBotaoNavegacao(
            icon: Icons.chevron_right,
            onPressed: () => _moverGrafico(220),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoNavegacao({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: Colors.grey[700]),
        onPressed: onPressed,
      ),
    );
  }

  void _moverGrafico(double delta) {
    if (!_graficoScrollController.hasClients) return;
    final novoOffset = (_graficoScrollController.offset + delta)
        .clamp(0.0, _graficoScrollController.position.maxScrollExtent);
    _graficoScrollController.animateTo(
      novoOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _formatHoras(double valor) {
    final arredondado = valor.round();
    return arredondado.toStringAsFixed(0);
  }

  String _textoPeriodo() {
    final inicio = _dateFormat.format(_inicioRelatorio);
    final fim = _dateFormat.format(_fimRelatorio);
    if (inicio == fim) return inicio;
    return '$inicio - $fim';
  }

  String _formatSemana(DateTime data) {
    final texto = _dateFormatSemana.format(data).replaceAll('.', '');
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }
}
