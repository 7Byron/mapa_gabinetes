import '../class/reservas.dart';
import 'database_helper.dart';

// Salvar uma lista de reservas no banco de dados SQLite
Future<void> salvarReservas(List<Reserva> reservas) async {
  for (var reserva in reservas) {
    await DatabaseHelper.salvarReserva(reserva); // Salva cada reserva no banco
  }
}

// Buscar todas as reservas do banco de dados SQLite
Future<List<Reserva>> buscarReservas() async {
  return await DatabaseHelper.buscarReservas(); // Busca reservas do banco
}

// Deletar uma reserva do banco de dados pelo ID
Future<void> deletarReserva(String id) async {
  await DatabaseHelper.deletarReserva(id); // Deleta pelo ID
}
