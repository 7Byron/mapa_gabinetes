// import 'package:flutter/material.dart';
// import '../../banco_dados/database_helper.dart';
// import '../../class/reservas.dart';
// import '../../class/medico.dart';
// import '../../class/gabinete.dart';
//
// class CadastroReserva extends StatefulWidget {
//   final Reserva? reserva;
//
//   const CadastroReserva({super.key, this.reserva});
//
//   @override
//   CadastroReservaState createState() => CadastroReservaState();
// }
//
// class CadastroReservaState extends State<CadastroReserva> {
//   final _formKey = GlobalKey<FormState>();
//
//   List<Medico> medicos = [];
//   List<Gabinete> gabinetes = [];
//
//   String? medicoSelecionado;
//   String? gabineteSelecionado;
//   DateTime? dataSelecionada;
//   String? horarioSelecionado;
//
//   @override
//   void initState() {
//     super.initState();
//     _carregarDados();
//
//     if (widget.reserva != null) {
//       medicoSelecionado = widget.reserva!.medicoId;
//       gabineteSelecionado = widget.reserva!.gabineteId;
//       dataSelecionada = widget.reserva!.data;
//       horarioSelecionado = widget.reserva!.horario;
//     }
//   }
//
//   Future<void> _carregarDados() async {
//     // Simulação: Substituir por busca no banco de dados
//     medicos = [
//       Medico(id: '1', nome: 'Dr. João', especialidade: 'Cardiologia', disponibilidades: [], ferias: []),
//       Medico(id: '2', nome: 'Dra. Maria', especialidade: 'Dermatologia', disponibilidades: [], ferias: []),
//     ];
//
//     gabinetes = [
//       Gabinete(id: '1', nome: 'Gabinete 1', especialidadesPermitidas: ['Cardiologia']),
//       Gabinete(id: '2', nome: 'Gabinete 2', especialidadesPermitidas: ['Dermatologia']),
//     ];
//
//     setState(() {});
//   }
//
//   Future<void> _salvarReserva() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     final reserva = Reserva(
//       id: widget.reserva?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       medicoId: medicoSelecionado!,
//       gabineteId: gabineteSelecionado!,
//       data: dataSelecionada!,
//       horario: horarioSelecionado!,
//     );
//     final navigator = Navigator.of(context);
//     await DatabaseHelper.salvarReserva(reserva);
//     navigator.pop();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.reserva == null ? 'Nova Reserva' : 'Editar Reserva'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               DropdownButtonFormField<String>(
//                 value: medicoSelecionado,
//                 decoration: InputDecoration(labelText: 'Selecione o Médico'),
//                 items: medicos.map((medico) {
//                   return DropdownMenuItem(
//                     value: medico.id,
//                     child: Text('${medico.nome} (${medico.especialidade})'),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() => medicoSelecionado = value);
//                 },
//                 validator: (value) => value == null ? 'Selecione um médico' : null,
//               ),
//               SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: gabineteSelecionado,
//                 decoration: InputDecoration(labelText: 'Selecione o Gabinete'),
//                 items: gabinetes.map((gabinete) {
//                   return DropdownMenuItem(
//                     value: gabinete.id,
//                     child: Text(gabinete.nome),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() => gabineteSelecionado = value);
//                 },
//                 validator: (value) => value == null ? 'Selecione um gabinete' : null,
//               ),
//               SizedBox(height: 16),
//               TextFormField(
//                 readOnly: true,
//                 decoration: InputDecoration(labelText: 'Data'),
//                 controller: TextEditingController(
//                   text: dataSelecionada != null
//                       ? '${dataSelecionada!.day}/${dataSelecionada!.month}/${dataSelecionada!.year}'
//                       : '',
//                 ),
//                 onTap: () async {
//                   final data = await showDatePicker(
//                     context: context,
//                     initialDate: DateTime.now(),
//                     firstDate: DateTime.now(),
//                     lastDate: DateTime.now().add(Duration(days: 365)),
//                   );
//                   if (data != null) {
//                     setState(() => dataSelecionada = data);
//                   }
//                 },
//                 validator: (value) => dataSelecionada == null ? 'Selecione uma data' : null,
//               ),
//               SizedBox(height: 16),
//               DropdownButtonFormField<String>(
//                 value: horarioSelecionado,
//                 decoration: InputDecoration(labelText: 'Selecione o Horário'),
//                 items: ['08:00', '09:00', '10:00', '11:00']
//                     .map((horario) => DropdownMenuItem(value: horario, child: Text(horario)))
//                     .toList(),
//                 onChanged: (value) {
//                   setState(() => horarioSelecionado = value);
//                 },
//                 validator: (value) => value == null ? 'Selecione um horário' : null,
//               ),
//               SizedBox(height: 24),
//               Center(
//                 child: ElevatedButton(
//                   onPressed: _salvarReserva,
//                   child: Text('Salvar'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
