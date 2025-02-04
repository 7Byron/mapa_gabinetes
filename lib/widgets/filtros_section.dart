import 'package:flutter/material.dart';

import '../main.dart';

class FiltrosSection extends StatelessWidget {
  final List<String> pisosSelecionados;
  final void Function(String setor, bool isSelected) onTogglePiso;
  final String filtroOcupacao;
  final void Function(String) onFiltroOcupacaoChanged;
  final bool mostrarConflitos;
  final void Function(bool) onMostrarConflitosChanged;
  final List<String> todosSetores;

  const FiltrosSection({
    Key? key,
    required this.pisosSelecionados,
    required this.onTogglePiso,
    required this.filtroOcupacao,
    required this.onFiltroOcupacaoChanged,
    required this.mostrarConflitos,
    required this.onMostrarConflitosChanged,
    required this.todosSetores,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12), // Espaçamento interno
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          const Text('Pisos:', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: todosSetores.map((setor) {
              return FilterChip(
                label: Text(
                  setor,
                  style: TextStyle(
                    color: pisosSelecionados.contains(setor) ? Colors.white : Colors.black,
                  ),
                ),
                selected: pisosSelecionados.contains(setor),
                onSelected: (selected) => onTogglePiso(setor, selected),
                selectedColor: MyAppTheme.roxo, // Cor do chip quando selecionado
                backgroundColor: Colors.grey.shade200, // Cor do chip quando não selecionado
                checkmarkColor: Colors.white, // Cor da marca de seleção
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Bordas arredondadas
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text('Ocupação:', style: TextStyle(fontWeight: FontWeight.w600)),
          DropdownButton<String>(
            value: filtroOcupacao,
            isExpanded: true, // Ocupa toda a largura
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Livres', child: Text('Livres')),
              DropdownMenuItem(value: 'Ocupados', child: Text('Ocupados')),
            ],
            onChanged: (value) {
              if (value != null) onFiltroOcupacaoChanged(value);
            },
          ),
          const SizedBox(height: 16),

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
