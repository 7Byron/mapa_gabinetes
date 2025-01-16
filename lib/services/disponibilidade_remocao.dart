// lib/services/disponibilidade_remocao.dart

import '../class/disponibilidade.dart';

List<Disponibilidade> removerDisponibilidade(
    List<Disponibilidade> disponibilidades,
    DateTime date, {
      bool removeSerie = false,
    }) {
  if (removeSerie) {
    // 1. Descobre qual é o tipo do dia selecionado
    final dispSelecionada = disponibilidades.firstWhere(
          (d) =>
      d.data.year == date.year &&
          d.data.month == date.month &&
          d.data.day == date.day,
      orElse: () => Disponibilidade(
        id: '',
        data: date,
        horarios: [],
        tipo: 'Única',
      ),
    );
    final tipo = dispSelecionada.tipo;

    // 2. Mantém:
    //    - Disponibilidades de outro tipo
    //    - Disponibilidades do mesmo tipo, mas com data < date
    //    Remove o resto (data >= date)
    return disponibilidades.where((d) {
      if (d.tipo != tipo) {
        return true; // mantém se for outro tipo
      } else {
        // se for do mesmo tipo, remove se data >= date
        // então só "mantemos" se d.data for antes
        return d.data.isBefore(date);
      }
    }).toList();
  } else {
    // Remover só a data exata
    return disponibilidades.where((d) {
      final isSameDay =
          d.data.year == date.year &&
              d.data.month == date.month &&
              d.data.day == date.day;
      return !isSameDay; // descarta o dia exato
    }).toList();
  }
}
