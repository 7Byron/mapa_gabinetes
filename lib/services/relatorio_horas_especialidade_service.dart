import 'dart:math' as math;

import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/medico.dart';
import '../models/relatorio_horas_especialidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/unidade.dart';
import '../utils/time_utils.dart';
import 'alocacao_clinica_config_service.dart';
import 'alocacao_clinica_status_service.dart';
import 'disponibilidade_unica_service.dart';
import 'medico_salvar_service.dart';
import 'serie_generator.dart';
import 'serie_service.dart';

class RelatorioHorasEspecialidadeService {
  static Future<RelatorioHorasEspecialidade> calcular({
    required Unidade unidade,
    required DateTime inicio,
    required DateTime fim,
    bool forcarServidor = false,
    void Function(double progresso, String mensagem)? onProgress,
  }) async {
    var inicioNormalizado = _normalizarData(inicio);
    var fimNormalizado = _normalizarData(fim);
    if (fimNormalizado.isBefore(inicioNormalizado)) {
      final temp = inicioNormalizado;
      inicioNormalizado = fimNormalizado;
      fimNormalizado = temp;
    }

    onProgress?.call(0.05, 'A carregar configurações da clínica...');
    final config =
        await AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
      unidadeId: unidade.id,
      forcarServidor: forcarServidor,
    );

    final anos = _anosNoIntervalo(inicioNormalizado, fimNormalizado).toList();
    final feriadosPorAno = <int, List<Map<String, String>>>{};
    final encerramentosPorAno = <int, List<Map<String, dynamic>>>{};

    for (int i = 0; i < anos.length; i++) {
      final ano = anos[i];
      onProgress?.call(
        0.08 + (0.12 * ((i + 1) / math.max(anos.length, 1))),
        'A carregar feriados e dias de encerramento...',
      );
      feriadosPorAno[ano] = await AlocacaoClinicaConfigService.carregarFeriados(
        unidadeId: unidade.id,
        anoSelecionado: ano,
        forcarServidor: forcarServidor,
      );
      encerramentosPorAno[ano] =
          await AlocacaoClinicaConfigService.carregarDiasEncerramento(
        unidadeId: unidade.id,
        anoSelecionado: ano,
        forcarServidor: forcarServidor,
      );
    }

    onProgress?.call(0.22, 'A preparar calendário do período...');
    final estadoClinicaPorDia = <String, _EstadoClinicaDia>{};
    for (final dia
        in _gerarDatasNoIntervalo(inicioNormalizado, fimNormalizado)) {
      final feriadosAno = feriadosPorAno[dia.year] ?? const [];
      final encerramentosAno = encerramentosPorAno[dia.year] ?? const [];

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
        estadoClinicaPorDia[_dataKey(dia)] = const _EstadoClinicaDia.fechado();
        continue;
      }

      final horariosDia = config.horariosClinica[dia.weekday] ?? const [];
      int abertura = 0;
      int fecho = 0;

      if (horariosDia.length >= 2) {
        final aberturaParsed = _parseHoraSegura(horariosDia[0]);
        final fechoParsed = _parseHoraSegura(horariosDia[1]);
        if (aberturaParsed != null && fechoParsed != null) {
          abertura = aberturaParsed;
          fecho = fechoParsed;
        }
      }

      if (fecho <= abertura && config.nuncaEncerra) {
        abertura = 0;
        fecho = 24 * 60;
      }

      if (fecho <= abertura) {
        estadoClinicaPorDia[_dataKey(dia)] = const _EstadoClinicaDia.fechado();
        continue;
      }

