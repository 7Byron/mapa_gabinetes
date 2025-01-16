import '../class/medico.dart';

/// Verifica se o médico está disponível em uma data e horário específicos
bool isMedicoDisponivel(Medico medico, DateTime data, String horario) {
  // Verificar se a data está dentro de um período de férias
  for (var periodo in medico.ferias) {
    if (data.isAfter(periodo.inicio) && data.isBefore(periodo.fim)) {
      return false; // Médico está de férias
    }
  }

  // Verificar se a data está nas disponibilidades
  for (var disponibilidade in medico.disponibilidades) {
    if (disponibilidade.data.year == data.year &&
        disponibilidade.data.month == data.month &&
        disponibilidade.data.day == data.day) {
      // Verificar se o horário está permitido
      if (_isHorarioPermitido(disponibilidade.horarios, horario)) {
        return true;
      }
    }
  }

  return false; // Não encontrou disponibilidade
}

/// Verifica se um horário está dentro dos horários permitidos
bool _isHorarioPermitido(List<String> horariosPermitidos, String horario) {
  return horariosPermitidos.any((h) {
    final partes = h.split('-');
    return horario.compareTo(partes[0]) >= 0 && horario.compareTo(partes[1]) <= 0;
  });
}
