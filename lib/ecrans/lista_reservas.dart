// import 'package:flutter/material.dart';
// import '../../banco_dados/database_helper.dart';
// import '../../class/reservas.dart';
// import 'cadastro_reservas.dart';
//
//
// class ListaReservas extends StatefulWidget {
//   const ListaReservas({super.key});
//
//   @override
//   ListaReservasState createState() => ListaReservasState();
// }
//
// class ListaReservasState extends State<ListaReservas> {
//   List<Reserva> reservas = [];
//   bool isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _carregarReservas();
//   }
//
//   Future<void> _carregarReservas() async {
//     setState(() => isLoading = true);
//     final reservasCarregadas = await DatabaseHelper.buscarReservas();
//     setState(() {
//       reservas = reservasCarregadas;
//       isLoading = false;
//     });
//   }
//
//   Future<void> _deletarReserva(String id) async {
//     await DatabaseHelper.deletarReserva(id);
//     _carregarReservas();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Lista de Reservas'),
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : reservas.isEmpty
//           ? Center(child: Text('Nenhuma reserva encontrada'))
//           : SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: DataTable(
//           columns: [
//             DataColumn(label: Text('Médico')),
//             DataColumn(label: Text('Gabinete')),
//             DataColumn(label: Text('Data')),
//             DataColumn(label: Text('Horário')),
//             DataColumn(label: Text('Ações')),
//           ],
//           rows: reservas.map((reserva) {
//             return DataRow(cells: [
//               DataCell(Text(reserva.medicoId)), // Substituir pelo nome do médico
//               DataCell(Text(reserva.gabineteId)), // Substituir pelo nome do gabinete
//               DataCell(Text(reserva.data.toIso8601String().split('T')[0])),
//               DataCell(Text(reserva.horario)),
//               DataCell(Row(
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.edit, color: Colors.blue),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => CadastroReserva(reserva: reserva),
//                         ),
//                       ).then((_) => _carregarReservas());
//                     },
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.delete, color: Colors.red),
//                     onPressed: () => _confirmarDelecao(context, reserva.id),
//                   ),
//                 ],
//               )),
//             ]);
//           }).toList(),
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => CadastroReserva()),
//           ).then((_) => _carregarReservas());
//         },
//         child: Icon(Icons.add),
//       ),
//     );
//   }
//
//   void _confirmarDelecao(BuildContext context, String id) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Confirmar Exclusão'),
//           content: Text('Tem certeza que deseja excluir esta reserva?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('Cancelar'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _deletarReserva(id);
//               },
//               child: Text('Excluir', style: TextStyle(color: Colors.red)),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
