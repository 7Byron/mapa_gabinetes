import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gabinete.dart';

class CadastroGabinete extends StatefulWidget {
  final Gabinete? gabinete;

  const CadastroGabinete({super.key, this.gabinete});

  @override
  CadastroGabineteState createState() => CadastroGabineteState();
}

class CadastroGabineteState extends State<CadastroGabinete> {
  final _formKey = GlobalKey<FormState>();
  final _setorController = TextEditingController();
  final _nomeController = TextEditingController();
  final _especialidadesController = TextEditingController();

  final List<String> _setoresDisponiveis = [];
  final List<String> _especialidadesDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
    if (widget.gabinete != null) {
      _setorController.text = widget.gabinete!.setor;
      _nomeController.text = widget.gabinete!.nome;
      _especialidadesController.text =
          widget.gabinete!.especialidadesPermitidas.join(', ');
    }
  }

  Future<void> _carregarDados() async {
    try {
      // Carrega setores existentes dos gabinetes
      final gabinetesSnapshot =
          await FirebaseFirestore.instance.collection('gabinetes').get();
      final setores = gabinetesSnapshot.docs
          .map((doc) => doc.data()['setor'] as String)
          .toSet()
          .toList();

      // Carrega especialidades existentes
      final medicosSnapshot =
          await FirebaseFirestore.instance.collection('medicos').get();
      final especialidades = medicosSnapshot.docs
          .map((doc) => doc.data()['especialidade'] as String)
          .toSet()
          .toList();

      setState(() {
        _setoresDisponiveis.clear();
        _setoresDisponiveis.addAll(setores);
        _especialidadesDisponiveis.clear();
        _especialidadesDisponiveis.addAll(especialidades);
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    }
  }

  Future<void> _salvarGabinete() async {
    // Verifica se o campo de setor está preenchido
    if (_setorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não introduziu Setor/Piso')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final gabineteId = widget.gabinete?.id ??
            DateTime.now().millisecondsSinceEpoch.toString();
        final setor = _setorController.text.trim();
        final nome = _nomeController.text.trim();
        final especialidades = _especialidadesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        debugPrint(
            'Salvando gabinete: ID=$gabineteId, Setor=$setor, Nome=$nome, Especialidades=$especialidades');

        // Cria o objeto Gabinete
        final gabinete = Gabinete(
          id: gabineteId,
          setor: setor,
          nome: nome,
          especialidadesPermitidas: especialidades,
        );

        // Converte para Map
        final gabineteMap = gabinete.toMap();
        debugPrint('Dados a salvar: $gabineteMap');

        // Salva no Firestore
        await FirebaseFirestore.instance
            .collection('gabinetes')
            .doc(gabineteId)
            .set(gabineteMap);

        debugPrint('Gabinete salvo com sucesso no Firestore');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gabinete salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Se for edição, volta para a tela anterior
        if (widget.gabinete != null) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('Erro ao salvar gabinete: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar gabinete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _criarNovo() {
    // Limpa os campos para adicionar um novo gabinete
    setState(() {
      _formKey.currentState!.reset();
      _setorController.clear();
      _nomeController.clear();
      _especialidadesController.clear();
    });
  }

  void _cancelar() {
    // Retorna para a tela anterior sem salvar
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gabinete == null ? 'Novo Gabinete' : 'Editar Gabinete',
        ),
      ),
      backgroundColor: MyAppTheme.cinzento,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 300),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Campo para Setor / Piso com TypeAheadField estilizado
                      TextFormField(
                        controller: _setorController,
                        decoration: const InputDecoration(
                          labelText: 'Setor / Piso',
                          hintText: 'Exemplo: Piso 1, Andar Térreo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o setor/piso';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Campo para o Número do Gabinete
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Número do Gabinete',
                          border: OutlineInputBorder(), // Borda quadrada
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o número do gabinete';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _especialidadesController,
                        decoration: const InputDecoration(
                          labelText: 'Especialidades Permitidas',
                          hintText:
                              'Exemplo: Ortopedia, ORL, Medicina Dentária',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe as especialidades permitidas';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: () => _salvarGabinete(),
                              icon: const Icon(Icons.save, color: Colors.blue),
                              tooltip: 'Salvar',
                            ),
                            IconButton(
                              onPressed: () async {
                                await _salvarGabinete();
                                _criarNovo();
                              },
                              icon: const Icon(Icons.add, color: Colors.green),
                              tooltip: 'Salvar e Adicionar Novo',
                            ),
                            IconButton(
                              onPressed: _cancelar,
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Cancelar',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
