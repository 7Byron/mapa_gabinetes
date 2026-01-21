import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
// import 'dart:convert'; // Comentado - usado apenas na instrumentação de debug
import '../utils/ui_alocar_cartoes_unicos.dart';
import '../utils/ui_desalocar_cartao_unico.dart';
// import '../utils/debug_log_file.dart'; // Comentado - usado apenas na instrumentação de debug

// Se criou o custom_drawer.dart

// Widgets locais
import '../widgets/conflitos_ano_dialog.dart';
import '../widgets/medicos_nao_alocados_dialog.dart';
import '../widgets/coluna_esquerda_alocacao.dart';
import '../widgets/clinica_fechada_aviso.dart';
import '../widgets/empty_state_unidade.dart';
import '../widgets/estatisticas_alocacao_card.dart';
import '../widgets/medicos_disponiveis_container.dart';
import '../widgets/gabinetes_container.dart';
import '../widgets/layout_responsivo_alocacao.dart';
import '../widgets/layout_desktop_alocacao.dart';
import '../widgets/alocacao_body.dart';
import '../widgets/alocacao_scaffold.dart';

// Lógica separada
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../utils/ui_atualizar_dia.dart';
import '../utils/progresso_dialog_controller.dart';

// Models
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';

// Services
import '../services/password_service.dart';
import '../services/alocacao_clinica_preparacao_service.dart';
import '../services/alocacao_clinica_config_service.dart';
import '../services/alocacao_conflitos_ano_carregamento_service.dart';
import '../services/alocacao_desalocacao_dia_service.dart';
import '../services/alocacao_desalocacao_decisao_service.dart';
import '../services/alocacao_desalocacao_serie_orchestrator.dart';
import '../services/alocacao_medico_alocacao_service.dart';
import '../services/alocacao_medicos_disponiveis_service.dart';
import '../services/alocacao_dados_essenciais_service.dart';
import '../services/alocacao_realocacao_otimista_service.dart';
import '../services/alocacao_serie_otimista_service.dart';
import '../services/alocacao_medicos_nao_alocados_ano_service.dart';
import '../services/alocacao_series_regeneracao_service.dart';
import '../services/alocacao_gabinetes_reload_service.dart';
import '../services/alocacao_refresh_service.dart';
import '../services/alocacao_progressao_service.dart';
import '../services/alocacao_pos_carregamento_service.dart';
import '../services/alocacao_finalizacao_ui_service.dart';
import '../services/alocacao_estatisticas_service.dart';
import '../utils/alocacao_date_change_handler.dart';
import '../utils/alocacao_medicos_search_utils.dart';
import '../utils/alocacao_cache_store.dart';
import 'cadastro_medicos.dart';

// #region agent log (COMENTADO - pode ser reativado se necessário)
// helper
//void _writeDebugLog(String location, String message, Map<String, dynamic> data, {String hypothesisId = 'A'}) {
//  try {
//    final logEntry = {
//      'timestamp': DateTime.now().millisecondsSinceEpoch,
//      'location': location,
//      'message': message,
//      'data': data,
//      'sessionId': 'debug-session',
//      'runId': 'run1',
//      'hypothesisId': hypothesisId,
//    };
//    writeLogToFile(jsonEncode(logEntry));
//  } catch (e) {
// Ignorar erros de escrita de log
//  }
//}

// #endregion

/// Tela principal de alocação de médicos aos gabinetes
/// Permite arrastar médicos disponíveis para gabinetes específicos
/// Inclui verificação de dias de encerramento e exibe mensagem quando clínica está fechada
/// Interface responsiva com largura máxima de 600px para melhor usabilidade

class AlocacaoMedicos extends StatefulWidget {
  final Unidade unidade;
  final bool isAdmin; // Novo parâmetro para indicar se é administrador
  final DateTime? dataInicial; // Data inicial para exibir no mapa

  const AlocacaoMedicos({
    super.key,
    required this.unidade,
    this.isAdmin = false, // Por defeito é utilizador normal
    this.dataInicial, // Se fornecido, será usado como data inicial
  });

  @override
  State<AlocacaoMedicos> createState() => AlocacaoMedicosState();
}

