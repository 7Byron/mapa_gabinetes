import 'package:flutter/material.dart';
import '../class/gabinete.dart';
import '../banco_dados/database_helper.dart';
import 'cadastro_gabinete.dart';

class ListaGabinetes extends StatefulWidget {
  const ListaGabinetes({super.key});

  @override
  ListaGabinetesState createState() => ListaGabinetesState();
}

class ListaGabinetesState extends State<ListaGabinetes> {
  List<Gabinete> gabinetes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarGabinetes(); // Carrega os dados ao abrir a tela
  }

  Future<void> _carregarGabinetes() async {
    setState(() => isLoading = true);
    gabinetes = await DatabaseHelper.buscarGabinetes();
    setState(() => isLoading = false);
  }

  Future<void> _adicionarOuEditarGabinete({Gabinete? gabineteExistente}) async {
    final novoGabinete = await Navigator.push<Gabinete>(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroGabinete(gabinete: gabineteExistente),
      ),
    );

    if (novoGabinete != null) {
      if (gabineteExistente != null) {
        await DatabaseHelper.atualizarGabinete(novoGabinete);
      } else {
        await DatabaseHelper.salvarGabinete(novoGabinete);
      }
      _carregarGabinetes();
    }
  }

  Future<void> _deletarGabinete(String id) async {
    await DatabaseHelper.deletarGabinete(id);
    _carregarGabinetes();
  }

  void _confirmarDelecao(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir este gabinete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletarGabinete(id);
              },
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Gabinetes'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : gabinetes.isEmpty
          ? Center(child: Text('Nenhum gabinete encontrado'))
          : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView.builder(
                      itemCount: gabinetes.length,
                      itemBuilder: (context, index) {
              final gabinete = gabinetes[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text('Setor: ${gabinete.setor} - Gabinete: ${gabinete.nome}'),
                  subtitle: Text(
                    'Especialidades Permitidas: ${gabinete.especialidadesPermitidas.join(', ')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _adicionarOuEditarGabinete(gabineteExistente: gabinete);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmarDelecao(context, gabinete.id),
                      ),
                    ],
                  ),
                ),
              );
                      },
                    ),
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarOuEditarGabinete(),
        child: Icon(Icons.add),
      ),
    );
  }
}
