import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
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

            // Campo Especialidade com lógica ajustada
            TypeAheadField<String>(
              suggestionsCallback: (pattern) async {
                // Se ainda está carregando, retorna lista vazia
                if (isLoadingEspecialidades) {
                  return <String>[];
                }

                // Filtra as especialidades disponíveis com base no texto digitado
                return especialidadesDisponiveis
                    .where((especialidade) => especialidade
                        .toLowerCase()
                        .contains(pattern.toLowerCase()))
                    .toList();
              },
              itemBuilder: (context, suggestion) {
                // Renderiza cada sugestão como um ListTile
                return ListTile(
                  title: Text(suggestion),
                );
              },
              onSelected: (suggestion) {
                // Atualiza ambos os controllers quando uma sugestão é selecionada
                localController.text = suggestion;
                widget.especialidadeController.text = suggestion;
                // Força a atualização do estado para refletir a mudança
                setState(() {});
              },
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: localController,
                  focusNode: focusNode,
                  onChanged: (value) {
                    // Propaga alterações para o especialidadeController
                    widget.especialidadeController.text = value;
                  },
                  decoration: InputDecoration(
                    labelText: 'Especialidade',
                    border: const OutlineInputBorder(),
                    labelStyle: const TextStyle(
                        color: MyAppTheme.roxo), // Cor do rótulo
                    floatingLabelStyle:
                        const TextStyle(color: MyAppTheme.roxo), // Cor ao focar
                    focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: MyAppTheme.roxo, width: 2), // Roxo
                    ),
                    suffixIcon: isLoadingEspecialidades
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    hintText: isLoadingEspecialidades
                        ? 'Carregando especialidades...'
                        : 'Digite ou selecione uma especialidade',
                  ),
                );
              },
              decorationBuilder: (context, child) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemSeparatorBuilder: (context, index) =>
                  const Divider(height: 1),
              debounceDuration:
                  const Duration(milliseconds: 300), // Evita chamadas rápidas
              hideOnEmpty:
                  true, // Esconde as sugestões quando o texto está vazio
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