class AlocacaoMedicosState extends State<AlocacaoMedicos>
    with WidgetsBindingObserver {
  bool isCarregando = true;
  double progressoCarregamento = 0.0; // Progresso de 0.0 a 1.0
  double _progressoAlvo = 0.0; // Progresso alvo para animação suave
  String mensagemProgresso =
      'A iniciar...'; // Mensagem de status do carregamento
  bool _isDesalocandoSerie =
      false; // Flag para controlar progress bar durante desalocação
  double _progressoDesalocacao = 0.0;
  String _mensagemDesalocacao = 'A iniciar...';
  Timer? _debounceTimer;
  Timer? _timerProgresso; // Timer para atualizar progresso gradualmente
  Timer? _timerProgressoSimulado;
  DateTime?
      _ultimaAtualizacaoMedicos; // Última vez que médicos disponíveis foram atualizados
  Timer?
      _timeoutFlagsTransicao; // Timer para limpar flags presas automaticamente
  late DateTime selectedDate;
  late DateTime
      _dataCalendarioVisualizada; // Data visualizada no calendário (pode ser diferente de selectedDate)

  // Controle de layout responsivo
  bool mostrarColunaEsquerda = true; // Para ecrãs pequenos

  // Controle de zoom usando InteractiveViewer
  final TransformationController _transformationController =
      TransformationController();
  double zoomLevel = 1.0; // Zoom inicial de 100%
  static const double minZoom = 0.5; // Zoom mínimo de 50%
  static const double maxZoom = 2.0; // Zoom máximo de 200%
  static const double zoomStep = 0.1; // Incremento de zoom

  // Dados principais
  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Medico> medicosDisponiveis = [];

  // Dados da clínica
  List<Map<String, String>> feriados = [];
  List<Map<String, dynamic>> diasEncerramento =
      []; // Dias específicos de encerramento
  Map<int, List<String>> horariosClinica = {};
  bool clinicaFechada = false;
  String mensagemClinicaFechada = '';

  // Configurações de encerramento
  bool nuncaEncerra = false;
  Map<int, bool> encerraDias = {
    1: false, // Segunda-feira
    2: false, // Terça-feira
    3: false, // Quarta-feira
    4: false, // Quinta-feira
    5: false, // Sexta-feira
    6: false, // Sábado
    7: false, // Domingo
  };
  bool encerraFeriados = false;

  // Filtros
  List<String> pisosSelecionados = [];
  String filtroOcupacao = 'Todos'; // 'Livres', 'Ocupados', 'Todos'
  bool mostrarConflitos = false;
  String? filtroEspecialidadeGabinete; // Filtro por especialidade do gabinete

  // Pesquisa
  String? pesquisaNome;
  String? pesquisaEspecialidade;
  Set<String> medicosDestacados =
      {}; // IDs dos médicos destacados pela pesquisa

  // (removido) alternância manual não utilizada

  // Método para verificar se deve usar layout responsivo
  bool _deveUsarLayoutResponsivo(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  void initState() {
    super.initState();
    // Inicializar datas: usar dataInicial se fornecida, senão usar data atual
    selectedDate = widget.dataInicial ?? DateTime.now();
    _dataCalendarioVisualizada = selectedDate;

    WidgetsBinding.instance.addObserver(this);
    // CORREÇÃO: Marcar app como em foco ao inicializar
    logic.AlocacaoMedicosLogic.setAppEmFoco(true);
    _carregarDadosIniciais();
    // Carregar passwords em background (não bloqueia a UI)
    _carregarPasswordsDoFirebase();
    // Inicializar transformação após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executarSeMontado(_updateTransformation);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Apenas atualizar flag de foco para estratégia de cache, mas SEM recarregar dados automaticamente
    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao foco - apenas atualizar flag, SEM recarregar dados
        logic.AlocacaoMedicosLogic.setAppEmFoco(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App perdeu foco - marcar como não em foco para forçar busca do servidor na próxima interação
        logic.AlocacaoMedicosLogic.setAppEmFoco(false);
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        logic.AlocacaoMedicosLogic.setAppEmFoco(false);
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dados só serão carregados quando o usuário interagir explicitamente
  }

  Future<void> _carregarPasswordsDoFirebase() async {
    try {
      // Carrega as passwords do Firebase para cache local
      await PasswordService.loadPasswordsFromFirebase(widget.unidade.id);
    } catch (e) {}
  }

  bool _isCarregandoDadosIniciais =
      false; // Lock para evitar múltiplas chamadas simultâneas
  bool _isRefreshing = false; // Estado de refresh para mostrar progress bar
  final AlocacaoProgressaoController _progressaoDadosController =
      AlocacaoProgressaoController();

  /// Atualiza o progresso de forma gradual e suave até o valor alvo
  void _atualizarProgressoGradual(double alvo, String mensagem) {
    // Cancelar timer anterior se existir
    _timerProgresso?.cancel();

    _progressoAlvo = alvo;
    _setStateSeMontado(() {
      mensagemProgresso = mensagem;
    });

    // Se o alvo é menor ou igual ao progresso atual, atualizar imediatamente
    if (alvo <= progressoCarregamento) {
      _setStateSeMontado(() {
        progressoCarregamento = alvo;
      });
      return;
    }

    // Calcular incremento baseado na diferença
    // Atualizar a cada 100ms para uma progressão suave e uniforme
    const duracaoAtualizacao = Duration(milliseconds: 100);
    final diferenca = alvo - progressoCarregamento;

    // Para progressões maiores (como de 0.2 para 0.8), usar incrementos menores
    // para uma progressão mais uniforme. Para progressões menores, usar incrementos maiores.
    final incrementoPorAtualizacao = diferenca > 0.3
        ? 0.01 // Incrementos de 1% para progressões grandes (mais uniforme)
        : 0.02; // Incrementos de 2% para progressões pequenas (mais rápido)

    final numAtualizacoes = (diferenca / incrementoPorAtualizacao).ceil();
    final incremento = diferenca / numAtualizacoes;

    _timerProgresso = Timer.periodic(duracaoAtualizacao, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _setStateSeMontado(() {
        progressoCarregamento += incremento;
        if (progressoCarregamento >= _progressoAlvo) {
          progressoCarregamento = _progressoAlvo;
          timer.cancel();
        }
      });
    });
  }

  /// Função de refresh: invalida todo o cache e recarrega os dados
  Future<void> _refreshDados() async {
    // Evitar múltiplos refreshes simultâneos
    if (_isRefreshing) {
      _logDebug('⚠️ Refresh já em andamento, ignorando chamada duplicada');
      return;
    }

    // Iniciar progress bar
    _setStateSeMontado(() {
      _isRefreshing = true;
      progressoCarregamento = 0.0;
    });

    try {
      await AlocacaoRefreshService.executar(
        selectedDate: selectedDate,
        recarregarDados: () => _carregarDadosIniciais(recarregarMedicos: true),
        onProgresso: (valor) {
          _setStateSeMontado(() {
            progressoCarregamento = valor;
          });
        },
      );
    } catch (e) {
      _logDebug('❌ Erro ao fazer refresh: $e');
    } finally {
      _setStateSeMontado(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _carregarDadosIniciais({bool recarregarMedicos = false}) async {
    // CORREÇÃO: Permitir carregamento mesmo se já estiver carregando se for refresh forçado
    // Mas ainda prevenir múltiplas chamadas simultâneas desnecessárias
    if (_isCarregandoDadosIniciais && !recarregarMedicos) {
      _logDebug(
          '⚠️ [LOCK] Ignorando chamada duplicada a _carregarDadosIniciais (já em execução)');
      return;
    }

    _isCarregandoDadosIniciais = true;

    // CORREÇÃO: Limpar dados antes de carregar para evitar dados vazios
    if (recarregarMedicos) {
      // Limpar apenas se for refresh forçado
      _limparDadosAlocacoes();
    }
    bool dadosCarregando =
        false; // Flag para controlar quando dados estão sendo carregados

    try {
      // Inicializar progresso
      _atualizarProgressoGradual(0.0, 'A verificar configurações...');

      // FASE 0: Carregar dados de encerramento PRIMEIRO (feriados, dias de encerramento, horários)
      // Isso permite verificar se a clínica está encerrada ANTES de carregar dados do Firestore
      final clinicaEncerrada = await _prepararClinicaParaCarregamento(
        forcarServidor: recarregarMedicos,
      );
      if (clinicaEncerrada) {
        return; // Sair sem carregar mais nada - NÃO chamar carregarDadosIniciais
      }

      // FASE 1/2: Carregar exceções e dados essenciais
      dadosCarregando = true;
      final dadosIniciais = await AlocacaoDadosEssenciaisService.carregar(
        unidade: widget.unidade,
        selectedDate: selectedDate,
        recarregarMedicos: recarregarMedicos,
        gabinetesAtuais: gabinetes,
        medicosAtuais: medicos,
        disponibilidadesAtuais: disponibilidades,
        alocacoesAtuais: alocacoes,
        atualizarProgresso: _atualizarProgressoGradual,
        iniciarProgressao: () {
          _progressaoDadosController.iniciar(
            deveCancelar: () =>
                !mounted || !dadosCarregando || progressoCarregamento >= 0.80,
            onCancel: () {
              dadosCarregando = false;
            },
            onTick: () {
              if (!dadosCarregando) return;
              _setStateSeMontado(() {
                progressoCarregamento =
                    (progressoCarregamento + 0.015).clamp(0.0, 0.80);
              });
            },
          );
        },
        pararProgressao: () {
          dadosCarregando = false;
          _progressaoDadosController.parar();
        },
        log: (mensagem) => _logDebug(mensagem),
      );
      gabinetes = dadosIniciais.gabinetes;
      medicos = dadosIniciais.medicos;
      disponibilidades = dadosIniciais.disponibilidades;
      alocacoes = dadosIniciais.alocacoes;

      // CORREÇÃO CRÍTICA: Marcar dados como completos e cancelar timer IMEDIATAMENTE
      dadosCarregando = false;

      // Atualizar progresso para refletir que os dados foram carregados
      // Garantir que o progresso esteja pelo menos em 0.80 antes de continuar
      await _garantirProgressoMinimo(0.80, 'A processar dados...');
      // Chamar fora do setState porque é assíncrono e atualiza o estado internamente
      // IMPORTANTE: Sempre chamar, mesmo quando dados vêm do cache, para verificar exceções
      // CORREÇÃO: Forçar recarregamento de alocações após carregar dados iniciais

      final posCarregamento = await AlocacaoPosCarregamentoService.processar(
        data: selectedDate,
        alocacoesAtuais: alocacoes,
        regenerarSeries: _regenerarAlocacoesSeries,
        atualizarProgresso: (alvo, mensagem) async {
          _atualizarProgressoGradual(alvo, mensagem);
        },
        atualizarMedicosDisponiveis: _atualizarMedicosDisponiveis,
        feriados: feriados,
        diasEncerramento: diasEncerramento,
        horariosClinica: horariosClinica,
        encerraFeriados: encerraFeriados,
        nuncaEncerra: nuncaEncerra,
        encerraDias: encerraDias,
      );

      // Atualizar lista de alocações
      _atualizarAlocacoes(posCarregamento.alocacoesAtualizadas);

      // CORREÇÃO: Cache é atualizado automaticamente em carregarDadosIniciais
      // Não precisamos atualizar manualmente aqui

      _setStateSeMontado(() {
        progressoCarregamento = 1.0;
        mensagemProgresso = 'Concluído!';
        clinicaFechada = posCarregamento.clinicaFechada;
        mensagemClinicaFechada = posCarregamento.mensagemClinicaFechada;
      });

      // CORREÇÃO: Atualizar UI apenas se não estiver processando alocação
      // Isso evita múltiplas atualizações durante drag and drop
      await AlocacaoFinalizacaoUiService.finalizar(
        mounted: mounted,
        setState: setState,
        cancelarTimerProgresso: () {
          _timerProgresso?.cancel();
        },
        inicializarFiltrosPiso: _inicializarFiltrosPiso,
        setIsCarregando: (valor) => isCarregando = valor,
        setProgresso: (valor) => progressoCarregamento = valor,
        setMensagem: (valor) => mensagemProgresso = valor,
      );

      // Log de métricas de cache em debug
      AlocacaoCacheStore.logResumo();
      AlocacaoClinicaConfigService.logResumo();
    } catch (e) {
      _logDebug('❌ Erro ao carregar dados iniciais: $e');

      _setStateSeMontado(() {
        isCarregando = false;
      });
      _atualizarProgressoGradual(0.0, 'A iniciar...');
    } finally {
      // CORREÇÃO CRÍTICA: Garantir que todos os timers sejam cancelados, mesmo em caso de erro
      dadosCarregando = false;
      _progressaoDadosController.parar();
      // NÃO cancelar _timerProgresso aqui - ele precisa continuar para completar a animação até 100%
      _isCarregandoDadosIniciais = false; // Liberar lock
    }
  }

  Future<bool> _prepararClinicaParaCarregamento({
    bool forcarServidor = false,
  }) async {
      final preparacao = await AlocacaoClinicaPreparacaoService.preparar(
        unidadeId: widget.unidade.id,
        dataReferencia: selectedDate,
      forcarServidor: forcarServidor,
      );
    _aplicarPreparacaoClinica(preparacao);

    if (!clinicaFechada) {
      return false;
    }

    _logDebug('🚫 Clínica encerrada: $mensagemClinicaFechada');
    _finalizarCarregamentoPorClinicaFechada();
    return true;
  }

  void _aplicarPreparacaoClinica(ClinicaPreparacaoResultado preparacao) {
    _setStateSeMontado(() {
      _atribuirPreparacaoClinica(preparacao);
    });
    if (!mounted) {
      _atribuirPreparacaoClinica(preparacao);
    }
  }

  void _atribuirPreparacaoClinica(ClinicaPreparacaoResultado preparacao) {
    feriados = preparacao.feriados;
    diasEncerramento = preparacao.diasEncerramento;
    horariosClinica = preparacao.horariosClinica;
    encerraFeriados = preparacao.encerraFeriados;
    nuncaEncerra = preparacao.nuncaEncerra;
    encerraDias = preparacao.encerraDias;
    clinicaFechada = preparacao.clinicaFechada;
    mensagemClinicaFechada = preparacao.mensagemClinicaFechada;
  }

  void _finalizarCarregamentoPorClinicaFechada() {
    if (!mounted) {
      _limparDadosAlocacoes();
      isCarregando = false;
      progressoCarregamento = 1.0;
      mensagemProgresso = 'Concluído!';
      return;
    }

    _setStateSeMontado(() {
      // Limpar dados existentes
      _limparDadosAlocacoes();
      // Desligar progress bar
      isCarregando = false;
      progressoCarregamento = 1.0;
      mensagemProgresso = 'Concluído!';
    });
  }

  Future<void> _garantirProgressoMinimo(
    double minimo,
    String mensagem,
  ) async {
    if (progressoCarregamento < minimo) {
      _atualizarProgressoGradual(minimo, mensagem);
      // Aguardar um pouco para a animação chegar ao mínimo desejado
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Regenera alocações de séries para o dia atual
  /// Isso garante que alocações de séries alocadas sejam sempre exibidas
  Future<List<Alocacao>> _regenerarAlocacoesSeries() async {
    try {
      final alocacoesGeradas =
          await AlocacaoSeriesRegeneracaoService.regenerarParaDia(
        data: selectedDate,
        unidade: widget.unidade,
        alocacoes: alocacoes,
      );
      if (alocacoesGeradas.length > 10) {
        _logDebug(
            '🔄 ${alocacoesGeradas.length} alocações de séries regeneradas');
      }
      return alocacoesGeradas;
    } catch (e) {
      _logDebug('❌ Erro ao regenerar alocações de séries: $e');
      return [];
    }
  }

  /// Recarrega apenas as alocações de um ou mais gabinetes específicos (reload focado)
  Future<void> _recarregarAlocacoesGabinetes(List<String> gabineteIds) async {
    try {
      final alocacoesAtualizadas =
          await AlocacaoGabinetesReloadService.recarregar(
        unidade: widget.unidade,
        data: selectedDate,
        alocacoesAtuais: alocacoes,
        gabineteIds: gabineteIds,
      );
      _atualizarAlocacoes(alocacoesAtualizadas);

      _logDebug(
          '✅ [RELOAD FOCADO] Total de alocações após reload: ${alocacoes.length}');

      _rebuild();
    } catch (e) {
      _logDebug('❌ Erro ao recarregar alocações dos gabinetes: $e');
    }
  }

  /// Recarrega apenas a lista de médicos desalocados (reload focado)
  Future<void> _recarregarDesalocados() async {
    try {
      await _atualizarMedicosDisponiveis();
      _rebuild();
      _logDebug('✅ [RELOAD FOCADO] Lista de desalocados atualizada');
    } catch (e) {
      _logDebug('❌ Erro ao recarregar desalocados: $e');
    }
  }

  Future<void> _atualizarMedicosDisponiveis() async {
    // CORREÇÃO: Prevenir atualizações muito frequentes
    if (_deveIgnorarAtualizacaoMedicos()) {
      return;
    }

    _marcarAtualizacaoMedicos();
    _logAtualizacaoMedicos();

    final novosDisponiveis = await AlocacaoMedicosDisponiveisService.calcular(
      medicos: medicos,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
      unidadeId: widget.unidade.id,
      data: selectedDate,
    );

    _aplicarMedicosDisponiveis(novosDisponiveis);
  }

  bool _deveIgnorarAtualizacaoMedicos() {
    if (_ultimaAtualizacaoMedicos == null) {
      return false;
    }

    final delta = DateTime.now().difference(_ultimaAtualizacaoMedicos!);
    if (delta < const Duration(milliseconds: 500)) {
      _logDebug(
          '⚠️ [ATUALIZAR-MÉDICOS] Ignorando (atualização muito recente)');
      return true;
    }

    return false;
  }

  void _marcarAtualizacaoMedicos() {
    _ultimaAtualizacaoMedicos = DateTime.now();
  }

  void _logAtualizacaoMedicos() {
    _logDebug(
        '🔍 _atualizarMedicosDisponiveis chamado para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
    _logDebug('  📊 Total de disponibilidades: ${disponibilidades.length}');
    // DEBUG: Mostrar algumas datas das disponibilidades para entender o problema
    if (disponibilidades.isNotEmpty) {
      _logDebug('  🔍 Primeiras 5 disponibilidades (datas):');
      for (var i = 0; i < disponibilidades.length && i < 5; i++) {
        final d = disponibilidades[i];
        _logDebug(
            '    ${i + 1}. ${d.medicoId}: ${d.data.day}/${d.data.month}/${d.data.year}');
      }
    }
    _logDebug('  📊 Total de médicos: ${medicos.length}');
  }

  void _aplicarMedicosDisponiveis(List<Medico> novosDisponiveis) {
    _setStateSeMontado(() {
      medicosDisponiveis = novosDisponiveis;
    });
  }

  void _executarSeMontado(VoidCallback acao) {
    if (!mounted) return;
    acao();
  }

  Future<T?> _executarSeMontadoAsync<T>(
    Future<T?> Function() acao, {
    T? retornoSeNaoMontado,
  }) async {
    if (!mounted) return retornoSeNaoMontado;
    return acao();
  }

  void _setStateSeMontado(VoidCallback atualizar) {
    if (!mounted) return;
    setState(atualizar);
  }

  void _rebuild() {
    _setStateSeMontado(() {});
  }

  void _logDebug(String mensagem) {
    if (!kDebugMode) return;
    debugPrint(mensagem);
  }

  void _limparDadosAlocacoes() {
    disponibilidades.clear();
    alocacoes.clear();
    medicosDisponiveis.clear();
  }

  void _atualizarAlocacoes(List<Alocacao> novas) {
    alocacoes
      ..clear()
      ..addAll(novas);
  }

  void _inicializarFiltrosPiso() {
    // Manter seleção existente e remover pisos inválidos
    if (gabinetes.isNotEmpty && pisosSelecionados.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet();
      pisosSelecionados = pisosSelecionados
          .where((setor) => todosSetores.contains(setor))
          .toList();
    }
  }

  // Obter médicos alocados no dia selecionado
  List<Medico> _getMedicosAlocadosNoDia() {
    return AlocacaoMedicosSearchUtils.medicosAlocadosNoDia(
      alocacoes: alocacoes,
      medicos: medicos,
      data: selectedDate,
    );
  }

  // Obter opções de pesquisa por nome
  List<String> _getOpcoesPesquisaNome() {
    return AlocacaoMedicosSearchUtils.opcoesPesquisaNome(
      _getMedicosAlocadosNoDia(),
    );
  }

  // Obter opções de pesquisa por especialidade
  List<String> _getOpcoesPesquisaEspecialidade() {
    return AlocacaoMedicosSearchUtils.opcoesPesquisaEspecialidade(
      _getMedicosAlocadosNoDia(),
    );
  }

  // Aplicar pesquisa por nome
  void _aplicarPesquisaNome(String? valor) {
    _atualizarPesquisa(
      nome: valor,
      especialidade:
          (valor != null && valor.isNotEmpty) ? null : pesquisaEspecialidade,
    );
  }

  // Aplicar pesquisa por especialidade
  void _aplicarPesquisaEspecialidade(String? valor) {
    _atualizarPesquisa(
      nome: (valor != null && valor.isNotEmpty) ? null : pesquisaNome,
      especialidade: valor,
    );
  }

  void _atualizarPesquisa({String? nome, String? especialidade}) {
    _setStateSeMontado(() {
      pesquisaNome = nome;
      pesquisaEspecialidade = especialidade;
      _atualizarMedicosDestacados();
    });
  }

  void _atualizarProgressoSeMontado(double progresso, String mensagem) {
    _executarSeMontado(() {
      final progressoClamped = progresso.clamp(0.0, 1.0);
      _setStateSeMontado(() {
        mensagemProgresso = mensagem;
        if (progressoClamped >= progressoCarregamento) {
          progressoCarregamento = progressoClamped;
        }
      });
    });
  }

  // Atualizar médicos destacados baseado na pesquisa ativa
  void _atualizarMedicosDestacados() {
    final medicosAlocados = _getMedicosAlocadosNoDia();
    medicosDestacados
      ..clear()
      ..addAll(AlocacaoMedicosSearchUtils.medicosDestacados(
        medicosAlocados: medicosAlocados,
        pesquisaNome: pesquisaNome,
        pesquisaEspecialidade: pesquisaEspecialidade,
      ));
  }

  // Obter especialidades únicas dos gabinetes
  List<String> _getEspecialidadesGabinetes() {
    return AlocacaoMedicosSearchUtils.especialidadesGabinetes(gabinetes);
  }

  // Limpar pesquisa
  void _limparPesquisa() {
    _atualizarPesquisa();
  }

  // Lock para prevenir múltiplas execuções simultâneas de _onDateChanged
  bool _isUpdatingDate = false;
  DateTime? _lastUpdateDate;

  void _onDateChanged(DateTime newDate) async {
    if (!mounted) return;

    // Verificar se é a mesma data (evitar atualizações desnecessárias)
    final dataNormalizada = _normalizarData(newDate);

    if (_deveIgnorarMudancaData(newDate, dataNormalizada)) {
      return;
    }

    _iniciarMudancaData(newDate, dataNormalizada);

    try {
      final resultado = await AlocacaoDateChangeHandler.processarMudancaData(
        unidade: widget.unidade,
        data: dataNormalizada,
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicosDisponiveis: medicosDisponiveis,
        atualizarDadosDoDia: atualizarDadosDoDia,
        onProgress: _atualizarProgressoSeMontado,
        onStateUpdate: _rebuild,
      );

      await _finalizarMudancaDataComSucesso(resultado);
    } catch (e) {
      _finalizarMudancaDataComErro(e);
    } finally {
      // Sempre liberar o lock, mesmo em caso de erro
      _isUpdatingDate = false;
    }
  }

  DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  bool _deveIgnorarMudancaData(DateTime data, DateTime dataNormalizada) {
    // CORREÇÃO CRÍTICA: Prevenir race conditions quando o sistema está lento
    if (_isUpdatingDate) {
      _logDebug(
          '⚠️ [RACE-CONDITION] Ignorando chamada duplicada de _onDateChanged para ${data.day}/${data.month}/${data.year}');
      return true;
    }

    if (_lastUpdateDate != null) {
      final lastDateNormalizada = DateTime(_lastUpdateDate!.year,
          _lastUpdateDate!.month, _lastUpdateDate!.day);
      if (lastDateNormalizada == dataNormalizada) {
        _logDebug(
            '⚠️ [RACE-CONDITION] Ignorando atualização duplicada para a mesma data: ${data.day}/${data.month}/${data.year}');
        // Limpar _lastUpdateDate para permitir nova tentativa após um delay
        _lastUpdateDate = null;
        return true;
      }
    }

    return false;
  }

  void _iniciarMudancaData(DateTime dataOriginal, DateTime dataNormalizada) {
    _isUpdatingDate = true;
    _lastUpdateDate = dataOriginal;

    _setStateSeMontado(() {
      selectedDate =
          dataNormalizada; // Usar data normalizada para garantir consistência
      _dataCalendarioVisualizada =
          dataNormalizada; // Atualizar também a data visualizada

      isCarregando = true;
      progressoCarregamento = 0.0;
      mensagemProgresso = 'A iniciar...';
      // Limpar dados do dia anterior antes de carregar novos dados
      _limparDadosAlocacoes();
    });

    _iniciarProgressoSimulado();
  }

  void _iniciarProgressoSimulado() {
    _timerProgressoSimulado?.cancel();
    _timerProgressoSimulado =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !isCarregando) {
        timer.cancel();
        return;
      }
      const limite = 0.90;
      if (progressoCarregamento >= limite) {
        timer.cancel();
        return;
      }
      _setStateSeMontado(() {
        progressoCarregamento =
            (progressoCarregamento + 0.01).clamp(0.0, limite);
      });
    });
  }

  void _pararProgressoSimulado() {
    _timerProgressoSimulado?.cancel();
  }

  Future<void> _finalizarMudancaDataComSucesso(
      DateChangeResult resultado) async {
    _pararProgressoSimulado();
    _setStateSeMontado(() {
      clinicaFechada = resultado.clinicaFechada;
      mensagemClinicaFechada = resultado.mensagemClinicaFechada;
      feriados = resultado.feriados;
      diasEncerramento = resultado.diasEncerramento;
      horariosClinica = resultado.horariosClinica;
      encerraFeriados = resultado.encerraFeriados;
      nuncaEncerra = resultado.nuncaEncerra;
      encerraDias = resultado.encerraDias;
    });

    _atualizarAlocacoes(resultado.alocacoesAtualizadas);

    // NOTA: Os médicos disponíveis já foram calculados em atualizarDadosDoDia,
    // mas precisamos atualizar novamente após regenerar as séries para garantir
    // que médicos com alocações de séries não apareçam como disponíveis
    Timer? timerFinal;
    timerFinal = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final alvo = 0.98;
      if (progressoCarregamento >= alvo) {
        timer.cancel();
        return;
      }
      _setStateSeMontado(() {
        progressoCarregamento =
            (progressoCarregamento + (alvo - progressoCarregamento) * 0.06)
                .clamp(0.0, alvo);
      });
    });

    final cacheDisponiveis =
        AlocacaoCacheStore.getMedicosDisponiveis(selectedDate);
    if (cacheDisponiveis != null) {
      _atualizarProgressoGradual(
          0.96, 'A usar cache de médicos disponíveis...');
      _setStateSeMontado(() {
        medicosDisponiveis = List<Medico>.from(cacheDisponiveis);
      });
    } else {
      _atualizarProgressoGradual(0.96, 'A processar médicos disponíveis...');
      await _atualizarMedicosDisponiveis();
      AlocacaoCacheStore.updateMedicosDisponiveis(
          selectedDate, medicosDisponiveis);
    }
    timerFinal.cancel();

    // Atualizar para 100% apenas no final, sem mensagens intermediárias
    _setStateSeMontado(() {
      progressoCarregamento = 1.0;
      mensagemProgresso = 'Concluído!';
    });
    // Pequeno delay para mostrar 100%
    await Future.delayed(const Duration(milliseconds: 300));

    // Atualizar UI após todas as operações - AGORA definir isCarregando = false
    _setStateSeMontado(() {
      isCarregando = false;
      progressoCarregamento = 0.0;
      mensagemProgresso = 'A iniciar...';
    });
  }

  void _finalizarMudancaDataComErro(Object erro) {
    _pararProgressoSimulado();
    _logDebug('❌ Erro ao atualizar dados do dia: $erro');
    _setStateSeMontado(() {
      isCarregando = false;
    });
    _mostrarSnackErro('Erro ao carregar dados: $erro');
  }

  Future<void> _alocarMedico(String medicoId, String gabineteId,
      {DateTime? dataEspecifica, List<String>? horarios}) async {
    final dataAlvo = dataEspecifica ?? selectedDate;

    try {
      await AlocacaoMedicoAlocacaoService.alocar(
        unidade: widget.unidade,
        dataAlvo: dataAlvo,
        medicoId: medicoId,
        gabineteId: gabineteId,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        atualizarUIAlocarCartaoUnico: atualizarUIAlocarCartaoUnico,
        onStateUpdate: _aplicarAtualizacaoAlocacao,
        horarios: horarios,
      );
    } catch (e) {
      await _tratarErroAlocacao(e);
    } finally {
      // Finalização concluída
      _logDebug('✅ [ALOCAÇÃO] FINALLY: Operação finalizada');
    }
  }

  void _aplicarAtualizacaoAlocacao() {
    _setStateSeMontado(() {
      alocacoes = List<Alocacao>.from(alocacoes);
      medicosDisponiveis = List<Medico>.from(medicosDisponiveis);
    });
  }

  Future<void> _tratarErroAlocacao(Object erro) async {
    _logDebug('❌ Erro ao alocar médico: $erro');
    await _recarregarDadosAposErro();
    _mostrarSnackErro('Erro ao alocar médico: $erro');
  }

  Future<void> _recarregarDadosAposErro() async {
    // Em caso de erro, recarregar dados para reverter estado
    _logDebug('🔄 Recarregando dados após erro');
    try {
      await _carregarDadosIniciais();
    } catch (e) {
      _logDebug('❌ Erro ao recarregar dados após erro: $e');
    }
  }

  void _mostrarSnackErro(String mensagem) {
    _executarSeMontado(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Future<ProgressoDialogController> _abrirProgressoDialog(
      String mensagem) async {
    if (!mounted) {
      return ProgressoDialogController(context: context, mensagem: mensagem);
    }
    final controller = ProgressoDialogController(
      context: context,
      mensagem: mensagem,
    );
    controller.abrir();
    // Aguardar um frame para garantir que o dialog foi construído
    await Future.delayed(const Duration(milliseconds: 50));
    return controller;
  }

  Future<void> _finalizarProgressoDialog(
    ProgressoDialogController controller, {
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    // Finalizar progresso: 95% -> 100%
    controller.atualizar(1.0);
    // Aguardar um pouco para mostrar 100% antes de fechar
    await Future.delayed(delay);
    controller.fechar();
  }

  Future<void> _mostrarDialogSeMontado(WidgetBuilder builder) async {
    await _executarSeMontadoAsync<void>(
      () => showDialog<void>(
        context: context,
        builder: builder,
      ),
    );
  }

  Future<T?> _mostrarDialogComResultado<T>(WidgetBuilder builder) async {
    return _executarSeMontadoAsync<T>(
      () => showDialog<T>(
        context: context,
        builder: builder,
      ),
    );
  }

  /// Limpa as flags de transição após realocação concluída
  /// Isso garante que o listener seja reativado e a UI volte ao normal
  // Variáveis temporárias para armazenar gabinetes afetados durante realocação
  String? _gabineteOrigemRealocacao;
  String? _gabineteDestinoRealocacao;

  void _limparFlagsTransicao() {
    _logDebug('🔴 [LIMPAR-FLAGS] Limpando flags de transição');

    _cancelarTimeoutFlagsTransicao();
    _finalizarRealocacaoSeCompleta();

    _logDebug('✅ [LIMPAR-FLAGS] Flags limpas');
  }

  void _cancelarTimeoutFlagsTransicao() {
    // Cancelar timeout se ainda estiver ativo
    _timeoutFlagsTransicao?.cancel();
    _timeoutFlagsTransicao = null;
  }

  void _finalizarRealocacaoSeCompleta() {
    // CORREÇÃO: Não recarregar após realocação
    // A atualização otimista já moveu a alocação no estado local, e _alocarMedico já atualizou o Firestore.
    // Não há necessidade de recarregar do Firestore, pois isso pode causar race conditions e reverter a mudança.
    if (_gabineteOrigemRealocacao != null &&
        _gabineteDestinoRealocacao != null) {
      _logDebug(
          '✅ [LIMPAR-FLAGS] Realocação completa - não recarregando (atualização otimista + Firestore já atualizados)');
      _gabineteOrigemRealocacao = null;
      _gabineteDestinoRealocacao = null;
    }
  }

  /// Atualização otimista durante realocação - atualiza estado local imediatamente
  /// para feedback visual instantâneo antes das operações no Firestore
  void _alocacaoSerieOtimista(
      String medicoId, String gabineteId, DateTime data) {
    AlocacaoSerieOtimistaService.aplicar(
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: data,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
    );

    // Atualizar UI imediatamente
    _rebuild();
  }

  Future<void> _realocacaoOtimista(String medicoId, String gabineteOrigem,
      String gabineteDestino, DateTime data) async {
    _logDebug(
        '🔵 [OTIMISTA] INÍCIO: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino');
    _logDebug('🔵 [OTIMISTA] Estado atual');

    // Armazenar gabinetes afetados para reload focado posterior
    _registrarRealocacao(gabineteOrigem, gabineteDestino);
    _invalidarCacheParaDataSelecionada();

    final resultado = AlocacaoRealocacaoOtimistaService.atualizar(
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicoId: medicoId,
      gabineteOrigem: gabineteOrigem,
      gabineteDestino: gabineteDestino,
      data: data,
    );
    if (resultado.ignorar) {
      return;
    }
    alocacoes = resultado.alocacoesAtualizadas;

    // CORREÇÃO CRÍTICA: Atualizar médicos disponíveis IMEDIATAMENTE
    _atualizarMedicosDisponiveisComLogErro();

    // CORREÇÃO CRÍTICA: Criar nova referência das listas para forçar detecção de mudança
    // Isso garante que widgets filhos (como DisponibilidadesGrid) detectem a mudança
    await _forcarAtualizacaoListas();

    _logDebug(
        '✅ Atualização otimista: médico $medicoId movido de $gabineteOrigem para $gabineteDestino (listener pausado)');
  }

  void _registrarRealocacao(String gabineteOrigem, String gabineteDestino) {
    _gabineteOrigemRealocacao = gabineteOrigem;
    _gabineteDestinoRealocacao = gabineteDestino;
  }

  void _invalidarCacheParaDataSelecionada() {
    // CORREÇÃO CRÍTICA: Invalidar cache ANTES de fazer realocação otimista
    final dataNormalizada = _normalizarData(selectedDate);
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    _logDebug('💾 Cache invalidado antes de realocação otimista');
  }

  void _atualizarMedicosDisponiveisComLogErro() {
    _atualizarMedicosDisponiveis().catchError((e) {
      _logDebug(
          '❌ Erro ao atualizar médicos disponíveis após atualização otimista: $e');
    });
  }

  Future<void> _forcarAtualizacaoListas() async {
    _setStateSeMontado(() {
      // Criar novas referências das listas para forçar detecção de mudança
      alocacoes = List<Alocacao>.from(alocacoes);
      disponibilidades = List<Disponibilidade>.from(disponibilidades);
      medicosDisponiveis = List<Medico>.from(medicosDisponiveis);
    });
    // Aguardar um frame para garantir que o setState foi processado
    await Future.delayed(Duration.zero);
  }

  /// Mostra lista de médicos não alocados no ano
  Future<void> _mostrarMedicosNaoAlocadosAno() async {
    ProgressoDialogController? progressoDialog;
    try {
      progressoDialog = await _abrirProgressoDialog('A carregar dados...');

      // Usar o ano visualizado no calendário (pode ser diferente de selectedDate se o usuário navegou sem clicar)
      final ano = _dataCalendarioVisualizada.year;

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2066', 'Início _mostrarMedicosNaoAlocadosAno', {
//        'ano': ano,
//        'totalMedicos': medicos.length,
//        'medicosAtivos': medicos.where((m) => m.ativo).length,
//        'medicosIds': medicos.map((m) => m.id).toList(),
//      }, hypothesisId: 'A');

// #endregion

      final resultadoAno =
          await AlocacaoMedicosNaoAlocadosAnoService.carregar(
        unidade: widget.unidade,
        ano: ano,
        medicos: medicos,
        onProgresso: (valor) => progressoDialog?.atualizar(valor),
      );

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2078', 'Disponibilidades de séries carregadas', {
//        'totalDisponibilidadesSeries': resultadoAno.disponibilidades.series.length,
//        'medicosComDisponibilidadeSeries': resultadoAno.disponibilidades.series.map((d) => d.medicoId).toSet().length,
//        'datasUnicas': resultadoAno.disponibilidades.series.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}').toSet().length,
//      }, hypothesisId: 'B');

// #endregion

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2086', 'Médicos ativos identificados', {
//        'totalMedicosAtivos': resultadoAno.disponibilidades.medicosAtivos.length,
//        'medicosAtivosIds': resultadoAno.disponibilidades.medicosAtivos.map((m) => m.id).toList(),
//        'medicosAtivosNomes': resultadoAno.disponibilidades.medicosAtivos.map((m) => m.nome).toList(),
//      }, hypothesisId: 'C');

// #endregion

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2103', 'Disponibilidades únicas carregadas', {
//        'totalDisponibilidadesUnicas': resultadoAno.disponibilidades.unicas.length,
//        'medicosComDisponibilidadeUnicas': resultadoAno.disponibilidades.unicas.map((d) => d.medicoId).toSet().length,
//      }, hypothesisId: 'E');

// #endregion

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2108', 'Todas disponibilidades combinadas', {
//        'totalDisponibilidades': resultadoAno.disponibilidades.todas.length,
//        'medicosComDisponibilidade': resultadoAno.disponibilidades.todas.map((d) => d.medicoId).toSet().length,
//        'datasUnicas': resultadoAno.disponibilidades.todas.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}').toSet().length,
//      }, hypothesisId: 'F');

// #endregion

      final resultadoNaoAlocados = resultadoAno.naoAlocados;

      final medicosComDias = resultadoNaoAlocados.medicosComDias;
      final medicosComDatas = resultadoNaoAlocados.medicosComDatas;
      final medicosComDiasNaoAlocados =
          resultadoNaoAlocados.medicosComDiasNaoAlocados;

      // #region agent log (COMENTADO - pode ser reativado se necessário)

//      _writeDebugLog('alocacao_medicos_screen.dart:2294', 'Resultado final', {
//        'totalMedicosComDiasNaoAlocados': medicosComDiasNaoAlocados.length,
//        'medicosComDiasNaoAlocados': medicosComDiasNaoAlocados.map((m) => {
//          'id': m.id,
//          'nome': m.nome,
//          'diasNaoAlocados': medicosComDias[m.id] ?? 0,
//        }).toList(),
//        'resumoDias': medicosComDias.entries.map((e) => {
//          'medicoId': e.key,
//          'dias': e.value,
//        }).toList(),
//      }, hypothesisId: 'M');

// #endregion

      await _finalizarProgressoDialog(progressoDialog);

      // Mostrar diálogo com a lista
      await _mostrarDialogSeMontado(
        (context) => MedicosNaoAlocadosDialog(
          ano: ano,
          medicos: medicosComDiasNaoAlocados,
          medicosComDias: medicosComDias,
          medicosComDatas: medicosComDatas,
          onAbrirCadastro: _abrirCadastroMedico,
          onSelecionarData: _onDateChanged,
        ),
      );
    } catch (e) {
      progressoDialog?.fechar(); // Fechar loading
      _mostrarSnackErro('Erro ao carregar dados: $e');
    }
  }

  /// Mostra lista de conflitos de gabinete no ano
  Future<void> _mostrarConflitosAno() async {
    ProgressoDialogController? progressoDialog;
    try {
      progressoDialog = await _abrirProgressoDialog('A carregar conflitos...');

      // Usar o ano visualizado no calendário (pode ser diferente de selectedDate se o usuário navegou sem clicar)
      final ano = _dataCalendarioVisualizada.year;

      final conflitos = await AlocacaoConflitosAnoCarregamentoService.carregar(
        unidade: widget.unidade,
        ano: ano,
        gabinetes: gabinetes,
        medicos: medicos,
        onProgresso: (valor) => progressoDialog?.atualizar(valor),
      );

      await _finalizarProgressoDialog(progressoDialog);

      // Mostrar diálogo com a lista
      await _mostrarDialogSeMontado(
        (context) => ConflitosAnoDialog(
          ano: ano,
          conflitos: conflitos,
          onSelecionarData: _onDateChanged,
        ),
      );
    } catch (e) {
      progressoDialog?.fechar(); // Fechar loading
      _mostrarSnackErro('Erro ao carregar dados: $e');
    }
  }

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    // Encontrar todas as alocações do médico no dia selecionado
    final dataAlvo = _normalizarData(selectedDate);
    final alocacoesDoDia = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    }).toList();

    if (alocacoesDoDia.isEmpty) {
      return; // Não há alocação para desalocar
    }

    final decisao = AlocacaoDesalocacaoDecisaoService.decidir(
      medicoId: medicoId,
      dataAlvo: selectedDate,
      disponibilidades: disponibilidades,
      alocacoes: alocacoes,
    );

    String? escolha;
    final tipoDisponibilidade = decisao.tipoDisponibilidade;

    if (decisao.desalocarDireto) {
      if (!mounted) return;

      final sucesso = await desalocarCartaoUnico(
        medicoId: medicoId,
        data: selectedDate,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        unidade: widget.unidade,
        setState: _rebuild,
        recarregarAlocacoesGabinetes: _recarregarAlocacoesGabinetes,
        recarregarDesalocados: _recarregarDesalocados,
      );

      if (sucesso) {
        _logDebug('✅ [DESALOCAÇÃO] Cartão único desalocado com sucesso');
      } else {
        _logDebug('❌ [DESALOCAÇÃO] Erro ao desalocar cartão único');
        _mostrarSnackErro('Erro ao desalocar médico');
      }

      return;
    }

    escolha = await _mostrarDialogComResultado<String>(
      (context) => AlertDialog(
        title: const Text('Confirmar Desalocação'),
        content: Text(decisao.mensagemDialogo ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '1dia'),
            child: const Text('Apenas este dia'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'serie'),
            child: const Text('Toda a série a partir deste dia'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (escolha == '1dia') {
      await _desalocarMedicoDiaUnico(medicoId);
    } else if (escolha == 'serie') {
      await _desalocarMedicoSerie(medicoId, tipoDisponibilidade);
    }
  }

  Future<void> _desalocarMedicoDiaUnico(String medicoId) async {
    try {
      final gabineteOrigem = await AlocacaoDesalocacaoDiaService.desalocar(
        unidade: widget.unidade,
        data: selectedDate,
        medicoId: medicoId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
      );

      // Aguardar um pouco para garantir que a desalocação foi processada
      await Future.delayed(const Duration(milliseconds: 300));

      // TESTE 3: Desalocar cartão - deve atualizar apenas gabinete de saída e caixa de desalocação
      if (gabineteOrigem.isNotEmpty) {
        // RELOAD FOCADO: Recarregar apenas o gabinete de saída (onde o cartão saiu) e desalocados (onde entrou)
        await _recarregarAlocacoesGabinetes([gabineteOrigem]);
        await _recarregarDesalocados();

        _logDebug(
            '✅ [DESALOCAÇÃO] Reload focado: gabinete $gabineteOrigem e desalocados atualizados');
      } else {
        await _recarregarDesalocados();
      }

      // Forçar atualização da UI
      _rebuild();
    } catch (e) {
      _mostrarSnackErro('Erro ao desalocar médico: $e');
    }
  }

  Future<void> _desalocarMedicoSerie(String medicoId, String tipo) async {
    await AlocacaoDesalocacaoSerieOrchestrator.executar(
      medicoId: medicoId,
      data: selectedDate,
      tipo: tipo,
      alocacoes: alocacoes,
      disponibilidades: disponibilidades,
      medicos: medicos,
      medicosDisponiveis: medicosDisponiveis,
      unidade: widget.unidade,
      recarregarAlocacoesGabinetes: _recarregarAlocacoesGabinetes,
      recarregarDesalocados: _recarregarDesalocados,
      onStateUpdate: _rebuild,
      onStart: _iniciarDesalocacaoSerie,
      onProgresso: _atualizarProgressoDesalocacao,
      onFinish: _finalizarDesalocacaoSerie,
      onErro: _mostrarErroDesalocacaoSerie,
      context: context,
    );
  }

  void _iniciarDesalocacaoSerie() {
    _setStateSeMontado(() {
      _isDesalocandoSerie = true;
      _progressoDesalocacao = 0.0;
      _mensagemDesalocacao = 'A iniciar desalocação...';
    });
  }

  void _atualizarProgressoDesalocacao(double progresso, String mensagem) {
    _setStateSeMontado(() {
      _progressoDesalocacao = progresso;
      _mensagemDesalocacao = mensagem;
    });
  }

  void _finalizarDesalocacaoSerie() {
    _setStateSeMontado(() {
      _isDesalocandoSerie = false;
      _progressoDesalocacao = 0.0;
      _mensagemDesalocacao = 'A iniciar...';
    });
  }

  void _mostrarErroDesalocacaoSerie(Object erro) {
    _mostrarSnackErro('Erro ao desalocar série: $erro');
  }

  bool _semDadosConfigurados() {
    return gabinetes.isEmpty && medicos.isEmpty;
  }

  List<Gabinete> _getGabinetesFiltrados() {
    return logic.AlocacaoMedicosLogic.filtrarGabinetesPorUI(
      gabinetes: gabinetes,
      alocacoes: alocacoes,
      selectedDate: selectedDate,
      pisosSelecionados: pisosSelecionados,
      filtroOcupacao: filtroOcupacao,
      mostrarConflitos: mostrarConflitos,
      filtroEspecialidadeGabinete: filtroEspecialidadeGabinete,
    );
  }

  Widget _buildEmptyStateOrContent() {
    // Se está carregando, não mostrar nada aqui (o overlay principal já mostra a barra de progresso)
    // Isso evita duplicação de barras de progresso
    if (isCarregando) {
      return const SizedBox
          .shrink(); // Widget vazio - o overlay principal mostra o progresso
    }

    if (_semDadosConfigurados()) {
      return EmptyStateUnidade(unidade: widget.unidade);
    }

    // Se há dados, mostrar o conteúdo normal
    final gabinetesFiltrados = _getGabinetesFiltrados();

    return Column(
      children: [
        const SizedBox(height: 12),

        // Widget de Estatísticas
        EstatisticasAlocacaoCard(
          data: AlocacaoEstatisticasService.calcular(
            selectedDate: selectedDate,
            alocacoes: alocacoes,
            gabinetes: gabinetes,
            numMedicosPorAlocar: medicosDisponiveis.length,
          ),
        ),

        // Seção de médicos disponíveis - apenas para administradores
        if (widget.isAdmin)
          MedicosDisponiveisContainer(
            medicosDisponiveis: medicosDisponiveis,
            disponibilidades: disponibilidades,
            alocacoes: alocacoes,
            selectedDate: selectedDate,
            onDesalocarMedicoComPergunta: _desalocarMedicoComPergunta,
            onDesalocarMedico: (mId) => _desalocarMedicoDiaUnico(mId),
            onEditarMedico: widget.isAdmin ? _abrirCadastroMedico : null,
            onMostrarMedicosNaoAlocadosAno: _mostrarMedicosNaoAlocadosAno,
            onMostrarConflitosAno: _mostrarConflitosAno,
          ),

        const SizedBox(height: 8),

        // Lista / Grade de Gabinetes
        GabinetesContainer(
          gabinetes: gabinetesFiltrados,
          alocacoes: alocacoes,
          medicos: medicos,
          disponibilidades: disponibilidades,
          selectedDate: selectedDate,
          onAlocarMedico: _alocarMedico,
          onAtualizarEstado: _carregarDadosIniciais,
          onDesalocarMedicoComPergunta: _desalocarMedicoComPergunta,
          isAdmin: widget.isAdmin,
          medicosDestacados: medicosDestacados,
          unidade: widget.unidade,
          onRealocacaoOtimista: _realocacaoOtimista,
          onRealocacaoConcluida: _limparFlagsTransicao,
          onAlocacaoSerieOtimista: _alocacaoSerieOtimista,
          onEditarMedico: widget.isAdmin ? _abrirCadastroMedico : null,
        ),
      ],
    );
  }

  void _abrirCadastroMedico(Medico medico) {
    _executarSeMontado(() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CadastroMedico(
            medico: medico,
            unidade: widget.unidade,
          ),
        ),
      );
    });
  }

  void _setMostrarColunaEsquerda(bool valor) {
    _setStateSeMontado(() {
      mostrarColunaEsquerda = valor;
    });
  }

  void _atualizarDataCalendarioVisualizada(DateTime data) {
    _setStateSeMontado(() {
      _dataCalendarioVisualizada = data;
    });
  }

  void _togglePisoSelecionado(String setor, bool isSelected) {
    _setStateSeMontado(() {
      if (isSelected) {
        if (pisosSelecionados.isEmpty) {
          pisosSelecionados = [setor];
        } else if (!pisosSelecionados.contains(setor)) {
          pisosSelecionados.add(setor);
        }
      } else {
        pisosSelecionados.remove(setor);
      }
    });
  }

  void _atualizarFiltroOcupacao(String novo) {
    _setStateSeMontado(() => filtroOcupacao = novo);
  }

  void _atualizarMostrarConflitos(bool valor) {
    _setStateSeMontado(() => mostrarConflitos = valor);
  }

  void _atualizarFiltroEspecialidadeGabinete(String? especialidade) {
    _setStateSeMontado(() => filtroEspecialidadeGabinete = especialidade);
  }

  // Funções de controle de zoom
  void _zoomIn() {
    final newScale = (zoomLevel + zoomStep).clamp(minZoom, maxZoom);
    if (newScale != zoomLevel) {
      _setStateSeMontado(() {
        zoomLevel = newScale;
      });
      _updateTransformation();
    }
  }

  void _zoomOut() {
    final newScale = (zoomLevel - zoomStep).clamp(minZoom, maxZoom);
    if (newScale != zoomLevel) {
      _setStateSeMontado(() {
        zoomLevel = newScale;
      });
      _updateTransformation();
    }
  }

  void _updateTransformation() {
    // Mantido para compatibilidade, mas não faz nada
  }

  @override
  Widget build(BuildContext context) {
    return AlocacaoScaffold(
      unidade: widget.unidade,
      isAdmin: widget.isAdmin,
      selectedDate: selectedDate,
      zoomLevel: zoomLevel,
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onRefresh: _refreshDados,
      body: AlocacaoBody(
        usarLayoutResponsivo: _deveUsarLayoutResponsivo(context),
        layoutResponsivo: _buildLayoutResponsivo(),
        layoutDesktop: _buildLayoutDesktop(),
        isCarregando: isCarregando,
        isRefreshing: _isRefreshing,
        mensagemProgresso: mensagemProgresso,
        progressoCarregamento: progressoCarregamento,
        isDesalocandoSerie: _isDesalocandoSerie,
        mensagemDesalocacao: _mensagemDesalocacao,
        progressoDesalocacao: _progressoDesalocacao,
      ),
    );
  }

  // Layout responsivo para ecrãs pequenos
  Widget _buildLayoutResponsivo() {
    return LayoutResponsivoAlocacao(
      mostrarColunaEsquerda: mostrarColunaEsquerda,
      onMostrarFiltros: () => _setMostrarColunaEsquerda(true),
      onMostrarMapa: () => _setMostrarColunaEsquerda(false),
      colunaEsquerda: _buildColunaEsquerda(),
      colunaDireita: _buildColunaDireita(),
      zoomLevel: zoomLevel,
    );
  }

  // Layout desktop para ecrãs grandes
  Widget _buildLayoutDesktop() {
    return LayoutDesktopAlocacao(
      colunaEsquerda: _buildColunaEsquerda(),
      colunaDireita: _buildColunaDireita(),
      zoomLevel: zoomLevel,
    );
  }

  // Conteúdo da coluna esquerda (DatePicker + Pesquisa + Filtros)
  Widget _buildColunaEsquerda() {
    return ColunaEsquerdaAlocacao(
      selectedDate: selectedDate,
      gabinetes: gabinetes,
      pisosSelecionados: pisosSelecionados,
      pesquisaNome: pesquisaNome,
      pesquisaEspecialidade: pesquisaEspecialidade,
      filtroOcupacao: filtroOcupacao,
      mostrarConflitos: mostrarConflitos,
      filtroEspecialidadeGabinete: filtroEspecialidadeGabinete,
      opcoesNome: _getOpcoesPesquisaNome(),
      opcoesEspecialidade: _getOpcoesPesquisaEspecialidade(),
      especialidadesGabinetes: _getEspecialidadesGabinetes(),
      onDateSelected: _onDateChanged,
      onViewChanged: _atualizarDataCalendarioVisualizada,
      onPesquisaNomeChanged: _aplicarPesquisaNome,
      onPesquisaEspecialidadeChanged: _aplicarPesquisaEspecialidade,
      onLimparPesquisa: _limparPesquisa,
      onTogglePiso: _togglePisoSelecionado,
      onFiltroOcupacaoChanged: _atualizarFiltroOcupacao,
      onMostrarConflitosChanged: _atualizarMostrarConflitos,
      onFiltroEspecialidadeGabineteChanged:
          _atualizarFiltroEspecialidadeGabinete,
    );
  }

  // Conteúdo da coluna direita (Médicos Disponíveis + Gabinetes)
  Widget _buildColunaDireita() {
    if (clinicaFechada) {
      return ClinicaFechadaAviso(mensagem: mensagemClinicaFechada);
    }

    return _buildEmptyStateOrContent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _timerProgresso?.cancel();
    _timerProgressoSimulado?.cancel();
    _timeoutFlagsTransicao?.cancel();
    _progressaoDadosController.parar();
    _transformationController.dispose();
    super.dispose();
  }
}
