import 'package:flutter/material.dart';
import '../utils/app_theme.dart';


class FiltrosSection extends StatelessWidget {
  final List<String> pisosSelecionados;
  final void Function(String setor, bool isSelected) onTogglePiso;
  final String filtroOcupacao;
  final void Function(String) onFiltroOcupacaoChanged;
  final bool mostrarConflitos;
  final void Function(bool) onMostrarConflitosChanged;
  final List<String> todosSetores;
  final String? filtroEspecialidadeGabinete;
  final void Function(String?) onFiltroEspecialidadeGabineteChanged;
  final List<String> especialidadesGabinetes;

  const FiltrosSection({
    super.key,
    required this.pisosSelecionados,
    required this.onTogglePiso,
    required this.filtroOcupacao,
    required this.onFiltroOcupacaoChanged,
    required this.mostrarConflitos,
    required this.onMostrarConflitosChanged,
    required this.todosSetores,
    required this.filtroEspecialidadeGabinete,
    required this.onFiltroEspecialidadeGabineteChanged,
    required this.especialidadesGabinetes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12), // Espaçamento interno
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MyAppTheme.azulEscuro.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                Icons.filter_list,
                  color: MyAppTheme.azulEscuro,
                size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Filtros',
                style: MyAppTheme.heading2.copyWith(
                  fontSize: 18,
                  color: MyAppTheme.azulEscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Pisos',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: todosSetores.map((setor) {
              final isSelected = pisosSelecionados.contains(setor);
              return FilterChip(
                label: Text(
                  setor,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => onTogglePiso(setor, selected),
                selectedColor: MyAppTheme.azulEscuro,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected 
                      ? MyAppTheme.azulEscuro 
                      : Colors.grey.shade300,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Ocupação',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
            value: filtroOcupacao,
              isExpanded: true,
              underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'Todos', child: Text('Todos')),
              DropdownMenuItem(value: 'Livres', child: Text('Livres')),
              DropdownMenuItem(value: 'Ocupados', child: Text('Ocupados')),
            ],
            onChanged: (value) {
              if (value != null) onFiltroOcupacaoChanged(value);
            },
          ),
          ),
          const SizedBox(height: 20),
          Text(
            'Especialidade do Gabinete',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
            value: filtroEspecialidadeGabinete,
              isExpanded: true,
              underline: const SizedBox(),
            hint: const Text('Todas especialidades'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todas especialidades'),
              ),
              ...especialidadesGabinetes
                  .map((especialidade) => DropdownMenuItem(
                        value: especialidade,
                        child: Text(especialidade),
                      )),
            ],
            onChanged: onFiltroEspecialidadeGabineteChanged,
          ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: CheckboxListTile(
              title: Text(
                'Mostrar Conflitos',
                style: MyAppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            controlAffinity: ListTileControlAffinity.leading,
            value: mostrarConflitos,
              activeColor: MyAppTheme.azulEscuro,
            onChanged: (val) {
              if (val != null) onMostrarConflitosChanged(val);
            },
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}
