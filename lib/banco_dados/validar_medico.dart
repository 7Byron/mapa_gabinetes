import '../class/medico.dart';

/// Verifica se o médico está disponível em uma data e horário específicos
bool isMedicoDisponivel(Medico medico, DateTime data, String horarioInicio, String horarioFim) {
  // Verificar se a data está nas disponibilidades
  for (var disponibilidade in medico.disponibilidades) {
    if (disponibilidade.data.year == data.year &&
        disponibilidade.data.month == data.month &&
        disponibilidade.data.day == data.day) {
      // Verificar se o horário está permitido
      if (_isHorarioPermitido(disponibilidade.horarios, horarioInicio, horarioFim)) {
        return true;
      }
    }
  }

  return false; // Não encontrou disponibilidade
}

/// Verifica se um horário está dentro dos horários permitidos
bool _isHorarioPermitido(List<String> horariosPermitidos, String horarioInicio, String horarioFim) {
  return horariosPermitidos.any((h) {
    final partes = h.split('-');
    return isHorarioEntre(horarioInicio, horarioFim, partes[0]) || isHorarioEntre(horarioInicio, horarioFim, partes[1]);
  });
}

bool isHorarioEntre(String horarioInicio, String horarioFim, String horario) {
  // Lógica para verificar se um horário está entre dois horários
  // Você precisará implementar a lógica para verificar se o horário está entre dois horários
  // com base em suas disponibilidades e no horário da reserva.
  // Retorna true se o horário estiver entre dois horários, false caso contrário.
  // Exemplo:
  // return horarios.any((horario) =>
  //     horario == horarioInicio ||
  //     horario == horarioFim ||
  //     (horario.compareTo(horarioInicio) > 0 && horario.compareTo(horarioFim) < 0));
  return (horario.compareTo(horarioInicio) >= 0 && horario.compareTo(horarioFim) <= 0);
}