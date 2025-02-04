import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/gabinete.dart';
import '../database/database_helper.dart';
import 'cadastro_gabinete.dart';

class ListaGabinetes extends StatefulWidget {
  const ListaGabinetes({super.key});

  @override
  ListaGabinetesState createState() => ListaGabinetesState();
}

class ListaGabinetesState extends State<ListaGabinetes> {
  List<Gabinete> gabinetes = [];
  Map<String, List<Gabinete>> gabinetesPorSetor = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarGabinetes(); // Carrega os dados ao abrir a tela
  }

  Future<void> _carregarGabinetes() async {
    setState(() => isLoading = true);
    gabinetes = await DatabaseHelper.buscarGabinetes();
    gabinetesPorSetor = agruparPorSetor(gabinetes);
    setState(() => isLoading = false);
  }

  // Função para agrupar e ordenar os gabinetes por setor
  Map<String, List<Gabinete>> agruparPorSetor(List<Gabinete> gabinetes) {
    Map<String, List<Gabinete>> gabinetesPorSetor = {};
    for (var gabinete in gabinetes) {
      if (!gabinetesPorSetor.containsKey(gabinete.setor)) {
        gabinetesPorSetor[gabinete.setor] = [];
      }
      gabinetesPorSetor[gabinete.setor]!.add(gabinete);
    }

    // Ordenar os gabinetes em cada setor
    gabinetesPorSetor.forEach((setor, lista) {
      lista.sort((a, b) => a.nome.compareTo(b.nome)); // Ordenação por nome
    });

    return gabinetesPorSetor;
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
      appBar: CustomAppBar(title: 'Lista de Gabinetes'),
      backgroundColor: MyAppTheme.cinzento,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : gabinetes.isEmpty
          ? Center(child: Text('Nenhum gabinete encontrado'))
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            itemCount: gabinetesPorSetor.length,
            itemBuilder: (context, index) {
              String setor = gabinetesPorSetor.keys.elementAt(index);
              List<Gabinete> gabinetesDoSetor =
              gabinetesPorSetor[setor]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      setor,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (var gabinete in gabinetesDoSetor)
                    Card(
                      margin: EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: RichText(
                          text: TextSpan(
                            text: 'Gabinete ${gabinete.nome} - ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                            children: [
                              TextSpan(
                                text: gabinete
                                    .especialidadesPermitidas
                                    .isNotEmpty
                                    ? gabinete
                                    .especialidadesPermitidas
                                    .first
                                    : 'Sem Especialidades',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: MyAppTheme.azulEscuro),
                              tooltip: 'Editar',
                              onPressed: () {
                                _adicionarOuEditarGabinete(
                                    gabineteExistente: gabinete);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete,
                                  color: Colors.red),
                              tooltip: 'Eliminar',
                              onPressed: () => _confirmarDelecao(
                                  context, gabinete.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarOuEditarGabinete(),
        tooltip: 'Adicionar Gabinete',
        child: Icon(Icons.add),
      ),
    );
  }
}
