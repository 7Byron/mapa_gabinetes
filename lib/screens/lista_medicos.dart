import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import 'cadastro_medicos.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListaMedicos extends StatefulWidget {
  final Unidade? unidade;
  const ListaMedicos({super.key, this.unidade});

  @override
  ListaMedicosState createState() => ListaMedicosState();
}

class ListaMedicosState extends State<ListaMedicos> {
  List<Medico> medicos = [];
  bool isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 30;

  // Pesquisa
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _fullyLoaded = false; // indica se já carregámos toda a coleção
  bool _loadingAll = false; // carregamento em progresso sem quebrar foco
  
  // Filtro de ativo/inativo
  bool _mostrarInativos = false; // Por padrão, mostra apenas ativos (false = ativos, true = inativos)

  @override
  void initState() {
    super.initState();
    _carregarMedicos(refresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore &&
          !isLoading) {
        _carregarMedicos();
      }
    });

    _searchController.addListener(() {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      if (hasQuery && !_fullyLoaded && !_loadingAll) {
        // Carregar tudo uma única vez para pesquisa local
        _carregarTodosMedicos();
      } else if (!hasQuery && _fullyLoaded && !_loadingAll) {
        // Quando limpa a pesquisa e já tinha carregado tudo, recarregar lista paginada
        _fullyLoaded = false;
        _carregarMedicos(refresh: true);
      } else {
        // Apenas refazer o build para aplicar o filtro
        setState(() {});
      }
    });
  }

  /// Função para buscar médicos (apenas dados básicos – sem disponibilidades)
  Future<void> _carregarMedicos({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        isLoading = true;
        _isLoadingMore = false;
        _hasMore = true;
        _lastDoc = null;
        medicos = [];
        _fullyLoaded = false; // reset ao estado de carregamento total
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }
    try {
      CollectionReference ocupantesRef;

      if (widget.unidade != null) {
        // Busca ocupantes da unidade específica
        ocupantesRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
      } else {
        // Busca todos os ocupantes (fallback para compatibilidade)
        ocupantesRef = FirebaseFirestore.instance.collection('medicos');
      }

      // Usa nomeSearch para ordenação correta (sem acentos)
      QuerySnapshot snapshot;
      try {
        Query query = ocupantesRef.orderBy('nomeSearch').limit(_pageSize);
        if (_lastDoc != null) {
          final lastNomeSearch =
              (_lastDoc!.data() as Map<String, dynamic>)['nomeSearch'] ??
                  _normalize(
                      (_lastDoc!.data() as Map<String, dynamic>)['nome'] ?? '');
          query = query.startAfter([lastNomeSearch]);
        }
        // Quando refresh é true, força buscar do servidor (sem cache) para garantir dados atualizados
        snapshot = await query.get(
          GetOptions(source: refresh ? Source.server : Source.serverAndCache),
        );
      } catch (e) {
        // Fallback: se nomeSearch não existir em alguns documentos, usa ordenação por nome
        // e depois ordena localmente
        Query query = ocupantesRef.orderBy('nome').limit(_pageSize);
        if (_lastDoc != null) {
          final lastNome =
              (_lastDoc!.data() as Map<String, dynamic>)['nome'] ?? '';
          query = query.startAfter([lastNome]);
        }
        snapshot = await query.get(
          GetOptions(source: refresh ? Source.server : Source.serverAndCache),
        );
      }
      debugPrint(
          '🔍 Buscando médicos na unidade: ${widget.unidade?.id ?? 'global'}');
      debugPrint('📊 Página carregada: ${snapshot.docs.length}');

      final medicosCarregados = <Medico>[];
      for (final doc in snapshot.docs) {
        final dados = doc.data() as Map<String, dynamic>;
        final ativo = dados['ativo'] ?? true;
        // Filtrar conforme o switch: false = apenas ativos, true = apenas inativos
        if ((!_mostrarInativos && ativo) || (_mostrarInativos && !ativo)) {
          medicosCarregados.add(Medico(
            id: dados['id'],
            nome: dados['nome'] ?? '',
            especialidade: dados['especialidade'] ?? '',
            observacoes: dados['observacoes'],
            disponibilidades: const [], // Não carregar aqui
            ativo: ativo,
          ));
        }
      }
      // Ordenar localmente para garantir ordenação correta (sem acentos)
      medicosCarregados.sort((a, b) {
        final nomeA = _normalize(a.nome);
        final nomeB = _normalize(b.nome);
        return nomeA.compareTo(nomeB);
      });
      setState(() {
        if (refresh) {
          medicos = medicosCarregados;
        } else {
          medicos.addAll(medicosCarregados);
          // Reordenar toda a lista após adicionar novos itens
          medicos.sort((a, b) {
            final nomeA = _normalize(a.nome);
            final nomeB = _normalize(b.nome);
            return nomeA.compareTo(nomeB);
          });
        }
        if (snapshot.docs.isNotEmpty) {
          _lastDoc = snapshot.docs.last;
        }
        // Se após filtrar não há médicos carregados, mas ainda há documentos no snapshot,
        // pode haver mais páginas. Mas se já filtramos e não encontramos nada, vamos parar
        // se não há mais documentos ou se encontramos menos que o tamanho da página
        _hasMore = snapshot.docs.length == _pageSize && medicosCarregados.isNotEmpty;
        isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _isLoadingMore = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erro ao carregar ${widget.unidade?.nomeOcupantes ?? 'Ocupantes'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Carrega todos os médicos (sem paginação) para pesquisa local
  Future<void> _carregarTodosMedicos() async {
    try {
      setState(() => _loadingAll = true);
      CollectionReference ocupantesRef;

      if (widget.unidade != null) {
        ocupantesRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
      } else {
        ocupantesRef = FirebaseFirestore.instance.collection('medicos');
      }

      final q = _searchController.text.trim().toLowerCase();
      // Pesquisa server-side por prefixo no nome ou por token na especialidade
      // Tenta nomeSearch (prefixo). Se vazio, usa apenas paginação normal.
      Query? query;
      if (q.isNotEmpty) {
        final end = '$q\uf8ff';
        query = ocupantesRef
            .orderBy('nomeSearch')
            .where('nomeSearch', isGreaterThanOrEqualTo: q)
            .where('nomeSearch', isLessThanOrEqualTo: end);
      }
      // Fallback: tokens
      var snapshot = await (query ?? ocupantesRef.orderBy('nomeSearch'))
          .get(const GetOptions(source: Source.serverAndCache));
      if (q.isNotEmpty && snapshot.docs.isEmpty) {
        // Coleção antiga sem nomeSearch: traz tudo e filtramos localmente
        snapshot = await ocupantesRef
            .orderBy('nomeSearch')
            .get(const GetOptions(source: Source.serverAndCache));
      }
      final todos = <Medico>[];
      for (final doc in snapshot.docs) {
        final dados = doc.data() as Map<String, dynamic>;
        final ativo = dados['ativo'] ?? true;
        // Filtrar conforme o switch: false = apenas ativos, true = apenas inativos
        if ((!_mostrarInativos && ativo) || (_mostrarInativos && !ativo)) {
          todos.add(Medico(
            id: dados['id'],
            nome: dados['nome'] ?? '',
            especialidade: dados['especialidade'] ?? '',
            observacoes: dados['observacoes'],
            disponibilidades: const [],
            ativo: ativo,
          ));
        }
      }
      // Ordenar localmente caso algum documento não tenha nomeSearch
      todos.sort((a, b) {
        final nomeA = _normalize(a.nome);
        final nomeB = _normalize(b.nome);
        return nomeA.compareTo(nomeB);
      });
      setState(() {
        medicos = todos; // substituir para garantir coleção completa
        _fullyLoaded = true;
        _hasMore = false; // desativa loader durante pesquisa
        _isLoadingMore = false;
        _loadingAll = false;
      });
      // Reafirma foco no campo de pesquisa após carregamento
      _searchFocusNode.requestFocus();
    } catch (e) {
      setState(() => _loadingAll = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erro ao carregar todos os ${widget.unidade?.nomeOcupantes ?? 'Ocupantes'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Função para deletar um médico
  /// Remove disponibilidades e alocações conforme a escolha do usuário
  Future<void> _deletarMedico(String id, {required bool apagarTodos}) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final dataAtual = DateTime.now();
      final dataAtualNormalizada =
          DateTime(dataAtual.year, dataAtual.month, dataAtual.day);

      CollectionReference ocupantesRef;
      CollectionReference disponibilidadesRef;
      CollectionReference excecoesRef;

      if (widget.unidade != null) {
        // Deleta ocupante da unidade específica
        ocupantesRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
        disponibilidadesRef =
            ocupantesRef.doc(id).collection('disponibilidades');
        excecoesRef = ocupantesRef.doc(id).collection('excecoes');
      } else {
        // Deleta da coleção antiga (fallback)
        ocupantesRef = firestore.collection('medicos');
        disponibilidadesRef =
            ocupantesRef.doc(id).collection('disponibilidades');
        excecoesRef = ocupantesRef.doc(id).collection('excecoes');
      }

      // 1. Apaga disponibilidades do médico
      final anosSnapshot = await disponibilidadesRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        // Buscar todos os registos e filtrar localmente para evitar necessidade de índice
        final todosRegistos = await registosRef.get();

        for (final doc in todosRegistos.docs) {
          final data = doc.data();
          final dataRegisto = data['data'] as String?;

          if (dataRegisto != null) {
            final dataRegistoDate = DateTime.parse(dataRegisto);
            final dataRegistoNormalizada = DateTime(
              dataRegistoDate.year,
              dataRegistoDate.month,
              dataRegistoDate.day,
            );

            // Se apagarTodos, remove tudo. Senão, remove apenas a partir de hoje (>= hoje)
            // Usa comparação direta para garantir que datas iguais também são removidas
            final deveRemover = apagarTodos ||
                (dataRegistoNormalizada
                        .isAtSameMomentAs(dataAtualNormalizada) ||
                    dataRegistoNormalizada.isAfter(dataAtualNormalizada));
            if (deveRemover) {
              await doc.reference.delete();
            }
          }
        }

        // Verificar se ainda há registos no ano
        final registosRestantes = await registosRef.get();
        if (registosRestantes.docs.isEmpty) {
          // Remove o documento do ano se estiver vazio
          await anoDoc.reference.delete();
        }
      }

      // 2. Apaga exceções do médico
      final excecoesAnosSnapshot = await excecoesRef.get();
      for (final anoDoc in excecoesAnosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final todosRegistos = await registosRef.get();
        for (final doc in todosRegistos.docs) {
          final data = doc.data();
          final dataExcecao = data['data'] as String?;

          if (dataExcecao != null) {
            final dataExcecaoDate = DateTime.parse(dataExcecao);
            final dataExcecaoNormalizada = DateTime(
              dataExcecaoDate.year,
              dataExcecaoDate.month,
              dataExcecaoDate.day,
            );

            // Se apagarTodos, remove tudo. Senão, remove apenas a partir de hoje (>= hoje)
            final deveRemover = apagarTodos ||
                (dataExcecaoNormalizada.isAtSameMomentAs(dataAtualNormalizada) ||
                    dataExcecaoNormalizada.isAfter(dataAtualNormalizada));
            if (deveRemover) {
              await doc.reference.delete();
            }
          } else {
            // Se não tem data, remover apenas se apagarTodos
            if (apagarTodos) {
              await doc.reference.delete();
            }
          }
        }

        // Verificar se ainda há registos no ano
        final registosRestantes = await registosRef.get();
        if (registosRestantes.docs.isEmpty) {
          // Remove o documento do ano se estiver vazio
          await anoDoc.reference.delete();
        }
      }

      // 3. Apaga alocações do médico
      if (widget.unidade != null) {
        final unidadeId = widget.unidade!.id;
        // Buscar alocações do ano atual e próximo ano
        final anosParaVerificar = [dataAtual.year, dataAtual.year + 1];

        for (final ano in anosParaVerificar) {
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('alocacoes')
              .doc(ano.toString())
              .collection('registos');

          // Buscar todas as alocações do médico e filtrar localmente
          // Isso evita a necessidade de índice composto
          final todasAlocacoes =
              await alocacoesRef.where('medicoId', isEqualTo: id).get();

          for (final doc in todasAlocacoes.docs) {
            final data = doc.data();
            final dataAlocacao = data['data'] as String?;

            if (dataAlocacao != null) {
              final dataAlocacaoDate = DateTime.parse(dataAlocacao);
              final dataAlocacaoNormalizada = DateTime(
                dataAlocacaoDate.year,
                dataAlocacaoDate.month,
                dataAlocacaoDate.day,
              );

              // Se apagarTodos, remove tudo. Senão, remove apenas a partir de hoje (>= hoje)
              // Usa comparação direta para garantir que datas iguais também são removidas
              final deveRemover = apagarTodos ||
                  (dataAlocacaoNormalizada
                          .isAtSameMomentAs(dataAtualNormalizada) ||
                      dataAlocacaoNormalizada.isAfter(dataAtualNormalizada));
              if (deveRemover) {
                await doc.reference.delete();
              }
            }
          }
        }
      }

      // 4. Se apagarTodos, deleta o documento do médico completamente
      // Senão, apenas marca como inativo para preservar histórico
      if (apagarTodos) {
        // Deleta o documento do médico completamente
        await ocupantesRef.doc(id).delete();
      } else {
        // Marca o médico como inativo em vez de apagá-lo
        // Isso preserva o histórico e evita cartões "Desconhecido"
        await ocupantesRef.doc(id).update({'ativo': false});
      }

      // Remove imediatamente da lista local para feedback visual instantâneo
      // (a lista só mostra médicos ativos)
      if (mounted) {
        setState(() {
          medicos.removeWhere((m) => m.id == id);
        });
      }

      // Invalida o cache de todos os dias futuros para garantir que os cartões desapareçam
      // Isso é importante para que quando o usuário voltar ao menu principal,
      // os cartões futuros não apareçam mais (nem alocados, nem na lista de não alocados)
      if (!apagarTodos) {
        // Se é "a partir de hoje", invalida o cache de todos os dias futuros
        // AlocacaoMedicosLogic.invalidateCacheFromDate(dataAtualNormalizada);
      } else {
        // Se é "todos os dados", limpa todo o cache
        // AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(2000, 1, 1));
      }

      // Recarrega a lista completa para garantir sincronização
      // Aguarda um pequeno delay para garantir que o Firebase processou a atualização
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await _carregarMedicos(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erro ao deletar ${widget.unidade?.nomeOcupantes ?? 'Ocupante'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Se houver erro, recarrega a lista para garantir estado correto
        await _carregarMedicos(refresh: true);
      }
    }
  }

  /// Confirmação de exclusão de médico
  void _confirmarDelecao(BuildContext context, String id) async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text(
            'Tem certeza que deseja excluir este ${widget.unidade?.nomeOcupantes ?? 'Ocupante'}?\n\n'
            'Escolha o que deseja remover:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('apartir_hoje'),
              child: const Text('A partir de hoje',
                  style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('todos'),
              child: const Text('Todos os dados',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (escolha != null) {
      _deletarMedico(id, apagarTodos: escolha == 'todos');
    }
  }

  /// Navega para o cadastro de médicos e recarrega a lista ao voltar
  Future<void> _adicionarOuEditarMedico({Medico? medico}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CadastroMedico(medico: medico, unidade: widget.unidade),
      ),
    );
    // Ao voltar, respeitar o filtro atual
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (hasQuery) {
      await _carregarTodosMedicos();
    } else {
      await _carregarMedicos(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
          title: 'Lista de ${widget.unidade?.nomeOcupantes ?? 'Ocupantes'}'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Pesquisar por nome ou especialidade',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          suffixIcon: _loadingAll
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : (_searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          _searchController.clear(),
                                    )
                                  : null),
                        ),
                          ),
                          const SizedBox(height: 8),
                          // Switch para filtrar ativos/inativos
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _mostrarInativos ? Icons.cancel : Icons.check_circle,
                                      color: _mostrarInativos ? Colors.red : Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _mostrarInativos ? 'Mostrar apenas inativos' : 'Mostrar apenas ativos',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _mostrarInativos,
                                  onChanged: (valor) {
                                    setState(() {
                                      _mostrarInativos = valor;
                                    });
                                    // Recarregar lista quando o switch muda
                                    final hasQuery = _searchController.text.trim().isNotEmpty;
                                    if (hasQuery) {
                                      _carregarTodosMedicos();
                                    } else {
                                      _carregarMedicos(refresh: true);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filtered().isEmpty && !isLoading && !_isLoadingMore
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _mostrarInativos ? Icons.cancel : Icons.search_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _mostrarInativos
                                          ? 'Sem médicos inativos'
                                          : 'Nenhum médico encontrado',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            _filtered().length + (_showTailLoader() ? 1 : 0),
                        itemBuilder: (context, index) {
                          final list = _filtered();
                          if (index >= list.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final medico = list[index];
                          return GestureDetector(
                            onTap: () =>
                                _adicionarOuEditarMedico(medico: medico),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  medico.ativo ? Icons.check_circle : Icons.cancel,
                                  color: medico.ativo ? Colors.green : Colors.grey,
                                  size: 24,
                                ),
                                title: Text(
                                  medico.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: medico.ativo ? null : Colors.grey,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((medico.especialidade).isNotEmpty)
                                      Text(medico.especialidade),
                                    if (!medico.ativo)
                                      const Text(
                                        'Inativo',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: 'Eliminar',
                                      onPressed: () =>
                                          _confirmarDelecao(context, medico.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarOuEditarMedico(),
        tooltip: 'Adicionar ',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Medico> _filtered() {
    final q = _normalize(_searchController.text.trim());
    if (q.isEmpty) return medicos;
    return medicos.where((m) {
      final nome = _normalize(m.nome);
      final esp = _normalize(m.especialidade);
      return nome.contains(q) || esp.contains(q);
    }).toList();
  }

  bool _showTailLoader() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return !hasQuery && _hasMore;
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[áàâã]"), 'a')
      .replaceAll(RegExp(r"[éê]"), 'e')
      .replaceAll(RegExp(r"[í]"), 'i')
      .replaceAll(RegExp(r"[óôõ]"), 'o')
      .replaceAll(RegExp(r"[ú]"), 'u')
      .replaceAll(RegExp(r"[ç]"), 'c');
}

