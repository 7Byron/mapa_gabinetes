import 'package:flutter/material.dart';
import 'lista_gabinetes.dart';
import 'lista_reservas.dart';
import 'lista_medicos.dart';

class TelaPrincipal extends StatelessWidget {
  const TelaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestão de Clínica Médica'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue, // Cor do cabeçalho do drawer
              ),
              child: Text(
                'Gestão Mapa Gabinetes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // ListTile(
            //   leading: Icon(Icons.event), // Ícone para reservas
            //   title: Text('Gerir Reservas'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => ListaReservas()),
            //     );
            //   },
            // ),
            ListTile(
              leading: Icon(Icons.medical_services), // Ícone para médicos
              title: Text('Gerir Médicos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaMedicos()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.business), // Ícone para gabinetes
              title: Text('Gerir Gabinetes'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListaGabinetes()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Bem-vindo ao Mapa de Gabinetes',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
