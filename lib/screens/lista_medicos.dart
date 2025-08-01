import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart';
import 'cadastro_medicos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListaMedicos extends StatefulWidget {
  final Unidade? unidade;
  const ListaMedicos({super.key, this.unidade});

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
      CollectionReference ocupantesRef;

      if (widget.unidade != null) {
        // Busca ocupantes da unidade específica
        ocupantesRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
      } else {
        // Busca todos os ocupantes (fallback para compatibilidade)
        ocupantesRef = FirebaseFirestore.instance.collection('medicos');
      }

      final snapshot = await ocupantesRef.get();
      print('🔍 Buscando médicos na unidade: ${widget.unidade?.id ?? 'global'}');
      print('📊 Documentos encontrados: ${snapshot.docs.length}');
      
      final medicosCarregados = <Medico>[];
      
      for (final doc in snapshot.docs) {
        final dados = doc.data() as Map<String, dynamic>;
        
        // Busca disponibilidades da nova estrutura por ano
        final dispRef = doc.reference.collection('disponibilidades');
        final disponibilidades = <Map<String, dynamic>>[];
        
        // Carrega apenas o ano atual por padrão (otimização)
        final anoAtual = DateTime.now().year.toString();
        final anoRef = dispRef.doc(anoAtual);
        final registosRef = anoRef.collection('registos');
        
        try {
          final registosSnapshot = await registosRef.get();
          for (final d in registosSnapshot.docs) {
            final data = d.data();
            disponibilidades.add({
              ...data,
              'horarios': data['horarios'] is List ? data['horarios'] : [],
            });
          }
        } catch (e) {
          // Fallback: tenta carregar de todos os anos
          final anosSnapshot = await dispRef.get();
          for (final anoDoc in anosSnapshot.docs) {
            final registosRef = anoDoc.reference.collection('registos');
            final registosSnapshot = await registosRef.get();
            for (final d in registosSnapshot.docs) {
              final data = d.data();
              disponibilidades.add({
                ...data,
                'horarios': data['horarios'] is List ? data['horarios'] : [],
              });
            }
          }
        }
        
        medicosCarregados.add(Medico(
          id: dados['id'],
          nome: dados['nome'],
          especialidade: dados['especialidade'],
          observacoes: dados['observacoes'],
          disponibilidades: disponibilidades.map((e) => Disponibilidade.fromMap(e)).toList(),
        ));
        
        print('✅ Médico carregado: ${dados['nome']} (${disponibilidades.length} disponibilidades)');
      }
      medicosCarregados.sort((a, b) => a.nome.compareTo(b.nome));
      setState(() {
        medicos = medicosCarregados;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erro ao carregar ${widget.unidade?.nomeOcupantes ?? 'Ocupantes'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Função para deletar um médico
  Future<void> _deletarMedico(String id) async {
    try {
      CollectionReference ocupantesRef;
      CollectionReference disponibilidadesRef;

      if (widget.unidade != null) {
        // Deleta ocupante da unidade específica
        ocupantesRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
        disponibilidadesRef =
            ocupantesRef.doc(id).collection('disponibilidades');
      } else {
        // Deleta da coleção antiga (fallback)
        ocupantesRef = FirebaseFirestore.instance.collection('medicos');
        disponibilidadesRef =
            ocupantesRef.doc(id).collection('disponibilidades');
      }

      // Apaga todas as disponibilidades do médico (nova estrutura por ano)
      final anosSnapshot = await disponibilidadesRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final registosSnapshot = await registosRef.get();
        for (final doc in registosSnapshot.docs) {
          await doc.reference.delete();
        }
        // Remove o documento do ano se estiver vazio
        await anoDoc.reference.delete();
      }
      // Agora apaga o médico
      await ocupantesRef.doc(id).delete();
      await _carregarMedicos(); // Recarrega a lista após exclusão
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erro ao deletar ${widget.unidade?.nomeOcupantes ?? 'Ocupante'}: $e'),
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
          content: Text(
              'Tem certeza que deseja excluir este ${widget.unidade?.nomeOcupantes ?? 'Ocupante'}?'),
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
        builder: (context) =>
            CadastroMedico(medico: medico, unidade: widget.unidade),
      ),
    );
    if (resultado != null) {
      await _carregarMedicos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
          title: 'Lista de ${widget.unidade?.nomeOcupantes ?? 'Ocupantes'}'),
      backgroundColor: MyAppTheme.cinzento,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medicos.isEmpty
              ? Center(
                  child: Text(
                      'Nenhum ${widget.unidade?.nomeOcupantes ?? 'Ocupante'} encontrado'))
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
        tooltip: 'Adicionar ',
        child: const Icon(Icons.add),
      ),
    );
  }
}
