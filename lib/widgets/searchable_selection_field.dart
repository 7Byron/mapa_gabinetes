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
  final List<SearchableSelectionOption<T>> options;
  final String label;
  final String hint;
  final String dialogTitle;
  final String searchHint;
  final IconData suffixIcon;
  final ValueChanged<T?> onChanged;

  const SearchableSelectionField({
    super.key,
    required this.value,
    required this.options,
    required this.label,
    required this.hint,
    required this.dialogTitle,
    required this.searchHint,
    required this.suffixIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final optionSelecionada = options.where((item) => item.value == value);
    final texto = optionSelecionada.isNotEmpty
        ? optionSelecionada.first.label
        : value?.toString() ?? hint;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _abrirDialogo(context),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          // O campo apresenta sempre um texto próprio (placeholder ou valor).
          // Manter a legenda flutuante evita que ambos ocupem a mesma linha.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 0.8),
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
            color: value == null ? Colors.grey.shade700 : null,
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
        selectedValue: value,
      ),
    );

    if (resultado != null) onChanged(resultado.value);
  }
}

class _SearchableSelectionResult<T> {
  final T? value;

  const _SearchableSelectionResult(this.value);
}

class _SearchableSelectionDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<SearchableSelectionOption<T>> options;
  final T? selectedValue;

  const _SearchableSelectionDialog({
    required this.title,
    required this.searchHint,
    required this.options,
    required this.selectedValue,
  });

  @override
  State<_SearchableSelectionDialog<T>> createState() =>
      _SearchableSelectionDialogState<T>();
}

class _SearchableSelectionDialogState<T>
    extends State<_SearchableSelectionDialog<T>> {
  String _query = '';

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
            if (widget.selectedValue != null && _query.isEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.clear, size: 20),
                title: const Text('Limpar seleção'),
                onTap: () => Navigator.of(context).pop(
                  _SearchableSelectionResult<T>(null),
                ),
              ),
            Expanded(
              child: opcoes.isEmpty
                  ? const Center(child: Text('Sem resultados'))
                  : ListView.builder(
                      itemCount: opcoes.length,
                      itemBuilder: (context, index) {
                        final option = opcoes[index];
                        final selecionada =
                            option.value == widget.selectedValue;
                        return ListTile(
                          dense: true,
                          title: Text(option.label),
                          trailing: selecionada
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () => Navigator.of(context).pop(
                            _SearchableSelectionResult<T>(option.value),
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
      ],
    );
  }
}
