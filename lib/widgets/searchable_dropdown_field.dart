import 'package:flutter/material.dart';

/// Campo de seleção com pesquisa no cabeçalho e opções ordenadas.
class SearchableDropdownField<T> extends StatelessWidget {
  final T? value;
  final String labelText;
  final String hintText;
  final String searchHintText;
  final IconData icon;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.hintText,
    required this.searchHintText,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  static String _searchable(String text) {
    const accented = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';
    var result = text.toLowerCase().trim();
    for (var index = 0; index < accented.length; index++) {
      result = result.replaceAll(accented[index], plain[index]);
    }
    return result;
  }

  List<T> get _sortedItems {
    final result = [...items];
    result.sort(
      (first, second) => _searchable(itemLabel(first))
          .compareTo(_searchable(itemLabel(second))),
    );
    return result;
  }

  Future<void> _showOptions(BuildContext context) async {
    final selected = await showDialog<Object?>(
      context: context,
      builder: (context) => _SearchableOptionsDialog<T>(
        value: value,
        title: labelText,
        hintText: hintText,
        searchHintText: searchHintText,
        items: _sortedItems,
        itemLabel: itemLabel,
      ),
    );

    // O diálogo devolve um wrapper para distinguir "limpar" de fechar/cancelar.
    if (selected case _SelectionResult<T> result) {
      onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: labelText,
      child: InkWell(
        key: key,
        onTap: () => _showOptions(context),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: labelText,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 0.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: Icon(icon),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? hintText : itemLabel(value as T),
                  overflow: TextOverflow.ellipsis,
                  style: value == null
                      ? TextStyle(color: Theme.of(context).hintColor)
                      : null,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionResult<T> {
  final T? value;

  const _SelectionResult(this.value);
}

class _SearchableOptionsDialog<T> extends StatefulWidget {
  final T? value;
  final String title;
  final String hintText;
  final String searchHintText;
  final List<T> items;
  final String Function(T item) itemLabel;

  const _SearchableOptionsDialog({
    required this.value,
    required this.title,
    required this.hintText,
    required this.searchHintText,
    required this.items,
    required this.itemLabel,
  });

  @override
  State<_SearchableOptionsDialog<T>> createState() =>
      _SearchableOptionsDialogState<T>();
}

class _SearchableOptionsDialogState<T>
    extends State<_SearchableOptionsDialog<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  List<T> get _filteredItems {
    final query = SearchableDropdownField._searchable(_query);
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) => SearchableDropdownField._searchable(
              widget.itemLabel(item),
            ).contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.searchHintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 420,
        child: filteredItems.isEmpty
            ? const Center(child: Text('Nenhum resultado encontrado.'))
            : ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return ListTile(
                    title: Text(widget.itemLabel(item)),
                    selected: item == widget.value,
                    trailing:
                        item == widget.value ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(
                      context,
                      _SelectionResult<T>(item),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
