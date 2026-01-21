import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../utils/series_helper.dart';

bool _pertenceSerie(Disponibilidade disp, SerieRecorrencia serie) {
  if (disp.medicoId != serie.medicoId) return false;

  if (disp.id.startsWith('serie_')) {
    final serieIdDisp = SeriesHelper.extrairSerieIdDeDisponibilidade(disp.id);
    return serieIdDisp == serie.id;
  }

  if (disp.tipo != serie.tipo) return false;

  final dataDisp = DateTime(disp.data.year, disp.data.month, disp.data.day);
  final dataInicio = DateTime(
    serie.dataInicio.year,
    serie.dataInicio.month,
    serie.dataInicio.day,
  );
  if (dataDisp.isBefore(dataInicio)) return false;
  if (serie.dataFim != null) {
    final dataFim = DateTime(
      serie.dataFim!.year,
      serie.dataFim!.month,
      serie.dataFim!.day,
    );
    if (dataDisp.isAfter(dataFim)) return false;
  }

  return SeriesHelper.verificarDataCorrespondeAoPadraoSerie(dataDisp, serie);
}

/// Remove uma ou mais disponibilidades de acordo com [date].
///
/// Se [removeSerie] = true, remove todas as disponibilidades
/// a partir de [date] (inclusive), mas somente aquelas com o mesmo tipo
/// da data selecionada.
///
/// Exemplo: se o dia 10/jan/2025 era 'Semanal',
/// remove todas as disponibilidades 'Semanal' com data >= 10/jan/2025.
List<Disponibilidade> removerDisponibilidade(
    List<Disponibilidade> disponibilidades,
    DateTime date, {
      bool removeSerie = false,
      SerieRecorrencia? serie,
    }) {
  if (removeSerie) {
    if (serie != null && serie.id.isNotEmpty) {
      final dataLimite = DateTime(date.year, date.month, date.day);
      return disponibilidades
          .where((d) {
            if (!_pertenceSerie(d, serie)) return true;
            final dataDisp = DateTime(d.data.year, d.data.month, d.data.day);
            return dataDisp.isBefore(dataLimite);
          })
          .toList();
    }

    // 1) Descobre qual é a disponibilidade no dia exato
    //    para saber qual 'tipo' ele tem
    final dispSelecionada = disponibilidades.firstWhere(
          (d) =>
      d.data.year == date.year &&
          d.data.month == date.month &&
          d.data.day == date.day,
      orElse: () => Disponibilidade(
        id: '',
        medicoId: '',  // <--- necessário agora
        data: date,
        horarios: [],
        tipo: 'Única',
      ),
    );

    final tipo = dispSelecionada.tipo;

    // 2) Mantemos:
    //    - Disponibilidades de outro tipo
    //    - Disponibilidades do mesmo tipo, mas com data < date
    //    Remove o resto (data >= date)
    return disponibilidades.where((d) {
      if (d.tipo != tipo) {
        // Se é outro tipo, mantemos
        return true;
      } else {
        // Se é do mesmo tipo, só mantemos se for antes de 'date'
        return d.data.isBefore(date);
      }
    }).toList();
  } else {
    // Remove só a data exata
    return disponibilidades.where((d) {
      final isSameDay =
          d.data.year == date.year &&
              d.data.month == date.month &&
              d.data.day == date.day;
      return !isSameDay;
    }).toList();
  }
}
