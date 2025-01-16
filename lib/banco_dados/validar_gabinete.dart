import '../class/reservas.dart';

bool isGabineteDisponivel(String gabineteId, String horario, DateTime data, List<Reserva> reservas) {
  return reservas.every((reserva) =>
  reserva.gabineteId != gabineteId ||
      reserva.horario != horario ||
      reserva.data != data);
}
