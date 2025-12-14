import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../main.dart';
import '../services/medico_salvar_service.dart';
import '../models/unidade.dart';

class FormularioMedico extends StatefulWidget {
  final TextEditingController nomeController;
  final TextEditingController especialidadeController;
  final TextEditingController observacoesController;
  final Unidade?
      unidade; // Adiciona unidade para buscar especialidades específicas

  const FormularioMedico({
    super.key,
    required this.nomeController,
    required this.especialidadeController,
    required this.observacoesController,
    this.unidade,
  });

  @override
  FormularioMedicoState createState() => FormularioMedicoState();
}

class FormularioMedicoState extends State<FormularioMedico> {
  final List<String> especialidadesDisponiveis = [];
  bool isLoadingEspecialidades = true;
  late TextEditingController localController;

  @override
  void initState() {
    super.initState();
    localController =
        TextEditingController(text: widget.especialidadeController.text);
    carregarEspecialidades();
  }

  @override
  void didUpdateWidget(FormularioMedico oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza quando o widget é atualizado
    if (localController.text != widget.especialidadeController.text) {
      localController.text = widget.especialidadeController.text;
    }
  }

  Future<void> carregarEspecialidades() async {
    setState(() {
      isLoadingEspecialidades = true;
    });

    try {
      final especialidades = await buscarEspecialidadesExistentes(
        unidade: widget.unidade,
      );

      setState(() {
        especialidadesDisponiveis.clear();
        especialidadesDisponiveis.addAll(especialidades);
        isLoadingEspecialidades = false;
      });
    } catch (e) {
      print('❌ Erro ao carregar especialidades: $e');
      setState(() {
        isLoadingEspecialidades = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome do Médico
            TextFormField(
              controller: widget.nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Médico',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: MyAppTheme.roxo), // Cor do rótulo
                floatingLabelStyle:
                    TextStyle(color: MyAppTheme.roxo), // Cor ao focar
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campo Especialidade com Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (isLoadingEspecialidades) {
                  return const Iterable<String>.empty();
                }

                final texto = textEditingValue.text.toLowerCase().trim();
                if (texto.isEmpty) {
                  return especialidadesDisponiveis;
                }
                
                final filtradas = especialidadesDisponiveis
                    .where((especialidade) =>
                        especialidade.toLowerCase().contains(texto))
                    .toList();
                filtradas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                return filtradas;
              },
              onSelected: (String selection) {
                // Quando uma opção é selecionada, atualiza ambos os controllers
                localController.text = selection;
                widget.especialidadeController.text = selection;
              },
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                // Sincroniza o controller local com o controller do Autocomplete
                if (textEditingController.text != localController.text) {
                  textEditingController.text = localController.text;
                }
                
                // Atualiza o controller local quando o usuário digita
                textEditingController.addListener(() {
                  if (textEditingController.text != localController.text) {
                    localController.text = textEditingController.text;
                    widget.especialidadeController.text = textEditingController.text;
                  }
                });
                
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                  decoration: InputDecoration(
                    labelText: 'Especialidade',
                    border: const OutlineInputBorder(),
                    labelStyle: const TextStyle(color: MyAppTheme.roxo),
                    floatingLabelStyle: const TextStyle(color: MyAppTheme.roxo),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: MyAppTheme.roxo, width: 2),
                    ),
                    hintText: isLoadingEspecialidades
                        ? 'Carregando especialidades...'
                        : 'Digite ou selecione uma especialidade',
                  ),
                );
              },
              optionsViewBuilder: (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          final bool isSelected = localController.text.toLowerCase().trim() == 
                              option.toLowerCase();
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? MyAppTheme.roxo.withOpacity(0.1)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected 
                                            ? MyAppTheme.roxo
                                            : Colors.black87,
                                        fontWeight: isSelected 
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: MyAppTheme.roxo,
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

            const SizedBox(height: 16),

            // Observações
            TextFormField(
              controller: widget.observacoesController,
              maxLines: 3, // Permitir múltiplas linhas para observações
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: MyAppTheme.roxo), // Cor do rótulo
                floatingLabelStyle:
                    TextStyle(color: Colors.black), // Cor ao focar
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    localController.dispose();
    super.dispose();
  }
}
