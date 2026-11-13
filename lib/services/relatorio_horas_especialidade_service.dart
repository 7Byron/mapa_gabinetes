import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/relatorio_horas_especialidade.dart';
import '../models/unidade.dart';
import '../models/resumo_horas_mes.dart';
import '../utils/time_utils.dart';
import 'alocacao_clinica_config_service.dart';
import 'alocacao_clinica_status_service.dart';
import 'cache_version_service.dart';
import 'medico_salvar_service.dart';
import 'relatorio_horas_disponibilidades_service.dart';
import 'relatorio_horas_cache_service.dart';

class RelatorioHorasEspecialidadeService {
  final RelatorioHorasCacheService? _cachePersistente;
  const RelatorioHorasEspecialidadeService(
      {RelatorioHorasCacheService? cachePersistente})
      : _cachePersistente = cachePersistente;

  RelatorioHorasCacheService? get cachePersistente =>
      _cachePersistente ?? RelatorioHorasCacheService.padrao;
  static final _caches = Expando<_CacheHorasClinica>();
  _CacheHorasClinica get _cache => _caches[this] ??= _CacheHorasClinica();

  Future<ClinicaConfiguracoes> carregarConfiguracoes(
          {required Unidade unidade, required bool forcarServidor}) =>
      AlocacaoClinicaConfigService.carregarHorariosEConfiguracoes(
          unidadeId: unidade.id, forcarServidor: forcarServidor);

  Future<List<Map<String, String>>> carregarFeriados(
          {required Unidade unidade,
          required int ano,
          required bool forcarServidor}) =>
      AlocacaoClinicaConfigService.carregarFeriados(
          unidadeId: unidade.id,
          anoSelecionado: ano,
          forcarServidor: forcarServidor);

  Future<List<Map<String, dynamic>>> carregarEncerramentos(
          {required Unidade unidade,
          required int ano,
          required bool forcarServidor}) =>
      AlocacaoClinicaConfigService.carregarDiasEncerramento(
          unidadeId: unidade.id,
          anoSelecionado: ano,
          forcarServidor: forcarServidor);

  Future<List<Medico>> carregarMedicos({
    required Unidade unidade,
    bool forcarServidor = false,
  }) =>
      buscarMedicos(unidade: unidade, forcarAtualizacao: forcarServidor);

  Future<String> obterVersaoCache({required Unidade unidade}) async {
    final versoes =
        await CacheVersionService.fetchVersions(unidadeId: unidade.id);
    return [
      versoes[CacheVersionService.fieldSeries] ?? 0,
      versoes[CacheVersionService.fieldDisponibilidades] ?? 0,
      versoes[CacheVersionService.fieldMedicos] ?? 0,
      versoes[CacheVersionService.fieldClinicaConfig] ?? 0,
    ].join('_');
  }

  Future<RelatorioHorasEspecialidade> calcular({
    required Unidade unidade,
    required DateTime inicio,
    required DateTime fim,
    bool forcarServidor = false,
    Set<String>? especialidades,
    Set<String>? medicoIds,
    void Function(double progresso, String mensagem)? onProgress,
  }) =>
      CacheVersionService.comVersoesPartilhadas(() async {
        final primeira = _normalizarData(inicio), ultima = _normalizarData(fim);
        final de = primeira.isBefore(ultima) ? primeira : ultima;
        final ate = primeira.isBefore(ultima) ? ultima : primeira;
        final versao = await obterVersaoCache(unidade: unidade);
        final estado = _cache;
        final futuros = <Future<ResumoHorasMes>>[];
        final donos = <DateTime, _PedidoHorasMes>{};
        for (var mes = DateTime(de.year, de.month);
            !mes.isAfter(ate);
            mes = DateTime(mes.year, mes.month + 1)) {
          final chave = (unidade.id, mes);
          final pendente = estado.pendentes[chave];
          final existente = estado.entradas[chave];
          if (!forcarServidor && pendente?.versao == versao) {
            futuros.add(pendente!.resultado.future);
          } else if (!forcarServidor && existente?.$1 == versao) {
            futuros.add(Future.value(existente!.$2));
          } else {
            final pedido = _PedidoHorasMes(versao);
            estado.pendentes[chave] = pedido;
            estado.entradas.remove(chave);
            donos[mes] = pedido;
            futuros.add(pedido.resultado.future);
          }
        }
        // Instalar os handlers antes de começar o trabalho: uma falha é propagada
        // a todos os pedidos em espera, sem resultados parciais nem Futures soltos.
        final tarefas = Future.wait<dynamic>([
          Future.wait(futuros),
          _resolverMeses(unidade, versao, donos, forcarServidor, onProgress),
        ]);
        final resultados = (await tarefas).first as List<ResumoHorasMes>;
        onProgress?.call(1, 'Concluído');
        return ResumoHorasMes.relatorio(
            meses: resultados,
            inicio: de,
            fim: ate,
            medicoIds: medicoIds,
            especialidades: especialidades);
      });

