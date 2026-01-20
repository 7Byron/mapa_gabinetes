// lib/services/relatorios_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Lista os anos no intervalo [inicio..fim] (inclusivo).
  static List<int> _anosNoIntervalo(DateTime inicio, DateTime fim) {
    final anos = <int>[];
    for (int ano = inicio.year; ano <= fim.year; ano++) {
      anos.add(ano);
    }
    return anos;
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

  /// Soma horas de um registo de alocação (legacy ou estrutura nova).
  static double _somarHorasAlocacaoRegistro(Map<String, dynamic> aloc) {
    final horarioInicio = aloc['horarioInicio'];
    final horarioFim = aloc['horarioFim'];
    if (horarioInicio is String && horarioFim is String) {
      if (!horarioInicio.contains(',') && horarioFim.trim().isNotEmpty) {
        return _calcHorasIntervalo(horarioInicio, horarioFim);
      }
    }
    if (horarioInicio is String) {
      return _somarHorasAlocacao(horarioInicio);
    }
    return 0.0;
  }

  /// Busca horários da clínica no Firestore
  static Future<Map<int, List<String>>> _carregarHorariosMap({String? unidadeId}) async {
    final firestore = FirebaseFirestore.instance;
    CollectionReference horariosRef;
    
    if (unidadeId != null) {
      horariosRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('horarios_clinica');
    } else {
      horariosRef = firestore.collection('horarios_clinica');
    }
    
    final snap = await horariosRef.get();
    final map = <int, List<String>>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ds = data['diaSemana'] as int;
      final ab = data['horaAbertura'] as String;
      final fe = data['horaFecho'] as String;
      map[ds] = [ab, fe];
    }
    return map;
  }

  /// Busca feriados no Firestore (nova estrutura por ano)
  static Future<List<Map<String, dynamic>>> _carregarFeriados({
    String? unidadeId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final firestore = FirebaseFirestore.instance;
    CollectionReference feriadosRef;
    
    if (unidadeId != null) {
      feriadosRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('feriados');
    } else {
      feriadosRef = firestore.collection('feriados');
    }
    
    final feriados = <Map<String, dynamic>>[];

    // Para relatórios, carregar apenas anos no intervalo
    for (final ano in _anosNoIntervalo(inicio, fim)) {
      final registosRef = feriadosRef.doc(ano.toString()).collection('registos');
      final registosSnapshot = await registosRef.get();
      for (final doc in registosSnapshot.docs) {
        feriados.add(doc.data());
      }
    }

    return feriados;
  }

  /// Busca alocações no Firestore
  static Future<List<Map<String, dynamic>>> _carregarAlocacoes({
    required DateTime inicio,
    required DateTime fim,
    String? unidadeId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    if (unidadeId == null) {
      final snap = await firestore.collection('alocacoes').get();
      return snap.docs.map((d) => d.data()).toList();
    }

    final alocacoes = <Map<String, dynamic>>[];
    for (final ano in _anosNoIntervalo(inicio, fim)) {
      final registosRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano.toString())
          .collection('registos');
      final snap = await registosRef.get();
      for (final doc in snap.docs) {
        alocacoes.add(doc.data());
      }
    }

    return alocacoes;
  }

  /// Busca gabinetes no Firestore
  static Future<List<Map<String, dynamic>>> _carregarGabinetes({String? unidadeId}) async {
    final firestore = FirebaseFirestore.instance;
    CollectionReference gabinetesRef;
    
    if (unidadeId != null) {
      // Busca gabinetes da unidade específica
      gabinetesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('gabinetes');
    } else {
      // Busca todos os gabinetes (fallback para compatibilidade)
      gabinetesRef = firestore.collection('gabinetes');
    }
    
    final snap = await gabinetesRef.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  /// ========== 1) Taxa Geral de todos os gabinetes ============================
  static Future<double> taxaOcupacaoGeral({
    required DateTime inicio,
    required DateTime fim,
    String? unidadeId,
  }) async {
    // Carrega alocações
    final alocacoes = await _carregarAlocacoes(
      inicio: inicio,
      fim: fim,
      unidadeId: unidadeId,
    );
    // Carrega horários e feriados do Firestore
    final horariosMap = await _carregarHorariosMap(unidadeId: unidadeId);
    final feriados = await _carregarFeriados(
      unidadeId: unidadeId,
      inicio: inicio,
      fim: fim,
    );

    // Filtra as alocações no intervalo
    final alocFiltradas = alocacoes.where((a) {
      return !DateTime.parse(a['data']).isBefore(inicio) && !DateTime.parse(a['data']).isAfter(fim);
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;

    final dias = _gerarDatasNoIntervalo(inicio, fim);
    for (final dia in dias) {
      if (feriados.any((f) => DateTime.parse(f['data']).year == dia.year && DateTime.parse(f['data']).month == dia.month && DateTime.parse(f['data']).day == dia.day)) {
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
      DateTime.parse(a['data']).year == dia.year &&
          DateTime.parse(a['data']).month == dia.month &&
          DateTime.parse(a['data']).day == dia.day);
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacaoRegistro(al);
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
    String? unidadeId,
  }) async {
    // Carrega gabinetes para saber quais IDs pertencem a esse setor
    final gabinetes = await _carregarGabinetes(unidadeId: unidadeId);
    final gabIds = gabinetes
        .where((g) => g['setor'] == setor)
        .map((g) => g['id'])
        .toSet();

    // Carrega alocações + horários + feriados
    final alocacoes = await _carregarAlocacoes(
      inicio: inicio,
      fim: fim,
      unidadeId: unidadeId,
    );
    final horariosMap = await _carregarHorariosMap(unidadeId: unidadeId);
    final feriados = await _carregarFeriados(
      unidadeId: unidadeId,
      inicio: inicio,
      fim: fim,
    );

    // Filtra alocações do período E desses gabinetes
    final alocFiltradas = alocacoes.where((a) {
      final dentroData = !DateTime.parse(a['data']).isBefore(inicio) && !DateTime.parse(a['data']).isAfter(fim);
      final dentroSetor = gabIds.contains(a['gabineteId']);
      return dentroData && dentroSetor;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.any((f) => DateTime.parse(f['data']).year == dia.year && DateTime.parse(f['data']).month == dia.month && DateTime.parse(f['data']).day == dia.day)) {
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
      DateTime.parse(a['data']).year == dia.year &&
          DateTime.parse(a['data']).month == dia.month &&
          DateTime.parse(a['data']).day == dia.day);
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacaoRegistro(al);
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
    String? unidadeId,
  }) async {
    // Carrega alocações
    final alocacoes = await _carregarAlocacoes(
      inicio: inicio,
      fim: fim,
      unidadeId: unidadeId,
    );
    final horariosMap = await _carregarHorariosMap(unidadeId: unidadeId);
    final feriados = await _carregarFeriados(
      unidadeId: unidadeId,
      inicio: inicio,
      fim: fim,
    );

    // Filtra só as do gabinete e do período
    final alocFiltradas = alocacoes.where((a) {
      final dataOk = !DateTime.parse(a['data']).isBefore(inicio) && !DateTime.parse(a['data']).isAfter(fim);
      final gabOk = (a['gabineteId'] == gabineteId);
      return dataOk && gabOk;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.any((f) => DateTime.parse(f['data']).year == dia.year && DateTime.parse(f['data']).month == dia.month && DateTime.parse(f['data']).day == dia.day)) {
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
      DateTime.parse(a['data']).year == dia.year &&
          DateTime.parse(a['data']).month == dia.month &&
          DateTime.parse(a['data']).day == dia.day
      );
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacaoRegistro(al);
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
    String? unidadeId,
  }) async {
    // Carrega gabinetes => filtra os que contêm essa especialidade
    final gabinetes = await _carregarGabinetes(unidadeId: unidadeId);
    final gabIds = gabinetes
        .where((g) => (g['especialidadesPermitidas'] as List).contains(especialidadeProcurada))
        .map((g) => g['id'])
        .toSet();

    final alocacoes = await _carregarAlocacoes(
      inicio: inicio,
      fim: fim,
      unidadeId: unidadeId,
    );
    final horariosMap = await _carregarHorariosMap(unidadeId: unidadeId);
    final feriados = await _carregarFeriados(
      unidadeId: unidadeId,
      inicio: inicio,
      fim: fim,
    );

    final alocFiltradas = alocacoes.where((a) {
      final dataOk = !DateTime.parse(a['data']).isBefore(inicio) && !DateTime.parse(a['data']).isAfter(fim);
      final gabOk = gabIds.contains(a['gabineteId']);
      return dataOk && gabOk;
    }).toList();

    double somaHorasTotais = 0.0;
    double somaHorasOcupadas = 0.0;
    final dias = _gerarDatasNoIntervalo(inicio, fim);

    for (final dia in dias) {
      if (feriados.any((f) => DateTime.parse(f['data']).year == dia.year && DateTime.parse(f['data']).month == dia.month && DateTime.parse(f['data']).day == dia.day)) continue;

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
      DateTime.parse(a['data']).year == dia.year &&
          DateTime.parse(a['data']).month == dia.month &&
          DateTime.parse(a['data']).day == dia.day
      );
      double horasOcupDia = 0.0;
      for (final al in alocDoDia) {
        horasOcupDia += _somarHorasAlocacaoRegistro(al);
      }
      if (horasOcupDia > horasAbertas) horasOcupDia = horasAbertas;
      somaHorasOcupadas += horasOcupDia;
    }

    if (somaHorasTotais <= 0) return 0.0;
    return (somaHorasOcupadas / somaHorasTotais) * 100.0;
  }
}
