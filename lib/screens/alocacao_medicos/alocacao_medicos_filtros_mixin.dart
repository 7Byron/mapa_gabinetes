part of '../alocacao_medicos_screen.dart';

mixin AlocacaoMedicosFiltrosMixin on AlocacaoMedicosStateBase {
  @override
  void _inicializarFiltrosPiso() {
    // Inicializar todos os filtros de piso como selecionados por padrão
    if (gabinetes.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
      pisosSelecionados = List<String>.from(todosSetores);
    }
  }

  @override
  List<Medico> _getMedicosAlocadosNoDia() {
    final medicosAlocados = <Medico>[];
    for (final alocacao in alocacoes) {
      final alocDate =
          DateTime(alocacao.data.year, alocacao.data.month, alocacao.data.day);
      final selectedDateNormalized =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      if (alocDate == selectedDateNormalized) {
        final medico = medicos.firstWhere(
          (m) => m.id == alocacao.medicoId,
          orElse: () => Medico(
              id: '',
              nome: '',
              especialidade: '',
              disponibilidades: [],
              ativo: false),
        );
        // FILTRAR: Não mostrar médicos inativos ou médicos não encontrados
        if (medico.id.isNotEmpty &&
            medico.ativo &&
            !medicosAlocados.any((m) => m.id == medico.id)) {
          medicosAlocados.add(medico);
        }
      }
    }
    return medicosAlocados;
  }

  @override
  List<String> _getOpcoesPesquisaNome() {
    final medicosAlocados = _getMedicosAlocadosNoDia();
    final nomes = medicosAlocados.map((m) => m.nome).toList();
    nomes.sort(); // Ordem alfabética
    return nomes;
  }

  @override
  List<String> _getOpcoesPesquisaEspecialidade() {
    final medicosAlocados = _getMedicosAlocadosNoDia();
    final especialidades =
        medicosAlocados.map((m) => m.especialidade).toSet().toList();
    especialidades.sort(); // Ordem alfabética
    return especialidades;
  }

  @override
  void _aplicarPesquisaNome(String? valor) {
    setState(() {
      pesquisaNome = valor;
      // Se selecionou um nome, limpar pesquisa por especialidade
      if (valor != null && valor.isNotEmpty) {
        pesquisaEspecialidade = null;
      }
      _atualizarMedicosDestacados();
    });
  }

  @override
  void _aplicarPesquisaEspecialidade(String? valor) {
    setState(() {
      pesquisaEspecialidade = valor;
      // Se selecionou uma especialidade, limpar pesquisa por nome
      if (valor != null && valor.isNotEmpty) {
        pesquisaNome = null;
      }
      _atualizarMedicosDestacados();
    });
  }

  @override
  void _atualizarMedicosDestacados() {
    medicosDestacados.clear();
    final medicosAlocados = _getMedicosAlocadosNoDia();

    // Pesquisa por nome (prioridade)
    if (pesquisaNome != null && pesquisaNome!.isNotEmpty) {
      final medicoEncontrado = medicosAlocados.firstWhere(
        (m) => m.nome == pesquisaNome,
        orElse: () =>
            Medico(id: '', nome: '', especialidade: '', disponibilidades: []),
      );
      if (medicoEncontrado.id.isNotEmpty) {
        medicosDestacados.add(medicoEncontrado.id);
      }
    }
    // Pesquisa por especialidade (apenas se não houver pesquisa por nome)
    else if (pesquisaEspecialidade != null &&
        pesquisaEspecialidade!.isNotEmpty) {
      for (final medico in medicosAlocados) {
        if (medico.especialidade == pesquisaEspecialidade) {
          medicosDestacados.add(medico.id);
        }
      }
    }
  }

  @override
  List<String> _getEspecialidadesGabinetes() {
    final especialidades = <String>{};
    for (final gabinete in gabinetes) {
      especialidades.addAll(gabinete.especialidadesPermitidas);
    }
    final lista = especialidades.toList();
    lista.sort(); // Ordem alfabética
    return lista;
  }

  @override
  void _limparPesquisa() {
    setState(() {
      pesquisaNome = null;
      pesquisaEspecialidade = null;
      medicosDestacados.clear();
    });
  }
}
