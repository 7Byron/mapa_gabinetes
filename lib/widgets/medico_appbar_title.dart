import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../utils/cadastro_medicos_helper.dart';

/// Widget reutilizável para o título do AppBar na tela de cadastro de médicos
/// Inclui o título "Novo Médico" ou "Editar Médico", um autocomplete para selecionar médicos,
/// e o ano visualizado (se aplicável)
class MedicoAppBarTitle extends StatefulWidget {
  final Medico? medicoAtual;
  final int? anoVisualizado;
  final List<Medico> listaMedicos;
  final bool carregandoMedicos;
  final TextEditingController medicoAutocompleteController;
  final Function(Medico) onMedicoSelecionado;

  const MedicoAppBarTitle({
    super.key,
    required this.medicoAtual,
    this.anoVisualizado,
    required this.listaMedicos,
    required this.carregandoMedicos,
    required this.medicoAutocompleteController,
    required this.onMedicoSelecionado,
  });

  @override
  State<MedicoAppBarTitle> createState() => _MedicoAppBarTitleState();
}

class _MedicoAppBarTitleState extends State<MedicoAppBarTitle> {
  // Controllers e listeners para o Autocomplete
  final Map<TextEditingController, VoidCallback> _listeners = {};

  @override
  void dispose() {
    // Remover todos os listeners antes de descartar
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.medicoAtual == null ? 'Novo Médico' : 'Editar Médico',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: SizedBox(
            width: 260,
            child: widget.carregandoMedicos
                ? const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  )
                : widget.listaMedicos.isEmpty
                    ? SizedBox(
                        height: 40,
                        child: TextField(
                          enabled: false,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar médico...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 40,
                        child: Autocomplete<Medico>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final texto = CadastroMedicosHelper.normalizarString(textEditingValue.text.trim());
                            if (texto.isEmpty) {
                              return widget.listaMedicos;
                            }
                            return widget.listaMedicos
                                .where((medico) {
                                  final nomeNormalizado = CadastroMedicosHelper.normalizarString(medico.nome);
                                  return nomeNormalizado.contains(texto);
                                })
                                .toList()
                              ..sort((a, b) {
                                final nomeA = CadastroMedicosHelper.normalizarString(a.nome);
                                final nomeB = CadastroMedicosHelper.normalizarString(b.nome);
                                return nomeA.compareTo(nomeB);
                              });
                          },
                          displayStringForOption: (Medico medico) => medico.nome,
                          onSelected: widget.onMedicoSelecionado,
                          fieldViewBuilder: (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            // Sincronizar com o controller local
                            if (textEditingController.text !=
                                widget.medicoAutocompleteController.text) {
                              textEditingController.text =
                                  widget.medicoAutocompleteController.text;
                            }

                            // Criar um StatefulBuilder para atualizar o botão X
                            return StatefulBuilder(
                              builder: (context, setStateLocal) {
                                // CORREÇÃO: Remover listener anterior se existir
                                final listenerAnterior = _listeners[textEditingController];
                                if (listenerAnterior != null) {
                                  textEditingController.removeListener(listenerAnterior);
                                }

                                // Criar novo listener
                                void listener() {
                                  if (textEditingController.text !=
                                      widget.medicoAutocompleteController.text) {
                                    widget.medicoAutocompleteController.text =
                                        textEditingController.text;
                                  }
                                  if (mounted) {
                                    setStateLocal(() {});
                                  }
                                }

                                // Adicionar listener e guardar referência
                                textEditingController.addListener(listener);
                                _listeners[textEditingController] = listener;

                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Pesquisar médico...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    isDense: true,
                                    suffixIcon: textEditingController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              size: 18,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                            onPressed: () {
                                              textEditingController.clear();
                                              widget.medicoAutocompleteController.clear();
                                              setStateLocal(() {});
                                              focusNode.requestFocus();
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          )
                                        : null,
                                  ),
                                  onSubmitted: (String value) {
                                    onFieldSubmitted();
                                  },
                                );
                              },
                            );
                          },
                          optionsViewBuilder: (
                            BuildContext context,
                            AutocompleteOnSelected<Medico> onSelected,
                            Iterable<Medico> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 8.0,
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 300,
                                    maxWidth: 300,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Medico medico = options.elementAt(index);
                                      final bool isSelected = widget.medicoAtual != null &&
                                          medico.id == widget.medicoAtual!.id;
                                      return InkWell(
                                        onTap: () {
                                          onSelected(medico);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 12.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue.withValues(alpha: 0.2)
                                                : Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  medico.nome,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isSelected
                                                        ? Colors.blue[900]
                                                        : Colors.black87,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[900],
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ),
        if (widget.medicoAtual != null && widget.anoVisualizado != null) ...[
          const SizedBox(width: 12),
          Text(
            widget.anoVisualizado.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}
