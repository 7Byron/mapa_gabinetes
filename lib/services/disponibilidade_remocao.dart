import '../models/disponibilidade.dart';

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
    }) {
  if (removeSerie) {
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
