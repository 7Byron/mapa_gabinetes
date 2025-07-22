import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gabinete.dart';
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
    try {
      final snapshot = await FirebaseFirestore.instance.collection('gabinetes').get();
      debugPrint('Documentos encontrados: ${snapshot.docs.length}');
      
      final gabinetesCarregados = <Gabinete>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          debugPrint('Dados do documento ${doc.id}: $data');
          
          // Adiciona o ID do documento se não existir
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          
          final gabinete = Gabinete.fromMap(data);
          gabinetesCarregados.add(gabinete);
        } catch (e) {
          debugPrint('Erro ao processar documento ${doc.id}: $e');
          // Continua com o próximo documento
        }
      }
      
      gabinetesCarregados.sort((a, b) => a.nome.compareTo(b.nome));
      debugPrint('Gabinetes carregados com sucesso: ${gabinetesCarregados.length}');
      
      setState(() {
        gabinetes = gabinetesCarregados;
        gabinetesPorSetor = agruparPorSetor(gabinetes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro geral ao carregar gabinetes: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar gabinetes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroGabinete(gabinete: gabineteExistente),
      ),
    );

    if (resultado == true) {
      _carregarGabinetes();
    }
  }

  Future<void> _deletarGabinete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('gabinetes').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gabinete eliminado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      _carregarGabinetes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao eliminar gabinete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
