import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/excecao_serie.dart';
import '../models/gabinete.dart';
import '../models/relatorio_ocupacao_dia.dart';
import '../models/unidade.dart';
import '../services/alocacao_clinica_config_service.dart';
import '../services/alocacao_clinica_status_service.dart';
import '../services/cache_version_service.dart';
import '../services/gabinete_service.dart';
import '../services/medico_salvar_service.dart';
import '../services/relatorios_service.dart';
import '../services/serie_generator.dart';
import '../services/serie_service.dart';
import '../utils/time_utils.dart';
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

enum ModoGrafico { ocupacao, disponibilidade }

class IntervaloRelatorio {
  final DateTime inicio;
  final DateTime fim;

  const IntervaloRelatorio({
    required this.inicio,
    required this.fim,
  });
}

class IntervaloMinutos {
  final int inicio;
  final int fim;

  const IntervaloMinutos({required this.inicio, required this.fim});
}

class RelatorioDisponibilidadeDia {
  final DateTime data;
  final int inicioMinutos;
  final int fimMinutos;
  final List<IntervaloMinutos> intervalos;
  final bool fechado;
  final String? motivoFecho;

  const RelatorioDisponibilidadeDia({
    required this.data,
    required this.inicioMinutos,
    required this.fimMinutos,
    required this.intervalos,
    required this.fechado,
    this.motivoFecho,
  });

  int get minutosTotais => fimMinutos - inicioMinutos;

  int get minutosDisponiveis {
    int total = 0;
    for (final intervalo in intervalos) {
      total += (intervalo.fim - intervalo.inicio);
    }
    return total;
  }

  double get percentual {
    final total = minutosTotais;
    if (total <= 0) return 0.0;
    return (minutosDisponiveis / total) * 100.0;
  }
}

class _CacheRelatorioOcupacao {
  final List<RelatorioOcupacaoDia> dias;
  final double percentual;
  final String versao;
  final DateTime criadoEm;

  const _CacheRelatorioOcupacao({
    required this.dias,
    required this.percentual,
    required this.versao,
    required this.criadoEm,
  });
}

class _CacheRelatorioDisponibilidade {
  final List<RelatorioDisponibilidadeDia> dias;
  final double percentual;
  final String versao;
  final DateTime criadoEm;