      estadoClinicaPorDia[_dataKey(dia)] =
          _EstadoClinicaDia.aberto(abertura: abertura, fecho: fecho);
    }

    onProgress?.call(0.25, 'A carregar médicos...');
    final medicos = await buscarMedicos(unidade: unidade);
    final medicosAtivos = medicos.where((m) => m.ativo).toList();
    if (medicosAtivos.isEmpty) {
      onProgress?.call(1.0, 'Concluído');
      return RelatorioHorasEspecialidade(
        inicio: inicioNormalizado,
        fim: fimNormalizado,
        linhas: const [],
      );
    }

    final acumuladoPorEspecialidade = <String, _AcumuladoEspecialidade>{};

    for (int i = 0; i < medicosAtivos.length; i++) {
      final medico = medicosAtivos[i];
      final especialidade = _normalizarEspecialidade(medico.especialidade);

      final disponibilidades = await _carregarDisponibilidadesMedicoPeriodo(
        medico: medico,
        unidade: unidade,
        anos: anos,
        inicio: inicioNormalizado,
        fim: fimNormalizado,
        forcarServidor: forcarServidor,
      );

      final intervalosPorDia = <String, List<_IntervaloMinutos>>{};
      for (final disponibilidade in disponibilidades) {
        final data = _normalizarData(disponibilidade.data);
        if (data.isBefore(inicioNormalizado) || data.isAfter(fimNormalizado)) {
          continue;
        }

        final key = _dataKey(data);
        final estadoDia = estadoClinicaPorDia[key];
        if (estadoDia == null || estadoDia.fechado) {
          continue;
        }

        final intervalos = _intervalosDaDisponibilidade(disponibilidade);
        if (intervalos.isEmpty) continue;
        intervalosPorDia.putIfAbsent(key, () => []);

        for (final intervalo in intervalos) {
          final inicioAjustado =
              math.max(intervalo.inicio, estadoDia.aberturaMinutos);
          final fimAjustado = math.min(intervalo.fim, estadoDia.fechoMinutos);
          if (fimAjustado <= inicioAjustado) continue;
          intervalosPorDia[key]!
              .add(_IntervaloMinutos(inicioAjustado, fimAjustado));
        }
      }

      int minutosMedico = 0;
      for (final intervalosDia in intervalosPorDia.values) {
        minutosMedico += _somarMinutosUnicos(intervalosDia);
      }

      if (minutosMedico > 0) {
        final acumulado = acumuladoPorEspecialidade.putIfAbsent(
          especialidade,
          () => _AcumuladoEspecialidade(),
        );
        // Neste relatório, contam apenas médicos com disponibilidade efetiva
        // (já após aplicar exceções no período).
        acumulado.medicosAtivos += 1;
        acumulado.medicosComDisponibilidade += 1;
        acumulado.horasConsulta += (minutosMedico / 60.0);
      }

      if (i % 3 == 0 || i == medicosAtivos.length - 1) {
        onProgress?.call(
          0.3 + (0.65 * ((i + 1) / medicosAtivos.length)),
          'A consolidar horas por especialidade...',
        );
      }
    }

    final linhas = acumuladoPorEspecialidade.entries
        .map(
          (entry) => RelatorioHorasEspecialidadeLinha(
            especialidade: entry.key,
            medicosAtivos: entry.value.medicosAtivos,
            medicosComDisponibilidade: entry.value.medicosComDisponibilidade,
            horasConsulta: entry.value.horasConsulta,
          ),
        )
        .toList()
      ..sort((a, b) {
        final cmpHoras = b.horasConsulta.compareTo(a.horasConsulta);
        if (cmpHoras != 0) return cmpHoras;
        return a.especialidade.compareTo(b.especialidade);
      });

    onProgress?.call(1.0, 'Concluído');
    return RelatorioHorasEspecialidade(
      inicio: inicioNormalizado,
      fim: fimNormalizado,
      linhas: linhas,
    );
  }

  static Future<List<Disponibilidade>> _carregarDisponibilidadesMedicoPeriodo({
    required Medico medico,
    required Unidade unidade,
    required List<int> anos,
    required DateTime inicio,
    required DateTime fim,
    required bool forcarServidor,
  }) async {
    final resultados = await Future.wait([
      SerieService.carregarSeries(
        medico.id,
        unidade: unidade,
        dataInicio: inicio,
        dataFim: fim,
        forcarServidor: forcarServidor,
      ),
      SerieService.carregarExcecoes(
        medico.id,
        unidade: unidade,
        dataInicio: inicio,
        dataFim: fim,
        forcarServidor: forcarServidor,
      ),
      _carregarDisponibilidadesUnicasPeriodo(
        medicoId: medico.id,
        unidade: unidade,
        anos: anos,
        inicio: inicio,
        fim: fim,
      ),
    ]);

    final series = (resultados[0] as List<SerieRecorrencia>)
        .where((s) => s.ativo)
        .toList();
    final excecoes = (resultados[1] as List<ExcecaoSerie>).toList();
    final unicas = (resultados[2] as List<Disponibilidade>).toList();

    if (series.isEmpty) {
      return unicas;
    }

    final geradas = SerieGenerator.gerarDisponibilidades(
      series: series,
      excecoes: excecoes,
      dataInicio: inicio,
      dataFim: fim,
    );

    return [...geradas, ...unicas];
  }

  static Future<List<Disponibilidade>> _carregarDisponibilidadesUnicasPeriodo({
    required String medicoId,
    required Unidade unidade,
    required List<int> anos,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final anosValidos = anos.toSet().toList()..sort();
    final carregamentos = await Future.wait(
      anosValidos.map(
        (ano) => DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
          medicoId,
          ano,
          unidade,
        ),
      ),
    );

    final unicas = <Disponibilidade>[];
    for (final listaAno in carregamentos) {
      for (final disponibilidade in listaAno) {
        final data = _normalizarData(disponibilidade.data);
        if (data.isBefore(inicio) || data.isAfter(fim)) continue;
        unicas.add(disponibilidade);
      }
    }
    return unicas;
  }

  static int _somarMinutosUnicos(List<_IntervaloMinutos> intervalos) {
    if (intervalos.isEmpty) return 0;

    final ordenados = List<_IntervaloMinutos>.from(intervalos)
      ..sort((a, b) => a.inicio.compareTo(b.inicio));

    int total = 0;
    int inicioAtual = ordenados.first.inicio;
    int fimAtual = ordenados.first.fim;

    for (int i = 1; i < ordenados.length; i++) {
      final intervalo = ordenados[i];
      if (intervalo.inicio <= fimAtual) {
        fimAtual = math.max(fimAtual, intervalo.fim);
      } else {
        total += (fimAtual - inicioAtual);
        inicioAtual = intervalo.inicio;
        fimAtual = intervalo.fim;
      }
    }

    total += (fimAtual - inicioAtual);
    return total;
  }

  static List<_IntervaloMinutos> _intervalosDaDisponibilidade(
      Disponibilidade disponibilidade) {
    final tokens = _expandirHorarios(disponibilidade.horarios);
    final intervalos = <_IntervaloMinutos>[];

    for (int i = 0; i + 1 < tokens.length; i += 2) {
      final inicio = _parseHoraSegura(tokens[i]);
      final fim = _parseHoraSegura(tokens[i + 1]);
      if (inicio == null || fim == null || fim <= inicio) continue;
      intervalos.add(_IntervaloMinutos(inicio, fim));
    }

    return intervalos;
  }

  static List<String> _expandirHorarios(List<String> horarios) {
    final resultado = <String>[];
    for (final horario in horarios) {
      final valor = horario.trim();
      if (valor.isEmpty) continue;
      if (valor.contains(',')) {
        resultado.addAll(
          valor
              .split(',')
              .map((parte) => parte.trim())
              .where((parte) => parte.isNotEmpty),
        );
      } else {
        resultado.add(valor);
      }
    }
    return resultado;
  }

  static int? _parseHoraSegura(String valor) {
    try {
      return TimeUtils.parseTimeToMinutes(valor);
    } catch (_) {
      return null;
    }
  }

  static String _normalizarEspecialidade(String valor) {
    final texto = valor.trim();
    if (texto.isEmpty) return 'Sem especialidade';
    return texto;
  }

  static DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  static String _dataKey(DateTime data) {
    final normalizada = _normalizarData(data);
    final ano = normalizada.year.toString().padLeft(4, '0');
    final mes = normalizada.month.toString().padLeft(2, '0');
    final dia = normalizada.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }

  static Iterable<int> _anosNoIntervalo(DateTime inicio, DateTime fim) sync* {
    for (int ano = inicio.year; ano <= fim.year; ano++) {
      yield ano;
    }
  }

  static Iterable<DateTime> _gerarDatasNoIntervalo(
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
}

class _EstadoClinicaDia {
  final bool fechado;
  final int aberturaMinutos;
  final int fechoMinutos;

  const _EstadoClinicaDia._({
    required this.fechado,
    required this.aberturaMinutos,
    required this.fechoMinutos,
  });

  const _EstadoClinicaDia.fechado()
      : this._(fechado: true, aberturaMinutos: 0, fechoMinutos: 0);

  const _EstadoClinicaDia.aberto({
    required int abertura,
    required int fecho,
  }) : this._(
          fechado: false,
          aberturaMinutos: abertura,
          fechoMinutos: fecho,
        );
}

class _IntervaloMinutos {
  final int inicio;
  final int fim;

  const _IntervaloMinutos(this.inicio, this.fim);
}

class _AcumuladoEspecialidade {
  int medicosAtivos = 0;
  int medicosComDisponibilidade = 0;
  double horasConsulta = 0.0;
}
