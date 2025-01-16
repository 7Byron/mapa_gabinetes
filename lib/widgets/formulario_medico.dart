import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../banco_dados/database_helper.dart';

class FormularioMedico extends StatelessWidget {
  final TextEditingController nomeController;
  final TextEditingController especialidadeController;

  const FormularioMedico({
    super.key,
    required this.nomeController,
    required this.especialidadeController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: nomeController,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: (value) =>
          value == null || value.isEmpty ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 16),
        TypeAheadField<String>(
          suggestionsCallback: (pattern) async {
            // Obtém sugestões do banco de dados
            final especialidades = await DatabaseHelper.buscarEspecialidades();
            return especialidades
                .where((especialidade) =>
                especialidade.toLowerCase().contains(pattern.toLowerCase()))
                .toList();
          },
          builder: (context, controller, focusNode) {
            return TextField(
              controller: especialidadeController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Especialidade',
                border: OutlineInputBorder(),
              ),
            );
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              title: Text(suggestion),
            );
          },
          onSelected: (suggestion) {
            especialidadeController.text = suggestion;
          },
          hideOnEmpty: true,
          hideOnLoading: false,
          animationDuration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }
}
