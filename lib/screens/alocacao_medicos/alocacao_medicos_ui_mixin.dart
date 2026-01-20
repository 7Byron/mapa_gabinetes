part of '../alocacao_medicos_screen.dart';

mixin AlocacaoMedicosUiMixin on AlocacaoMedicosStateBase {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar já vem estilizado pelo theme
      appBar: CustomAppBar(
        title:
            'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        currentZoom: zoomLevel,
        onRefresh: _refreshDados,
      ),
      drawer: CustomDrawer(
        onRefresh: _refreshDados, // Função melhorada de refresh
        unidade: widget.unidade, // Passa a unidade para personalizar o drawer
        isAdmin: widget.isAdmin, // Passa informação se é administrador
      ),
      // Corpo com gradiente elegante e layout responsivo
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Container principal com gradiente profissional
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MyAppTheme.backgroundGradientStart,
                      MyAppTheme.backgroundGradientEnd,
                    ],
                  ),
                ),
                child: _deveUsarLayoutResponsivo(context)
                    ? _buildLayoutResponsivo()
                    : _buildLayoutDesktop(),
              ),
              // Mostrar progress bar durante carregamento inicial OU refresh
              if (isCarregando || _isRefreshing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mensagem de status
                          Text(
                            _isRefreshing
                                ? 'A atualizar dados...'
                                : mensagemProgresso,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Barra de progresso horizontal
                          Container(
                            width: 300,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Barra de progresso
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progressoCarregamento,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    minHeight: 10,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Percentagem
                                Text(
                                  '${(progressoCarregamento * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Overlay de progresso durante desalocação de série
              if (_isDesalocandoSerie)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mensagem de status
                          Text(
                            _mensagemDesalocacao,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Barra de progresso horizontal
                          Container(
                            width: 300,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Barra de progresso
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _progressoDesalocacao,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    minHeight: 10,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Percentagem
                                Text(
                                  '${(_progressoDesalocacao * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget _buildLayoutResponsivo() {
    return Column(
      children: [
        // Botões de alternância entre colunas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: MyAppTheme.cardBackground,
            boxShadow: MyAppTheme.shadowCard,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botão "Ver Filtros"
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        mostrarColunaEsquerda = true;
                      });
                    },
                    icon: Icon(
                      Icons.settings,
                      size: 16,
                      color: mostrarColunaEsquerda
                          ? Colors.white
                          : Colors.blue.shade600,
                    ),
                    label: Text(
                      'Ver Filtros',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mostrarColunaEsquerda
                            ? Colors.white
                            : Colors.blue.shade600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mostrarColunaEsquerda
                          ? Colors.blue.shade600
                          : Colors.white,
                      foregroundColor: mostrarColunaEsquerda
                          ? Colors.white
                          : Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.blue.shade600,
                          width: 1,
                        ),
                      ),
                      elevation: mostrarColunaEsquerda ? 2 : 0,
                    ),
                  ),
                ),
              ),

              // Botão "Ver Mapa"
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        mostrarColunaEsquerda = false;
                      });
                    },
                    icon: Icon(
                      Icons.map,
                      size: 16,
                      color: !mostrarColunaEsquerda
                          ? Colors.white
                          : Colors.blue.shade600,
                    ),
                    label: Text(
                      'Ver Mapa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: !mostrarColunaEsquerda
                            ? Colors.white
                            : Colors.blue.shade600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !mostrarColunaEsquerda
                          ? Colors.blue.shade600
                          : Colors.white,
                      foregroundColor: !mostrarColunaEsquerda
                          ? Colors.white
                          : Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Colors.blue.shade600,
                          width: 1,
                        ),
                      ),
                      elevation: !mostrarColunaEsquerda ? 2 : 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Conteúdo da coluna selecionada
        Expanded(
          child: mostrarColunaEsquerda
              ? _buildColunaEsquerda()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Calcula o tamanho do container interno baseado no zoom
                    final containerWidth = constraints.maxWidth / zoomLevel;
                    final containerHeight = constraints.maxHeight / zoomLevel;

                    return OverflowBox(
                      minWidth: containerWidth,
                      maxWidth: containerWidth,
                      minHeight: containerHeight,
                      maxHeight: containerHeight,
                      alignment: Alignment.topLeft,
                      child: Transform.scale(
                        scale: zoomLevel,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: containerWidth,
                          height: containerHeight,
                          child: _buildColunaDireita(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


  @override
  Widget _buildLayoutDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda: DatePicker + Filtros (SEM zoom - sempre visível)
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SingleChildScrollView(
            child: _buildColunaEsquerda(),
          ),
        ),

        // Coluna Direita: Médicos Disponíveis e Gabinetes (COM zoom)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calcula o tamanho do container interno baseado no zoom
              final containerWidth = constraints.maxWidth / zoomLevel;
              final containerHeight = constraints.maxHeight / zoomLevel;

              return OverflowBox(
                minWidth: containerWidth,
                maxWidth: containerWidth,
                minHeight: containerHeight,
                maxHeight: containerHeight,
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: zoomLevel,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: containerWidth,
                    height: containerHeight,
                    child: _buildColunaDireita(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  @override
  Widget _buildColunaEsquerda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          // 1. Seletor de Data
          CalendarioDisponibilidades(
              diasSelecionados: [selectedDate],
              onAdicionarData: (date, tipo) {
                // Não usado no modo apenas seleção
              },
              onRemoverData: (date, removeSerie) {
                // Não usado no modo apenas seleção
              },
              dataCalendario: selectedDate,
              modoApenasSelecao: true,
              onDateSelected: (date) {
                // Quando uma data é selecionada, atualizar a data selecionada
                _onDateChanged(date);
              },
              onViewChanged: (visibleDate) {
                // Atualizar a data visualizada no calendário (para uso no diálogo de médicos não alocados)
                setState(() {
                  _dataCalendarioVisualizada = visibleDate;
                });
              },
            ),

          // 2. Pesquisa
          PesquisaSection(
            pesquisaNome: pesquisaNome,
            pesquisaEspecialidade: pesquisaEspecialidade,
            opcoesNome: _getOpcoesPesquisaNome(),
            opcoesEspecialidade: _getOpcoesPesquisaEspecialidade(),
            onPesquisaNomeChanged: _aplicarPesquisaNome,
            onPesquisaEspecialidadeChanged: _aplicarPesquisaEspecialidade,
            onLimparPesquisa: _limparPesquisa,
          ),

          // 3. Filtros
          Container(
            decoration: BoxDecoration(
              color: MyAppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: MyAppTheme.shadowCard3D,
            ),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.none,
            child: FiltrosSection(
                todosSetores: gabinetes.map((g) => g.setor).toSet().toList(),
                pisosSelecionados: pisosSelecionados,
                onTogglePiso: (setor, isSelected) {
                  setState(() {
                    if (isSelected) {
                      pisosSelecionados.add(setor);
                    } else {
                      pisosSelecionados.remove(setor);
                    }
                  });
                },
                filtroOcupacao: filtroOcupacao,
                onFiltroOcupacaoChanged: (novo) {
                  setState(() => filtroOcupacao = novo);
                },
                mostrarConflitos: mostrarConflitos,
                onMostrarConflitosChanged: (val) {
                  setState(() => mostrarConflitos = val);
                },
                filtroEspecialidadeGabinete: filtroEspecialidadeGabinete,
                onFiltroEspecialidadeGabineteChanged: (especialidade) {
                  setState(() => filtroEspecialidadeGabinete = especialidade);
                },
                especialidadesGabinetes: _getEspecialidadesGabinetes(),
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget _buildColunaDireita() {
    if (clinicaFechada) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Clínica Encerrada!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensagemClinicaFechada,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildEmptyStateOrContent();
  }
}
