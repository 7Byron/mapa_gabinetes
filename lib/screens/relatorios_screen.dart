import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/relatorio_ocupacao_prefs_service.dart';
import '../screens/relatorio_ocupacao_detalhe_screen.dart';

enum PeriodoRelatorio { hoje, estaSemana, esteMes, esteAno, intervalo }

class IntervaloRelatorio {
  final DateTime inicio;
  final DateTime fim;

  const IntervaloRelatorio({
    required this.inicio,
    required this.fim,
  });
}

class RelatoriosScreen extends StatefulWidget {
  final Unidade? unidade;

  const RelatoriosScreen({super.key, this.unidade});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  PeriodoRelatorio _periodoSelecionado = PeriodoRelatorio.estaSemana;
  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now();

  List<Gabinete> _gabinetes = [];
  Map<String, bool> _gabinetesSelecionados = {};
  String? _gabineteSelecionadoId;

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
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

  Map<String, List<Gabinete>> _agruparGabinetesPorSetor(
    List<Gabinete> gabinetes,
  ) {
    final map = <String, List<Gabinete>>{};
    for (final g in gabinetes) {
      map.putIfAbsent(g.setor, () => []).add(g);
    }
    return map;
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
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

    final idsSalvos =
        await RelatorioOcupacaoPrefsService.carregarGabinetesSelecionados(
      unidadeId: widget.unidade?.id,
    );
    final selecionados = <String, bool>{};
    for (final g in gabinetes) {
      selecionados[g.id] = idsSalvos == null ? true : idsSalvos.contains(g.id);
    }

    String? gabineteSelecionadoId;
    for (final g in gabinetes) {
      if (selecionados[g.id] ?? false) {
        gabineteSelecionadoId = g.id;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _gabinetes = gabinetes;
      _gabinetesSelecionados = selecionados;
      _gabineteSelecionadoId = gabineteSelecionadoId;
      _dataInicio = _normalizarData(_dataInicio);
      _dataFim = _normalizarData(_dataFim);
      _carregando = false;
    });
  }

  Future<void> _salvarSelecaoGabinetes() async {
    final ids = _gabinetes
        .where((g) => _gabinetesSelecionados[g.id] ?? false)
        .map((g) => g.id)
        .toList();
    await RelatorioOcupacaoPrefsService.salvarGabinetesSelecionados(
      ids,
      unidadeId: widget.unidade?.id,
    );
  }

  Future<void> _definirSelecaoTodos(bool selecionado) async {
    setState(() {
      for (final g in _gabinetes) {
        _gabinetesSelecionados[g.id] = selecionado;
      }
      _garantirGabineteSelecionadoValido();
    });
    await _salvarSelecaoGabinetes();
  }

  Future<void> _atualizarSelecaoGabinete(String id, bool selecionado) async {
    setState(() {
      _gabinetesSelecionados[id] = selecionado;
      _garantirGabineteSelecionadoValido();
    });
    await _salvarSelecaoGabinetes();
  }

