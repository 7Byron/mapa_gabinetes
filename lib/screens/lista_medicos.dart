import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/medico.dart';
import 'cadastro_medicos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListaMedicos extends StatefulWidget {
  const ListaMedicos({super.key});

  @override
  ListaMedicosState createState() => ListaMedicosState();
}

class ListaMedicosState extends State<ListaMedicos> {
  List<Medico> medicos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarMedicos();
    // Adiciona observer para detectar retorno à tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ModalRoute.of(context)?.addScopedWillPopCallback(() async {
        _carregarMedicos();
        return true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sempre que a tela volta a ser exibida, recarrega a lista
    _carregarMedicos();
  }

  /// Função para buscar médicos
  Future<void> _carregarMedicos() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('medicos').get();
      final medicosCarregados = snapshot.docs.map((doc) => Medico.fromMap(doc.data())).toList();
      medicosCarregados.sort((a, b) => a.nome.compareTo(b.nome));
      setState(() {
        medicos = medicosCarregados;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar médicos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Função para deletar um médico
  Future<void> _deletarMedico(String id) async {
    try {
      // Apaga todas as disponibilidades do médico
      final disponSnapshot = await FirebaseFirestore.instance
          .collection('medicos')
          .doc(id)
          .collection('disponibilidades')
          .get();
      for (final doc in disponSnapshot.docs) {
        await doc.reference.delete();
      }
      // Agora apaga o médico
      await FirebaseFirestore.instance.collection('medicos').doc(id).delete();
      await _carregarMedicos(); // Recarrega a lista após exclusão
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao deletar médico: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Confirmação de exclusão de médico
  void _confirmarDelecao(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja excluir este médico?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletarMedico(id);
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Navega para o cadastro de médicos e recarrega a lista ao voltar
  Future<void> _adicionarOuEditarMedico({Medico? medico}) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroMedico(medico: medico),
      ),
    );
    if (resultado != null) {
      await _carregarMedicos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Lista de Médicos'),
      backgroundColor: MyAppTheme.cinzento,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medicos.isEmpty
              ? const Center(child: Text('Nenhum médico encontrado'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView.builder(
                      itemCount: medicos.length,
                      itemBuilder: (context, index) {
                        final medico = medicos[index];
                        return GestureDetector(
                          onTap: () => _adicionarOuEditarMedico(medico: medico),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: ListTile(
                              title: Text(medico.nome),
                              subtitle: Text(medico.especialidade),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'Eliminar',
                                    onPressed: () =>
                                        _confirmarDelecao(context, medico.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarOuEditarMedico(),
        tooltip: 'Adicionar Médico',
        child: const Icon(Icons.add),
      ),
    );
  }
}
