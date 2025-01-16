import 'database_helper.dart';
import '../class/medico.dart';
import 'validar_gabinete.dart';
import 'validar_medico.dart';
import '../class/gabinete.dart';
import '../class/reservas.dart';

Future<void> criarReserva(
    Reserva reserva,
    Medico medico,
    Gabinete gabinete,
    List<Reserva> reservas,
    ) async {
  // Verificar disponibilidade do médico
  if (!isMedicoDisponivel(medico, reserva.data, reserva.horario)) {
    throw Exception('Médico indisponível neste horário.');
  }

  // Verificar disponibilidade do gabinete
  if (!isGabineteDisponivel(reserva.gabineteId, reserva.horario, reserva.data, reservas)) {
    throw Exception('Gabinete indisponível neste horário.');
  }

  // Persistir reserva no banco de dados
  await DatabaseHelper.salvarReserva(reserva); // Chama o método correto
}