  void _garantirGabineteSelecionadoValido() {
    if (_gabineteSelecionadoId != null &&
        (_gabinetesSelecionados[_gabineteSelecionadoId!] ?? false)) {
      return;
    }
    _gabineteSelecionadoId = null;
    for (final g in _gabinetes) {
      if (_gabinetesSelecionados[g.id] ?? false) {
        _gabineteSelecionadoId = g.id;
        break;
      }
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

  Future<void> _selecionarDataInicio() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (novo == null) return;
    final normalizado = _normalizarData(novo);
    setState(() {
      _dataInicio = normalizado;
      if (_dataFim.isBefore(_dataInicio)) {
        _dataFim = _dataInicio;
      }
    });
  }

  Future<void> _selecionarDataFim() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (novo == null) return;
    final normalizado = _normalizarData(novo);
    setState(() {
      _dataFim = normalizado;
      if (_dataFim.isBefore(_dataInicio)) {
        _dataInicio = _dataFim;
      }
    });
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _mostrarSelecaoGabinete(
    List<Gabinete> gabinetesSelecionados,
  ) async {
    if (gabinetesSelecionados.isEmpty) return;
    final altura = MediaQuery.of(context).size.height * 0.75;
    final grupos = _agruparGabinetesPorSetor(gabinetesSelecionados);

    final escolhido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 400),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: altura,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selecionar gabinete',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ListView(
                        children: grupos.entries.map((entry) {
                          final setor = entry.key;
                          final lista = entry.value;
                          return ExpansionTile(
                            shape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            leading:
                                const Icon(Icons.folder, color: Colors.blue),
                            title: Text(
                              setor,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${lista.length} gabinete(s)'),
                            children: lista.map((gabinete) {
                              final isSelecionado =
                                  _gabineteSelecionadoId == gabinete.id;
                              return ListTile(
                                leading: Icon(
                                  isSelecionado
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isSelecionado ? Colors.blue : Colors.grey,
                                ),
                                title: Text(_tituloGabinete(gabinete)),
                                onTap: () =>
                                    Navigator.of(context).pop(gabinete.id),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (escolhido != null && mounted) {
      setState(() {
        _gabineteSelecionadoId = escolhido;
      });
    }
  }

  void _abrirRelatorioConjunto() {
    final gabinetesSelecionados = _gabinetes
        .where((g) => _gabinetesSelecionados[g.id] ?? false)
        .toList();
    if (gabinetesSelecionados.isEmpty) {
      _mostrarErro('Selecione pelo menos um gabinete.');
      return;
    }
    if (widget.unidade == null) {
      _mostrarErro('Unidade não definida.');
      return;
    }

    final intervalo = _calcularIntervalo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioOcupacaoDetalheScreen(
          unidade: widget.unidade!,
          titulo: 'Relatório conjunto',
          subtitulo:
              'Gabinetes: ${gabinetesSelecionados.length}',
          periodoLabel: _rotuloPeriodoTitulo(_periodoSelecionado),
          inicio: intervalo.inicio,
          fim: intervalo.fim,
          gabineteIds: gabinetesSelecionados.map((g) => g.id).toList(),
        ),
      ),
    );
  }

  void _abrirRelatorioGabinete() {
    if (_gabineteSelecionadoId == null) {
      _mostrarErro('Selecione um gabinete válido.');
      return;
    }
    if (widget.unidade == null) {
      _mostrarErro('Unidade não definida.');
      return;
    }

    final intervalo = _calcularIntervalo();
    final gabineteSelecionado = _gabinetes.firstWhere(
      (g) => g.id == _gabineteSelecionadoId,
      orElse: () => _gabinetes.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioOcupacaoDetalheScreen(
          unidade: widget.unidade!,
          titulo: 'Relatório do gabinete',
          subtitulo: _tituloGabinete(gabineteSelecionado),
          periodoLabel: _rotuloPeriodoTitulo(_periodoSelecionado),
          inicio: intervalo.inicio,
          fim: intervalo.fim,
          gabineteIds: [_gabineteSelecionadoId!],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final intervaloAtual = _calcularIntervalo();
    final gabinetesSelecionados = _gabinetes
        .where((g) => _gabinetesSelecionados[g.id] ?? false)
        .toList();

    return Scaffold(
      appBar: CustomAppBar(title: 'Relatórios de Ocupação'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          _buildPeriodoCard(intervaloAtual),
                          const SizedBox(height: 16),
                          _buildRelatorioConjuntoCard(
                            gabinetesSelecionados,
                          ),
                          const SizedBox(height: 16),
                          _buildRelatorioGabineteCard(
                            gabinetesSelecionados,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaGabinetesConjunto() {
    if (_gabinetes.isEmpty) {
      return const Text('Nenhum gabinete encontrado.');
    }

    final grupos = _agruparGabinetesPorSetor(_gabinetes);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: Column(
        children: grupos.entries.map((entry) {
          final setor = entry.key;
          final lista = entry.value;
          return ExpansionTile(
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
            ),
            collapsedShape: const RoundedRectangleBorder(
              side: BorderSide.none,
            ),
            leading: const Icon(Icons.folder, color: Colors.blue),
            title: Text(
              setor,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${lista.length} gabinete(s)'),
            children: lista.map((gabinete) {
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(_tituloGabinete(gabinete)),
                value: _gabinetesSelecionados[gabinete.id] ?? false,
                onChanged: (value) =>
                    _atualizarSelecaoGabinete(gabinete.id, value ?? false),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodoCard(IntervaloRelatorio intervalo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período do relatório',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<PeriodoRelatorio>(
              isExpanded: true,
              value: _periodoSelecionado,
              items: [
                for (final p in PeriodoRelatorio.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(_rotuloPeriodo(p)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _periodoSelecionado = value;
                });
              },
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
            Text(
              'Período: ${_dateFormat.format(intervalo.inicio)} - '
              '${_dateFormat.format(intervalo.fim)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatorioConjuntoCard(List<Gabinete> gabinetesSelecionados) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relatório conjunto',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Gabinetes selecionados: ${gabinetesSelecionados.length} de ${_gabinetes.length}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => _definirSelecaoTodos(true),
                  child: const Text('Selecionar todos'),
                ),
                TextButton(
                  onPressed: () => _definirSelecaoTodos(false),
                  child: const Text('Limpar seleção'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildListaGabinetesConjunto(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: gabinetesSelecionados.isEmpty
                  ? null
                  : _abrirRelatorioConjunto,
              child: const Text('Calcular relatório conjunto'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatorioGabineteCard(List<Gabinete> gabinetesSelecionados) {
    Gabinete? gabineteSelecionado;
    if (_gabineteSelecionadoId != null) {
      for (final g in gabinetesSelecionados) {
        if (g.id == _gabineteSelecionadoId) {
          gabineteSelecionado = g;
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Relatório por gabinete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (gabinetesSelecionados.isEmpty)
              const Text(
                'Selecione pelo menos um gabinete na lista acima.',
              )
            else
              InkWell(
                onTap: () => _mostrarSelecaoGabinete(gabinetesSelecionados),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gabineteSelecionado != null
                                  ? _tituloGabinete(gabineteSelecionado)
                                  : 'Selecionar gabinete',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (gabineteSelecionado == null)
                              Text(
                                'Toque para escolher',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (gabinetesSelecionados.isEmpty ||
                      _gabineteSelecionadoId == null)
                  ? null
                  : _abrirRelatorioGabinete,
              child: const Text('Calcular relatório do gabinete'),
            ),
          ],
        ),
      ),
    );
  }
}
