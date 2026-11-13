import 'package:flutter/material.dart';

class SearchableSelectionOption<T> {
  final T value;
  final String label;

  const SearchableSelectionOption({
    required this.value,
    required this.label,
  });
}

/// Campo de seleção que abre uma lista pesquisável num diálogo.
class SearchableSelectionField<T> extends StatelessWidget {
  final T? value;
  final Set<T>? values;
  final List<SearchableSelectionOption<T>> options;
  final String label;
  final String hint;
  final bool showLabel;
  final String dialogTitle;
  final String searchHint;
  final IconData suffixIcon;
  final ValueChanged<T?>? onChanged;
  final ValueChanged<Set<T>>? onSelectionChanged;

  const SearchableSelectionField({
    super.key,
    required this.value,
    required this.options,
    required this.label,
    required this.hint,
    this.showLabel = true,
    required this.dialogTitle,
    required this.searchHint,
    required this.suffixIcon,
    required this.onChanged,
  })  : values = null,
        onSelectionChanged = null;

  const SearchableSelectionField.multiple({
    super.key,
    required this.values,
    required this.options,
    required this.label,
    required this.hint,
    this.showLabel = true,
    required this.dialogTitle,
    required this.searchHint,
    required this.suffixIcon,
    required this.onSelectionChanged,
  })  : value = null,
        onChanged = null;

  @override
  Widget build(BuildContext context) {
    final selecionadas = values ?? {if (value != null) value as T};
    final optionSelecionada =
        options.where((item) => selecionadas.contains(item.value));
    final vazio = selecionadas.isEmpty;
    final texto = values != null
        ? (vazio
            ? hint
            : optionSelecionada.map((item) => item.label).join(', '))
        : optionSelecionada.isNotEmpty
            ? optionSelecionada.first.label
            : value?.toString() ?? hint;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _abrirDialogo(context),
      child: InputDecorator(
        isEmpty: vazio,
        decoration: InputDecoration(
          labelText: showLabel ? label : null,
          // O campo apresenta sempre um texto próprio (placeholder ou valor).
          // Manter a legenda flutuante evita que ambos ocupem a mesma linha.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline, width: 0.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: Icon(suffixIcon),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                vazio ? Theme.of(context).colorScheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }

  Future<void> _abrirDialogo(BuildContext context) async {
    final resultado = await showDialog<_SearchableSelectionResult<T>>(
      context: context,
      builder: (context) => _SearchableSelectionDialog<T>(
        title: dialogTitle,
        searchHint: searchHint,
        options: options,
        selectedValues: values ?? {if (value != null) value as T},
        multiple: values != null,
      ),
    );

    if (resultado == null) return;
    if (values != null) {
      onSelectionChanged!(resultado.values);
    } else {
      onChanged!(resultado.values.firstOrNull);
    }
  }
}

class _SearchableSelectionResult<T> {
  final Set<T> values;

  const _SearchableSelectionResult(this.values);
}

class _SearchableSelectionDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<SearchableSelectionOption<T>> options;
  final Set<T> selectedValues;
  final bool multiple;

  const _SearchableSelectionDialog({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedValues,
    required this.multiple,
  });

  @override
  State<_SearchableSelectionDialog<T>> createState() =>
      _SearchableSelectionDialogState<T>();
}

class _SearchableSelectionDialogState<T>
    extends State<_SearchableSelectionDialog<T>> {
  String _query = '';
  late final Set<T> _selectedValues = Set.of(widget.selectedValues);

  String _normalizar(String texto) {
    return texto
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  List<SearchableSelectionOption<T>> get _opcoesFiltradas {
    final unicas = <T, SearchableSelectionOption<T>>{};
    for (final option in widget.options) {
      unicas.putIfAbsent(option.value, () => option);
    }

    final queryNormalizada = _normalizar(_query);
    final resultado = unicas.values.where((option) {
      return _normalizar(option.label).contains(queryNormalizada);
    }).toList();

    resultado.sort((a, b) {
      final comparacao = _normalizar(a.label).compareTo(_normalizar(b.label));
      return comparacao != 0 ? comparacao : a.label.compareTo(b.label);
    });
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final opcoes = _opcoesFiltradas;
    final altura =
        (MediaQuery.sizeOf(context).height * 0.65).clamp(280.0, 520.0);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        height: altura,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            if (_selectedValues.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.clear, size: 20),
                title: const Text('Limpar seleção'),
                onTap: () {
                  if (widget.multiple) {
                    setState(_selectedValues.clear);
                  } else {
                    Navigator.of(context).pop(
                      _SearchableSelectionResult<T>({}),
                    );
                  }
                },
              ),
            if (widget.multiple)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_selectedValues.length == 1
                    ? '1 selecionado'
                    : '${_selectedValues.length} selecionados'),
              ),
            Expanded(
              child: opcoes.isEmpty
                  ? const Center(child: Text('Sem resultados'))
                  : ListView.builder(
                      itemCount: opcoes.length,
                      itemBuilder: (context, index) {
                        final option = opcoes[index];
                        final selecionada =
                            _selectedValues.contains(option.value);
                        if (widget.multiple) {
                          return CheckboxListTile(
                            dense: true,
                            title: Text(option.label),
                            value: selecionada,
                            onChanged: (selecionar) => setState(() {
                              if (selecionar == true) {
                                _selectedValues.add(option.value);
                              } else {
                                _selectedValues.remove(option.value);
                              }
                            }),
                          );
                        }
                        return ListTile(
                          dense: true,
                          title: Text(option.label),
                          trailing: selecionada
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () => Navigator.of(context).pop(
                            _SearchableSelectionResult<T>({option.value}),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (widget.multiple)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _SearchableSelectionResult<T>(Set.of(_selectedValues)),
            ),
            child: const Text('Aplicar'),
          ),
      ],
    );
  }
}
