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
    final textoSeletor = TextStyle(
      fontSize: 13,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.all(10), // Espaçamento interno reduzido
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: MyAppTheme.azulEscuro.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Filtros',
                style: MyAppTheme.heading2.copyWith(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pisos',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: todosSetores.map((setor) {
              final isSelected = pisosSelecionados.contains(setor);
              return FilterChip(
                label: Text(
                  setor,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => onTogglePiso(setor, selected),
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Ocupação',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            constraints: const BoxConstraints(minHeight: 36),
            child: DropdownButton<String>(
              value: filtroOcupacao,
              isExpanded: true,
              underline: const SizedBox(),
              style: textoSeletor,
              isDense: true,
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
          const SizedBox(height: 14),
          Text(
            'Especialidade do Gabinete',
            style: MyAppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            constraints: const BoxConstraints(minHeight: 36),
            child: DropdownButton<String>(
              value: filtroEspecialidadeGabinete,
              isExpanded: true,
              underline: const SizedBox(),
              style: textoSeletor,
              isDense: true,
              hint: Text('Todas especialidades', style: textoSeletor),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todas especialidades', style: textoSeletor),
                ),
                ...especialidadesGabinetes
                    .map((especialidade) => DropdownMenuItem(
                          value: especialidade,
                          child: Text(especialidade,
                              style: const TextStyle(fontSize: 13)),
                        )),
              ],
              onChanged: onFiltroEspecialidadeGabineteChanged,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outline, width: 0.5),
            ),
            constraints: const BoxConstraints(minHeight: 40),
            child: CheckboxListTile(
              title: Text(
                'Mostrar Conflitos',
                style: MyAppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              value: mostrarConflitos,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                if (val != null) onMostrarConflitosChanged(val);
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}
