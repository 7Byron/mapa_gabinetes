import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../models/gabinete.dart';
import '../database/database_helper.dart';

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

  List<String> _setoresDisponiveis = [];
  List<String> _especialidadesDisponiveis = [];

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
    final gabinetes = await DatabaseHelper.buscarGabinetes();

    setState(() {
      _setoresDisponiveis = {...gabinetes.map((g) => g.setor)}.toList();

      _especialidadesDisponiveis =
          {...gabinetes.expand((g) => g.especialidadesPermitidas)}.toList();
    });
  }

  Future<void> _salvarGabinete() async {
    if (_formKey.currentState!.validate()) {
      final gabinete = Gabinete(
        id: widget.gabinete?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        setor: _setorController.text,
        nome: _nomeController.text,
        especialidadesPermitidas: _especialidadesController.text
            .split(',')
            .map((e) => e.trim())
            .toList(),
      );

      // Salva ou atualiza o gabinete no banco de dados
      if (widget.gabinete != null) {
        await DatabaseHelper.atualizarGabinete(gabinete);
      } else {
        await DatabaseHelper.salvarGabinete(gabinete);
      }

      Navigator.pop(context, gabinete); // Retorna o gabinete atualizado
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          await _salvarGabinete(); // Chama o método para salvar ao voltar
          return true; // Permite a navegação para trás
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                widget.gabinete == null ? 'Novo Gabinete' : 'Editar Gabinete'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Campo para Setor / Piso com TypeAheadField estilizado
                      TypeAheadField<String>(
                        suggestionsCallback: (pattern) {
                          return _setoresDisponiveis
                              .where((setor) => setor
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()))
                              .toList();
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: _setorController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Setor / Piso',
                              hintText: 'Exemplo: Piso 1, Andar Térreo',
                              border: OutlineInputBorder(), // Borda quadrada
                            ),
                          );
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          _setorController.text = suggestion;
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

                      // Campo para Especialidades Permitidas com TypeAheadField estilizado
                      TypeAheadField<String>(
                        suggestionsCallback: (pattern) {
                          return _especialidadesDisponiveis
                              .where((especialidade) => especialidade
                                  .toLowerCase()
                                  .contains(pattern.toLowerCase()))
                              .toList();
                        },
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: _especialidadesController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Especialidades Permitidas',
                              hintText:
                                  'Exemplo: Ortopedia, ORL, Medicina Dentária',
                              border: OutlineInputBorder(), // Borda quadrada
                            ),
                          );
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(
                            title: Text(suggestion),
                          );
                        },
                        onSelected: (suggestion) {
                          _especialidadesController.text = suggestion;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}
