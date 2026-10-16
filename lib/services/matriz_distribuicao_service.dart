import '../models/matriz_distribuicao.dart';
import '../models/medico.dart';
import '../models/serie_recorrencia.dart';
import '../utils/time_utils.dart';
import '../utils/series_helper.dart';

/// Projeta as regras habituais da distribuição, sem exceções pontuais ou férias.
class MatrizDistribuicaoService {
  /// Regras habituais do ano, separadas por períodos de gabinete.
  /// Não inclui exceções pontuais nem férias.
  static MatrizDistribuicao gerarAnual({
    required List<Medico> medicos,
    required List<SerieRecorrencia> series,
    required DateTime referencia,
  }) {
    final anoInicio = DateTime.utc(referencia.year);
    final anoFim = DateTime.utc(referencia.year, 12, 31);
    final porId = {for (final m in medicos.where((m) => m.ativo)) m.id: m};
    final itens = <MatrizDistribuicaoItem>[];
    final semGabinete = <String>[];
    for (final original in series) {
      // Snapshot ordenado: não altera as regras partilhadas com outros ecrãs.
      final serie = SerieRecorrencia.fromMap(original.toMap());
      final medico = porId[serie.medicoId];
      if (medico == null ||
          !serie.ativo ||
          !['Semanal', 'Quinzenal', 'Mensal'].contains(serie.tipo)) {
        continue;
      }
      final ancora = _dia(serie.dataInicio);
      final inicio = ancora.isAfter(anoInicio) ? ancora : anoInicio;
      final fimRegra = serie.dataFim == null ? anoFim : _dia(serie.dataFim!);
      final fim = fimRegra.isBefore(anoFim) ? fimRegra : anoFim;
      if (inicio.isAfter(fim)) continue;
      final limites = <DateTime>{inicio, fim.add(const Duration(days: 1))};
      for (final mudanca in serie.mudancasGabinete) {
        final data = _dia(mudanca.dataInicio);
        if (data.isAfter(inicio) && !data.isAfter(fim)) limites.add(data);
      }
      final ordenados = limites.toList()..sort();
      final ocorrencia = (ancora.day - 1) ~/ 7 + 1;
      final ultima = (ocorrencia == 4 &&
              serie.parametros['usarUltimoQuandoExiste5'] == true) ||
          (ocorrencia == 5 &&
              serie.parametros['usarUltimoQuandoNaoExiste5'] == true);
      final ciclo = serie.tipo == 'Mensal'
          ? (ultima
              ? 'Mensal · última semana'
              : 'Mensal · $ocorrencia.ª semana')
          : serie.tipo;
      final horarios = serie.horarios
          .expand((h) => h.split(','))
          .map((h) => h.trim())
          .toList();
      for (var segmento = 0; segmento + 1 < ordenados.length; segmento++) {
        final de = ordenados[segmento];
        final ate = ordenados[segmento + 1].subtract(const Duration(days: 1));
        final datas = <DateTime>{};
        for (var data = de;
            !data.isAfter(ate);
            data = data.add(const Duration(days: 1))) {
          final corresponde = serie.tipo == 'Quinzenal'
              ? data.difference(ancora).inDays % 14 == 0
              : SeriesHelper.verificarDataCorrespondeAoPadraoSerie(data, serie);
          if (corresponde) datas.add(data);
        }
        if (datas.isEmpty) continue;
        final gabinete = serie.obterGabineteParaData(de);
        if (gabinete == null || gabinete.trim().isEmpty) {
          semGabinete.add('${medico.nome} · ${serie.tipo} · '
              '${de.day}/${de.month}/${de.year} a ${ate.day}/${ate.month}/${ate.year}');
          continue;
        }
        for (var h = 0; h + 1 < horarios.length; h += 2) {
          final inicioMinutos = _minutos(horarios[h]);
          final fimMinutos = _minutos(horarios[h + 1]);
          if (inicioMinutos == null ||
              fimMinutos == null ||
              fimMinutos <= inicioMinutos) {
            continue;
          }
          itens.add(MatrizDistribuicaoItem(
            serieId: serie.id,
            medicoId: medico.id,
            medicoNome: medico.nome,
            especialidade: medico.especialidade,
            gabineteId: gabinete,
            tipo: serie.tipo,
            ciclo: ciclo,
            dia: ancora.weekday,
            inicioMinutos: inicioMinutos,
            fimMinutos: fimMinutos,
            validadeInicio: de,
            validadeFim: ate,
            ocorrencias: Set.unmodifiable(datas),
          ));
        }
      }
    }
    final celulas = <String, List<MatrizDistribuicaoItem>>{};
    for (final item in itens) {
      celulas.putIfAbsent('${item.gabineteId}_${item.dia}', () => []).add(item);
    }
    return MatrizDistribuicao(
      itens: celulas.values.expand(_marcarConflitos).toList(),
      regrasSemGabinete: semGabinete,
    );
  }

