import '../class/reservas.dart';
import 'database_helper.dart';

/// Buscar todas as reservas do banco de dados SQLite
Future<List<Reserva>> buscarReservas() async {
  return await DatabaseHelper.buscarReservas(); // Usa o método do DatabaseHelper
}
