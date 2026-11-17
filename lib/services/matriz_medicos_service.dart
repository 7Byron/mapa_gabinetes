import '../models/matriz_distribuicao.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';
import 'serie_generator.dart';

class MatrizMedicoLinha {
  final Medico medico;
  final List<String> horarios;
  final int semana, mes, ano;
  const MatrizMedicoLinha(
      this.medico, this.horarios, this.semana, this.mes, this.ano);
}

class MatrizMedicosService {
  static const dias = [
    '2.ª feira',
    '3.ª feira',
    '4.ª feira',
    '5.ª feira',
    '6.ª feira',
    'Sábado',
    'Domingo'
  ];
  static String horas(int minutos) =>
      '${minutos ~/ 60}:${(minutos % 60).toString().padLeft(2, '0')}';

  static List<MatrizMedicoLinha> gerar(
    List<Medico> medicos,
    List<SerieRecorrencia> series,
    DateTime referencia, {
    DateTime? semanaReferencia,
    List<ExcecaoSerie> excecoes = const [],
    Set<DateTime> encerramentos = const {},
  }) {
    final data = DateTime(referencia.year, referencia.month, referencia.day);
    final refSemana = semanaReferencia ?? data;
    final segunda = refSemana.subtract(Duration(days: refSemana.weekday - 1));
    final domingo = segunda.add(const Duration(days: 6));
    final inicio =
        DateTime(data.year).isBefore(segunda) ? DateTime(data.year) : segunda;
    final fimAno = DateTime(data.year, 12, 31);
    final fim = fimAno.isAfter(domingo) ? fimAno : domingo;
    final recorrentes = series
        .where((s) =>
            s.ativo && ['Semanal', 'Quinzenal', 'Mensal'].contains(s.tipo))
        .toList();
    final efetivas = recorrentes.map((s) {
      final seguintes = recorrentes
          .where((r) =>
              r.medicoId == s.medicoId &&
              r.tipo == s.tipo &&
              r.dataInicio.weekday == s.dataInicio.weekday &&
              r.horarios.isNotEmpty &&
              s.horarios.isNotEmpty &&
              r.horarios.first == s.horarios.first &&
              r.horarios.join('|') != s.horarios.join('|') &&
              r.dataInicio.isAfter(s.dataInicio))
          .toList()
        ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
      var limite = s.dataFim;
      if (seguintes.isNotEmpty &&
          (limite == null || !limite.isBefore(seguintes.first.dataInicio))) {
        limite = seguintes.first.dataInicio.subtract(const Duration(days: 1));
      }
      return SerieRecorrencia(
          id: s.id,
          medicoId: s.medicoId,
          dataInicio: s.dataInicio,
          dataFim: limite,
          tipo: s.tipo,
          horarios: s.horarios,
          parametros: s.parametros,
          gabineteId: s.gabineteId,
          mudancasGabinete: s.mudancasGabinete);
    }).toList();
    final ocorrencias = SerieGenerator.gerarDisponibilidades(
        series: efetivas, excecoes: excecoes, dataInicio: inicio, dataFim: fim);
    final porMedico = <String, List<Disponibilidade>>{};
    for (final d in ocorrencias) {
      porMedico.putIfAbsent(d.medicoId, () => []).add(d);
    }
    return medicos.where((m) => m.ativo).map((medico) {
      // União de minutos por dia: horários sobrepostos contam apenas uma vez.
      final minutosPorDia = <DateTime, List<(int, int)>>{};
      for (final d in porMedico[medico.id] ?? <Disponibilidade>[]) {
        if (encerramentos
            .contains(DateTime(d.data.year, d.data.month, d.data.day))) {
          continue;
        }
        final partes = d.horarios
            .expand((h) => h.split(','))
            .map((h) => h.trim())
            .toList();
        final minutos = minutosPorDia.putIfAbsent(
            DateTime(d.data.year, d.data.month, d.data.day),
            () => <(int, int)>[]);
        for (var i = 0; i + 1 < partes.length; i += 2) {
          int? parse(String h) {
            final p = h.split(':');
            if (p.length != 2) return null;
            final hora = int.tryParse(p[0]), minuto = int.tryParse(p[1]);
            return hora == null || minuto == null ? null : hora * 60 + minuto;
          }

          final de = parse(partes[i]), ate = parse(partes[i + 1]);
          if (de != null && ate != null && de >= 0 && ate <= 1440) {
            if (ate > de) minutos.add((de, ate));
          }
        }
      }
      var semana = 0, mes = 0, ano = 0;
      for (final e in minutosPorDia.entries) {
        final intervalos = e.value..sort((a, b) => a.$1.compareTo(b.$1));
        var total = 0, fimAnterior = -1;
        for (final intervalo in intervalos) {
          final inicioEfetivo =
              intervalo.$1 > fimAnterior ? intervalo.$1 : fimAnterior;
          if (intervalo.$2 > inicioEfetivo) {
            total += intervalo.$2 - inicioEfetivo;
          }
          if (intervalo.$2 > fimAnterior) fimAnterior = intervalo.$2;
        }
        if (!e.key.isBefore(segunda) && !e.key.isAfter(domingo)) {
          semana += total;
        }
        if (e.key.year == data.year) {
          ano += total;
          if (e.key.month == data.month) mes += total;
        }
      }
      final regras = recorrentes
          .where((s) =>
              s.medicoId == medico.id &&
              !s.dataInicio.isAfter(fimAno) &&
              (s.dataFim == null || !s.dataFim!.isBefore(DateTime(data.year))))
          .toList()
        ..sort((a, b) => a.dataInicio.weekday.compareTo(b.dataInicio.weekday));
      // A fase da quinzena não altera a descrição do horário habitual.
      // Reunir séries do mesmo dia e horário antes de apresentar a validade.
      final grupos = <String, List<SerieRecorrencia>>{};
      for (final s in regras) {
        final chave = s.tipo == 'Quinzenal'
            ? '${s.dataInicio.weekday}|${s.horarios.join('|')}|${s.tipo}'
            : 'serie:${s.id}';
        grupos.putIfAbsent(chave, () => []).add(s);
      }
      final horarios = grupos.values
          .map((grupo) {
            grupo.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
            final s = grupo.first;
            final inicioAno = DateTime(data.year);
            final inicioRegra = DateTime(
                s.dataInicio.year, s.dataInicio.month, s.dataInicio.day);
            var fimRegra = grupo
                .map((r) => r.dataFim ?? fimAno)
                .reduce((a, b) => a.isAfter(b) ? a : b);
            // Uma nova duração no mesmo dia delimita a descrição anterior.
            final seguintes = regras
                .where((r) =>
                    r.tipo == s.tipo &&
                    r.dataInicio.weekday == s.dataInicio.weekday &&
                    r.horarios.isNotEmpty &&
                    s.horarios.isNotEmpty &&
                    r.horarios.first == s.horarios.first &&
                    r.horarios.join('|') != s.horarios.join('|') &&
                    r.dataInicio.isAfter(inicioRegra))
                .toList()
              ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
            if (seguintes.isNotEmpty &&
                !fimRegra.isBefore(seguintes.first.dataInicio)) {
              fimRegra = seguintes.first.dataInicio;
            }
            // Qualquer início em janeiro é apresentado como início do ano.
            final inicioVisivel =
                inicioRegra.isBefore(inicioAno) || inicioRegra.month == 1
                    ? inicioAno
                    : inicioRegra;
            final periodo = MatrizDistribuicaoItem.descreverPeriodo(
                inicioVisivel, fimRegra.isAfter(fimAno) ? fimAno : fimRegra);
            return '${dias[s.dataInicio.weekday - 1]} · ${s.horarios.join(' – ')}${s.tipo == 'Semanal' ? '' : ' · ${s.tipo}'}${periodo == null ? '' : ' · $periodo'}';
          })
          .toSet()
          .toList();
      return MatrizMedicoLinha(medico, horarios, semana, mes, ano);
    }).toList();
  }
}
