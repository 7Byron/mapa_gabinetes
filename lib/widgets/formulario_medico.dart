import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../database/database_helper.dart';
import '../main.dart';

class FormularioMedico extends StatefulWidget {
  final TextEditingController nomeController;
  final TextEditingController especialidadeController;
  final TextEditingController observacoesController;

  const FormularioMedico({
    super.key,
    required this.nomeController,
    required this.especialidadeController,
    required this.observacoesController,
  });

  @override
  _FormularioMedicoState createState() => _FormularioMedicoState();
}

class _FormularioMedicoState extends State<FormularioMedico> {
  List<String> _especialidadesDisponiveis = [];
  late TextEditingController _typeAheadController; // Controller para TypeAheadField

  @override
  void initState() {
    super.initState();
    _carregarEspecialidades();

    // Inicializa o TypeAheadField com o valor atual do especialidadeController
    _typeAheadController =
        TextEditingController(text: widget.especialidadeController.text);
  }

  Future<void> _carregarEspecialidades() async {
    try {
      // Busca as especialidades dos médicos no banco de dados
      final medicos = await DatabaseHelper.buscarMedicos();
      setState(() {
        _especialidadesDisponiveis = {
          ...medicos.map((medico) => medico.especialidade).where((e) => e.isNotEmpty)
        }.toList();
      });
    } catch (e) {
      debugPrint('Erro ao carregar especialidades: $e');
      setState(() {
        _especialidadesDisponiveis = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome do Médico
            TextFormField(
              controller: widget.nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Médico',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: MyAppTheme.roxo), // Cor do rótulo
                floatingLabelStyle: TextStyle(color: MyAppTheme.roxo), // Cor ao focar
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campo Especialidade com lógica ajustada
            TypeAheadField<String>(
              suggestionsCallback: (pattern) async {
                // Filtra as especialidades disponíveis com base no texto digitado
                return _especialidadesDisponiveis
                    .where((especialidade) =>
                    especialidade.toLowerCase().contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                // Renderiza cada sugestão como um ListTile
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSelected: (suggestion) {
                // Atualiza ambos os controllers ao selecionar uma sugestão
                _typeAheadController.text = suggestion;
                widget.especialidadeController.text = suggestion;
              },
              builder: (context, controller, focusNode) {
                // Sincroniza o _typeAheadController
                controller.text = _typeAheadController.text;

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (value) {
                    // Propaga alterações para o especialidadeController
                    widget.especialidadeController.text = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Especialidade',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: MyAppTheme.roxo), // Cor do rótulo
                    floatingLabelStyle: TextStyle(color: MyAppTheme.roxo), // Cor ao focar
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                    ),
                  ),
                );
              },
              decorationBuilder: (context, child) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemSeparatorBuilder: (context, index) => const Divider(height: 1),
              debounceDuration: const Duration(milliseconds: 300), // Evita chamadas rápidas
              hideOnEmpty: true, // Esconde as sugestões quando o texto está vazio
            ),

            const SizedBox(height: 16),

            // Observações
            TextFormField(
              controller: widget.observacoesController,
              maxLines: 3, // Permitir múltiplas linhas para observações
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: MyAppTheme.roxo), // Cor do rótulo
                floatingLabelStyle: TextStyle(color: Colors.black), // Cor ao focar
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typeAheadController.dispose(); // Libera o controller
    super.dispose();
  }
}
