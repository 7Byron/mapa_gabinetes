import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../banco_dados/database_helper.dart';

class FormularioMedico extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome do Médico',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: especialidadeController,
          decoration: const InputDecoration(
            labelText: 'Especialidade',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: observacoesController,
          maxLines: 3, // Permitir múltiplas linhas para observações
          decoration: const InputDecoration(
            labelText: 'Observações',
            hintText: 'Adicione informações adicionais sobre o médico',
          ),
        ),
      ],
    );
  }
}