  static DateTime _dia(DateTime data) =>
      DateTime.utc(data.year, data.month, data.day);

  static MatrizDistribuicao gerar({
    required List<Medico> medicos,
    required List<SerieRecorrencia> series,
    required DateTime referencia,
    int semanas = 5,
    bool alternarQuinzena = false,
  }) {
    if (semanas != 4 && semanas != 5) {
      throw ArgumentError('A matriz deve ter 4 ou 5 semanas.');
    }
    final hoje =
        DateTime.utc(referencia.year, referencia.month, referencia.day);
    final segunda = hoje.subtract(Duration(days: hoje.weekday - 1));
    final medicosPorId = {
      for (final m in medicos.where((m) => m.ativo)) m.id: m
    };
    final itens = <MatrizDistribuicaoItem>[];
    final semGabinete = <String>[];
    for (final serie in series) {
      final medico = medicosPorId[serie.medicoId];
      final inicio = DateTime.utc(
          serie.dataInicio.year, serie.dataInicio.month, serie.dataInicio.day);
      final fim = serie.dataFim;
      if (medico == null ||
          !serie.ativo ||
          inicio.isAfter(hoje) ||
          (fim != null &&
              DateTime.utc(fim.year, fim.month, fim.day).isBefore(hoje))) {
        continue;
      }
      if (!['Semanal', 'Quinzenal', 'Mensal'].contains(serie.tipo)) {
        continue;
      }
      // Usa deliberadamente o gabinete base da regra, sem realocações.
      final gabinete = serie.gabineteId;
      if (gabinete == null || gabinete.trim().isEmpty) {
        semGabinete.add('${medico.nome} · ${serie.tipo}');
        continue;
      }
      final weekday = inicio.weekday;
      final semanasDaSerie = <int>[];
      String ciclo;
      if (serie.tipo == 'Semanal') {
        semanasDaSerie.addAll(List.generate(semanas, (i) => i + 1));
        ciclo = 'Todas as semanas';
      } else if (serie.tipo == 'Quinzenal') {
        final semanaInicio = inicio.subtract(Duration(days: weekday - 1));
        final diferenca = segunda.difference(semanaInicio).inDays ~/ 7;
        for (var semana = 1; semana <= semanas; semana++) {
          if ((diferenca + semana - 1 + (alternarQuinzena ? 1 : 0)) % 2 == 0) {
            semanasDaSerie.add(semana);
          }
        }
        ciclo = '14 dias · semanas ${semanasDaSerie.join(', ')}';
      } else {
        final ocorrencia = (inicio.day - 1) ~/ 7 + 1;
        var semana = ocorrencia;
        final ultima = (ocorrencia == 4 &&
                serie.parametros['usarUltimoQuandoExiste5'] == true) ||
            (ocorrencia == 5 &&
                serie.parametros['usarUltimoQuandoNaoExiste5'] == true);
        if (ultima) semana = semanas;
        if (semana <= semanas) semanasDaSerie.add(semana);
        ciclo =
            ultima ? 'Mensal · última semana' : 'Mensal · $ocorrencia.ª semana';
      }
      final horarios = serie.horarios
          .expand((h) => h.split(','))
          .map((h) => h.trim())
          .toList();
      for (var i = 0; i + 1 < horarios.length; i += 2) {
        final inicioMinutos = _minutos(horarios[i]);
        final fimMinutos = _minutos(horarios[i + 1]);
        if (inicioMinutos == null ||
            fimMinutos == null ||
            fimMinutos <= inicioMinutos) {
          continue;
        }
        for (final semana in semanasDaSerie) {
          itens.add(MatrizDistribuicaoItem(
            serieId: serie.id,
            medicoId: medico.id,
            medicoNome: medico.nome,
            especialidade: medico.especialidade,
            gabineteId: gabinete,
            tipo: serie.tipo,
            ciclo: ciclo,
            dia: (semana - 1) * 7 + weekday,
            inicioMinutos: inicioMinutos,
            fimMinutos: fimMinutos,
          ));
        }
      }
    }
    itens.sort((a, b) {
      final dia = a.dia.compareTo(b.dia);
      return dia != 0 ? dia : a.inicioMinutos.compareTo(b.inicioMinutos);
    });
    final porCelula = <String, List<MatrizDistribuicaoItem>>{};
    for (final item in itens) {
      porCelula
          .putIfAbsent('${item.gabineteId}_${item.dia}', () => [])
          .add(item);
    }
    final resultado = <MatrizDistribuicaoItem>[];
    for (final celula in porCelula.values) {
      resultado.addAll(_marcarConflitos(celula));
    }
    return MatrizDistribuicao(itens: resultado, regrasSemGabinete: semGabinete);
  }

