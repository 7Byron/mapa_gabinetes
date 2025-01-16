import 'package:flutter/material.dart';
import '../class/gabinete.dart';
import '../banco_dados/database_helper.dart';

class CadastroGabinete extends StatefulWidget {
  final Gabinete? gabinete;

  const CadastroGabinete({super.key, this.gabinete});

  @override
  CadastroGabineteState createState() => CadastroGabineteState();
}

class CadastroGabineteState extends State<CadastroGabinete> {
  final _formKey = GlobalKey<FormState>();
  final _setorController = TextEditingController(); // Controlador para Setor/Piso
  final _nomeController = TextEditingController(); // Controlador para Número do Gabinete
  final _especialidadesController = TextEditingController(); // Controlador para Especialidades Permitidas

  List<String> _setoresDisponiveis = []; // Setores/Pisos disponíveis
  List<String> _especialidadesDisponiveis = []; // Especialidades disponíveis

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
      _setoresDisponiveis = {
        ...gabinetes.map((g) => g.setor)
      }.toList(); // Garante valores únicos

      _especialidadesDisponiveis = {
        ...gabinetes.expand((g) => g.especialidadesPermitidas)
      }.toList(); // Combina listas de especialidades e remove duplicados
    });
  }

  void _salvarGabinete() {
    if (_formKey.currentState!.validate()) {
      final gabinete = Gabinete(
        id: widget.gabinete?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        setor: _setorController.text,
        nome: _nomeController.text,
        especialidadesPermitidas: _especialidadesController.text
            .split(',')
            .map((e) => e.trim())
            .toList(),
      );

      Navigator.pop(context, gabinete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gabinete == null ? 'Novo Gabinete' : 'Editar Gabinete'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _salvarGabinete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Campo para o setor/piso com opções do banco de dados
              TextFormField(
                controller: _setorController,
                decoration: InputDecoration(
                  labelText: 'Setor / Piso',
                  hintText: 'Exemplo: Piso 1, Andar Térreo',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o setor / piso';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (!_setoresDisponiveis.contains(value)) {
                    setState(() {
                      _setoresDisponiveis.add(value);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Campo para o número do gabinete
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Número do Gabinete'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o número do gabinete';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo para especialidades permitidas com opções do banco de dados
              TextFormField(
                controller: _especialidadesController,
                decoration: InputDecoration(
                  labelText: 'Especialidades Permitidas',
                  hintText: 'Exemplo: Ortopedia, ORL, Medicina Dentária',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe pelo menos uma especialidade';
                  }
                  return null;
                },
                onChanged: (value) {
                  final novasEspecialidades = value
                      .split(',')
                      .map((e) => e.trim())
                      .toList();

                  for (final especialidade in novasEspecialidades) {
                    if (!_especialidadesDisponiveis.contains(especialidade)) {
                      setState(() {
                        _especialidadesDisponiveis.add(especialidade);
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
