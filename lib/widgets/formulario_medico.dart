import 'package:flutter/material.dart';

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
        TextFormField(
          controller: especialidadeController,
          decoration: const InputDecoration(labelText: 'Especialidade'),
          validator: (value) => value == null || value.isEmpty
              ? 'Informe a especialidade'
              : null,
        ),
      ],
    );
  }
}