  static Iterable<MatrizDistribuicaoItem> _marcarConflitos(
      List<MatrizDistribuicaoItem> celula) sync* {
    for (final item in celula) {
      final conflito = celula.any((outro) =>
          outro.medicoId != item.medicoId &&
          outro.inicioMinutos < item.fimMinutos &&
          outro.fimMinutos > item.inicioMinutos &&
          (item.validadeInicio == null ||
              outro.validadeInicio == null ||
              item.ocorrencias.any(outro.ocorrencias.contains)));
      yield conflito ? item.comConflito() : item;
    }
  }

  /// Processa pequenos lotes, permitindo à interface desenhar o progresso.
  static Future<MatrizDistribuicao> gerarProgressivo({
    required List<Medico> medicos,
    required List<SerieRecorrencia> series,
    required DateTime referencia,
    void Function(double)? onProgresso,
    bool anual = false,
  }) async {
    final itens = <MatrizDistribuicaoItem>[];
    final semGabinete = <String>[];
    const tamanhoLote = 20;
    for (var inicio = 0; inicio < series.length; inicio += tamanhoLote) {
      final fim = (inicio + tamanhoLote).clamp(0, series.length);
      final gerarLote = anual ? gerarAnual : gerar;
      final lote = gerarLote(
          medicos: medicos,
          series: series.sublist(inicio, fim),
          referencia: referencia);
      itens.addAll(lote.itens);
      semGabinete.addAll(lote.regrasSemGabinete);
      onProgresso?.call(0.8 * fim / series.length);
      await Future<void>.delayed(Duration.zero);
    }
    itens.sort((a, b) {
      final dia = a.dia.compareTo(b.dia);
      return dia != 0 ? dia : a.inicioMinutos.compareTo(b.inicioMinutos);
    });
    final celulas = <String, List<MatrizDistribuicaoItem>>{};
    for (final item in itens) {
      celulas.putIfAbsent('${item.gabineteId}_${item.dia}', () => []).add(item);
    }
    final resultado = <MatrizDistribuicaoItem>[];
    var concluidas = 0;
    for (final celula in celulas.values) {
      resultado.addAll(_marcarConflitos(celula));
      concluidas++;
      if (concluidas % 20 == 0 || concluidas == celulas.length) {
        onProgresso?.call(0.8 + 0.2 * concluidas / celulas.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgresso?.call(1);
    return MatrizDistribuicao(itens: resultado, regrasSemGabinete: semGabinete);
  }

  static int? _minutos(String hora) {
    if (!RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$').hasMatch(hora) &&
        hora != '24:00') {
      return null;
    }
    return hora == '24:00' ? 1440 : TimeUtils.parseTimeToMinutes(hora);
  }
}
