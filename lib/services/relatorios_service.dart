// lib/services/relatorios_service.dart

import '../database/database_helper.dart';

class RelatoriosService {
  /// Gera todas as datas de [inicio] até [fim] (incluso).
  static List<DateTime> _gerarDatasNoIntervalo(DateTime inicio, DateTime fim) {
    final List<DateTime> lista = [];
    DateTime diaAtual = DateTime(inicio.year, inicio.month, inicio.day);
    final end = DateTime(fim.year, fim.month, fim.day);

    while (!diaAtual.isAfter(end)) {
      lista.add(diaAtual);
      diaAtual = diaAtual.add(const Duration(days: 1));
    }
    return lista;
  }

  /// Converte string "HH:MM" em número de horas (ex: "08:30" -> 8.5).
  static double _strHoraParaDouble(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0.0;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    return h + (m / 60.0);
  }

  /// Soma as horas de um campo "08:00,12:00,14:00,18:00"
  /// interpretando de 2 em 2 como [início,fim].
  static double _somarHorasAlocacao(String horarioStr) {
    if (horarioStr.trim().isEmpty) return 0.0;
    final parts = horarioStr.split(',').map((s) => s.trim()).toList();
    double soma = 0.0;
    for (int i = 0; i < parts.length; i += 2) {
      if (i + 1 >= parts.length) break;
      final ini = _strHoraParaDouble(parts[i]);
      final fim = _strHoraParaDouble(parts[i + 1]);
      final delta = fim - ini;
      if (delta > 0) soma += delta;
    }
    return soma;
  }

  /// Calcula a diferença (em horas) entre "horaAbertura" e "horaFecho".
  /// Exemplo: "08:00" e "20:00" -> 12h
  static double _calcHorasIntervalo(String abertura, String fecho) {
    final ini = _strHoraParaDouble(abertura);
    final fim = _strHoraParaDouble(fecho);
    final delta = fim - ini;
    return (delta > 0) ? delta : 0.0;
  }

  /// Busca do DB os horários e feriados, e retorna em estruturas de fácil uso
  static Future<Map<int, List<String>>> _carregarHorariosMap() async {
    final rows = await DatabaseHelper.buscarHorariosClinica();
    // diaSemana -> ["08:00","20:00"]
    final map = <int, List<String>>{};
    for (final row in rows) {
      final ds = row['diaSemana'] as int;
      final ab = row['horaAbertura'] as String;
      final fe = row['horaFecho'] as String;
      map[ds] = [ab, fe];
    }
    return map;
  }

  static Future<Set<DateTime>> _carregarFeriados() async {
    final feriadosList = await DatabaseHelper.buscarFeriados();
    return feriadosList.map((e) => e['data'] as DateTime).toSet();
  }