  Future<void> _resolverMeses(
      Unidade unidade,
      String versao,
      Map<DateTime, _PedidoHorasMes> donos,
      bool forcarServidor,
      void Function(double, String)? onProgress) async {
    final estado = _cache;
    void concluir(DateTime mes, ResumoHorasMes resumo) {
      final pedido = donos[mes]!;
      final chave = (unidade.id, mes);
      if (identical(estado.pendentes[chave], pedido)) {
        estado.entradas.remove(chave);
        if (estado.entradas.length >= 48) {
          estado.entradas.remove(estado.entradas.keys.first);
        }
        estado.entradas[chave] = (versao, resumo);
      }
      pedido.resultado.complete(resumo);
    }

    try {
      final faltam = <DateTime>[];
      final meses = donos.keys.toList();
      for (var i = 0; i < meses.length; i += 6) {
        await Future.wait(
            meses.sublist(i, math.min(i + 6, meses.length)).map((mes) async {
          final resumo = forcarServidor
              ? null
              : await cachePersistente?.ler(unidade.id, mes, versao);
          if (resumo != null) {
            concluir(mes, resumo);
          } else {
            faltam.add(mes);
          }
        }));
      }
      faltam.sort();
      final grupos = <List<DateTime>>[];
      for (final mes in faltam) {
        if (grupos.isEmpty ||
            DateTime(grupos.last.last.year, grupos.last.last.month + 1) !=
                mes) {
          grupos.add([]);
        }
        grupos.last.add(mes);
      }
      // Meses contíguos em falta são calculados de uma vez. Um primeiro
      // relatório anual não multiplica as leituras por doze consultas mensais.
      for (var i = 0; i < grupos.length; i++) {
        final grupo = grupos[i];
        final resumos = await _calcularResumos(
            unidade: unidade,
            inicio: grupo.first,
            fim: DateTime(grupo.last.year, grupo.last.month + 1, 0),
            forcarServidor: forcarServidor,
            onProgress: (valor, mensagem) => onProgress?.call(
                0.1 + 0.85 * (i + valor) / grupos.length, mensagem));
        final atuais = resumos
            .where((r) =>
                identical(estado.pendentes[(unidade.id, r.mes)], donos[r.mes]))
            .toList();
        if (atuais.isNotEmpty) {
          await cachePersistente?.guardar(unidade.id, versao, atuais);
        }
        for (final resumo in resumos) {
          concluir(resumo.mes, resumo);
        }
      }
    } catch (erro, stack) {
      for (final pedido
          in donos.values.where((p) => !p.resultado.isCompleted)) {
        pedido.resultado.completeError(erro, stack);
      }
    } finally {
      for (final entrada in donos.entries) {
        final chave = (unidade.id, entrada.key);
        if (identical(estado.pendentes[chave], entrada.value)) {
          estado.pendentes.remove(chave);
        }
      }
    }
  }

  Future<List<ResumoHorasMes>> _calcularResumos({
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
    final config = await carregarConfiguracoes(
      unidade: unidade,
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
      feriadosPorAno[ano] = await carregarFeriados(
        unidade: unidade,
        ano: ano,
        forcarServidor: forcarServidor,
      );
      encerramentosPorAno[ano] = await carregarEncerramentos(
        unidade: unidade,
        ano: ano,
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
    final medicos =
        await carregarMedicos(unidade: unidade, forcarServidor: true);
    final medicosAtivos = medicos.where((m) => m.ativo).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    final porMes = <DateTime, List<MedicoHorasMes>>{
      for (var mes = DateTime(inicio.year, inicio.month);
          !mes.isAfter(fim);
          mes = DateTime(mes.year, mes.month + 1))
        mes: [],
    };

    var concluidos = 0;
    Future<void> processar(Medico medico) async {
      final especialidade = _normalizarEspecialidade(medico.especialidade);

      final disponibilidades = await carregarDisponibilidadesMedicoPeriodo(
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

      final minutosPorDia = {
        for (final entrada in intervalosPorDia.entries)
          entrada.key: _somarMinutosUnicos(entrada.value),
      };
      for (final entrada in porMes.entries) {
        final mes = entrada.key;
        entrada.value.add(MedicoHorasMes(
            id: medico.id,
            nome: medico.nome,
            especialidade: especialidade,
            minutos: [
              for (var dia = 1;
                  dia <= DateTime(mes.year, mes.month + 1, 0).day;
                  dia++)
                minutosPorDia[_dataKey(DateTime(mes.year, mes.month, dia))] ??
                    0,
            ]));
      }

      concluidos++;
      if (concluidos % 3 == 0 || concluidos == medicosAtivos.length) {
        onProgress?.call(
          0.3 + (0.65 * (concluidos / medicosAtivos.length)),
          'A calcular as horas da clínica...',
        );
      }
    }

    // Limita o número de leituras simultâneas e cede tempo ao ecrã entre lotes.
    for (var i = 0; i < medicosAtivos.length; i += 6) {
      await Future.wait(medicosAtivos
          .sublist(i, math.min(i + 6, medicosAtivos.length))
          .map(processar));
      await Future<void>.delayed(Duration.zero);
    }
    return [
      for (final entrada in porMes.entries)
        ResumoHorasMes(
            mes: entrada.key,
            medicos: entrada.value..sort((a, b) => a.nome.compareTo(b.nome))),
    ];
  }

  Future<List<Disponibilidade>> carregarDisponibilidadesMedicoPeriodo({
    required Medico medico,
    required Unidade unidade,
    required List<int> anos,
    required DateTime inicio,
    required DateTime fim,
    required bool forcarServidor,
  }) =>
      RelatorioHorasDisponibilidadesService.carregar(
          firestore: FirebaseFirestore.instance,
          unidadeId: unidade.id,
          medicoId: medico.id,
          inicio: inicio,
          fim: fim,
          forcarServidor: forcarServidor);

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
      atual = DateTime(atual.year, atual.month, atual.day + 1);
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

class _CacheHorasClinica {
  final entradas = <(String, DateTime), (String, ResumoHorasMes)>{};
  final pendentes = <(String, DateTime), _PedidoHorasMes>{};
}

class _PedidoHorasMes {
  final String versao;
  final resultado = Completer<ResumoHorasMes>();
  _PedidoHorasMes(this.versao);
}
