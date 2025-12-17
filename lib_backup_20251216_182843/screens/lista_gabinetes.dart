import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import 'cadastro_gabinete.dart';

class ListaGabinetes extends StatefulWidget {
  final Unidade? unidade;
  const ListaGabinetes({super.key, this.unidade});

  @override
  ListaGabinetesState createState() => ListaGabinetesState();
}

class ListaGabinetesState extends State<ListaGabinetes> {
  List<Gabinete> gabinetes = [];
  Map<String, List<Gabinete>> gabinetesPorSetor = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarGabinetes();
    // Adiciona observer para detectar retorno à tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ModalRoute.of(context)?.addScopedWillPopCallback(() async {
        _carregarGabinetes();
        return true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sempre que a tela volta a ser exibida, recarrega a lista
    _carregarGabinetes();
  }

  Future<void> _carregarGabinetes() async {
    setState(() => isLoading = true);
    try {
      final gabinetesCarregados =
          await buscarGabinetes(unidade: widget.unidade);
      debugPrint('Gabinetes encontrados: ${gabinetesCarregados.length}');

      gabinetesCarregados.sort((a, b) => a.nome.compareTo(b.nome));
      debugPrint(
          'Gabinetes carregados com sucesso: ${gabinetesCarregados.length}');

      setState(() {
        gabinetes = gabinetesCarregados;
        gabinetesPorSetor = agruparPorSetor(gabinetes);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro geral ao carregar gabinetes: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar gabinetes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Extrai o número do nome do gabinete para ordenação
  /// Exemplos: "Gabinete 101" -> 101, "103" -> 103, "Sala A" -> null
  int? _extrairNumeroGabinete(String nome) {
    // Procura por sequências de dígitos no nome
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(nome);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '');
    }
    return null;
  }

  /// Ordena gabinetes por número (se disponível) ou alfabeticamente
  void _ordenarGabinetesPorNumero(List<Gabinete> gabinetes) {
    gabinetes.sort((a, b) {
      final numA = _extrairNumeroGabinete(a.nome);
      final numB = _extrairNumeroGabinete(b.nome);

      // Se ambos têm números, ordena numericamente
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }

      // Se apenas um tem número, ele vem primeiro
      if (numA != null) return -1;
      if (numB != null) return 1;

      // Se nenhum tem número, ordena alfabeticamente
      return a.nome.compareTo(b.nome);
    });
  }

  // Função para agrupar e ordenar os gabinetes por setor
  Map<String, List<Gabinete>> agruparPorSetor(List<Gabinete> gabinetes) {
    Map<String, List<Gabinete>> gabinetesPorSetor = {};
    for (var gabinete in gabinetes) {
      if (!gabinetesPorSetor.containsKey(gabinete.setor)) {
        gabinetesPorSetor[gabinete.setor] = [];
      }
      gabinetesPorSetor[gabinete.setor]!.add(gabinete);
    }

    // Ordenar os gabinetes em cada setor por número
    gabinetesPorSetor.forEach((setor, lista) {
      _ordenarGabinetesPorNumero(lista);
    });

    return gabinetesPorSetor;
  }

  Future<void> _adicionarOuEditarGabinete({Gabinete? gabineteExistente}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroGabinete(
          gabinete: gabineteExistente,
          unidade: widget.unidade,
        ),
      ),
    );

    // Sempre recarrega após voltar da tela de cadastro
    _carregarGabinetes();
  }

  Future<void> _deletarGabinete(String id) async {
    try {
      await deletarGabinete(id, unidade: widget.unidade);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gabinete eliminado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      _carregarGabinetes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao eliminar gabinete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarDelecao(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir este gabinete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletarGabinete(id);
              },
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
          title: 'Lista de ${widget.unidade?.nomeAlocacao ?? 'Gabinetes'}'),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : gabinetes.isEmpty
              ? Center(child: Text('Nenhum gabinete encontrado'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView.builder(
                      itemCount: gabinetesPorSetor.length,
                      itemBuilder: (context, index) {
                        String setor = gabinetesPorSetor.keys.elementAt(index);
                        List<Gabinete> gabinetesDoSetor =
                            gabinetesPorSetor[setor]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                setor,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            for (var gabinete in gabinetesDoSetor)
                              Card(
                                margin: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                child: ListTile(
                                  title: RichText(
                                    text: TextSpan(
                                      text: 'Gabinete ${gabinete.nome} - ',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: gabinete
                                                  .especialidadesPermitidas
                                                  .isNotEmpty
                                              ? gabinete
                                                  .especialidadesPermitidas
                                                  .first
                                              : 'Sem Especialidades',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit,
                                            color: MyAppTheme.azulEscuro),
                                        tooltip: 'Editar',
                                        onPressed: () {
                                          _adicionarOuEditarGabinete(
                                              gabineteExistente: gabinete);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        tooltip: 'Eliminar',
                                        onPressed: () => _confirmarDelecao(
                                            context, gabinete.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarOuEditarGabinete(),
        tooltip: 'Adicionar Gabinete',
        child: Icon(Icons.add),
      ),
    );
  }
}