  /// ========== 1) Taxa Geral de todos os gabinetes ============================
  static Future<double> taxaOcupacaoGeral({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    // Carrega alocações
    final alocacoes = await DatabaseHelper.buscarAlocacoes();
    // Carrega horários e feriados do DB
    final horariosMap = await _carregarHorariosMap();
    final feriados = await _carregarFeriados();

    // Filtra as alocações no intervalo
    final alocFiltradas = alocacoes.where((a) {
      return !a.data.isBefore(inicio) && !a.data.isAfter(fim);
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;

    final dias = _gerarDatasNoIntervalo(inicio, fim);
    for (final dia in dias) {
      if (feriados.contains(dia)) {
        // se é feriado, ignora (0h)
        continue;
      }
      final ds = dia.weekday; // 1=Seg ... 7=Dom
      // Descobre se há horário definido
      double horasAbertas = 0.0;
      if (horariosMap.containsKey(ds)) {
        final ab = horariosMap[ds]![0];
        final fe = horariosMap[ds]![1];
        horasAbertas = _calcHorasIntervalo(ab, fe);
      }
      somaHorasTotais += horasAbertas;

      // Soma as horas ocupadas
      final alocDoDia = alocFiltradas.where((a) =>
      a.data.year == dia.year &&
          a.data.month == dia.month &&
          a.data.day == dia.day);
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacao(al.horarioInicio);
      }
      if (horasOcupDia > horasAbertas) {
        horasOcupDia = horasAbertas;
      }
      somaHorasOcupadas += horasOcupDia;
    }

    if (somaHorasTotais <= 0) return 0.0;
    return (somaHorasOcupadas / somaHorasTotais) * 100.0;
  }

  /// ========== 2) Taxa de ocupação filtrada por Setor ========================
  static Future<double> taxaOcupacaoPorSetor({
    required DateTime inicio,
    required DateTime fim,
    required String setor,
  }) async {
    // Carrega gabinetes para saber quais IDs pertencem a esse setor
    final gabinetes = await DatabaseHelper.buscarGabinetes();
    final gabIds = gabinetes
        .where((g) => g.setor == setor)
        .map((g) => g.id)
        .toSet();

    // Carrega alocações + horários + feriados
    final alocacoes = await DatabaseHelper.buscarAlocacoes();
    final horariosMap = await _carregarHorariosMap();
    final feriados = await _carregarFeriados();

    // Filtra alocações do período E desses gabinetes
    final alocFiltradas = alocacoes.where((a) {
      final dentroData = !a.data.isBefore(inicio) && !a.data.isAfter(fim);
      final dentroSetor = gabIds.contains(a.gabineteId);
      return dentroData && dentroSetor;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.contains(dia)) {
        continue; // feriado => 0h
      }
      final ds = dia.weekday;
      double horasAbertas = 0.0;
      if (horariosMap.containsKey(ds)) {
        horasAbertas = _calcHorasIntervalo(
          horariosMap[ds]![0],
          horariosMap[ds]![1],
        );
      }
      somaHorasTotais += horasAbertas;

      // Soma horas das alocações
      final alocDoDia = alocFiltradas.where((a) =>
      a.data.year == dia.year &&
          a.data.month == dia.month &&
          a.data.day == dia.day);
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacao(al.horarioInicio);
      }
      if (horasOcupDia > horasAbertas) {
        horasOcupDia = horasAbertas;
      }
      somaHorasOcupadas += horasOcupDia;
    }

    if (somaHorasTotais <= 0) return 0.0;
    return (somaHorasOcupadas / somaHorasTotais) * 100.0;
  }

  /// ========== 3) Taxa de ocupação filtrada por Gabinete =====================
  static Future<double> taxaOcupacaoPorGabinete({
    required DateTime inicio,
    required DateTime fim,
    required String gabineteId,
  }) async {
    // Carrega alocações
    final alocacoes = await DatabaseHelper.buscarAlocacoes();
    final horariosMap = await _carregarHorariosMap();
    final feriados = await _carregarFeriados();

    // Filtra só as do gabinete e do período
    final alocFiltradas = alocacoes.where((a) {
      final dataOk = !a.data.isBefore(inicio) && !a.data.isAfter(fim);
      final gabOk = (a.gabineteId == gabineteId);
      return dataOk && gabOk;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.contains(dia)) {
        continue;
      }
      final ds = dia.weekday;
      double horasAbertas = 0.0;
      if (horariosMap.containsKey(ds)) {
        horasAbertas = _calcHorasIntervalo(
          horariosMap[ds]![0],
          horariosMap[ds]![1],
        );
      }
      somaHorasTotais += horasAbertas;

      final alocDoDia = alocFiltradas.where((a) =>
      a.data.year == dia.year &&
          a.data.month == dia.month &&
          a.data.day == dia.day
      );
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacao(al.horarioInicio);
      }
      if (horasOcupDia > horasAbertas) horasOcupDia = horasAbertas;
      somaHorasOcupadas += horasOcupDia;
    }

    if (somaHorasTotais <= 0) return 0.0;
    return (somaHorasOcupadas / somaHorasTotais) * 100.0;
  }

  /// ========== 4) Taxa de ocupação por Especialidade do gabinete =============
  static Future<double> taxaOcupacaoPorEspecialidade({
    required DateTime inicio,
    required DateTime fim,
    required String especialidadeProcurada,
  }) async {
    // Carrega gabinetes => filtra os que contêm essa especialidade
    final gabinetes = await DatabaseHelper.buscarGabinetes();
    final gabIds = gabinetes
        .where((g) => g.especialidadesPermitidas.contains(especialidadeProcurada))
        .map((g) => g.id)
        .toSet();

    final alocacoes = await DatabaseHelper.buscarAlocacoes();
    final horariosMap = await _carregarHorariosMap();
    final feriados = await _carregarFeriados();

    final alocFiltradas = alocacoes.where((a) {
      final dataOk = !a.data.isBefore(inicio) && !a.data.isAfter(fim);
      final gabOk = gabIds.contains(a.gabineteId);
      return dataOk && gabOk;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.contains(dia)) continue;

      final ds = dia.weekday;
      double horasAbertas = 0.0;
      if (horariosMap.containsKey(ds)) {
        horasAbertas = _calcHorasIntervalo(
          horariosMap[ds]![0],
          horariosMap[ds]![1],
        );
      }
      somaHorasTotais += horasAbertas;

      final alocDoDia = alocFiltradas.where((a) =>
      a.data.year == dia.year &&
          a.data.month == dia.month &&
          a.data.day == dia.day
      );
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacao(al.horarioInicio);
      }
      if (horasOcupDia > horasAbertas) horasOcupDia = horasAbertas;
      somaHorasOcupadas += horasOcupDia;
    }

    if (somaHorasTotais <= 0) return 0.0;
    return (somaHorasOcupadas / somaHorasTotais) * 100.0;
  }
}