  const _CacheRelatorioDisponibilidade({
    required this.dias,
    required this.percentual,
    required this.versao,
    required this.criadoEm,
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
  static final Map<String, _CacheRelatorioOcupacao> _cacheOcupacao = {};
  static final Map<String, _CacheRelatorioDisponibilidade>
      _cacheDisponibilidade = {};
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateFormatCurto = DateFormat('dd/MM');
  final DateFormat _dateFormatSemana = DateFormat('EEE', 'pt_PT');

  bool _carregando = true;
  String? _erro;
  List<RelatorioOcupacaoDia> _dias = [];
  List<RelatorioDisponibilidadeDia> _diasDisponibilidade = [];
  double _percentualGeral = 0.0;
  double _progressoCarregamento = 0.0;
  double _progressoDestino = 0.0;
  String _mensagemProgresso = 'A iniciar...';
  final ScrollController _graficoScrollController = ScrollController();
  Timer? _timerProgresso;
  late PeriodoRelatorio _periodoSelecionado;
  DiaSemanaFiltro _filtroDiaSelecionado = DiaSemanaFiltro.todos;
  ModoGrafico _modoGrafico = ModoGrafico.ocupacao;
  List<Gabinete> _gabinetes = [];
  String? _gabineteSelecionadoId;
  late DateTime _dataInicio;
  late DateTime _dataFim;
  late DateTime _inicioRelatorio;
  late DateTime _fimRelatorio;

  @override
  void dispose() {
    _graficoScrollController.dispose();
    _timerProgresso?.cancel();
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

  void _atualizarProgresso(double valor, String mensagem) {
    if (!mounted) return;
    final novoValor = valor.clamp(0.0, 1.0);
    setState(() {
      _progressoDestino =
          novoValor > _progressoDestino ? novoValor : _progressoDestino;
      _mensagemProgresso = mensagem;
    });
    _iniciarProgressoAnimado();
  }

  void _iniciarProgressoAnimado() {
    _timerProgresso ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) {
        if (!mounted || !_carregando) {
          _timerProgresso?.cancel();
          _timerProgresso = null;
          return;
        }
        final alvo = _progressoDestino;
        final atual = _progressoCarregamento;
        if (atual >= alvo) return;
        final delta = (alvo - atual).clamp(0.002, 0.02);
        final novoValor = (atual + delta).clamp(0.0, 1.0);
        if (novoValor != atual) {
          setState(() {
            _progressoCarregamento = novoValor;
          });
        }
      },
    );
  }

  Future<Map<String, int>> _obterVersoesCache() async {
    return CacheVersionService.fetchVersions(
      unidadeId: widget.unidade.id,
    );
  }

  String _montarVersaoOcupacao(Map<String, int> versoes) {
    return [
      versoes[CacheVersionService.fieldAlocacoes] ?? 0,
      versoes[CacheVersionService.fieldSeries] ?? 0,
      versoes[CacheVersionService.fieldClinicaConfig] ?? 0,
      versoes[CacheVersionService.fieldGabinetes] ?? 0,
    ].join('_');
  }

  String _montarVersaoDisponibilidade(Map<String, int> versoes) {
    return [
      versoes[CacheVersionService.fieldSeries] ?? 0,
      versoes[CacheVersionService.fieldDisponibilidades] ?? 0,
      versoes[CacheVersionService.fieldMedicos] ?? 0,
      versoes[CacheVersionService.fieldClinicaConfig] ?? 0,
      versoes[CacheVersionService.fieldGabinetes] ?? 0,
    ].join('_');
  }

  String _montarCacheKey(String tipo) {
    return [
      tipo,
      widget.unidade.id,
      _gabineteSelecionadoId,
      _inicioRelatorio.millisecondsSinceEpoch,
      _fimRelatorio.millisecondsSinceEpoch,
    ].join('|');
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
      if (selecionado == null && widget.gabineteIds.length == 1) {
        final id = widget.gabineteIds.first;
        if (gabinetes.any((g) => g.id == id)) {
          selecionado = id;
        }
      }

      if (!mounted) return;
      setState(() {
        _gabinetes = gabinetes;
        _gabineteSelecionadoId = selecionado;
      });
      if (selecionado == null) {
        setState(() {
          _dias = [];
          _diasDisponibilidade = [];
          _percentualGeral = 0.0;
          _carregando = false;
        });
      } else {
        await _carregarDadosPorModo();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os gabinetes.';
        _carregando = false;
      });
    }
  }

  Future<void> _carregarDadosPorModo() async {
    if (_modoGrafico == ModoGrafico.disponibilidade) {
      await _carregarDisponibilidade();
      return;
    }
    await _carregarRelatorio();
  }

  Future<void> _carregarRelatorio() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _progressoCarregamento = 0.0;
      _progressoDestino = 0.0;
      _mensagemProgresso = 'A iniciar...';
    });

    try {
      _atualizarProgresso(0.05, 'A verificar cache...');
      if (_gabineteSelecionadoId == null) {
        setState(() {
          _dias = [];
        _diasDisponibilidade = [];
          _percentualGeral = 0.0;
          _carregando = false;
        });
        return;
      }
      final versoes = await _obterVersoesCache();
      final versaoCache = _montarVersaoOcupacao(versoes);
      final cacheKey = _montarCacheKey('ocupacao');
      final cache = _cacheOcupacao[cacheKey];
      if (cache != null && cache.versao == versaoCache) {
        _atualizarProgresso(0.9, 'A usar cache...');
        if (!mounted) return;
        setState(() {
          _dias = cache.dias;
          _percentualGeral = cache.percentual;
          _carregando = false;
        });
        _atualizarProgresso(1.0, 'Concluído');
        return;
      }
      _atualizarProgresso(0.2, 'A carregar alocações...');
      final ids = [_gabineteSelecionadoId!];
      final dias = await RelatoriosService.ocupacaoPorGabinetesPorDia(
        inicio: _inicioRelatorio,
        fim: _fimRelatorio,
        unidade: widget.unidade,
        gabineteIds: ids,
      ).timeout(_tempoLimiteCalculo);

      _atualizarProgresso(0.8, 'A calcular percentuais...');
      final percentualGeral = _calcularPercentualGeral(dias);
      _atualizarProgresso(1.0, 'Concluído');

      if (!mounted) return;
      setState(() {
        _dias = dias;
        _percentualGeral = percentualGeral;
        _carregando = false;
      });
      _cacheOcupacao[cacheKey] = _CacheRelatorioOcupacao(
        dias: dias,
        percentual: percentualGeral,
        versao: versaoCache,
        criadoEm: DateTime.now(),
      );
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

  Future<void> _carregarDisponibilidade() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _progressoCarregamento = 0.0;
      _progressoDestino = 0.0;
      _mensagemProgresso = 'A iniciar...';
    });

    if (_gabineteSelecionadoId == null) {
      setState(() {
        _diasDisponibilidade = [];
        _percentualGeral = 0.0;
        _carregando = false;
      });
      return;
    }

    try {
      _atualizarProgresso(0.05, 'A verificar cache...');
      final versoes = await _obterVersoesCache();
      final versaoCache = _montarVersaoDisponibilidade(versoes);
      final cacheKey = _montarCacheKey('disponibilidade');
      final cache = _cacheDisponibilidade[cacheKey];
      if (cache != null && cache.versao == versaoCache) {
        _atualizarProgresso(0.9, 'A usar cache...');
        if (!mounted) return;
        setState(() {
          _diasDisponibilidade = cache.dias;
          _percentualGeral = cache.percentual;
          _carregando = false;
        });
        _atualizarProgresso(1.0, 'Concluído');
        return;
      }
      _atualizarProgresso(0.1, 'A carregar configurações da clínica...');
      final config =
          await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
        unidadeId: widget.unidade.id,
        forcarServidor: false,
      );

      final feriadosPorAno = <int, List<Map<String, String>>>{};
      final encerramentosPorAno = <int, List<Map<String, dynamic>>>{};
      for (final ano in _anosNoIntervalo(_inicioRelatorio, _fimRelatorio)) {
        _atualizarProgresso(0.2, 'A carregar feriados e encerramentos...');
        feriadosPorAno[ano] =
            await AlocacaoClinicaConfigService.carregarFeriados(
          unidadeId: widget.unidade.id,
          anoSelecionado: ano,
          forcarServidor: false,
        );
        encerramentosPorAno[ano] =
            await AlocacaoClinicaConfigService.carregarDiasEncerramento(
          unidadeId: widget.unidade.id,
          anoSelecionado: ano,
          forcarServidor: false,
        );
      }

      _atualizarProgresso(0.3, 'A carregar médicos...');
      final medicos = await buscarMedicos(unidade: widget.unidade);
      final medicosAtivos = medicos.where((m) => m.ativo).toList();

      final intervalosPorDia = <String, List<IntervaloMinutos>>{};
      final gabineteSelecionado = _gabineteSelecionadoId!;

      for (int i = 0; i < medicosAtivos.length; i++) {
        final medico = medicosAtivos[i];
        if (medicosAtivos.isNotEmpty && (i % 4 == 0 || i == medicosAtivos.length - 1)) {
          final progressoMedicos =
              0.35 + (0.4 * ((i + 1) / medicosAtivos.length));
          _atualizarProgresso(
            progressoMedicos.clamp(0.35, 0.75),
            'A carregar disponibilidades médicas...',
          );
        }
        final series = await SerieService.carregarSeries(
          medico.id,
          unidade: widget.unidade,
          dataInicio: _inicioRelatorio,
          dataFim: _fimRelatorio,
          forcarServidor: false,
        );
        if (series.isEmpty) continue;
        final seriesAtivas = series.where((s) => s.ativo).toList();
        if (seriesAtivas.isEmpty) continue;
        final seriesPorId = {
          for (final serie in seriesAtivas) serie.id: serie,
        };
        final excecoes = await SerieService.carregarExcecoes(
          medico.id,
          unidade: widget.unidade,
          dataInicio: _inicioRelatorio,
          dataFim: _fimRelatorio,
          forcarServidor: false,
        );
        final excecoesMap = _mapExcecoes(excecoes);
        final disponibilidades = SerieGenerator.gerarDisponibilidades(
          series: seriesAtivas,
          excecoes: excecoes,
          dataInicio: _inicioRelatorio,
          dataFim: _fimRelatorio,
        );

        for (final disp in disponibilidades) {
          final dataNormalizada = _normalizarData(disp.data);
          final dataKey = _dataKey(dataNormalizada);
          final serieId = _extrairSerieId(disp.id, dataKey);
          if (serieId == null) continue;
          final serie = seriesPorId[serieId];
          if (serie == null) continue;

          final excecao = excecoesMap['${serie.id}_$dataKey'];
          final gabineteId = excecao?.gabineteId ??
              serie.obterGabineteParaData(dataNormalizada);
          if (gabineteId == null || gabineteId != gabineteSelecionado) {
            continue;
          }

          if (disp.horarios.length < 2) continue;
          final inicioMin = TimeUtils.parseTimeToMinutes(disp.horarios[0]);
          final fimMin = TimeUtils.parseTimeToMinutes(disp.horarios[1]);
          if (fimMin <= inicioMin) continue;

          final keyDia = _dataKey(dataNormalizada);
          intervalosPorDia.putIfAbsent(keyDia, () => []);
          intervalosPorDia[keyDia]!.add(
            IntervaloMinutos(inicio: inicioMin, fim: fimMin),
          );
        }
      }

      _atualizarProgresso(0.85, 'A consolidar dias...');
      final resultados = <RelatorioDisponibilidadeDia>[];
      for (final dia in _gerarDatasNoIntervalo(
        _inicioRelatorio,
        _fimRelatorio,
      )) {
        final feriadosAno = feriadosPorAno[dia.year] ?? [];
        final encerramentosAno = encerramentosPorAno[dia.year] ?? [];
        final status = AlocacaoClinicaStatusService.verificar(
          data: dia,
          nuncaEncerra: config.nuncaEncerra,
          encerraFeriados: config.encerraFeriados,
          encerraDias: config.encerraDias,
          horariosClinica: config.horariosClinica,
          diasEncerramento: encerramentosAno,
          feriados: feriadosAno,
        );
        if (status.fechada) {
          resultados.add(
            RelatorioDisponibilidadeDia(
              data: dia,
              inicioMinutos: 0,
              fimMinutos: 0,
              intervalos: const [],
              fechado: true,
              motivoFecho: status.mensagem,
            ),
          );
          continue;
        }

        final horariosDia = config.horariosClinica[dia.weekday] ?? [];
        int inicioMinutos = 0;
        int fimMinutos = 0;
        if (horariosDia.length >= 2) {
          inicioMinutos = TimeUtils.parseTimeToMinutes(horariosDia[0]);
          fimMinutos = TimeUtils.parseTimeToMinutes(horariosDia[1]);
        } else if (config.nuncaEncerra) {
          inicioMinutos = 0;
          fimMinutos = 24 * 60;
        }
        if (fimMinutos <= inicioMinutos) {
          resultados.add(
            RelatorioDisponibilidadeDia(
              data: dia,
              inicioMinutos: 0,
              fimMinutos: 0,
              intervalos: const [],
              fechado: true,
              motivoFecho: 'Sem horários',
            ),
          );
          continue;
        }

        final keyDia = _dataKey(dia);
        final intervalos = intervalosPorDia[keyDia] ?? [];
        final intervalosFiltrados =
            _filtrarEUnirIntervalos(intervalos, inicioMinutos, fimMinutos);

        resultados.add(
          RelatorioDisponibilidadeDia(
            data: dia,
            inicioMinutos: inicioMinutos,
            fimMinutos: fimMinutos,
            intervalos: intervalosFiltrados,
            fechado: false,
          ),
        );
      }

      _atualizarProgresso(0.95, 'A calcular percentuais...');
      final percentualGeral =
          _calcularPercentualGeralDisponibilidade(resultados);
      _atualizarProgresso(1.0, 'Concluído');

      if (!mounted) return;
      setState(() {
        _diasDisponibilidade = resultados;
        _percentualGeral = percentualGeral;
        _carregando = false;
      });
      _cacheDisponibilidade[cacheKey] = _CacheRelatorioDisponibilidade(
        dias: resultados,
        percentual: percentualGeral,
        versao: versaoCache,
        criadoEm: DateTime.now(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível calcular a disponibilidade.';
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

  String _dataKey(DateTime data) {
    return '${data.year}-${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  Iterable<int> _anosNoIntervalo(DateTime inicio, DateTime fim) sync* {
    for (int ano = inicio.year; ano <= fim.year; ano++) {
      yield ano;
    }
  }

  Iterable<DateTime> _gerarDatasNoIntervalo(
    DateTime inicio,
    DateTime fim,
  ) sync* {
    var atual = _normalizarData(inicio);
    final fimNormalizado = _normalizarData(fim);
    while (!atual.isAfter(fimNormalizado)) {
      yield atual;
      atual = atual.add(const Duration(days: 1));
    }
  }

  Map<String, ExcecaoSerie> _mapExcecoes(List<ExcecaoSerie> excecoes) {
    final map = <String, ExcecaoSerie>{};
    for (final excecao in excecoes) {
      final dataKey = _dataKey(excecao.data);
      map['${excecao.serieId}_$dataKey'] = excecao;
    }
    return map;
  }

  List<IntervaloMinutos> _filtrarEUnirIntervalos(
    List<IntervaloMinutos> intervalos,
    int inicioMinutos,
    int fimMinutos,
  ) {
    final filtrados = <IntervaloMinutos>[];
    for (final intervalo in intervalos) {
      final inicio = intervalo.inicio.clamp(inicioMinutos, fimMinutos);
      final fim = intervalo.fim.clamp(inicioMinutos, fimMinutos);
      if (fim > inicio) {
        filtrados.add(IntervaloMinutos(inicio: inicio, fim: fim));
      }
    }
    if (filtrados.isEmpty) return [];
    filtrados.sort((a, b) => a.inicio.compareTo(b.inicio));
    final unidos = <IntervaloMinutos>[];
    var atual = filtrados.first;
    for (int i = 1; i < filtrados.length; i++) {
      final prox = filtrados[i];
      if (prox.inicio <= atual.fim) {
        atual = IntervaloMinutos(
          inicio: atual.inicio,
          fim: prox.fim > atual.fim ? prox.fim : atual.fim,
        );
      } else {
        unidos.add(atual);
        atual = prox;
      }
    }
    unidos.add(atual);
    return unidos;
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

  double _calcularPercentualGeralDisponibilidade(
    List<RelatorioDisponibilidadeDia> dias,
  ) {
    final filtrados = _filtrarDiasDisponibilidade(dias);
    int totalMinutos = 0;
    int totalDisponiveis = 0;
    for (final dia in filtrados) {
      totalMinutos += dia.minutosTotais;
      totalDisponiveis += dia.minutosDisponiveis;
    }
    if (totalMinutos <= 0) return 0.0;
    return (totalDisponiveis / totalMinutos) * 100.0;
  }

  List<RelatorioOcupacaoDia> _filtrarDias(
    List<RelatorioOcupacaoDia> dias,
  ) {
    return dias.where((dia) {
      if (dia.fechado) return false;
      return _matchFiltroDia(dia.data);
    }).toList();
  }

  List<RelatorioDisponibilidadeDia> _filtrarDiasDisponibilidade(
    List<RelatorioDisponibilidadeDia> dias,
  ) {
    return dias.where((dia) {
      if (dia.fechado) return false;
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
    await _carregarDadosPorModo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.titulo,
        titleWidget: _buildAppBarTitle(),
        onRefresh: _forcarAtualizacao,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 845),
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

  Widget _buildAppBarTitle() {
    const textoStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    if (_gabinetes.isEmpty) {
      return Text(widget.titulo, style: textoStyle);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ocupação do Gabinete ', style: textoStyle),
          const SizedBox(width: 8),
          _buildDropdownGabinete3D(textoStyle),
        ],
      ),
    );
  }

  Widget _buildDropdownGabinete3D(TextStyle textoStyle) {
    final base = Colors.blue.shade700;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade900.withOpacity(0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      base.withOpacity(0.92),
                      base.withOpacity(0.98),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 2,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 1,
              child: Container(color: Colors.white.withOpacity(0.22)),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 1,
              child: Container(color: Colors.white.withOpacity(0.18)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _gabineteSelecionadoId,
                  iconEnabledColor: Colors.white,
                  dropdownColor: Colors.blue.shade700,
                  style: textoStyle,
                  hint: const Text(
                    'Selecionar gabinete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
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
                    await _carregarDadosPorModo();
                  },
                ),
              ),
            ),
          ],
        ),
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
          onPressed: _carregarDadosPorModo,
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildBarra3D({
    required double width,
    required double height,
    required Color cor,
    required double radius,
  }) {
    final espessura = height >= 10 ? 2.0 : 1.0;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cor.withOpacity(0.98),
                cor.withOpacity(0.85),
                cor.withOpacity(0.7),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: cor.withOpacity(0.55),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: espessura,
                child: Container(color: Colors.white.withOpacity(0.35)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: espessura,
                child: Container(color: Colors.black.withOpacity(0.18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge3D({
    required String texto,
    required Color cor,
  }) {
    const radius = 12.0;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cor.withOpacity(0.98),
                cor.withOpacity(0.8),
              ],
            ),
            border: Border.all(
              color: cor.withOpacity(0.6),
              width: 0.6,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(color: Colors.white.withOpacity(0.35)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(color: Colors.black.withOpacity(0.18)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon3D({
    required IconData icon,
    required Color cor,
    required bool selecionado,
  }) {
    final base =
        selecionado ? cor : (Color.lerp(cor, Colors.grey.shade500, 0.6) ?? cor);
    final topo = base.withOpacity(selecionado ? 0.4 : 0.2);
    final baseFundo = base.withOpacity(selecionado ? 0.28 : 0.12);
    final borda = base.withOpacity(selecionado ? 0.8 : 0.4);
    final sombraPrincipal = BoxShadow(
      color: base.withOpacity(selecionado ? 0.5 : 0.2),
      blurRadius: selecionado ? 10 : 4,
      offset: const Offset(0, 3),
    );
    final sombraSecundaria = BoxShadow(
      color: Colors.white.withOpacity(selecionado ? 0.35 : 0.18),
      blurRadius: selecionado ? 6 : 3,
      offset: const Offset(0, -1),
    );
    return Transform.scale(
      scale: selecionado ? 1.06 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topo, baseFundo],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borda, width: selecionado ? 1.1 : 0.8),
          boxShadow: [sombraPrincipal, sombraSecundaria],
        ),
        child: SizedBox(
          width: 36,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(color: Colors.white.withOpacity(0.35)),
              ),
              Icon(icon, size: 20, color: base),
            ],
          ),
        ),
      ),
    );
  }

  bool _cacheKeyPertenceUnidade(String key, String unidadeId) {
    final partes = key.split('|');
    return partes.length > 1 && partes[1] == unidadeId;
  }

  Future<void> _forcarAtualizacao() async {
    final unidadeId = widget.unidade.id;
    _cacheOcupacao.removeWhere(
      (key, _) => _cacheKeyPertenceUnidade(key, unidadeId),
    );
    _cacheDisponibilidade.removeWhere(
      (key, _) => _cacheKeyPertenceUnidade(key, unidadeId),
    );
    await _carregarDadosPorModo();
  }

  Widget _buildCarregamento() {
    final percentual = (_progressoCarregamento * 100).clamp(0, 100).toInt();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progressoCarregamento),
            const SizedBox(height: 12),
            Text(
              '$percentual%',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
        _buildToggleGrafico(),
        const SizedBox(height: 8),
        Text(
          _modoGrafico == ModoGrafico.disponibilidade
              ? 'Ocupação por dia e hora'
              : 'Ocupação por dia',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        _buildGraficoDiasExpansivo(),
      ],
    );
  }

  Widget _buildToggleGrafico() {
    return Center(
      child: ToggleButtons(
        borderRadius: BorderRadius.circular(12),
        borderColor: Colors.transparent,
        selectedBorderColor: Colors.transparent,
        fillColor: Colors.transparent,
        selectedColor: Colors.transparent,
        color: Colors.transparent,
        isSelected: [
          _modoGrafico == ModoGrafico.ocupacao,
          _modoGrafico == ModoGrafico.disponibilidade,
        ],
        onPressed: (index) async {
          final novoModo =
              index == 0 ? ModoGrafico.ocupacao : ModoGrafico.disponibilidade;
          if (novoModo == _modoGrafico) return;
          setState(() {
            _modoGrafico = novoModo;
          });
          await _carregarDadosPorModo();
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildIcon3D(
              icon: Icons.bar_chart,
              cor: Colors.blue.shade600,
              selecionado: _modoGrafico == ModoGrafico.ocupacao,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildIcon3D(
              icon: Icons.stacked_bar_chart,
              cor: Colors.deepPurple.shade400,
              selecionado: _modoGrafico == ModoGrafico.disponibilidade,
            ),
          ),
        ],
      ),
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
            child: _modoGrafico == ModoGrafico.disponibilidade
                ? _buildGraficoDisponibilidade()
                : _buildGraficoDias(),
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
                        _percentualGeral = _modoGrafico ==
                                ModoGrafico.disponibilidade
                            ? _calcularPercentualGeralDisponibilidade(
                                _diasDisponibilidade,
                              )
                            : _calcularPercentualGeral(_dias);
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
                        child: _buildBarra3D(
                          width: largura,
                          height: 48,
                          cor: _corParaPercentual(_percentualGeral),
                          radius: 18,
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
                                    _buildBarra3D(
                                      width: larguraBarra,
                                      height: alturaFinal,
                                      cor: cor,
                                      radius: 14,
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

  Widget _buildGraficoDisponibilidade() {
    if (_diasDisponibilidade.isEmpty) {
      return const Text('Sem dados no período selecionado.');
    }

    const alturaMaximaBarra = 280.0;
    final diasVisiveis = _filtrarDiasDisponibilidade(_diasDisponibilidade);
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
    const legendaLateral = 28.0;

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
                    final larguraGrafico = larguraTotal + (2 * legendaLateral);
                    final larguraFinal = larguraGrafico < larguraDisponivel
                        ? larguraDisponivel
                        : larguraGrafico;
                    final inicioGlobal = diasVisiveis
                        .map((dia) => dia.inicioMinutos)
                        .reduce((a, b) => a < b ? a : b);
                    final fimGlobal = diasVisiveis
                        .map((dia) => dia.fimMinutos)
                        .reduce((a, b) => a > b ? a : b);
                    return SingleChildScrollView(
                      controller: _graficoScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        width: larguraFinal,
                        child: Align(
                          alignment: larguraGrafico < larguraDisponivel
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: SizedBox(
                            width: larguraGrafico,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: alturaMaximaBarra,
                                  child: Stack(
                                    children: [
                                      ..._buildLinhasHorasGlobais(
                                        inicioGlobal,
                                        fimGlobal,
                                        alturaMaximaBarra,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: legendaLateral,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: diasVisiveis.map((dia) {
                                            final percentual =
                                                dia.percentual.clamp(0.0, 100.0);
                                            final cor =
                                                _corParaPercentual(percentual);
                                            final totalGlobal =
                                                (fimGlobal - inicioGlobal)
                                                    .clamp(1, 24 * 60);
                                            final topAberto =
                                                ((dia.inicioMinutos -
                                                            inicioGlobal) /
                                                        totalGlobal) *
                                                    alturaMaximaBarra;
                                            final alturaAberto =
                                                ((dia.fimMinutos -
                                                            dia.inicioMinutos) /
                                                        totalGlobal) *
                                                    alturaMaximaBarra;
                                            final textoBarra =
                                                '${percentual.toStringAsFixed(0)}%';

                                            return Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: intervalo / 2,
                                              ),
                                              child: SizedBox(
                                                width: larguraItem,
                                                height: alturaMaximaBarra,
                                                child: Stack(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  children: [
                                                    SizedBox(
                                                      width: larguraBarra,
                                                      height:
                                                          alturaMaximaBarra,
                                                      child: Stack(
                                                        children: [
                                                          Positioned(
                                                            top: topAberto
                                                                .clamp(
                                                                    0.0,
                                                                    alturaMaximaBarra),
                                                            height: alturaAberto
                                                                .clamp(
                                                                    0.0,
                                                                    alturaMaximaBarra),
                                                            left: 0,
                                                            right: 0,
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .grey[300],
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            14),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width: larguraBarra,
                                                      height:
                                                          alturaMaximaBarra,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                        child: Stack(
                                                          children: [
                                                            ..._buildSegmentosDisponibilidade(
                                                              dia,
                                                              alturaMaximaBarra,
                                                              cor,
                                                              inicioGlobal,
                                                              fimGlobal,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 6,
                                                      left: 0,
                                                      right: 0,
                                                      child: Center(
                                                        child:
                                                            _buildBadge3D(
                                                          texto: textoBarra,
                                                          cor: cor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      ..._buildLegendasHorasGlobais(
                                        inicioGlobal,
                                        fimGlobal,
                                        alturaMaximaBarra,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: legendaLateral,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: diasVisiveis.map((dia) {
                                      final textoHoras = dia.fechado
                                          ? 'Fechado'
                                          : '${_formatHoras(dia.minutosDisponiveis / 60)}h/'
                                              '${_formatHoras(dia.minutosTotais / 60)}h';
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: intervalo / 2,
                                        ),
                                        child: SizedBox(
                                          width: larguraItem,
                                          child: Column(
                                            children: [
                                              Text(
                                                _dateFormatCurto
                                                    .format(dia.data),
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
                              ],
                            ),
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

  List<Widget> _buildSegmentosDisponibilidade(
    RelatorioDisponibilidadeDia dia,
    double alturaMaximaBarra,
    Color cor,
    int inicioGlobal,
    int fimGlobal,
  ) {
    if (dia.minutosTotais <= 0) return const [];
    final totalMinutos = (fimGlobal - inicioGlobal).clamp(1, 24 * 60);
    return dia.intervalos.map((intervalo) {
      final inicioRel = (intervalo.inicio - inicioGlobal) / totalMinutos;
      final fimRel = (intervalo.fim - inicioGlobal) / totalMinutos;
      final alturaSegmento = ((fimRel - inicioRel) * alturaMaximaBarra)
          .clamp(0.0, alturaMaximaBarra);
      final top = (inicioRel * alturaMaximaBarra).clamp(0.0, alturaMaximaBarra);
      return Positioned(
        left: 0,
        right: 0,
        top: top,
        height: alturaSegmento,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cor.withOpacity(0.98),
                cor.withOpacity(0.85),
                cor.withOpacity(0.7),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: cor.withOpacity(0.55),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: Container(color: Colors.white.withOpacity(0.35)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 2,
                child: Container(color: Colors.black.withOpacity(0.18)),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildLinhasHorasGlobais(
    int inicioMinutos,
    int fimMinutos,
    double alturaMaximaBarra,
  ) {
    final totalMinutos = (fimMinutos - inicioMinutos).clamp(1, 24 * 60);
    final totalHoras = (totalMinutos / 60).floor();
    if (totalHoras <= 0) return const [];
    final corLinha = Colors.grey[500]!.withOpacity(0.3);
    const paddingLabel = 6.0;
    final alturaUtil =
        (alturaMaximaBarra - (2 * paddingLabel)).clamp(0.0, alturaMaximaBarra);
    final widgets = <Widget>[];
    for (int i = 0; i <= totalHoras; i++) {
      final top = (paddingLabel + ((i / totalHoras) * alturaUtil))
          .clamp(0.0, alturaMaximaBarra - 1);
      widgets.add(
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: Container(height: 1, color: corLinha),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildLegendasHorasGlobais(
    int inicioMinutos,
    int fimMinutos,
    double alturaMaximaBarra,
  ) {
    final totalMinutos = (fimMinutos - inicioMinutos).clamp(1, 24 * 60);
    final totalHoras = (totalMinutos / 60).floor();
    if (totalHoras <= 0) return const [];
    const paddingLabel = 6.0;
    final alturaUtil =
        (alturaMaximaBarra - (2 * paddingLabel)).clamp(0.0, alturaMaximaBarra);
    final estiloTexto = TextStyle(
      fontSize: 9,
      color: Colors.grey[700],
    );
    final widgets = <Widget>[];
    for (int i = 0; i <= totalHoras; i++) {
      final minutos = inicioMinutos + (i * 60);
      final top = (paddingLabel + ((i / totalHoras) * alturaUtil))
          .clamp(0.0, alturaMaximaBarra);
      final posicaoTexto =
          (top - 6.0).clamp(0.0, alturaMaximaBarra - 12.0);
      final label = _formatHoraLegenda(minutos);
      widgets.add(
        Positioned(
          left: 0,
          top: posicaoTexto,
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(label, style: estiloTexto),
            ),
          ),
        ),
      );
      widgets.add(
        Positioned(
          right: 0,
          top: posicaoTexto,
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(label, style: estiloTexto),
            ),
          ),
        ),
      );
    }
    return widgets;
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

  String? _extrairSerieId(String disponibilidadeId, String dataKey) {
    const prefixo = 'serie_';
    final sufixo = '_$dataKey';
    if (!disponibilidadeId.startsWith(prefixo) ||
        !disponibilidadeId.endsWith(sufixo)) {
      return null;
    }
    final inicio = prefixo.length;
    final fim = disponibilidadeId.length - sufixo.length;
    if (fim <= inicio) return null;
    final serieId = disponibilidadeId.substring(inicio, fim);
    return serieId.isEmpty ? null : serieId;
  }

  String _formatHoraLegenda(int minutos) {
    final horas = (minutos ~/ 60) % 24;
    final mins = minutos % 60;
    if (mins == 0) {
      return '${horas.toString().padLeft(2, '0')}h';
    }
    return '${horas.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
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
