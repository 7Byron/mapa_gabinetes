import '../models/gabinete.dart';
import '../utils/disponibilidade_resumo.dart';
import '../models/matriz_distribuicao.dart';
import 'alocacao_clinica_config_service.dart';

/// Complemento das regras habituais, limitado ao funcionamento da unidade.
class MatrizGabinetesLivresService {
  static MatrizDistribuicao gerar({
    required List<Gabinete> gabinetes,
    required MatrizDistribuicao ocupacao,
    required int ano,
    required ClinicaConfiguracoes config,
    Set<DateTime> encerramentos = const {},
  }) {
    DateTime dia(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    final fechados = encerramentos.map(dia).toSet();
    final ocupados = <(String, DateTime), List<MatrizDistribuicaoItem>>{};
    for (final item in ocupacao.itens) {
      for (final data in item.ocorrencias) {
        ocupados.putIfAbsent((item.gabineteId, dia(data)), () => []).add(item);
      }
    }
    final livres = <MatrizDistribuicaoItem>[];
    for (final gabinete in gabinetes) {
      final grupos = <(int, int, int), Set<DateTime>>{};
      for (var data = DateTime.utc(ano);
          data.year == ano;
          data = data.add(const Duration(days: 1))) {
        if (fechados.contains(data)) continue;
        if (!config.nuncaEncerra && config.encerraDias[data.weekday] == true) {
          continue;
        }
        final horario = config.horariosClinica[data.weekday];
        final abertura = config.nuncaEncerra
            ? 0
            : _minutos(
                horario != null && horario.length == 2 ? horario.first : null);
        final fecho = config.nuncaEncerra
            ? 1440
            : _minutos(
                horario != null && horario.length == 2 ? horario.last : null);
        if (abertura == null || fecho == null || fecho <= abertura) continue;
        final lista = [...?ocupados[(gabinete.id, data)]]
          ..sort((a, b) => a.inicioMinutos.compareTo(b.inicioMinutos));
        void guardar(int inicio, int fim) {
          if (fim - inicio > 120) {
            grupos.putIfAbsent((data.weekday, inicio, fim), () => {}).add(data);
          }
        }

        var cursor = abertura;
        for (final item in lista) {
          final inicio = item.inicioMinutos.clamp(abertura, fecho);
          final fim = item.fimMinutos.clamp(abertura, fecho);
          if (inicio > cursor) guardar(cursor, inicio);
          if (fim > cursor) cursor = fim;
        }
        guardar(cursor, fecho);
      }
      for (final entrada in grupos.entries) {
        final datas = _periodosComMaisDeDoisMeses(
            _semQuintasEsporadicas(entrada.value, fechados));
        if (datas.isEmpty) continue;
        final periodos = dividirDisponibilidade(datas,
            incluirQuintaNoPadraoMensal: false, encerramentos: fechados);
        final (semana, inicio, fim) = entrada.key;
        livres.add(MatrizDistribuicaoItem(
          serieId: 'livre_${gabinete.id}_${semana}_${inicio}_$fim',
          medicoId: '',
          medicoNome: 'Livre',
          especialidade: '',
          gabineteId: gabinete.id,
          tipo: 'Livre',
          ciclo: periodos.map((p) => p.resumo).join('\n'),
          disponibilidades: List.unmodifiable(periodos),
          dia: semana,
          inicioMinutos: inicio,
          fimMinutos: fim,
          ocorrencias: Set.unmodifiable(datas),
        ));
      }
    }
    return MatrizDistribuicao(
        itens: livres, regrasSemGabinete: ocupacao.regrasSemGabinete);
  }

  static Set<DateTime> _semQuintasEsporadicas(
      Set<DateTime> datas, Set<DateTime> encerramentos) {
    final padroes =
        analisarDisponibilidadeRegular(datas, encerramentos: encerramentos);
    return datas
        .where((d) =>
            d.day <= 28 ||
            padroes[d.month]?.semanal == true ||
            padroes[d.month]?.quinzena != null)
        .toSet();
  }

  // Aplica o mínimo a cada sequência de meses, sem juntar períodos separados.
  static Set<DateTime> _periodosComMaisDeDoisMeses(Set<DateTime> datas) {
    final meses = datas.map((d) => d.year * 12 + d.month - 1).toSet().toList()
      ..sort();
    final mesesValidos = <int>{};
    var inicio = 0;
    for (var i = 0; i < meses.length; i++) {
      if (i + 1 < meses.length && meses[i + 1] == meses[i] + 1) continue;
      if (i - inicio + 1 > 2) {
        mesesValidos.addAll(meses.sublist(inicio, i + 1));
      }
      inicio = i + 1;
    }
    return datas
        .where((d) => mesesValidos.contains(d.year * 12 + d.month - 1))
        .toSet();
  }

  static int? _minutos(String? texto) {
    if (texto == null) return null;
    final partes = texto.split(':');
    if (partes.length != 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null ||
        minuto == null ||
        hora < 0 ||
        hora > 24 ||
        minuto < 0 ||
        minuto > 59 ||
        (hora == 24 && minuto != 0)) {
      return null;
    }
    return hora * 60 + minuto;
  }
}
