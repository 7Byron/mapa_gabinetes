import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:mapa_gabinetes/main.dart';
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
    // TODO: Refatorar para usar Firestore diretamente.
    // Todas as referências a DatabaseHelper removidas.
    // Remover import do banco de dados local.
  }

  Future<void> _salvarGabinete() async {
    // Verifica se o campo de setor está preenchido
    if (_setorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não introduziu  Setor/Piso')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      // Removido: variável 'gabinete' não utilizada.
      widget.gabinete?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();
      _setorController.text;
      _nomeController.text;
      _especialidadesController.text
          .split(',')
          .map((e) => e.trim())
          .toList();

      // TODO: Salvar ou atualizar o gabinete no Firestore
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
                      TypeAheadField<String>(
                        suggestionsCallback: (pattern) async {
                          // Filtra os setores disponíveis com base no padrão digitado
                          return _setoresDisponiveis
                              .where((setor) => setor
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          // Renderiza cada sugestão como um ListTile
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          // Atualiza o campo de texto ao selecionar uma sugestão
                          _setorController.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          // Define a aparência do campo de texto
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Setor / Piso',
                              hintText: 'Exemplo: Piso 1, Andar Térreo',
                              border:
                                  OutlineInputBorder(), // Define a borda do campo
                            ),
                          );
                        },
                        decorationBuilder: (context, child) {
                          // Define a aparência do popup de sugestões
                          return Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: child,
                          );
                        },
                        itemSeparatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        debounceDuration: const Duration(
                            milliseconds: 300), // Evita chamadas rápidas
                        hideOnEmpty:
                            true, // Esconde as sugestões quando o texto está vazio
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

                      TypeAheadField<String>(
                        controller: _especialidadesController,
                        suggestionsCallback: (pattern) async {
                          // Filtra as especialidades disponíveis com base no padrão digitado
                          return _especialidadesDisponiveis
                              .where((especialidade) => especialidade
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          // Renderiza cada sugestão como um ListTile
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          // Atualiza o campo de texto ao selecionar uma sugestão
                          _especialidadesController.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          // Define a aparência do campo de texto
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Especialidades Permitidas',
                              hintText:
                                  'Exemplo: Ortopedia, ORL, Medicina Dentária',
                              border:
                                  OutlineInputBorder(), // Define a borda do campo
                            ),
                          );
                        },
                        decorationBuilder: (context, child) {
                          // Define a aparência do popup de sugestões
                          return Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: child,
                          );
                        },
                        itemSeparatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        debounceDuration: const Duration(
                            milliseconds: 350), // Evita chamadas rápidas
                        hideOnEmpty:
                            true, // Esconde as sugestões quando o texto está vazio
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
