// lib/widgets/filtros_section.dart

import 'package:flutter/material.dart';

class FiltrosSection extends StatelessWidget {
  final List<String> pisosSelecionados;
  final void Function(String setor, bool isSelected) onTogglePiso;
  final String filtroOcupacao;
  final void Function(String) onFiltroOcupacaoChanged;
  final bool mostrarConflitos;
  final void Function(bool) onMostrarConflitosChanged;
  final List<String> todosSetores;

  const FiltrosSection({
    super.key,
    required this.pisosSelecionados,
    required this.onTogglePiso,
    required this.filtroOcupacao,
    required this.onFiltroOcupacaoChanged,
    required this.mostrarConflitos,
    required this.onMostrarConflitosChanged,
    required this.todosSetores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 30),

          const Text('Pisos:'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: todosSetores.map((setor) {
              return FilterChip(
                label: Text(setor),
                selected: pisosSelecionados.contains(setor),
                onSelected: (selected) => onTogglePiso(setor, selected),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          const Text('Ocupação:'),
          DropdownButton<String>(
            value: filtroOcupacao,
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Livres', child: Text('Livres')),
              DropdownMenuItem(value: 'Ocupados', child: Text('Ocupados')),
            ],
            onChanged: (value) {
              if (value != null) onFiltroOcupacaoChanged(value);
            },
          ),
          const SizedBox(height: 10),

          CheckboxListTile(
            title: const Text('Mostrar Conflitos'),
            controlAffinity: ListTileControlAffinity.leading,
            value: mostrarConflitos,
            onChanged: (val) {
              if (val != null) onMostrarConflitosChanged(val);
            },
          ),
        ],
      ),
    );
  }
}
