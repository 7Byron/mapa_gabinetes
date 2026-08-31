/// Utilitários para editar horários sem modificar listas partilhadas por uma
/// série, pelos seus cartões gerados ou por uma exceção já carregada.
class HorariosDisponibilidadeUtils {
  HorariosDisponibilidadeUtils._();

  /// Indica se a lista contém horas de início e de fim preenchidas.
  static bool temInicioEFim(List<String> horarios) =>
      horarios.length >= 2 &&
      horarios[0].trim().isNotEmpty &&
      horarios[1].trim().isNotEmpty;

  /// Devolve uma nova lista com o horário alterado.
  ///
  /// Os horários atuais nunca são modificados. Isto permite que os cartões
  /// normais continuem a partilhar os horários-base da série e só cria uma
  /// lista independente quando existe uma edição efetiva (copy-on-write).
  static List<String> comHorarioAlterado({
    required List<String> horariosAtuais,
    required String novoHorario,
    required bool isInicio,
  }) {
    final horariosEditados = List<String>.from(horariosAtuais);

    if (isInicio) {
      if (horariosEditados.isEmpty) {
        horariosEditados.add(novoHorario);
      } else {
        horariosEditados[0] = novoHorario;
      }
    } else if (horariosEditados.isEmpty) {
      horariosEditados.addAll(['', novoHorario]);
    } else if (horariosEditados.length == 1) {
      horariosEditados.add(novoHorario);
    } else {
      horariosEditados[1] = novoHorario;
    }

    return horariosEditados;
  }
}
