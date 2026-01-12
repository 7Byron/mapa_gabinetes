import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../utils/ui_alocar_cartoes_unicos.dart';
import '../utils/ui_desalocar_cartao_unico.dart';
import '../utils/ui_desalocar_cartao_serie.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log_file.dart';

// Se criou o custom_drawer.dart
import '../widgets/custom_drawer.dart';
import '../utils/app_theme.dart';

// Widgets locais
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/gabinetes_section.dart';
import '../widgets/medicos_disponiveis_section.dart';
import '../widgets/filtros_section.dart';
import '../widgets/pesquisa_section.dart';

// Lógica separada
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../utils/ui_atualizar_dia.dart';
import '../utils/conflict_utils.dart';
import '../services/disponibilidade_unica_service.dart';

// Models
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';

// Services
import '../services/password_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';
import 'cadastro_medicos.dart';

// #region agent log helper
void _writeDebugLog(String location, String message, Map<String, dynamic> data, {String hypothesisId = 'A'}) {
  try {
    final logEntry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'data': data,
      'sessionId': 'debug-session',
      'runId': 'run1',
      'hypothesisId': hypothesisId,
    };
    writeLogToFile(jsonEncode(logEntry));
  } catch (e) {
    // Ignorar erros de escrita de log
  }
}
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
  DateTime?
      _ultimaAtualizacaoMedicos; // Última vez que médicos disponíveis foram atualizados
  Timer?
      _timeoutFlagsTransicao; // Timer para limpar flags presas automaticamente
  late DateTime selectedDate;
  late DateTime _dataCalendarioVisualizada; // Data visualizada no calendário (pode ser diferente de selectedDate)

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
      if (mounted) {
        _updateTransformation();
      }
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

  /// Atualiza o progresso de forma gradual e suave até o valor alvo
  void _atualizarProgressoGradual(double alvo, String mensagem) {
    // Cancelar timer anterior se existir
    _timerProgresso?.cancel();

    _progressoAlvo = alvo;
    if (mounted) {
      setState(() {
        mensagemProgresso = mensagem;
      });
    }

    // Se o alvo é menor ou igual ao progresso atual, atualizar imediatamente
    if (alvo <= progressoCarregamento) {
      if (mounted) {
        setState(() {
          progressoCarregamento = alvo;
        });
      }
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

      setState(() {
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
      debugPrint('⚠️ Refresh já em andamento, ignorando chamada duplicada');
      return;
    }

    // Iniciar progress bar
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        progressoCarregamento = 0.0;
      });
    }

    try {
      // CORREÇÃO: Invalidar cache ANTES de limpar flags para garantir invalidação
      // Invalidar todo o cache do ano atual
      final anoAtual = selectedDate.year;
      final dataNormalizada =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      // Invalidar cache do dia e do ano
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(anoAtual, 1, 1));

      // Atualizar progresso
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.2;
        });
      }

      // Aguardar um pouco para garantir que a invalidação foi processada
      await Future.delayed(const Duration(milliseconds: 100));

      // Recarregar dados
      await _carregarDadosIniciais(recarregarMedicos: true);
    } catch (e) {
      debugPrint('❌ Erro ao fazer refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _carregarDadosIniciais({bool recarregarMedicos = false}) async {
    // CORREÇÃO: Permitir carregamento mesmo se já estiver carregando se for refresh forçado
    // Mas ainda prevenir múltiplas chamadas simultâneas desnecessárias
    if (_isCarregandoDadosIniciais && !recarregarMedicos) {
      debugPrint(
          '⚠️ [LOCK] Ignorando chamada duplicada a _carregarDadosIniciais (já em execução)');
      return;
    }

    _isCarregandoDadosIniciais = true;

    // CORREÇÃO: Limpar dados antes de carregar para evitar dados vazios
    if (recarregarMedicos) {
      // Limpar apenas se for refresh forçado
      disponibilidades.clear();
      alocacoes.clear();
      medicosDisponiveis.clear();
    }
    Timer? timerProgressaoDados; // Timer para progressão automática durante carregamento
    bool dadosCarregando = false; // Flag para controlar quando dados estão sendo carregados

    try {
      // Inicializar progresso
      _atualizarProgressoGradual(0.0, 'A verificar configurações...');

      // FASE 0: Carregar dados de encerramento PRIMEIRO (feriados, dias de encerramento, horários)
      // Isso permite verificar se a clínica está encerrada ANTES de carregar dados do Firestore
      try {
        await Future.wait([
          _carregarFeriados(),
          _carregarDiasEncerramento(),
          _carregarHorariosEConfiguracoes(),
        ]);
      } catch (e) {
        // CORREÇÃO: Reduzir logs desnecessários - apenas em caso de erro real
        // Se houver erro, assumir que a clínica está aberta para não bloquear o carregamento
        if (mounted) {
          setState(() {
            clinicaFechada = false;
            mensagemClinicaFechada = '';
          });
        }
      }

      // Verificar se a clínica está encerrada ANTES de carregar dados do Firestore
      // CORREÇÃO: Só verificar se os dados foram carregados corretamente
      if (horariosClinica.isNotEmpty ||
          encerraDias.isNotEmpty ||
          feriados.isNotEmpty ||
          diasEncerramento.isNotEmpty) {
        _verificarClinicaFechada();
      } else {
        if (mounted) {
          setState(() {
            clinicaFechada = false;
            mensagemClinicaFechada = '';
          });
        }
      }

      // CORREÇÃO: Reduzir logs excessivos - apenas mostrar se clínica estiver fechada
      if (clinicaFechada) {
        debugPrint('🚫 Clínica encerrada: $mensagemClinicaFechada');
      }

      if (clinicaFechada) {
        // Clínica está encerrada - não carregar dados do Firestore
        if (mounted) {
          setState(() {
            // Limpar dados existentes
            disponibilidades.clear();
            alocacoes.clear();
            medicosDisponiveis.clear();
            // Desligar progress bar
            isCarregando = false;
            progressoCarregamento = 1.0;
            mensagemProgresso = 'Concluído!';
          });
        }
        _isCarregandoDadosIniciais = false;
        return; // Sair sem carregar mais nada - NÃO chamar carregarDadosIniciais
      }

      // FASE 1: Carregar exceções canceladas UMA ÚNICA VEZ (otimização de performance)
      _atualizarProgressoGradual(0.05, 'A verificar exceções...');

      final datasComExcecoesCanceladas =
          await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
        widget.unidade.id,
        selectedDate,
      );

      // FASE 2: Carregar dados essenciais (gabinetes, médicos, disponibilidades e alocações)
      // Só chega aqui se a clínica NÃO estiver encerrada
      _atualizarProgressoGradual(0.15, 'A carregar dados...');

      // Iniciar progressão automática durante carregamento de dados (0.15 -> 0.80)
      dadosCarregando = true;
      
      timerProgressaoDados =
          Timer.periodic(const Duration(milliseconds: 80), (timer) {
        // CORREÇÃO: Cancelar timer imediatamente se carregamento completo ou progresso atingido
        if (!mounted || !dadosCarregando || progressoCarregamento >= 0.80) {
          timer.cancel();
          timerProgressaoDados = null;
          dadosCarregando = false;
          return;
        }
        // Avançar gradualmente: 0.015 a cada 80ms (aproximadamente 18.75% por segundo)
        if (mounted && dadosCarregando) {
          setState(() {
            progressoCarregamento =
                (progressoCarregamento + 0.015).clamp(0.0, 0.80);
          });
        }
      });

      // CORREÇÃO: Se for refresh, garantir que cache está invalidado antes de carregar
      if (recarregarMedicos) {
        final dataNormalizada =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
        logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
            DateTime(selectedDate.year, 1, 1));

        await Future.delayed(
            const Duration(milliseconds: 50)); // Garantir invalidação
      }

      await logic.AlocacaoMedicosLogic.carregarDadosIniciais(
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        onGabinetes: (g) {
          // CORREÇÃO CRÍTICA: Se não estamos recarregando dados estáticos e recebemos lista vazia,
          // preservar dados existentes (não limpar dados estáticos durante mudança de data)
          if (!recarregarMedicos && g.isEmpty && gabinetes.isNotEmpty) {
            // Preservar dados existentes - não atualizar com lista vazia
            // CORREÇÃO: Reduzir logs desnecessários
            return;
          }
          // Atualizar normalmente se:
          // 1. Estamos recarregando dados estáticos (recarregarMedicos = true), OU
          // 2. Recebemos dados não vazios, OU
          // 3. Não havia dados antes (gabinetes.isEmpty)
          gabinetes = g;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onMedicos: (m) {
          // CORREÇÃO CRÍTICA: Se não estamos recarregando dados estáticos e recebemos lista vazia,
          // preservar dados existentes (não limpar dados estáticos durante mudança de data)
          if (!recarregarMedicos && m.isEmpty && medicos.isNotEmpty) {
            // Preservar dados existentes - não atualizar com lista vazia
            // CORREÇÃO: Reduzir logs desnecessários
            return;
          }
          // Atualizar normalmente se:
          // 1. Estamos recarregando dados estáticos (recarregarMedicos = true), OU
          // 2. Recebemos dados não vazios, OU
          // 3. Não havia dados antes (medicos.isEmpty)
          medicos = m;
          // CORREÇÃO: Reduzir logs desnecessários - apenas em modo debug detalhado
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onDisponibilidades: (d) {
          // CORREÇÃO: Remover logs excessivos que continuam executando após carregamento
          disponibilidades = d;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onAlocacoes: (a) {
          // CORREÇÃO CRÍTICA: Preservar TODAS as alocações otimistas durante recarregamento
          // Mesmo quando não há transição, pode haver alocações otimistas que ainda não foram
          // substituídas pela real do Firestore (ex: Teste1 alocado antes do Teste2)
          // Criar Map para mesclar alocações
          final alocacoesMap = <String, Alocacao>{};

          // Primeiro, adicionar alocações do servidor
          for (final aloc in a) {
            final chave =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
            alocacoesMap[chave] = aloc;
          }

          // CORREÇÃO CRÍTICA: Verificar se a alocação é do dia selecionado antes de preservar
          // Isso evita que alocações de dias anteriores sejam transportadas para o dia atual
          final selectedDateNormalized = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
          );

          // Depois, preservar alocações otimistas que correspondem a alocações reais no servidor
          // (mesmo médico, mesmo gabinete, mesmo dia) - essas são alocações confirmadas mas
          // que ainda têm ID otimista temporário
          // IMPORTANTE: Apenas preservar alocações do dia selecionado
          for (final aloc in alocacoes) {
            // CORREÇÃO: Verificar se a alocação é do dia selecionado antes de preservar
            final alocDateNormalized = DateTime(
              aloc.data.year,
              aloc.data.month,
              aloc.data.day,
            );
            if (alocDateNormalized != selectedDateNormalized) {
              // Pular alocações de outros dias - não devem ser preservadas
              continue;
            }

            if (aloc.id.startsWith('otimista_')) {
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';

              // Se existe uma alocação real no servidor para esta chave, substituir a otimista pela real
              if (alocacoesMap.containsKey(chave)) {
                debugPrint(
                    '✅ Substituindo alocação otimista pela real durante recarregamento: ${aloc.id} -> ${alocacoesMap[chave]!.id}');
              } else {
                // Não existe no servidor ainda - preservar otimista (pode ser do médico em transição)
                alocacoesMap[chave] = aloc;
                debugPrint(
                    '✅ Preservando alocação otimista durante recarregamento: ${aloc.id} (médico: ${aloc.medicoId})');
              }
            } else {
              // Alocação não é otimista - se não existe no servidor, pode ser de série gerada
              // Preservar apenas se não existe no servidor (pode ser alocação gerada de série)
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
              if (!alocacoesMap.containsKey(chave) &&
                  aloc.id.startsWith('serie_')) {
                // Preservar alocações geradas de séries que não estão no Firestore
                alocacoesMap[chave] = aloc;
              }
            }
          }

          alocacoes = alocacoesMap.values.toList();
          // CORREÇÃO: Reduzir logs excessivos - apenas mostrar em casos importantes
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        unidade: widget.unidade,
        dataFiltroDia: selectedDate,
        reloadStatic:
            recarregarMedicos, // Força recarregar médicos se solicitado
        excecoesCanceladas:
            datasComExcecoesCanceladas, // Passar exceções já carregadas
      );

      // CORREÇÃO CRÍTICA: Marcar dados como completos e cancelar timer IMEDIATAMENTE
      dadosCarregando = false;
      timerProgressaoDados?.cancel();
      timerProgressaoDados = null;

      // Atualizar progresso para refletir que os dados foram carregados
      // Garantir que o progresso esteja pelo menos em 0.80 antes de continuar
      if (progressoCarregamento < 0.80) {
        _atualizarProgressoGradual(0.80, 'A processar dados...');
        // Aguardar um pouco para a animação chegar a 0.80
        await Future.delayed(const Duration(milliseconds: 200));
      }
      // Chamar fora do setState porque é assíncrono e atualiza o estado internamente
      // IMPORTANTE: Sempre chamar, mesmo quando dados vêm do cache, para verificar exceções
      // CORREÇÃO: Forçar recarregamento de alocações após carregar dados iniciais

      // CORREÇÃO CRÍTICA: Regenerar alocações de séries ANTES de atualizar médicos disponíveis
      final alocacoesSeriesRegeneradas = await _regenerarAlocacoesSeries();

      // Atualizar lista de alocações com as alocações regeneradas
      // CORREÇÃO CRÍTICA: Remover alocações antigas de séries antes de adicionar novas
      // MAS preservar atualização otimista se houver transição em andamento
      final chavesSeriesParaRemover = <String>{};
      for (final aloc in alocacoesSeriesRegeneradas) {
        final chaveSemGabinete =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        chavesSeriesParaRemover.add(chaveSemGabinete);
      }

      final alocacoesAtualizadas = <Alocacao>[];
      // CORREÇÃO CRÍTICA: Preservar atualização otimista durante regeneração
      // Primeiro, adicionar alocações que NÃO são de séries ou que não serão regeneradas
      // MAS sempre preservar alocações otimistas do médico em transição
      // IMPORTANTE: Apenas preservar alocações do dia selecionado
      final selectedDateNormalized = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      for (final aloc in alocacoes) {
        // CORREÇÃO: Verificar se a alocação é do dia selecionado antes de preservar
        final alocDateNormalized = DateTime(
          aloc.data.year,
          aloc.data.month,
          aloc.data.day,
        );
        if (alocDateNormalized != selectedDateNormalized) {
          // Pular alocações de outros dias - não devem ser preservadas
          continue;
        }

        // CORREÇÃO: Se é uma alocação otimista, preservar apenas se não há alocação real correspondente
        if (aloc.id.startsWith('otimista_serie_')) {
          // Verificar se há uma alocação real correspondente nas alocações regeneradas
          final temAlocacaoReal = alocacoesSeriesRegeneradas.any((a) {
            return a.medicoId == aloc.medicoId &&
                a.gabineteId == aloc.gabineteId &&
                a.data.year == aloc.data.year &&
                a.data.month == aloc.data.month &&
                a.data.day == aloc.data.day;
          });
          if (!temAlocacaoReal) {
            // Não há alocação real - preservar otimista temporariamente
            alocacoesAtualizadas.add(aloc);
            // CORREÇÃO: Reduzir logs excessivos
          } else {
            // Há alocação real - não preservar otimista
            // CORREÇÃO: Reduzir logs excessivos
          }
          continue;
        }

        if (aloc.id.startsWith('serie_')) {
          final chaveSemGabinete =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          if (chavesSeriesParaRemover.contains(chaveSemGabinete)) {
            continue; // Pular alocações de séries que serão regeneradas
          }
        }
        alocacoesAtualizadas.add(aloc);
      }
      // Depois, adicionar alocações regeneradas de séries
      alocacoesAtualizadas.addAll(alocacoesSeriesRegeneradas);

      // Atualizar lista de alocações
      alocacoes.clear();
      alocacoes.addAll(alocacoesAtualizadas);

      // CORREÇÃO: Cache é atualizado automaticamente em carregarDadosIniciais
      // Não precisamos atualizar manualmente aqui

      // CORREÇÃO: Atualizar médicos disponíveis após regenerar alocações de séries
      if (mounted) {
        // CORREÇÃO: Reduzir logs desnecessários
        _atualizarProgressoGradual(0.90, 'A processar médicos disponíveis...');
        await _atualizarMedicosDisponiveis();
        
        // Atualizar para 100% apenas no final, sem mensagens intermediárias de "finalizar"
        if (mounted) {
          setState(() {
            progressoCarregamento = 1.0;
            mensagemProgresso = 'Concluído!';
          });
        }
      }

      // CORREÇÃO: Atualizar UI apenas se não estiver processando alocação
      // Isso evita múltiplas atualizações durante drag and drop
      if (mounted) {
        setState(() {
          // Inicializar filtros de piso com todos os setores selecionados por padrão
          _inicializarFiltrosPiso();
          // Verificar novamente se a clínica está fechada (já foi verificado antes, mas garantir)
          _verificarClinicaFechada();
          // Cancelar qualquer timer de progressão em andamento
          _timerProgresso?.cancel();
          // Desligar progress bar após um pequeno delay para mostrar 100%
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                isCarregando = false;
                progressoCarregamento = 0.0;
                mensagemProgresso = 'A iniciar...';
              });
            }
          });
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');

      if (mounted) {
        setState(() {
          isCarregando = false;
        });
        _atualizarProgressoGradual(0.0, 'A iniciar...');
      }
    } finally {
      // CORREÇÃO CRÍTICA: Garantir que todos os timers sejam cancelados, mesmo em caso de erro
      dadosCarregando = false;
      timerProgressaoDados?.cancel();
      timerProgressaoDados = null;
      // NÃO cancelar _timerProgresso aqui - ele precisa continuar para completar a animação até 100%
      _isCarregandoDadosIniciais = false; // Liberar lock
    }
  }

  Future<void> _carregarFeriados() async {
    try {
      final feriadosRef = FirebaseFirestore.instance
          .collection('unidades')
          .doc(widget.unidade.id)
          .collection('feriados');

      // Carrega o ano do dia selecionado (não apenas o ano atual)
      final anoSelecionado = selectedDate.year.toString();
      final anoRef = feriadosRef.doc(anoSelecionado);
      final registosRef = anoRef.collection('registos');

      try {
        final registosSnapshot = await registosRef.get();
        if (mounted) {
          setState(() {
            feriados = registosSnapshot.docs.map((doc) {
              final data = doc.data();
              return <String, String>{
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
              };
            }).toList();
          });
        }
      } catch (e) {
        // Fallback: tenta carregar de todos os anos
        final anosSnapshot = await feriadosRef.get();
        final feriadosTemp = <Map<String, String>>[];
        for (final anoDoc in anosSnapshot.docs) {
          final registosRef = anoDoc.reference.collection('registos');
          final registosSnapshot = await registosRef.get();
          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            feriadosTemp.add(<String, String>{
              'id': doc.id,
              'data': data['data'] as String? ?? '',
              'descricao': data['descricao'] as String? ?? '',
            });
          }
        }
        if (mounted) {
          setState(() {
            feriados = feriadosTemp;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          feriados = [];
        });
      }
    }
  }

  Future<void> _carregarDiasEncerramento() async {
    try {
      final encerramentosRef = FirebaseFirestore.instance
          .collection('unidades')
          .doc(widget.unidade.id)
          .collection('encerramentos');

      // Carrega apenas o ano do dia selecionado (otimização)
      final anoSelecionado = selectedDate.year.toString();
      final anoRef = encerramentosRef.doc(anoSelecionado);
      final registosRef = anoRef.collection('registos');

      try {
        final registosSnapshot = await registosRef.get();
        if (mounted) {
          setState(() {
            diasEncerramento = registosSnapshot.docs.map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
                'motivo': data['motivo'] as String? ?? 'Encerramento',
              };
            }).toList();
          });
        }
      } catch (e) {
        // Fallback: tenta carregar de todos os anos
        final anosSnapshot = await encerramentosRef.get();
        final diasTemp = <Map<String, dynamic>>[];
        for (final anoDoc in anosSnapshot.docs) {
          final registosRef = anoDoc.reference.collection('registos');
          final registosSnapshot = await registosRef.get();
          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            diasTemp.add({
              'id': doc.id,
              'data': data['data'] as String? ?? '',
              'descricao': data['descricao'] as String? ?? '',
              'motivo': data['motivo'] as String? ?? 'Encerramento',
            });
          }
        }
        if (mounted) {
          setState(() {
            diasEncerramento = diasTemp;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          diasEncerramento = [];
        });
      }
    }
  }

  Future<void> _carregarHorariosEConfiguracoes() async {
    try {
      final horariosRef = FirebaseFirestore.instance
          .collection('unidades')
          .doc(widget.unidade.id)
          .collection('horarios_clinica');

      final horariosSnapshot = await horariosRef.get();
      final horariosTemp = <int, List<String>>{};
      for (final doc in horariosSnapshot.docs) {
        final data = doc.data();
        final diaSemana = data['diaSemana'] as int? ?? 0;
        final horaAbertura = data['horaAbertura'] as String? ?? '';
        final horaFecho = data['horaFecho'] as String? ?? '';
        if (horaAbertura.isNotEmpty && horaFecho.isNotEmpty) {
          horariosTemp[diaSemana] = [horaAbertura, horaFecho];
        }
      }

      // Carregar configurações de encerramento
      try {
        final configDoc = await horariosRef.doc('config').get();
        if (configDoc.exists && mounted) {
          final configData = configDoc.data() as Map<String, dynamic>;
          setState(() {
            horariosClinica = horariosTemp;
            nuncaEncerra = configData['nuncaEncerra'] as bool? ?? false;
            encerraFeriados = configData['encerraFeriados'] as bool? ?? false;

            // Carregar configurações por dia
            for (int i = 1; i <= 7; i++) {
              encerraDias[i] = configData['encerraDia$i'] as bool? ?? false;
            }
          });
        } else if (mounted) {
          setState(() {
            horariosClinica = horariosTemp;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            horariosClinica = horariosTemp;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          horariosClinica = {};
        });
      }
    }
  }

  void _verificarClinicaFechada() {
    // Se "nunca encerra" está ativo, a clínica nunca está fechada
    if (nuncaEncerra) {
      clinicaFechada = false;
      mensagemClinicaFechada = '';
      return;
    }

    final diaSemana = selectedDate.weekday;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(selectedDate);

    // PRIMEIRO: Verificar se há um dia específico de encerramento configurado
    // CORREÇÃO: Remover logs desnecessários dentro de loop

    final diaEncerramento = diasEncerramento.firstWhere(
      (d) {
        final dataDia = d['data'] as String? ?? '';
        if (dataDia.isEmpty) return false;
        try {
          final dataDiaParsed = DateTime.parse(dataDia);
          final dataFormatadaParsed = DateTime.parse(dataFormatada);
          return dataDiaParsed.year == dataFormatadaParsed.year &&
              dataDiaParsed.month == dataFormatadaParsed.month &&
              dataDiaParsed.day == dataFormatadaParsed.day;
        } catch (e) {
          return dataDia == dataFormatada;
        }
      },
      orElse: () => <String, dynamic>{},
    );

    if (diaEncerramento.containsKey('id') &&
        diaEncerramento['id']!.toString().isNotEmpty) {
      clinicaFechada = true;
      final descricao = diaEncerramento['descricao'] as String? ?? '';
      // Usar apenas a descrição (ex: "Feriado Nacional") sem o prefixo "Clínica encerrada -"
      mensagemClinicaFechada =
          descricao.isNotEmpty ? descricao : 'Encerramento';
      // CORREÇÃO: Reduzir logs - apenas mostrar mensagem importante
      debugPrint('🚫 Clínica encerrada: $mensagemClinicaFechada');
      return;
    }

    // SEGUNDO: Verificar se o dia específico da semana está configurado para encerrar
    if (encerraDias[diaSemana] == true) {
      clinicaFechada = true;
      final diasSemana = [
        '',
        'Segunda-feira',
        'Terça-feira',
        'Quarta-feira',
        'Quinta-feira',
        'Sexta-feira',
        'Sábado',
        'Domingo'
      ];
      mensagemClinicaFechada = '${diasSemana[diaSemana]}s';
      debugPrint('🚫 Clínica encerrada: $mensagemClinicaFechada');
      return;
    }

    // TERCEIRO: Verificar se é feriado e se está configurado para encerrar em feriados
    final feriado = feriados.firstWhere(
      (f) {
        final dataFeriado = f['data']?.toString() ?? '';
        if (dataFeriado.isEmpty) return false;
        try {
          final dataFeriadoParsed = DateTime.parse(dataFeriado);
          final dataFormatadaParsed = DateTime.parse(dataFormatada);
          return dataFeriadoParsed.year == dataFormatadaParsed.year &&
              dataFeriadoParsed.month == dataFormatadaParsed.month &&
              dataFeriadoParsed.day == dataFormatadaParsed.day;
        } catch (e) {
          return dataFeriado == dataFormatada;
        }
      },
      orElse: () => <String, String>{},
    );

    if (feriado.containsKey('id') && feriado['id']!.isNotEmpty) {
      if (encerraFeriados) {
        clinicaFechada = true;
        // Usar apenas a descrição do feriado (ex: "Feriado Nacional") sem o prefixo
        mensagemClinicaFechada = feriado['descricao'] ?? 'Feriado';
        debugPrint('🚫 Clínica encerrada: $mensagemClinicaFechada');
        return;
      }
    }

    // QUARTO: Verificar horários tradicionais (fallback)
    final horariosDoDia = horariosClinica[diaSemana] ?? [];
    if (horariosDoDia.isEmpty) {
      clinicaFechada = true;
      mensagemClinicaFechada = 'Sem horários';
      debugPrint('🚫 Clínica encerrada: $mensagemClinicaFechada');
      return;
    }

    clinicaFechada = false;
    mensagemClinicaFechada = '';
  }

  /// Regenera alocações de séries para o dia atual
  /// Isso garante que alocações de séries alocadas sejam sempre exibidas
  Future<List<Alocacao>> _regenerarAlocacoesSeries() async {
    try {
      final dataInicio =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final dataFim = dataInicio.add(const Duration(days: 1));

      // SEMPRE buscar do Firestore (cache removido)
      // Extrair médicos que têm alocações de séries para o dia atual
      final alocacoesSeriesDoDia = alocacoes.where((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        final sd =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        return ad == sd && a.id.startsWith('serie_');
      }).toList();

      if (alocacoesSeriesDoDia.isEmpty) {
        // Não há alocações de séries para o dia, não precisa processar nenhum médico
        return <Alocacao>[];
      }

      // Extrair os médicos dessas alocações
      final medicoIds =
          alocacoesSeriesDoDia.map((a) => a.medicoId).toSet().toList();

      // OTIMIZAÇÃO: Paralelizar processamento de médicos
      final futures = medicoIds.map((medicoId) async {
        // Carregar séries do Firestore
        final seriesCarregadas = await SerieService.carregarSeries(
          medicoId,
          unidade: widget.unidade,
          dataInicio: null,
          dataFim: dataInicio.add(const Duration(days: 1)),
        );

        // Filtrar apenas séries com gabineteId (alocadas)
        final series = seriesCarregadas
            .where((s) =>
                s.ativo && s.gabineteId != null && s.gabineteId!.isNotEmpty)
            .toList();

        if (series.isEmpty) {
          return <Alocacao>[];
        }

        // CORREÇÃO CRÍTICA: Forçar servidor se o cache estiver invalidado para este dia
        // Isso garante que exceções recém-criadas (ex: exceção cancelada ao desalocar "apenas este dia")
        // sejam carregadas imediatamente
        final cacheInvalidado = logic.AlocacaoMedicosLogic.isCacheInvalidado(dataInicio);
        final excecoesCarregadas = await SerieService.carregarExcecoes(
          medicoId,
          unidade: widget.unidade,
          dataInicio: dataInicio,
          dataFim: dataFim,
          forcarServidor: cacheInvalidado, // Forçar servidor se cache invalidado
        );

        // Filtrar exceções apenas para o dia atual
        final excecoes = excecoesCarregadas
            .where((e) =>
                e.data.year == dataInicio.year &&
                e.data.month == dataInicio.month &&
                e.data.day == dataInicio.day)
            .toList();

        // Filtrar apenas séries com gabineteId != null (já filtrado acima, mas manter para compatibilidade)
        final seriesComGabinete = series
            .where((s) => s.gabineteId != null && s.gabineteId!.isNotEmpty)
            .toList();

        if (seriesComGabinete.isEmpty) {
          return <Alocacao>[];
        }

        // Gerar alocações dinamicamente
        final alocsGeradas = SerieGenerator.gerarAlocacoes(
          series: seriesComGabinete,
          excecoes: excecoes,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

        return alocsGeradas;
      }).toList();

      // Aguardar todas as futures em paralelo
      final resultados = await Future.wait(futures);

      // Combinar todas as alocações geradas
      final alocacoesGeradas = <Alocacao>[];
      for (final alocs in resultados) {
        alocacoesGeradas.addAll(alocs);
      }

      // CORREÇÃO: Reduzir logs excessivos - apenas mostrar se houver muitas alocações
      if (alocacoesGeradas.length > 10) {
        debugPrint('🔄 ${alocacoesGeradas.length} alocações de séries regeneradas');
      }
      return alocacoesGeradas;
    } catch (e) {
      debugPrint('❌ Erro ao regenerar alocações de séries: $e');
      return [];
    }
  }

  /// Recarrega apenas as alocações de um ou mais gabinetes específicos (reload focado)
  Future<void> _recarregarAlocacoesGabinetes(List<String> gabineteIds) async {
    try {
      final dataNormalizada =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      // Invalidar cache apenas para este dia
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      // Recarregar alocações do dia selecionado do Firestore
      final novasAlocacoes =
          await logic.AlocacaoMedicosLogic.carregarAlocacoesUnidade(
              widget.unidade,
              dataFiltroDia: dataNormalizada);

      // CORREÇÃO CRÍTICA: Preservar alocações de outros gabinetes e apenas atualizar os gabinetes especificados
      // Criar um mapa das alocações atuais para preservar as que não são dos gabinetes especificados
      final alocacoesPreservadas = <String, Alocacao>{};
      for (final aloc in alocacoes) {
        final aDate = DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
        // Preservar alocações que NÃO são dos gabinetes especificados OU que são de outros dias
        if (aDate != dataNormalizada ||
            !gabineteIds.contains(aloc.gabineteId)) {
          final chave =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
          alocacoesPreservadas[chave] = aloc;
        }
      }

      // Adicionar novas alocações dos gabinetes especificados
      for (final gabineteId in gabineteIds) {
        final alocacoesDoGabinete = novasAlocacoes.where((a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.gabineteId == gabineteId && aDate == dataNormalizada;
        }).toList();

        for (final aloc in alocacoesDoGabinete) {
          final chave =
              '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
          alocacoesPreservadas[chave] = aloc;
        }

        debugPrint(
            '✅ [RELOAD FOCADO] Gabinete $gabineteId: ${alocacoesDoGabinete.length} alocações recarregadas');
      }

      // Atualizar lista de alocações preservando as de outros gabinetes
      alocacoes.clear();
      alocacoes.addAll(alocacoesPreservadas.values);
      debugPrint(
          '✅ [RELOAD FOCADO] Total de alocações após reload: ${alocacoes.length} (preservadas: ${alocacoesPreservadas.length - novasAlocacoes.length})');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Erro ao recarregar alocações dos gabinetes: $e');
    }
  }

  /// Recarrega apenas a lista de médicos desalocados (reload focado)
  Future<void> _recarregarDesalocados() async {
    try {
      await _atualizarMedicosDisponiveis();
      if (mounted) {
        setState(() {});
      }
      debugPrint('✅ [RELOAD FOCADO] Lista de desalocados atualizada');
    } catch (e) {
      debugPrint('❌ Erro ao recarregar desalocados: $e');
    }
  }

  Future<void> _atualizarMedicosDisponiveis() async {
    // CORREÇÃO: Prevenir atualizações muito frequentes
    if (_ultimaAtualizacaoMedicos != null &&
        DateTime.now().difference(_ultimaAtualizacaoMedicos!) <
            const Duration(milliseconds: 500)) {
      debugPrint(
          '⚠️ [ATUALIZAR-MÉDICOS] Ignorando (atualização muito recente)');

      return;
    }

    _ultimaAtualizacaoMedicos = DateTime.now();

    debugPrint(
        '🔍 _atualizarMedicosDisponiveis chamado para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
    debugPrint('  📊 Total de disponibilidades: ${disponibilidades.length}');
    // DEBUG: Mostrar algumas datas das disponibilidades para entender o problema
    if (disponibilidades.isNotEmpty) {
      debugPrint('  🔍 Primeiras 5 disponibilidades (datas):');
      for (var i = 0; i < disponibilidades.length && i < 5; i++) {
        final d = disponibilidades[i];
        debugPrint(
            '    ${i + 1}. ${d.medicoId}: ${d.data.day}/${d.data.month}/${d.data.year}');
      }
    }
    debugPrint('  📊 Total de médicos: ${medicos.length}');

    // CORREÇÃO CRÍTICA: Incluir médico em transição como alocado
    final medicosAlocados = alocacoes
        .where((a) =>
            DateFormat('yyyy-MM-dd').format(a.data) ==
            DateFormat('yyyy-MM-dd').format(selectedDate))
        .map((a) => a.medicoId)
        .toSet();

    // Médicos alocados já foram identificados acima

    // Filtra médicos que:
    // 1. Estão ativos
    // 2. Não estão alocados no dia selecionado
    // 3. Têm disponibilidade para o dia selecionado
    // 4. NÃO têm exceção cancelada para esse dia
    final selectedDateNormalized =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    // Carregar exceções canceladas para o dia selecionado

    debugPrint('  🔄 Carregando exceções canceladas...');
    final datasComExcecoesCanceladas =
        await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      widget.unidade.id,
      selectedDate,
    );

    // OTIMIZAÇÃO: Em vez de iterar sobre todos os médicos, primeiro criar um Set
    // de IDs de médicos que têm disponibilidade para o dia (iterando apenas sobre disponibilidades)
    // CRÍTICO: Filtrar disponibilidades com exceções canceladas ANTES de criar o Set
    final medicosComDisponibilidade = <String>{};

    for (final d in disponibilidades) {
      final dd = DateTime(d.data.year, d.data.month, d.data.day);
      if (dd == selectedDateNormalized) {
        // Verificar se esta disponibilidade não tem exceção cancelada
        final dataKey =
            '${d.medicoId}_${d.data.year}-${d.data.month}-${d.data.day}';
        final temExcecaoCancelada = datasComExcecoesCanceladas.contains(dataKey);
        
        // #region agent log
        final medico = medicos.firstWhere((m) => m.id == d.medicoId, orElse: () => Medico(id: '', nome: '', especialidade: '', disponibilidades: [], ativo: false));
        if (medico.nome.toLowerCase().contains('francisco') && medico.nome.toLowerCase().contains('gama')) {
          _writeDebugLog('alocacao_medicos_screen.dart:1270', 'Disponibilidade de Francisco Gama encontrada', {
            'medicoId': d.medicoId,
            'medicoNome': medico.nome,
            'data': '${dd.day}/${dd.month}/${dd.year}',
            'selectedDate': '${selectedDateNormalized.day}/${selectedDateNormalized.month}/${selectedDateNormalized.year}',
            'dataKey': dataKey,
            'temExcecaoCancelada': temExcecaoCancelada,
            'seraAdicionado': !temExcecaoCancelada,
          }, hypothesisId: 'V');
        }
        // #endregion
        
        if (!temExcecaoCancelada) {
          medicosComDisponibilidade.add(d.medicoId);
        }
      }
    }
    
    // #region agent log
    final franciscoGama = medicos.firstWhere(
      (m) => m.nome.toLowerCase().contains('francisco') && m.nome.toLowerCase().contains('gama'),
      orElse: () => Medico(id: '', nome: '', especialidade: '', disponibilidades: [], ativo: false),
    );
    if (franciscoGama.id.isNotEmpty) {
      _writeDebugLog('alocacao_medicos_screen.dart:1285', 'Francisco Gama - verificação final', {
        'medicoId': franciscoGama.id,
        'medicoNome': franciscoGama.nome,
        'ativo': franciscoGama.ativo,
        'estaAlocado': medicosAlocados.contains(franciscoGama.id),
        'temDisponibilidade': medicosComDisponibilidade.contains(franciscoGama.id),
        'medicosComDisponibilidade': medicosComDisponibilidade.toList(),
        'totalDisponibilidades': disponibilidades.length,
        'disponibilidadesDoDia': disponibilidades.where((d) {
          final dd = DateTime(d.data.year, d.data.month, d.data.day);
          return dd == selectedDateNormalized;
        }).length,
      }, hypothesisId: 'V');
    }
    // #endregion

    if (mounted) {
      setState(() {
        // OTIMIZAÇÃO: Agora iterar apenas sobre médicos que têm disponibilidade
        // (muito menos iterações: de 155 para ~10)
        final medicoTesteInfo = <String, dynamic>{};

        medicosDisponiveis = medicos.where((m) {
          final isMedicoTeste = m.nome.toLowerCase().contains('teste');

          // FILTRAR: Não mostrar médicos inativos
          if (!m.ativo) {
            if (isMedicoTeste) medicoTesteInfo['filtradoPor'] = 'inativo';
            return false;
          }

          // Verifica se não está alocado
          if (medicosAlocados.contains(m.id)) {
            if (isMedicoTeste) medicoTesteInfo['filtradoPor'] = 'alocado';
            return false;
          }

          // Verifica se tem exceção cancelada para esse dia
          final dataKey =
              '${m.id}_${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
          if (datasComExcecoesCanceladas.contains(dataKey)) {
            if (isMedicoTeste) {
              medicoTesteInfo['filtradoPor'] = 'excecaoCancelada';
            }
            return false; // Não mostrar se tem exceção cancelada
          }

          // OTIMIZAÇÃO: Verificar apenas se o médico está no Set de médicos com disponibilidade
          // (muito mais rápido que iterar sobre todas as disponibilidades)
          final temDisponibilidade = medicosComDisponibilidade.contains(m.id);

          if (isMedicoTeste) {
            medicoTesteInfo['temDisponibilidade'] = temDisponibilidade;
            medicoTesteInfo['medicosComDisponibilidadeContains'] =
                medicosComDisponibilidade.contains(m.id);
          }

          if (!temDisponibilidade && isMedicoTeste) {
            medicoTesteInfo['filtradoPor'] = 'semDisponibilidade';
          }

          return temDisponibilidade;
        }).toList();
      });
    }
  }

  void _inicializarFiltrosPiso() {
    // Inicializar todos os filtros de piso como selecionados por padrão
    if (gabinetes.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
      pisosSelecionados = List<String>.from(todosSetores);
    }
  }

  // Obter médicos alocados no dia selecionado
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

  // Obter opções de pesquisa por nome
  List<String> _getOpcoesPesquisaNome() {
    final medicosAlocados = _getMedicosAlocadosNoDia();
    final nomes = medicosAlocados.map((m) => m.nome).toList();
    nomes.sort(); // Ordem alfabética
    return nomes;
  }

  // Obter opções de pesquisa por especialidade
  List<String> _getOpcoesPesquisaEspecialidade() {
    final medicosAlocados = _getMedicosAlocadosNoDia();
    final especialidades =
        medicosAlocados.map((m) => m.especialidade).toSet().toList();
    especialidades.sort(); // Ordem alfabética
    return especialidades;
  }

  // Aplicar pesquisa por nome
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

  // Aplicar pesquisa por especialidade
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

  // Atualizar médicos destacados baseado na pesquisa ativa
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

  // Obter especialidades únicas dos gabinetes
  List<String> _getEspecialidadesGabinetes() {
    final especialidades = <String>{};
    for (final gabinete in gabinetes) {
      especialidades.addAll(gabinete.especialidadesPermitidas);
    }
    final lista = especialidades.toList();
    lista.sort(); // Ordem alfabética
    return lista;
  }

  // Limpar pesquisa
  void _limparPesquisa() {
    setState(() {
      pesquisaNome = null;
      pesquisaEspecialidade = null;
      medicosDestacados.clear();
    });
  }

  // Lock para prevenir múltiplas execuções simultâneas de _onDateChanged
  bool _isUpdatingDate = false;
  DateTime? _lastUpdateDate;

  void _onDateChanged(DateTime newDate) async {
    if (!mounted) return;

    // CORREÇÃO CRÍTICA: Prevenir race conditions quando o sistema está lento
    if (_isUpdatingDate) {
      debugPrint(
          '⚠️ [RACE-CONDITION] Ignorando chamada duplicada de _onDateChanged para ${newDate.day}/${newDate.month}/${newDate.year}');
      return;
    }

    // Verificar se é a mesma data (evitar atualizações desnecessárias)
    final dataNormalizada = DateTime(newDate.year, newDate.month, newDate.day);


    if (_lastUpdateDate != null) {
      final lastDateNormalizada = DateTime(
          _lastUpdateDate!.year, _lastUpdateDate!.month, _lastUpdateDate!.day);
      if (lastDateNormalizada == dataNormalizada) {
        debugPrint(
            '⚠️ [RACE-CONDITION] Ignorando atualização duplicada para a mesma data: ${newDate.day}/${newDate.month}/${newDate.year}');
        // Limpar _lastUpdateDate para permitir nova tentativa após um delay
        _lastUpdateDate = null;
        return;
      }
    }

    _isUpdatingDate = true;
    _lastUpdateDate = newDate;

    try {
      // Invalidar cache ANTES de limpar dados
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(newDate.year, 1, 1));

      setState(() {
        selectedDate =
            dataNormalizada; // Usar data normalizada para garantir consistência
        _dataCalendarioVisualizada = dataNormalizada; // Atualizar também a data visualizada


        isCarregando = true;
        // Limpar dados do dia anterior antes de carregar novos dados
        disponibilidades.clear();
        alocacoes.clear();
        medicosDisponiveis.clear();
      });

      // Usar a função reutilizável para atualizar os dados do dia
      final resultado = await atualizarDadosDoDia(
        unidade: widget.unidade,
        data: dataNormalizada, // Usar data normalizada
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicosDisponiveis: medicosDisponiveis,
        recarregarMedicos:
            false, // Não precisa recarregar médicos ao mudar de dia
        onProgress: (progresso, mensagem) {
          if (mounted) {
            _atualizarProgressoGradual(progresso, mensagem);
          }
        },
        onStateUpdate: () {
          if (mounted) {
            setState(() {});
          }
        },
      );

      // Atualizar estado com informações da clínica (mas manter isCarregando = true até todas as operações terminarem)
      if (mounted) {
        setState(() {
          clinicaFechada = resultado['clinicaFechada'] ?? false;
          mensagemClinicaFechada = resultado['mensagemClinicaFechada'] ?? '';
          feriados = resultado['feriados'] ?? [];
          diasEncerramento = resultado['diasEncerramento'] ?? [];
          horariosClinica = resultado['horariosClinica'] ?? {};
          encerraFeriados = resultado['encerraFeriados'] ?? false;
          nuncaEncerra = resultado['nuncaEncerra'] ?? false;
          encerraDias = resultado['encerraDias'] ?? {};
          // NÃO definir isCarregando = false aqui - manter true até todas as operações terminarem
        });
      }

      // CRÍTICO: Regenerar alocações de séries após carregar os dados
      // Isso é necessário para que as alocações de séries apareçam nos gabinetes
      _atualizarProgressoGradual(0.75, 'A regenerar alocações de séries...');
      final alocacoesSeriesRegeneradas = await _regenerarAlocacoesSeries();
      _atualizarProgressoGradual(0.80, 'A processar dados...');

      // Atualizar lista de alocações com as alocações regeneradas
      // Remover alocações antigas de séries antes de adicionar novas
      final chavesSeriesParaRemover = <String>{};
      for (final aloc in alocacoesSeriesRegeneradas) {
        final chaveSemGabinete =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        chavesSeriesParaRemover.add(chaveSemGabinete);
      }

      // Remover alocações antigas de séries do dia atual
      alocacoes.removeWhere((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        final sd =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        if (ad != sd) return false;
        final chaveSemGabinete =
            '${a.medicoId}_${a.data.year}-${a.data.month}-${a.data.day}';
        return a.id.startsWith('serie_') &&
            chavesSeriesParaRemover.contains(chaveSemGabinete);
      });

      // Adicionar novas alocações de séries
      alocacoes.addAll(alocacoesSeriesRegeneradas);

      // NOTA: Os médicos disponíveis já foram calculados em atualizarDadosDoDia,
      // mas precisamos atualizar novamente após regenerar as séries para garantir
      // que médicos com alocações de séries não apareçam como disponíveis
      _atualizarProgressoGradual(0.90, 'A processar médicos disponíveis...');
      await _atualizarMedicosDisponiveis();
      
      // Atualizar para 100% apenas no final, sem mensagens intermediárias
      if (mounted) {
        setState(() {
          progressoCarregamento = 1.0;
          mensagemProgresso = 'Concluído!';
        });
        // Pequeno delay para mostrar 100%
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Atualizar UI após todas as operações - AGORA definir isCarregando = false
      if (mounted) {
        // CORREÇÃO CRÍTICA: Garantir que pisosSelecionados esteja inicializado
        // antes de atualizar a UI, para que os gabinetes sejam exibidos corretamente
        if (pisosSelecionados.isEmpty && gabinetes.isNotEmpty) {
          final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
          pisosSelecionados = List<String>.from(todosSetores);
        }

        setState(() {
          isCarregando = false;
          progressoCarregamento = 0.0;
          mensagemProgresso = 'A iniciar...';
        });
      }

    } catch (e) {
      debugPrint('❌ Erro ao atualizar dados do dia: $e');
      if (mounted) {
        setState(() {
          isCarregando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Sempre liberar o lock, mesmo em caso de erro
      _isUpdatingDate = false;
    }
  }

  Future<void> _alocarMedico(String medicoId, String gabineteId,
      {DateTime? dataEspecifica, List<String>? horarios}) async {
    final dataAlvo = dataEspecifica ?? selectedDate;
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

    try {
      // Atualização otimista: cartão aparece no gabinete instantaneamente
      debugPrint(
          '🟢 [ALOCAÇÃO] Executando atualização otimista: médico=$medicoId, gabinete=$gabineteId');

      // Buscar horários da disponibilidade se não foram forçados
      String horarioInicio = '00:00';
      String horarioFim = '00:00';
      if (horarios != null && horarios.length >= 2) {
        horarioInicio = horarios[0];
        horarioFim = horarios[1];
      } else {
        final dispDoDia = disponibilidades.where((disp) {
          final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
          return disp.medicoId == medicoId && dd == dataAlvoNormalizada;
        }).toList();
        if (dispDoDia.isNotEmpty) {
          horarioInicio = dispDoDia.first.horarios[0];
          horarioFim = dispDoDia.first.horarios[1];
        }
      }

      // CORREÇÃO: Verificar se já existe alocação no destino ANTES de atualizar UI
      final alocacoesNoDestino = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteId &&
            aDate == dataAlvoNormalizada;
      }).toList();
      final alocacaoJaExisteNoDestino = alocacoesNoDestino.isNotEmpty;

      if (alocacaoJaExisteNoDestino) {
        debugPrint(
            '⚠️ [ALOCAÇÃO] Alocação já existe no destino, atualizando Firestore diretamente');

        // Encontrar a alocação existente
        final alocacaoExistente = alocacoes.firstWhere((a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == medicoId &&
              a.gabineteId == gabineteId &&
              aDate == dataAlvoNormalizada;
        });

        // Atualizar o Firestore diretamente sem remover e recriar
        try {
          final firestore = FirebaseFirestore.instance;
          final unidadeId = widget.unidade.id;
          final ano = dataAlvoNormalizada.year.toString();
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('alocacoes')
              .doc(ano)
              .collection('registos');

          // Atualizar apenas o gabineteId no Firestore (se necessário)
          await alocacoesRef.doc(alocacaoExistente.id).update({
            'gabineteId': gabineteId,
            'medicoId': medicoId,
            'data': alocacaoExistente.data.toIso8601String(),
            'horarioInicio': alocacaoExistente.horarioInicio,
            'horarioFim': alocacaoExistente.horarioFim,
          });

          debugPrint(
              '✅ [ALOCAÇÃO] Firestore atualizado diretamente (sem remover): ${alocacaoExistente.id}');
        } catch (e) {
          debugPrint('❌ [ALOCAÇÃO] Erro ao atualizar Firestore: $e');
        }

        return;
      }

      // CORREÇÃO: Remover alocações antigas do mesmo médico/dia em OUTROS gabinetes
      // Isso deve ser feito ANTES de adicionar a nova alocação otimista
      // IMPORTANTE: Isso é a ÚNICA modificação que fazemos nas listas antes de chamar atualizarUIAlocarCartaoUnico
      alocacoes.removeWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            aDate == dataAlvoNormalizada &&
            a.gabineteId != gabineteId;
      });

      // NOVO: Usar função reutilizável para atualizar UI
      // Esta função remove o cartão dos desalocados e adiciona ao gabinete de destino
      final uiAtualizada = await atualizarUIAlocarCartaoUnico(
        medicoId: medicoId,
        gabineteId: gabineteId,
        data: dataAlvoNormalizada,
        alocacoes: alocacoes,
        medicosDisponiveis: medicosDisponiveis,
        medicos: medicos,
        setState: () {
          // CORREÇÃO: Criar nova referência da lista dentro do setState
          if (mounted) {
            setState(() {
              // Criar novas referências das listas para forçar detecção de mudança
              alocacoes = List<Alocacao>.from(alocacoes);
              medicosDisponiveis = List<Medico>.from(medicosDisponiveis);
            });
          }
        },
        horarioInicio: horarioInicio,
        horarioFim: horarioFim,
      );

      // O setState já foi chamado dentro do callback de atualizarUIAlocarCartaoUnico

      if (!uiAtualizada) {
        debugPrint(
            '⚠️ [ALOCAÇÃO] Falha ao atualizar UI, continuando mesmo assim...');
      }

      // Invalidar cache antes de salvar no Firestore
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvoNormalizada);

      // Salvar no Firestore
      await logic.AlocacaoMedicosLogic.alocarMedico(
        selectedDate: dataAlvo,
        medicoId: medicoId,
        gabineteId: gabineteId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        onAlocacoesChanged: () {
          // Não recarregar durante processamento
        },
        unidade: widget.unidade,
        horariosForcados: horarios,
      );

      // Invalidar cache após salvar
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataAlvoNormalizada);

      debugPrint('✅ [ALOCAÇÃO] Alocação concluída com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao alocar médico: $e');

      // Em caso de erro, recarregar dados para reverter estado
      debugPrint('🔄 Recarregando dados após erro');
      try {
        await _carregarDadosIniciais();
      } catch (e2) {
        debugPrint('❌ Erro ao recarregar dados após erro: $e2');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Finalização concluída
      debugPrint('✅ [ALOCAÇÃO] FINALLY: Operação finalizada');
    }
  }

  /// Limpa as flags de transição após realocação concluída
  /// Isso garante que o listener seja reativado e a UI volte ao normal
  // Variáveis temporárias para armazenar gabinetes afetados durante realocação
  String? _gabineteOrigemRealocacao;
  String? _gabineteDestinoRealocacao;

  void _limparFlagsTransicao() {
    debugPrint('🔴 [LIMPAR-FLAGS] Limpando flags de transição');

    // Cancelar timeout se ainda estiver ativo
    _timeoutFlagsTransicao?.cancel();
    _timeoutFlagsTransicao = null;

    // CORREÇÃO: Não recarregar após realocação
    // A atualização otimista já moveu a alocação no estado local, e _alocarMedico já atualizou o Firestore.
    // Não há necessidade de recarregar do Firestore, pois isso pode causar race conditions e reverter a mudança.
    if (_gabineteOrigemRealocacao != null &&
        _gabineteDestinoRealocacao != null) {
      debugPrint(
          '✅ [LIMPAR-FLAGS] Realocação completa - não recarregando (atualização otimista + Firestore já atualizados)');
      _gabineteOrigemRealocacao = null;
      _gabineteDestinoRealocacao = null;
    }

    debugPrint('✅ [LIMPAR-FLAGS] Flags limpas');
  }

  /// Atualização otimista durante realocação - atualiza estado local imediatamente
  /// para feedback visual instantâneo antes das operações no Firestore
  void _alocacaoSerieOtimista(
      String medicoId, String gabineteId, DateTime data) {
    debugPrint(
        '🟢 [ALOCAÇÃO-SÉRIE-OTIMISTA] INÍCIO: médico=$medicoId, gabinete=$gabineteId');

    // Atualização otimista durante alocação de série

    // CORREÇÃO: Remover médico dos disponíveis IMEDIATAMENTE
    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Médico não identificado',
        especialidade: '',
        disponibilidades: [],
        ativo: false,
      ),
    );
    if (medicosDisponiveis.contains(medico)) {
      medicosDisponiveis.remove(medico);
      debugPrint(
          '✅ [ALOCAÇÃO-SÉRIE-OTIMISTA] Médico removido dos desalocados: $medicoId');
    }

    // Buscar horários da disponibilidade
    String horarioInicio = '08:00';
    String horarioFim = '15:00';
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final dispDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataNormalizada;
    }).toList();
    if (dispDoDia.isNotEmpty) {
      horarioInicio = dispDoDia.first.horarios[0];
      horarioFim = dispDoDia.first.horarios[1];
    }

    // Criar alocação otimista temporária (será substituída pela real quando a série for alocada)
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dataStr =
        '${dataNormalizada.year}${dataNormalizada.month.toString().padLeft(2, '0')}${dataNormalizada.day.toString().padLeft(2, '0')}';
    final alocacaoOtimista = Alocacao(
      id: 'otimista_serie_${timestamp}_${medicoId}_${gabineteId}_$dataStr',
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataNormalizada,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );

    // Adicionar alocação otimista localmente
    alocacoes.add(alocacaoOtimista);

    // Atualizar UI imediatamente
    if (mounted) {
      setState(() {
        // Estado já foi atualizado acima
      });
    }

    debugPrint(
        '✅ [ALOCAÇÃO-SÉRIE-OTIMISTA] Cartão removido dos desalocados e adicionado ao gabinete');
  }

  void _realocacaoOtimista(String medicoId, String gabineteOrigem,
      String gabineteDestino, DateTime data) {
    debugPrint(
        '🔵 [OTIMISTA] INÍCIO: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino');
    debugPrint('🔵 [OTIMISTA] Estado atual');

    // Armazenar gabinetes afetados para reload focado posterior
    _gabineteOrigemRealocacao = gabineteOrigem;
    _gabineteDestinoRealocacao = gabineteDestino;

    // CORREÇÃO CRÍTICA: Invalidar cache ANTES de fazer realocação otimista
    final dataNormalizada =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
    debugPrint('💾 Cache invalidado antes de realocação otimista');

    // Encontrar todas as alocações do médico no dia do gabinete de origem
    final alocacoesParaMover = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate.year == data.year &&
          aDate.month == data.month &&
          aDate.day == data.day;
    }).toList();

    // CORREÇÃO CRÍTICA: Se não encontrou alocação no gabinete origem (cartão está nos desalocados),
    // criar alocação otimista diretamente no destino
    if (alocacoesParaMover.isEmpty) {
      debugPrint(
          '🟢 [OTIMISTA] Nenhuma alocação encontrada no gabinete origem - cartão está nos desalocados. Criando alocação otimista no destino.');

      // Buscar horários da disponibilidade
      String horarioInicio = '08:00';
      String horarioFim = '15:00';
      final dataNormalizada = DateTime(data.year, data.month, data.day);
      final dispDoDia = disponibilidades.where((disp) {
        final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId && dd == dataNormalizada;
      }).toList();
      if (dispDoDia.isNotEmpty && dispDoDia.first.horarios.length >= 2) {
        horarioInicio = dispDoDia.first.horarios[0];
        horarioFim = dispDoDia.first.horarios[1];
      }

      // Criar alocação otimista temporária no destino
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final dataStr =
          '${dataNormalizada.year}${dataNormalizada.month.toString().padLeft(2, '0')}${dataNormalizada.day.toString().padLeft(2, '0')}';
      final alocacaoOtimista = Alocacao(
        id: 'otimista_realoc_${timestamp}_${medicoId}_${gabineteDestino}_$dataStr',
        medicoId: medicoId,
        gabineteId: gabineteDestino,
        data: dataNormalizada,
        horarioInicio: horarioInicio,
        horarioFim: horarioFim,
      );

      // Adicionar alocação otimista no destino
      alocacoes.add(alocacaoOtimista);
      debugPrint(
          '   - Alocação otimista criada no destino: id=${alocacaoOtimista.id}, gabinete=${alocacaoOtimista.gabineteId}');
    } else {
      // Atualizar cada alocação: remover da origem e adicionar no destino
      debugPrint(
          '🟢 [OTIMISTA] Movendo ${alocacoesParaMover.length} alocação(ões) de $gabineteOrigem para $gabineteDestino');

      for (final aloc in alocacoesParaMover) {
        debugPrint(
            '   - Movendo alocação: id=${aloc.id}, gabinete atual=${aloc.gabineteId}');
        // Remover da lista (será substituída pela nova)
        final removido = alocacoes.remove(aloc);
        debugPrint('   - Removido da lista: $removido');

        // Criar nova alocação com o novo gabinete
        // IMPORTANTE: Manter o mesmo ID para que o Firestore reconheça como atualização, não nova alocação
        final novaAloc = Alocacao(
          id: aloc.id, // Manter o mesmo ID - isso é crítico!
          medicoId: aloc.medicoId,
          gabineteId: gabineteDestino, // NOVO gabinete
          data: aloc.data,
          horarioInicio: aloc.horarioInicio,
          horarioFim: aloc.horarioFim,
        );

        // Adicionar no destino
        alocacoes.add(novaAloc);
        debugPrint(
            '   - Adicionado no destino: id=${novaAloc.id}, novo gabinete=${novaAloc.gabineteId}');
      }
    }

    // Verificar se a atualização foi feita corretamente
    final alocacoesNoDestino = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteDestino &&
          aDate.year == data.year &&
          aDate.month == data.month &&
          aDate.day == data.day;
    }).toList();
    debugPrint(
        '✅ [OTIMISTA] Verificação: ${alocacoesNoDestino.length} alocação(ões) no destino após atualização');

    // CORREÇÃO CRÍTICA: Atualizar médicos disponíveis IMEDIATAMENTE
    _atualizarMedicosDisponiveis().catchError((e) {
      debugPrint(
          '❌ Erro ao atualizar médicos disponíveis após atualização otimista: $e');
    });

    // Atualizar UI imediatamente
    if (mounted) {
      setState(() {
        // Forçar rebuild para mostrar mudança imediata
      });
    }

    debugPrint(
        '✅ Atualização otimista: médico $medicoId movido de $gabineteOrigem para $gabineteDestino (listener pausado)');
  }

  /// Mostra lista de médicos não alocados no ano
  Future<void> _mostrarMedicosNaoAlocadosAno() async {
    double progressoAtual = 0.0;
    StateSetter? setStateDialog;

    try {
      // Mostrar loading com progressbar linear
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              setStateDialog = setState;
              return Center(
                child: Card(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barra de progresso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressoAtual,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                MyAppTheme.azulEscuro),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Percentagem
                        Text(
                          '${(progressoAtual * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('A carregar dados...'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      // Aguardar um frame para garantir que o dialog foi construído
      await Future.delayed(const Duration(milliseconds: 50));

      // Usar o ano visualizado no calendário (pode ser diferente de selectedDate se o usuário navegou sem clicar)
      final ano = _dataCalendarioVisualizada.year;

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2066', 'Início _mostrarMedicosNaoAlocadosAno', {
        'ano': ano,
        'totalMedicos': medicos.length,
        'medicosAtivos': medicos.where((m) => m.ativo).length,
        'medicosIds': medicos.map((m) => m.id).toList(),
      }, hypothesisId: 'A');
      // #endregion

      // Atualizar progresso para 10%
      setStateDialog?.call(() {
        progressoAtual = 0.10;
      });

      // Carregar todas as disponibilidades do ano (séries)
      final todasDisponibilidadesSeries =
          await logic.AlocacaoMedicosLogic.carregarDisponibilidadesDeSeries(
        unidade: widget.unidade,
        anoEspecifico: ano.toString(),
      );

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2078', 'Disponibilidades de séries carregadas', {
        'totalDisponibilidadesSeries': todasDisponibilidadesSeries.length,
        'medicosComDisponibilidadeSeries': todasDisponibilidadesSeries.map((d) => d.medicoId).toSet().length,
        'datasUnicas': todasDisponibilidadesSeries.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}').toSet().length,
      }, hypothesisId: 'B');
      // #endregion

      // Atualizar progresso para 30%
      setStateDialog?.call(() {
        progressoAtual = 0.30;
      });

      // Carregar disponibilidades únicas de todos os médicos para o ano EM PARALELO
      final medicosAtivos = medicos.where((m) => m.ativo).toList();

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2086', 'Médicos ativos identificados', {
        'totalMedicosAtivos': medicosAtivos.length,
        'medicosAtivosIds': medicosAtivos.map((m) => m.id).toList(),
        'medicosAtivosNomes': medicosAtivos.map((m) => m.nome).toList(),
      }, hypothesisId: 'C');
      // #endregion

      final futuresUnicas = medicosAtivos.map((medico) {
        return DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
          medico.id,
          ano,
          widget.unidade,
        ).catchError((e) {
          // #region agent log
          _writeDebugLog('alocacao_medicos_screen.dart:2093', 'Erro ao carregar disponibilidades únicas', {
            'medicoId': medico.id,
            'medicoNome': medico.nome,
            'erro': e.toString(),
          }, hypothesisId: 'D');
          // #endregion
          // Retornar lista vazia em caso de erro
          return <Disponibilidade>[];
        });
      }).toList();

      // Aguardar todas as cargas em paralelo
      final resultadosUnicas = await Future.wait(futuresUnicas);
      final todasDisponibilidadesUnicas = <Disponibilidade>[];
      for (final resultado in resultadosUnicas) {
        todasDisponibilidadesUnicas.addAll(resultado);
      }

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2103', 'Disponibilidades únicas carregadas', {
        'totalDisponibilidadesUnicas': todasDisponibilidadesUnicas.length,
        'medicosComDisponibilidadeUnicas': todasDisponibilidadesUnicas.map((d) => d.medicoId).toSet().length,
      }, hypothesisId: 'E');
      // #endregion

      // Combinar séries e únicas
      final todasDisponibilidades = <Disponibilidade>[];
      todasDisponibilidades.addAll(todasDisponibilidadesSeries);
      todasDisponibilidades.addAll(todasDisponibilidadesUnicas);

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2108', 'Todas disponibilidades combinadas', {
        'totalDisponibilidades': todasDisponibilidades.length,
        'medicosComDisponibilidade': todasDisponibilidades.map((d) => d.medicoId).toSet().length,
        'datasUnicas': todasDisponibilidades.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}').toSet().length,
      }, hypothesisId: 'F');
      // #endregion

      // Atualizar progresso para 50%
      setStateDialog?.call(() {
        progressoAtual = 0.50;
      });

      // CORREÇÃO: Carregar TODAS as alocações do ano diretamente do servidor (sem cache)
      // Usar uma query direta ao Firestore para garantir que carregamos todos os dados do ano
      final firestore = FirebaseFirestore.instance;
      final todasAlocacoes = <Alocacao>[];
      
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(widget.unidade.id)
            .collection('alocacoes')
            .doc(ano.toString())
            .collection('registos');
      
      // Carregar TODAS as alocações do ano do servidor (sem cache)
      final registosSnapshot = await alocacoesRef
          .get(const GetOptions(source: Source.server));
      
        debugPrint('🔍 [MÉDICOS NÃO ALOCADOS] Carregadas ${registosSnapshot.docs.length} alocações do ano $ano do servidor');
        
        // #region agent log
        _writeDebugLog('alocacao_medicos_screen.dart:2128', 'Alocações do servidor carregadas', {
          'totalAlocacoesServidor': registosSnapshot.docs.length,
        }, hypothesisId: 'G');
        // #endregion
        
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          final alocacao = Alocacao.fromMap(data);
          todasAlocacoes.add(alocacao);
        }
        
        // CORREÇÃO CRÍTICA: Gerar alocações de séries para TODO o ano
        // Não usar carregarAlocacoesUnidade com dataFiltroDia porque isso limita apenas para aquele dia
        try {
          final alocacoesGeradasAno = <Alocacao>[];
          
          // Carregar todos os médicos ativos
          final medicosRef = firestore
              .collection('unidades')
              .doc(widget.unidade.id)
              .collection('ocupantes')
              .where('ativo', isEqualTo: true);
          final medicosSnapshot = await medicosRef
              .get(const GetOptions(source: Source.server));
          final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
          
          // Período para gerar alocações (todo o ano)
          final dataInicioAno = DateTime(ano, 1, 1);
          final dataFimAno = DateTime(ano + 1, 1, 1);
          
          // Processar médicos em paralelo
          final futures = <Future<List<Alocacao>>>[];
          for (final medicoId in medicoIds) {
            futures.add((() async {
              // Carregar séries do médico que podem gerar alocações no ano
              // CORREÇÃO CRÍTICA: Carregar TODAS as séries ativas, não apenas as que começam no ano
              // Séries que começaram antes (ex: fevereiro) ainda geram alocações durante o ano
              final series = await SerieService.carregarSeries(
                medicoId,
                unidade: widget.unidade,
                dataInicio: null, // Carregar TODAS as séries ativas
                dataFim: dataFimAno, // Filtrar apenas séries que começam depois do fim do ano
                forcarServidor: true, // Sempre forçar servidor para garantir dados atualizados
              );
              
              // Filtrar apenas séries com gabineteId (que geram alocações)
              final seriesComGabinete = series
                  .where((s) => s.gabineteId != null)
                  .toList();
              
              if (seriesComGabinete.isEmpty) return <Alocacao>[];
              
              // Carregar exceções do médico para o ano
              final excecoes = await SerieService.carregarExcecoes(
                medicoId,
                unidade: widget.unidade,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
                forcarServidor: false,
              );
              
              // Gerar alocações de séries para todo o ano
              return SerieGenerator.gerarAlocacoes(
                series: seriesComGabinete,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
                excecoes: excecoes,
              );
            })());
          }
          
          final resultados = await Future.wait(futures);
          for (final resultado in resultados) {
            alocacoesGeradasAno.addAll(resultado);
          }
          
          debugPrint('🔍 [MÉDICOS NÃO ALOCADOS] Geradas ${alocacoesGeradasAno.length} alocações de séries para o ano $ano');
        
        // #region agent log
        _writeDebugLog('alocacao_medicos_screen.dart:2202', 'Alocações de séries geradas', {
          'totalAlocacoesGeradas': alocacoesGeradasAno.length,
          'medicosComAlocacoesGeradas': alocacoesGeradasAno.map((a) => a.medicoId).toSet().length,
          'datasUnicas': alocacoesGeradasAno.map((a) => '${a.data.year}-${a.data.month}-${a.data.day}').toSet().length,
        }, hypothesisId: 'H');
        // #endregion
        
        // Mesclar evitando duplicados
        final alocacoesMap = <String, Alocacao>{};
        for (final aloc in todasAlocacoes) {
          final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
          alocacoesMap[chave] = aloc;
        }
        for (final aloc in alocacoesGeradasAno) {
          final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
          alocacoesMap[chave] = aloc;
        }
        todasAlocacoes.clear();
        todasAlocacoes.addAll(alocacoesMap.values);
        
        debugPrint('🔍 [MÉDICOS NÃO ALOCADOS] Total após mesclar com séries: ${todasAlocacoes.length} alocações');

        // #region agent log
        _writeDebugLog('alocacao_medicos_screen.dart:2218', 'Alocações mescladas', {
          'totalAlocacoesMescladas': todasAlocacoes.length,
          'medicosComAlocacoes': todasAlocacoes.map((a) => a.medicoId).toSet().length,
          'datasUnicas': todasAlocacoes.map((a) => '${a.data.year}-${a.data.month}-${a.data.day}').toSet().length,
        }, hypothesisId: 'I');
        // #endregion
      } catch (e) {
        debugPrint('⚠️ [MÉDICOS NÃO ALOCADOS] Erro ao carregar alocações de séries: $e');
      }

      // Atualizar progresso para 70%
      setStateDialog?.call(() {
        progressoAtual = 0.70;
      });

      // CORREÇÃO: Identificar médicos com disponibilidade e verificar dia a dia
      // Não excluir médicos que têm pelo menos uma alocação - eles podem ter outros dias não alocados
      final medicosComDisponibilidade = todasDisponibilidades
          .where((d) => d.data.year == ano)
          .map((d) => d.medicoId)
          .toSet();

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2234', 'Médicos com disponibilidade identificados', {
        'totalMedicosComDisponibilidade': medicosComDisponibilidade.length,
        'medicosComDisponibilidadeIds': medicosComDisponibilidade.toList(),
      }, hypothesisId: 'J');
      // #endregion

      // Incluir TODOS os médicos com disponibilidade (não filtrar por terem alocações)
      final medicosNaoAlocadosIds = medicosComDisponibilidade.toList();

      // Buscar informações dos médicos
      final medicosNaoAlocados = medicosNaoAlocadosIds
          .map((id) => medicos.firstWhere(
                (m) => m.id == id,
                orElse: () => Medico(
                  id: id,
                  nome: 'Desconhecido',
                  especialidade: '',
                  disponibilidades: [],
                  ativo: false,
                ),
              ))
          .where((m) => m.ativo && m.nome != 'Desconhecido')
          .toList();

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2252', 'Médicos não alocados após filtro', {
        'totalMedicosNaoAlocados': medicosNaoAlocados.length,
        'medicosNaoAlocadosIds': medicosNaoAlocados.map((m) => m.id).toList(),
        'medicosNaoAlocadosNomes': medicosNaoAlocados.map((m) => m.nome).toList(),
      }, hypothesisId: 'K');
      // #endregion

      // Ordenar por nome
      medicosNaoAlocados.sort((a, b) => a.nome.compareTo(b.nome));

      // Contar dias com disponibilidade mas sem alocação por médico e guardar as datas
      final medicosComDias = <String, int>{};
      final medicosComDatas = <String, List<DateTime>>{};
      
      int totalMedicos = medicosNaoAlocadosIds.length;
      int processedMedicos = 0;
      
      for (final medicoId in medicosNaoAlocadosIds) {
        // #region agent log
        final todasDisponibilidadesMedico = todasDisponibilidades
            .where((d) => d.medicoId == medicoId && d.data.year == ano)
            .toList();
        final todasAlocacoesMedico = todasAlocacoes
            .where((a) => a.medicoId == medicoId && a.data.year == ano)
            .toList();
        // #endregion

        final diasComDisponibilidade = todasDisponibilidades
            .where((d) =>
                d.medicoId == medicoId &&
                d.data.year == ano &&
                !todasAlocacoes.any((a) =>
                    a.medicoId == medicoId &&
                    a.data.year == d.data.year &&
                    a.data.month == d.data.month &&
                    a.data.day == d.data.day))
            .map((d) => DateTime(d.data.year, d.data.month, d.data.day))
            .toSet()
            .toList();
        diasComDisponibilidade.sort();
        medicosComDias[medicoId] = diasComDisponibilidade.length;
        medicosComDatas[medicoId] = diasComDisponibilidade;

        // #region agent log
        final medicoNome = medicos.firstWhere((m) => m.id == medicoId, orElse: () => Medico(id: medicoId, nome: 'Desconhecido', especialidade: '', disponibilidades: [], ativo: false)).nome;
        _writeDebugLog('alocacao_medicos_screen.dart:2265', 'Processando médico', {
          'medicoId': medicoId,
          'medicoNome': medicoNome,
          'totalDisponibilidadesMedico': todasDisponibilidadesMedico.length,
          'totalAlocacoesMedico': todasAlocacoesMedico.length,
          'diasComDisponibilidadeNaoAlocados': diasComDisponibilidade.length,
          'datasDisponibilidades': todasDisponibilidadesMedico.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}').toSet().toList(),
          'datasAlocacoes': todasAlocacoesMedico.map((a) => '${a.data.year}-${a.data.month}-${a.data.day}').toSet().toList(),
          'datasNaoAlocadas': diasComDisponibilidade.map((d) => '${d.year}-${d.month}-${d.day}').toList(),
        }, hypothesisId: 'L');
        // #endregion
        
        // Atualizar progresso durante processamento (70% -> 95%)
        processedMedicos++;
        if (totalMedicos > 0) {
          final progressoProcessamento = 0.70 + (processedMedicos / totalMedicos) * 0.25;
          setStateDialog?.call(() {
            progressoAtual = progressoProcessamento.clamp(0.0, 0.95);
          });
        }
      }
      
      // CORREÇÃO: Filtrar apenas médicos que realmente têm dias não alocados
      final medicosComDiasNaoAlocados = medicosNaoAlocados
          .where((m) => (medicosComDias[m.id] ?? 0) > 0)
          .toList();

      // #region agent log
      _writeDebugLog('alocacao_medicos_screen.dart:2294', 'Resultado final', {
        'totalMedicosComDiasNaoAlocados': medicosComDiasNaoAlocados.length,
        'medicosComDiasNaoAlocados': medicosComDiasNaoAlocados.map((m) => {
          'id': m.id,
          'nome': m.nome,
          'diasNaoAlocados': medicosComDias[m.id] ?? 0,
        }).toList(),
        'resumoDias': medicosComDias.entries.map((e) => {
          'medicoId': e.key,
          'dias': e.value,
        }).toList(),
      }, hypothesisId: 'M');
      // #endregion
      
      // Finalizar progresso: 95% -> 100%
      setStateDialog?.call(() {
        progressoAtual = 1.0;
      });
      
      // Aguardar um pouco para mostrar 100% antes de fechar
      await Future.delayed(const Duration(milliseconds: 200));

      // Fechar loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar diálogo com a lista
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            title: Stack(
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Médicos Não Alocados ($ano)'),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
                child: medicosComDiasNaoAlocados.isEmpty
                    ? const Text('Não há médicos não alocados no ano.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: medicosComDiasNaoAlocados.length,
                        itemBuilder: (context, index) {
                          final medico = medicosComDiasNaoAlocados[index];
                          final numDias = medicosComDias[medico.id] ?? 0;
                          final datas = medicosComDatas[medico.id] ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Coluna esquerda: Avatar e informações (clicável para editar)
                                  Expanded(
                                    flex: 3,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop(); // Fechar diálogo atual
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CadastroMedico(
                                              medico: medico,
                                              unidade: widget.unidade,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor:
                                                    Colors.blue.shade100,
                                                radius: 20,
                                                child: Text(
                                                  medico.nome[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      medico.nome,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      medico.especialidade
                                                              .isNotEmpty
                                                          ? medico.especialidade
                                                          : "Sem especialidade",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey.shade600,
                                                      ),
                                                    ),
                                                    Text(
                                                      '$numDias ${numDias == 1 ? "dia" : "dias"} não alocados',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Coluna direita: Dias clicáveis
                                  Expanded(
                                    flex: 2,
                                    child: SingleChildScrollView(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        children: datas.take(10).map((data) {
                                          return InkWell(
                                            onTap: () {
                                              Navigator.of(context).pop();
                                              // Garantir que a data está normalizada corretamente (sem horas/minutos/segundos)
                                              final dataNormalizada = DateTime(
                                                  data.year,
                                                  data.month,
                                                  data.day);
                                              _onDateChanged(dataNormalizada);
                                            },
                                            child: Chip(
                                              label: Text(
                                                '${data.day}/${data.month}',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              ),
                                              backgroundColor:
                                                  Colors.blue.shade50,
                                              side: BorderSide(
                                                  color: Colors.blue.shade200),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
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
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Fechar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  /// Mostra lista de conflitos de gabinete no ano
  Future<void> _mostrarConflitosAno() async {
    double progressoAtual = 0.0;
    StateSetter? setStateDialog;

    try {
      // Mostrar loading com progressbar linear
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              setStateDialog = setState;
              return Center(
                child: Card(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barra de progresso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressoAtual,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                MyAppTheme.azulEscuro),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Percentagem
                        Text(
                          '${(progressoAtual * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('A carregar conflitos...'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      // Aguardar um frame para garantir que o dialog foi construído
      await Future.delayed(const Duration(milliseconds: 50));

      // Usar o ano visualizado no calendário (pode ser diferente de selectedDate se o usuário navegou sem clicar)
      final ano = _dataCalendarioVisualizada.year;

      // Atualizar progresso para 10%
      setStateDialog?.call(() {
        progressoAtual = 0.10;
      });

      // CORREÇÃO: Carregar TODAS as alocações do ano diretamente do servidor (sem cache)
      // Usar uma query direta ao Firestore para garantir que carregamos todos os dados do ano
      final firestore = FirebaseFirestore.instance;
      final todasAlocacoes = <Alocacao>[];
      
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(widget.unidade.id)
          .collection('alocacoes')
          .doc(ano.toString())
          .collection('registos');
      
      // Carregar TODAS as alocações do ano do servidor (sem cache)
      final registosSnapshot = await alocacoesRef
          .get(const GetOptions(source: Source.server));
      
        debugPrint('🔍 [CONFLITOS] Carregadas ${registosSnapshot.docs.length} alocações do ano $ano do servidor');
        
        for (final doc in registosSnapshot.docs) {
          final data = doc.data();
          final alocacao = Alocacao.fromMap(data);
          todasAlocacoes.add(alocacao);
        }
        
        // CORREÇÃO CRÍTICA: Gerar alocações de séries para TODO o ano
        // Não usar carregarAlocacoesUnidade com dataFiltroDia porque isso limita apenas para aquele dia
        try {
          final alocacoesGeradasAno = <Alocacao>[];
          
          // Carregar todos os médicos ativos
          final medicosRef = firestore
              .collection('unidades')
              .doc(widget.unidade.id)
              .collection('ocupantes')
              .where('ativo', isEqualTo: true);
          final medicosSnapshot = await medicosRef
              .get(const GetOptions(source: Source.server));
          final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();
          
          // Período para gerar alocações (todo o ano)
          final dataInicioAno = DateTime(ano, 1, 1);
          final dataFimAno = DateTime(ano + 1, 1, 1);
          
          // Processar médicos em paralelo
          final futures = <Future<List<Alocacao>>>[];
          for (final medicoId in medicoIds) {
            futures.add((() async {
              // Carregar séries do médico que podem gerar alocações no ano
              // CORREÇÃO CRÍTICA: Carregar TODAS as séries ativas, não apenas as que começam no ano
              // Séries que começaram antes (ex: fevereiro) ainda geram alocações durante o ano
              final series = await SerieService.carregarSeries(
                medicoId,
                unidade: widget.unidade,
                dataInicio: null, // Carregar TODAS as séries ativas
                dataFim: dataFimAno, // Filtrar apenas séries que começam depois do fim do ano
                forcarServidor: true, // Sempre forçar servidor para garantir dados atualizados
              );
              
              // Filtrar apenas séries com gabineteId (que geram alocações)
              final seriesComGabinete = series
                  .where((s) => s.gabineteId != null)
                  .toList();
              
              if (seriesComGabinete.isEmpty) return <Alocacao>[];
              
              // Carregar exceções do médico para o ano
              final excecoes = await SerieService.carregarExcecoes(
                medicoId,
                unidade: widget.unidade,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
                forcarServidor: false,
              );
              
              // Gerar alocações de séries para todo o ano
              return SerieGenerator.gerarAlocacoes(
                series: seriesComGabinete,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
                excecoes: excecoes,
              );
            })());
          }
          
          final resultados = await Future.wait(futures);
          for (final resultado in resultados) {
            alocacoesGeradasAno.addAll(resultado);
          }
          
          debugPrint('🔍 [CONFLITOS] Geradas ${alocacoesGeradasAno.length} alocações de séries para o ano $ano');
        
        // Mesclar evitando duplicados
        final alocacoesMap = <String, Alocacao>{};
        for (final aloc in todasAlocacoes) {
          final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
          alocacoesMap[chave] = aloc;
        }
        for (final aloc in alocacoesGeradasAno) {
          final chave = '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}_${aloc.horarioInicio}_${aloc.horarioFim}';
          alocacoesMap[chave] = aloc;
        }
        todasAlocacoes.clear();
        todasAlocacoes.addAll(alocacoesMap.values);
        
        debugPrint('🔍 [CONFLITOS] Total após mesclar com séries: ${todasAlocacoes.length} alocações');
      } catch (e) {
        debugPrint('⚠️ [CONFLITOS] Erro ao carregar alocações de séries: $e');
      }

      // Atualizar progresso para 40%
      setStateDialog?.call(() {
        progressoAtual = 0.40;
      });

      // Agrupar alocações por gabinete e data
      final alocacoesPorGabineteEData = <String, List<Alocacao>>{};
      for (final aloc in todasAlocacoes) {
        if (aloc.data.year == ano) {
          final chave =
              '${aloc.gabineteId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
          alocacoesPorGabineteEData.putIfAbsent(chave, () => []).add(aloc);
        }
      }

      // Atualizar progresso para 50%
      setStateDialog?.call(() {
        progressoAtual = 0.50;
      });

      // Identificar conflitos
      final conflitos = <Map<String, dynamic>>[];
      int totalEntries = alocacoesPorGabineteEData.length;
      int processedEntries = 0;

      for (final entry in alocacoesPorGabineteEData.entries) {
        final alocs = entry.value;
        
        // CORREÇÃO: Remover alocações otimistas quando há alocações reais correspondentes
        // Isso previne conflitos falsos causados por alocações otimistas duplicadas
        // Também remover duplicados exatos (mesma alocação com IDs diferentes)
        final alocacoesFiltradas = <Alocacao>[];
        final chavesAdicionadas = <String>{};
        
        for (final aloc in alocs) {
          // Criar chave única baseada em médico, gabinete, data e horários
          final chave = '${aloc.medicoId}_${aloc.gabineteId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.horarioInicio}_${aloc.horarioFim}';
          
          // Se já existe uma alocação com esta chave, verificar qual manter
          if (chavesAdicionadas.contains(chave)) {
            // Já existe uma alocação idêntica - verificar se devemos substituir
            final indiceExistente = alocacoesFiltradas.indexWhere((a) {
              return a.medicoId == aloc.medicoId &&
                  a.gabineteId == aloc.gabineteId &&
                  a.data.year == aloc.data.year &&
                  a.data.month == aloc.data.month &&
                  a.data.day == aloc.data.day &&
                  a.horarioInicio == aloc.horarioInicio &&
                  a.horarioFim == aloc.horarioFim;
            });
            
            if (indiceExistente >= 0) {
              final existente = alocacoesFiltradas[indiceExistente];
              // Priorizar alocações reais sobre otimistas
              if (aloc.id.startsWith('otimista_serie_') &&
                  !existente.id.startsWith('otimista_')) {
                // Nova é otimista e existente é real - manter a existente (real)
                continue; // Não adicionar a otimista
              } else if (!aloc.id.startsWith('otimista_') &&
                  existente.id.startsWith('otimista_serie_')) {
                // Nova é real e existente é otimista - substituir pela real
                alocacoesFiltradas[indiceExistente] = aloc;
                continue;
              } else {
                // Ambas são do mesmo tipo - manter a primeira (evitar duplicação)
                continue;
              }
            }
          }
          
          // Se é otimista, verificar se há alocação real correspondente
          if (aloc.id.startsWith('otimista_serie_')) {
            final temAlocacaoReal = alocs.any((a) {
              return a != aloc && // Não comparar com ela mesma
                  !a.id.startsWith('otimista_') &&
                  a.medicoId == aloc.medicoId &&
                  a.gabineteId == aloc.gabineteId &&
                  a.data.year == aloc.data.year &&
                  a.data.month == aloc.data.month &&
                  a.data.day == aloc.data.day &&
                  a.horarioInicio == aloc.horarioInicio &&
                  a.horarioFim == aloc.horarioFim;
            });
            // Se há alocação real, ignorar a otimista (não adicionar à lista)
            if (temAlocacaoReal) {
              continue;
            }
          }
          
          // Adicionar à lista filtrada
          alocacoesFiltradas.add(aloc);
          chavesAdicionadas.add(chave);
        }
        
        // Usar lista filtrada para verificar conflitos
        if (alocacoesFiltradas.length >= 2 && ConflictUtils.temConflitoGabinete(alocacoesFiltradas)) {
          // Encontrar pares em conflito
          for (int i = 0; i < alocacoesFiltradas.length; i++) {
            for (int j = i + 1; j < alocacoesFiltradas.length; j++) {
              // CORREÇÃO: Não reportar conflito se for o mesmo médico (evita "conflito consigo mesmo")
              if (alocacoesFiltradas[i].medicoId == alocacoesFiltradas[j].medicoId) {
                continue;
              }
              
              if (ConflictUtils.temConflitoEntre(alocacoesFiltradas[i], alocacoesFiltradas[j])) {
                final medico1 = medicos.firstWhere(
                  (m) => m.id == alocacoesFiltradas[i].medicoId,
                  orElse: () => Medico(
                    id: alocacoesFiltradas[i].medicoId,
                    nome: 'Desconhecido',
                    especialidade: '',
                    disponibilidades: [],
                    ativo: false,
                  ),
                );
                final medico2 = medicos.firstWhere(
                  (m) => m.id == alocacoesFiltradas[j].medicoId,
                  orElse: () => Medico(
                    id: alocacoesFiltradas[j].medicoId,
                    nome: 'Desconhecido',
                    especialidade: '',
                    disponibilidades: [],
                    ativo: false,
                  ),
                );
                final gabinete = gabinetes.firstWhere(
                  (g) => g.id == alocacoesFiltradas[i].gabineteId,
                  orElse: () => Gabinete(
                    id: alocacoesFiltradas[i].gabineteId,
                    setor: '',
                    nome: alocacoesFiltradas[i].gabineteId,
                    especialidadesPermitidas: [],
                  ),
                );
                conflitos.add({
                  'gabinete': gabinete,
                  'data': alocacoesFiltradas[i].data,
                  'medico1': medico1,
                  'horario1':
                      '${alocacoesFiltradas[i].horarioInicio} - ${alocacoesFiltradas[i].horarioFim}',
                  'medico2': medico2,
                  'horario2':
                      '${alocacoesFiltradas[j].horarioInicio} - ${alocacoesFiltradas[j].horarioFim}',
                });
              }
            }
          }
        }

        // Atualizar progresso durante processamento (50% -> 95%)
        processedEntries++;
        if (totalEntries > 0) {
          final progressoProcessamento =
              0.50 + (processedEntries / totalEntries) * 0.45;
          setStateDialog?.call(() {
            progressoAtual = progressoProcessamento.clamp(0.0, 0.95);
          });
        }
      }

      // Finalizar progresso: 95% -> 100%
      setStateDialog?.call(() {
        progressoAtual = 1.0;
      });

      // Aguardar um pouco para mostrar 100%
      await Future.delayed(const Duration(milliseconds: 200));

      // Fechar loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Ordenar por data e depois por gabinete
      conflitos.sort((a, b) {
        final dataA = a['data'] as DateTime;
        final dataB = b['data'] as DateTime;
        final cmpData = dataA.compareTo(dataB);
        if (cmpData != 0) return cmpData;
        final gabA = a['gabinete'] as Gabinete;
        final gabB = b['gabinete'] as Gabinete;
        return gabA.nome.compareTo(gabB.nome);
      });

      // Mostrar diálogo com a lista
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            title: Stack(
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Conflitos de Gabinete ($ano)'),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              child: conflitos.isEmpty
                  ? const Text('Não há conflitos no ano.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: conflitos.length,
                      itemBuilder: (context, index) {
                        final conflito = conflitos[index];
                        final gabinete = conflito['gabinete'] as Gabinete;
                        final data = conflito['data'] as DateTime;
                        final medico1 = conflito['medico1'] as Medico;
                        final horario1 = conflito['horario1'] as String;
                        final medico2 = conflito['medico2'] as Medico;
                        final horario2 = conflito['horario2'] as String;
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            // Garantir que a data está normalizada corretamente (sem horas/minutos/segundos)
                            final dataNormalizada =
                                DateTime(data.year, data.month, data.day);

                            debugPrint(
                                '🔍 [DEBUG] Clicou em conflito - navegando para data: ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year} (selectedDate antes: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year})');

                            _onDateChanged(dataNormalizada);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.red.shade50,
                            child: ListTile(
                              leading:
                                  const Icon(Icons.error, color: Colors.red),
                              title: Text(
                                '${gabinete.nome} - ${data.day}/${data.month}/${data.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${medico1.nome}: $horario1'),
                                  Text('${medico2.nome}: $horario2'),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Fechar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    // Encontrar todas as alocações do médico no dia selecionado
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final alocacoesDoDia = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    }).toList();

    if (alocacoesDoDia.isEmpty) {
      return; // Não há alocação para desalocar
    }

    // Encontrar a disponibilidade para verificar o tipo
    // Primeiro tenta encontrar no dia selecionado
    var disponibilidade = disponibilidades
            .where(
              (d) =>
                  d.medicoId == medicoId &&
                  d.data.year == selectedDate.year &&
                  d.data.month == selectedDate.month &&
                  d.data.day == selectedDate.day,
            )
            .isNotEmpty
        ? disponibilidades
            .where(
              (d) =>
                  d.medicoId == medicoId &&
                  d.data.year == selectedDate.year &&
                  d.data.month == selectedDate.month &&
                  d.data.day == selectedDate.day,
            )
            .first
        : null;

    // OTIMIZAÇÃO: Verificar primeiro na lista local antes de buscar no Firebase
    // Isso evita buscas pesadas desnecessárias quando é claramente uma alocação única
    final alocacoesLocaisDoMedico = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    }).toList();

    // Se há apenas uma alocação local e não há disponibilidade de série, pode ser única
    bool podeSerSerieLocal = false;
    if (alocacoesLocaisDoMedico.length == 1) {
      // Verificar se há outras alocações do mesmo médico em outras datas (na lista local)
      final outrasAlocacoes = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate != dataAlvo;
      }).toList();

      // Verificar se há disponibilidade de série
      final temDisponibilidadeSerie = disponibilidades.any((d) =>
          d.medicoId == medicoId &&
          (d.tipo == 'Semanal' ||
              d.tipo == 'Quinzenal' ||
              d.tipo == 'Mensal' ||
              d.tipo.startsWith('Consecutivo')));

      podeSerSerieLocal = outrasAlocacoes.isNotEmpty || temDisponibilidadeSerie;
    }

    // OTIMIZAÇÃO: Usar lista local quando possível para evitar buscas pesadas no Firebase
    // A lista local já contém todas as alocações do dia selecionado e pode conter outras
    List<Alocacao> alocacoesMedicoFirebase = [];

    // Se há apenas uma alocação local e não há disponibilidade de série, pode ser única
    if (alocacoesLocaisDoMedico.length == 1 && !podeSerSerieLocal) {
      debugPrint(
          '⚡ Pulando busca no Firebase - alocação única detectada (otimização)');
      // Usar apenas a lista local para verificação
      alocacoesMedicoFirebase = alocacoesLocaisDoMedico;
    } else {
      // OTIMIZAÇÃO: Usar lista local primeiro (contém todas as alocações já carregadas)
      // Apenas buscar no Firebase se realmente necessário (quando há indicação de série)
      final alocacoesLocaisDoMedicoTodas = alocacoes.where((a) {
        return a.medicoId == medicoId;
      }).toList();

      // (a lista local já contém todas as alocações do dia selecionado e pode ter outras)
      if (alocacoesLocaisDoMedicoTodas.length > 1 || podeSerSerieLocal) {
        debugPrint(
            '⚡ Usando lista local para verificação (${alocacoesLocaisDoMedicoTodas.length} alocações encontradas)');
        alocacoesMedicoFirebase = alocacoesLocaisDoMedicoTodas;
      } else {
        // OTIMIZAÇÃO: Usar lista local que já contém todas as alocações carregadas
        // Evita busca adicional no Firebase quando não necessário
        debugPrint(
            '⚡ Usando lista local para verificação (otimização - evitando busca no Firebase)');
        alocacoesMedicoFirebase = alocacoesLocaisDoMedicoTodas;
      }
    }

    // Verificar se há outras alocações do mesmo médico em datas futuras ou passadas
    // que possam indicar uma série
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

    final alocacoesFuturas = alocacoesMedicoFirebase.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
      return aDateNormalizada.isAfter(dataAlvoNormalizada);
    }).toList();

    final alocacoesPassadas = alocacoesMedicoFirebase.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
      return aDateNormalizada.isBefore(dataAlvoNormalizada);
    }).toList();

    bool temAlocacoesFuturas = alocacoesFuturas.isNotEmpty;
    bool temAlocacoesPassadas = alocacoesPassadas.isNotEmpty;
    bool podeSerSerie = temAlocacoesFuturas || temAlocacoesPassadas;

    debugPrint('🔍 Verificando desalocação para médico $medicoId');
    debugPrint(
        '  📅 Data alvo: ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');
    debugPrint(
        '  📊 Alocações futuras encontradas: ${alocacoesFuturas.length}');
    debugPrint(
        '  📊 Alocações passadas encontradas: ${alocacoesPassadas.length}');
    debugPrint('  🔄 Pode ser série: $podeSerSerie');
    if (alocacoesFuturas.isNotEmpty) {
      debugPrint('  📅 Próximas alocações:');
      for (var a in alocacoesFuturas.take(5)) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year}');
      }
    }
    if (alocacoesPassadas.isNotEmpty) {
      debugPrint('  📅 Alocações passadas:');
      for (var a in alocacoesPassadas.take(5)) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year}');
      }
    }

    // Se pode ser série (há alocações futuras/passadas), buscar o tipo correto da série
    // mesmo que a disponibilidade encontrada no dia seja "Única"
    String tipoSerie = 'Única';
    if (podeSerSerie) {
      debugPrint('  🔍 Pode ser série, buscando tipo correto da série...');
      // Tentar encontrar uma disponibilidade do médico que seja de série
      final dispSerieList = disponibilidades
          .where((d) =>
              d.medicoId == medicoId &&
              (d.tipo == 'Semanal' ||
                  d.tipo == 'Quinzenal' ||
                  d.tipo == 'Mensal' ||
                  d.tipo.startsWith('Consecutivo')))
          .toList();

      if (dispSerieList.isNotEmpty) {
        tipoSerie = dispSerieList.first.tipo;
        debugPrint('  ✅ Tipo de série encontrado: $tipoSerie');
        // Atualizar o tipo da disponibilidade para o tipo correto da série
        if (disponibilidade == null) {
          disponibilidade = Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: tipoSerie,
          );
        } else if (disponibilidade.tipo == 'Única') {
          // Se a disponibilidade encontrada é "Única" mas há uma série, usar o tipo da série
          disponibilidade = Disponibilidade(
            id: disponibilidade.id,
            medicoId: disponibilidade.medicoId,
            data: disponibilidade.data,
            horarios: disponibilidade.horarios,
            tipo: tipoSerie,
          );
          debugPrint('  🔄 Tipo atualizado de "Única" para "$tipoSerie"');
        }
      } else {
        debugPrint(
            '  ⚠️ Nenhuma disponibilidade de série encontrada, tentando inferir do padrão das alocações...');
        // Tentar inferir o tipo da série analisando o padrão das alocações
        if (alocacoesFuturas.isNotEmpty) {
          final primeiraFutura = alocacoesFuturas.first;
          final primeiraFuturaDate = DateTime(primeiraFutura.data.year,
              primeiraFutura.data.month, primeiraFutura.data.day);
          final diasDiferenca =
              primeiraFuturaDate.difference(dataAlvoNormalizada).inDays;

          if (diasDiferenca == 7 || diasDiferenca % 7 == 0) {
            tipoSerie = 'Semanal';
            debugPrint(
                '  ✅ Tipo inferido: Semanal (diferença de $diasDiferenca dias)');
          } else if (diasDiferenca == 14 || diasDiferenca % 14 == 0) {
            tipoSerie = 'Quinzenal';
            debugPrint(
                '  ✅ Tipo inferido: Quinzenal (diferença de $diasDiferenca dias)');
          } else if (primeiraFuturaDate.day == dataAlvoNormalizada.day) {
            tipoSerie = 'Mensal';
            debugPrint('  ✅ Tipo inferido: Mensal (mesmo dia do mês)');
          }

          // Atualizar a disponibilidade com o tipo inferido
          if (tipoSerie != 'Única') {
            disponibilidade = disponibilidade ??
                Disponibilidade(
                  id: '',
                  medicoId: '',
                  data: DateTime(1900, 1, 1),
                  horarios: [],
                  tipo: tipoSerie,
                );
            if (disponibilidade.tipo == 'Única') {
              disponibilidade = Disponibilidade(
                id: disponibilidade.id,
                medicoId: disponibilidade.medicoId,
                data: disponibilidade.data,
                horarios: disponibilidade.horarios,
                tipo: tipoSerie,
              );
              debugPrint(
                  '  🔄 Tipo atualizado de "Única" para "$tipoSerie" (inferido)');
            }
          }
        }
      }
    } else if (disponibilidade == null || disponibilidade.medicoId.isEmpty) {
      debugPrint('  ⚠️ Disponibilidade não encontrada no dia selecionado');
      disponibilidade = disponibilidade ??
          Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: 'Única',
          );
    } else {
      debugPrint(
          '  ✅ Disponibilidade encontrada no dia: tipo = ${disponibilidade.tipo}');
    }

    // Garantir que disponibilidade não é null
    final disponibilidadeFinal = disponibilidade ??
        Disponibilidade(
          id: '',
          medicoId: '',
          data: DateTime(1900, 1, 1),
          horarios: [],
          tipo: podeSerSerie ? tipoSerie : 'Única',
        );

    String? escolha;
    final tipoDisponibilidade = disponibilidadeFinal.tipo;
    debugPrint('  📋 Tipo final da disponibilidade: $tipoDisponibilidade');
    debugPrint('  🔄 Tem alocações futuras: $temAlocacoesFuturas');

    // Verificar se é um tipo de série
    final eTipoSerie = tipoDisponibilidade == 'Semanal' ||
        tipoDisponibilidade == 'Quinzenal' ||
        tipoDisponibilidade == 'Mensal' ||
        tipoDisponibilidade.startsWith('Consecutivo');

    debugPrint('  🔄 É tipo de série: $eTipoSerie');
    debugPrint(
        '  📊 Total de alocações do médico: ${alocacoes.where((a) => a.medicoId == medicoId).length}');
    debugPrint('  📊 Todas as alocações do médico:');
    for (var a in alocacoes.where((a) => a.medicoId == medicoId).take(10)) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      debugPrint(
          '    - ${aDate.day}/${aDate.month}/${aDate.year} (gabinete: ${a.gabineteId})');
    }

    // Se é tipo único E não há alocações futuras/passadas (não pode ser série), desalocar diretamente
    // O gesto do utilizador de arrastar o cartão para a área de desalocados já é suficiente para confirmar
    // Caso contrário (tipo série OU pode ser série), sempre perguntar se quer desalocar apenas o dia ou toda a série
    if (!eTipoSerie && tipoDisponibilidade == 'Única' && !podeSerSerie) {
      debugPrint(
          '  ℹ️ Disponibilidade única sem alocações futuras/passadas - desalocando diretamente (sem diálogo)');

      // Para disponibilidade única, desalocar diretamente usando a função reutilizável
      if (!mounted) return;

      final sucesso = await desalocarCartaoUnico(
        medicoId: medicoId,
        data: selectedDate,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        unidade: widget.unidade,
        setState: () {
          if (mounted) setState(() {});
        },
        recarregarAlocacoesGabinetes: _recarregarAlocacoesGabinetes,
        recarregarDesalocados: _recarregarDesalocados,
      );

      if (sucesso) {
        debugPrint('✅ [DESALOCAÇÃO] Cartão único desalocado com sucesso');
      } else {
        debugPrint('❌ [DESALOCAÇÃO] Erro ao desalocar cartão único');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao desalocar médico'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      return; // Retornar imediatamente após desalocar (não precisa processar escolha)
    } else {
      debugPrint(
          '  ❓ Mostrando diálogo para escolher entre desalocar apenas o dia ou toda a série');

      // Para disponibilidade em série ou quando há alocações futuras/passadas, perguntar se quer desalocar apenas um dia ou toda a série
      String mensagem;
      if (podeSerSerie && tipoDisponibilidade == 'Única') {
        mensagem =
            'Este médico tem outras alocações em datas futuras ou passadas.\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série?';
      } else {
        mensagem = 'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série a partir deste?';
      }

      if (!mounted) return;
      escolha = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Desalocação'),
          content: Text(mensagem),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, '1dia'),
              child: const Text('Apenas este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'serie'),
              child: const Text('Toda a série'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }

    if (escolha == '1dia') {
      await _desalocarMedicoDiaUnico(medicoId);
    } else if (escolha == 'serie') {
      await _desalocarMedicoSerie(medicoId, tipoDisponibilidade);
    }
  }

  Future<void> _desalocarMedicoDiaUnico(String medicoId) async {
    try {
      // CORREÇÃO CRÍTICA: Encontrar gabinete de origem ANTES de desalocar
      final dataNormalizada =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      final alocacaoAntesRemover = alocacoes.firstWhere(
        (a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == medicoId && aDate == dataNormalizada;
        },
        orElse: () => Alocacao(
          id: '',
          medicoId: '',
          gabineteId: '',
          data: DateTime(1900, 1, 1),
          horarioInicio: '',
          horarioFim: '',
        ),
      );

      final gabineteOrigem = alocacaoAntesRemover.gabineteId;
      debugPrint(
          '🔍 [DESALOCAÇÃO] Gabinete de origem encontrado: $gabineteOrigem');

      // CORREÇÃO CRÍTICA: Invalidar cache ANTES de desalocar
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);

      await logic.AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
        selectedDate: selectedDate,
        medicoId: medicoId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: () {
          // CORREÇÃO: NÃO recarregar dados aqui - isso sobrescreve a atualização de médicos disponíveis
          // A atualização será feita manualmente após a desalocação
        },
        unidade: widget.unidade,
      );

      // CORREÇÃO CRÍTICA: Invalidar cache APÓS desalocar também
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      debugPrint('💾 Cache invalidado após desalocação');

      // CORREÇÃO CRÍTICA: Atualizar médicos disponíveis

      // CORREÇÃO CRÍTICA: Invalidar cache APÓS desalocar também
      logic.AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
      debugPrint('💾 Cache invalidado após desalocação');

      // CORREÇÃO CRÍTICA: Atualizar médicos disponíveis

      // Aguardar um pouco para garantir que a desalocação foi processada
      await Future.delayed(const Duration(milliseconds: 300));

      // TESTE 3: Desalocar cartão - deve atualizar apenas gabinete de saída e caixa de desalocação
      if (gabineteOrigem.isNotEmpty) {
        // RELOAD FOCADO: Recarregar apenas o gabinete de saída (onde o cartão saiu) e desalocados (onde entrou)
        await _recarregarAlocacoesGabinetes([gabineteOrigem]);
        await _recarregarDesalocados();

        debugPrint(
            '✅ [DESALOCAÇÃO] Reload focado: gabinete $gabineteOrigem e desalocados atualizados');
      } else {
        await _recarregarDesalocados();
      }

      // Forçar atualização da UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao desalocar médico: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _desalocarMedicoSerie(String medicoId, String tipo) async {
    // Iniciar progress bar
    if (mounted) {
      setState(() {
        _isDesalocandoSerie = true;
        _progressoDesalocacao = 0.0;
        _mensagemDesalocacao = 'A iniciar desalocação...';
      });
    }

    try {
      final sucesso = await desalocarCartaoSerie(
        medicoId: medicoId,
        data: selectedDate,
        tipo: tipo,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        unidade: widget.unidade,
        setState: () {
          if (mounted) setState(() {});
        },
        recarregarAlocacoesGabinetes: _recarregarAlocacoesGabinetes,
        recarregarDesalocados: _recarregarDesalocados,
        onProgresso: (progresso, mensagem) {
          if (mounted) {
            setState(() {
              _progressoDesalocacao = progresso;
              _mensagemDesalocacao = mensagem;
            });
          }
        },
        context: context,
      );

      if (!sucesso) {
        throw Exception('Falha ao desalocar série');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desalocar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ocultar progress bar
      if (mounted) {
        setState(() {
          _isDesalocandoSerie = false;
          _progressoDesalocacao = 0.0;
          _mensagemDesalocacao = 'A iniciar...';
        });
      }
    }
  }

  Widget _buildEmptyStateOrContent() {
    // Se está carregando, não mostrar nada aqui (o overlay principal já mostra a barra de progresso)
    // Isso evita duplicação de barras de progresso
    if (isCarregando) {
      return const SizedBox
          .shrink(); // Widget vazio - o overlay principal mostra o progresso
    }

    if (gabinetes.isEmpty && medicos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Bem-vindo à ${widget.unidade.nome}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta unidade ainda não tem dados configurados.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Se há dados, mostrar o conteúdo normal
    // CORREÇÃO CRÍTICA: Garantir que pisosSelecionados não esteja vazio
    // Se estiver vazio e houver gabinetes, inicializar com todos os setores
    if (pisosSelecionados.isEmpty && gabinetes.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
      pisosSelecionados = List<String>.from(todosSetores);
    }

    final gabinetesFiltrados = logic.AlocacaoMedicosLogic.filtrarGabinetesPorUI(
      gabinetes: gabinetes,
      alocacoes: alocacoes,
      selectedDate: selectedDate,
      pisosSelecionados: pisosSelecionados,
      filtroOcupacao: filtroOcupacao,
      mostrarConflitos: mostrarConflitos,
      filtroEspecialidadeGabinete: filtroEspecialidadeGabinete,
    );

    return Column(
      children: [
        const SizedBox(height: 12),

        // Widget de Estatísticas
        Builder(
          builder: (context) {
            // Calcular estatísticas
            final dataAlvo = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
            );
            
            // Médicos alocados no dia (médicos únicos)
            final medicosAlocadosIds = alocacoes
                .where((a) {
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                  return aDate == dataAlvo;
                })
                .map((a) => a.medicoId)
                .toSet();
            final numMedicosAlocados = medicosAlocadosIds.length;
            
            // Médicos por alocar
            final numMedicosPorAlocar = medicosDisponiveis.length;
            
            // Gabinetes ocupados (gabinetes com pelo menos uma alocação no dia)
            final gabinetesOcupadosIds = alocacoes
                .where((a) {
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                  return aDate == dataAlvo;
                })
                .map((a) => a.gabineteId)
                .toSet();
            final numGabinetesOcupados = gabinetesOcupadosIds.length;
            
            // Gabinetes livres (total de gabinetes menos ocupados)
            final numGabinetesLivres = gabinetes.length - numGabinetesOcupados;
            
            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                
                if (isNarrow) {
                  // Layout em duas linhas para telas pequenas
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: MyAppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: MyAppTheme.shadowCard,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildEstatisticaItem(
                                numMedicosAlocados.toString(),
                                'médicos alocados',
                                MyAppTheme.azulEscuro,
                              ),
                            ),
                            _buildDivisor(),
                            Expanded(
                              child: _buildEstatisticaItem(
                                numMedicosPorAlocar.toString(),
                                'médicos por alocar',
                                MyAppTheme.laranja,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildEstatisticaItem(
                                numGabinetesOcupados.toString(),
                                'gabinetes ocupados',
                                MyAppTheme.verde,
                              ),
                            ),
                            _buildDivisor(),
                            Expanded(
                              child: _buildEstatisticaItem(
                                numGabinetesLivres.toString(),
                                'gabinetes livres',
                                MyAppTheme.cinzento,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                } else {
                  // Layout em uma linha para telas maiores
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: MyAppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: MyAppTheme.shadowCard,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildEstatisticaItem(
                            numMedicosAlocados.toString(),
                            'médicos alocados',
                            MyAppTheme.azulEscuro,
                          ),
                        ),
                        _buildDivisor(),
                        Expanded(
                          child: _buildEstatisticaItem(
                            numMedicosPorAlocar.toString(),
                            'médicos por alocar',
                            MyAppTheme.laranja,
                          ),
                        ),
                        _buildDivisor(),
                        Expanded(
                          child: _buildEstatisticaItem(
                            numGabinetesOcupados.toString(),
                            'gabinetes ocupados',
                            MyAppTheme.verde,
                          ),
                        ),
                        _buildDivisor(),
                        Expanded(
                          child: _buildEstatisticaItem(
                            numGabinetesLivres.toString(),
                            'gabinetes livres',
                            MyAppTheme.cinzento,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            );
          },
        ),

        // Seção de médicos disponíveis - apenas para administradores
        if (widget.isAdmin) ...[
          Builder(
            builder: (context) {
              // Calcular altura mínima dinamicamente baseado no número de cartões
              // Se há cartões, calcular baseado no número de linhas necessárias
              double minHeight;
              if (medicosDisponiveis.isEmpty) {
                // Apenas título: padding top (14) + título (~40) + padding bottom (8) + padding conteúdo (12)
                minHeight = 14 + 40 + 8 + 12;
              } else {
                // Calcular quantas linhas serão necessárias
                // Assumindo largura de tela e cartões de ~180px + 6px spacing
                final larguraTela = MediaQuery.of(context).size.width;
                final larguraCartao = 180.0;
                final spacing = 6.0;
                final paddingHorizontal = 40.0; // margin left + right (20 + 20)
                final paddingInterno = 24.0; // padding interno (12 + 12)
                final larguraDisponivel =
                    larguraTela - paddingHorizontal - paddingInterno;
                final cartoesPorLinha =
                    (larguraDisponivel / (larguraCartao + spacing)).floor();
                final numLinhas = (medicosDisponiveis.length /
                        (cartoesPorLinha > 0 ? cartoesPorLinha : 1))
                    .ceil();

                // Altura do título: padding top (14) + título (~40) + padding bottom (8)
                final alturaTitulo = 14 + 40 + 8;
                // Altura dos cartões: altura do cartão (~100px) + runSpacing (6px) por linha
                final alturaCartao = 100.0;
                final alturaCartoes =
                    (alturaCartao * numLinhas) + (6 * (numLinhas - 1));
                // Padding bottom do conteúdo (12)
                final paddingBottom = 12.0;

                // Se tem 2 ou mais linhas, garantir altura mínima para 2 linhas
                if (numLinhas >= 2) {
                  minHeight =
                      alturaTitulo + (alturaCartao * 2) + 6 + paddingBottom;
                } else {
                  minHeight = alturaTitulo + alturaCartoes + paddingBottom;
                }
              }

              return Container(
                constraints: BoxConstraints(
                  minHeight: minHeight,
                  maxHeight: 300, // Altura máxima para 2 linhas
                ),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                decoration: BoxDecoration(
                  color: MyAppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: MyAppTheme.shadowCard,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título da seção - DragTarget aqui para evitar conflitos de gestos
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (details) {
                          final medicoId = details.data;

                          // Verifica se o médico realmente está alocado no dia selecionado antes de aceitar o cartão
                          final dataAlvo = DateTime(selectedDate.year,
                              selectedDate.month, selectedDate.day);
                          final estaAlocado = alocacoes.any((a) {
                            final aDate =
                                DateTime(a.data.year, a.data.month, a.data.day);
                            return a.medicoId == medicoId && aDate == dataAlvo;
                          });

                          if (!estaAlocado) {
                            debugPrint(
                                '❌ Médico $medicoId NÃO está alocado no dia ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}, ignorando desalocação.');
                            return false;
                          }
                          debugPrint(
                              '✅ Médico $medicoId está alocado no dia ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}, aceitando para desalocar.');
                          return true;
                        },
                        onAcceptWithDetails: (details) async {
                          final medicoId = details.data;
                          debugPrint(
                              '🔄 onAcceptWithDetails chamado para desalocar médico $medicoId');
                          // Agora só será chamado para médicos alocados no dia selecionado
                          await _desalocarMedicoComPergunta(medicoId);
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          return Container(
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? Colors.blue.shade50
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isHovering
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        MyAppTheme.azulEscuro.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.people_outline,
                                    size: 18,
                                    color: MyAppTheme.azulEscuro,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Médicos por Alocar',
                                  style: MyAppTheme.heading2.copyWith(
                                    fontSize: 17,
                                    color: MyAppTheme.azulEscuro,
                                  ),
                                ),
                                const Spacer(),
                                // Ícone 1: Médicos não alocados no ano
                                Tooltip(
                                  message: 'Médicos não alocados no ano',
                                  child: InkWell(
                                    onTap: () =>
                                        _mostrarMedicosNaoAlocadosAno(),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: MyAppTheme.azulEscuro
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.list_alt,
                                        size: 18,
                                        color: MyAppTheme.azulEscuro,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Ícone 2: Conflitos no ano
                                Tooltip(
                                  message: 'Conflitos de gabinete no ano',
                                  child: InkWell(
                                    onTap: () => _mostrarConflitosAno(),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Conteúdo
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: MedicosDisponiveisSection(
                        medicosDisponiveis: medicosDisponiveis,
                        disponibilidades: disponibilidades,
                        selectedDate: selectedDate,
                        onDesalocarMedico: (mId) =>
                            _desalocarMedicoDiaUnico(mId),
                        // Só permitir edição se for administrador
                        onEditarMedico: widget.isAdmin
                            ? (medico) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CadastroMedico(
                                      medico: medico,
                                      unidade: widget.unidade,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 8),

        // Lista / Grade de Gabinetes
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GabinetesSection(
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
              // Só permitir edição se for administrador
              onEditarMedico: widget.isAdmin
                  ? (medico) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CadastroMedico(
                            medico: medico,
                            unidade: widget.unidade,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // Métodos auxiliares para o widget de estatísticas
  Widget _buildEstatisticaItem(String numero, String label, Color cor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          numero,
          style: MyAppTheme.heading2.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: MyAppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: MyAppTheme.cinzento,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDivisor() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade300,
    );
  }

  // Funções de controle de zoom
  void _zoomIn() {
    final newScale = (zoomLevel + zoomStep).clamp(minZoom, maxZoom);
    if (newScale != zoomLevel) {
      setState(() {
        zoomLevel = newScale;
      });
      _updateTransformation();
    }
  }

  void _zoomOut() {
    final newScale = (zoomLevel - zoomStep).clamp(minZoom, maxZoom);
    if (newScale != zoomLevel) {
      setState(() {
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

  // Layout responsivo para ecrãs pequenos
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

  // Layout desktop para ecrãs grandes
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

  // Conteúdo da coluna esquerda (DatePicker + Pesquisa + Filtros)
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
                // CORREÇÃO: Invalidar cache ao mudar de dia para garantir dados atualizados
                final dataNormalizada =
                    DateTime(date.year, date.month, date.day);
                logic.AlocacaoMedicosLogic.invalidateCacheForDay(
                    dataNormalizada);
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

  // Conteúdo da coluna direita (Médicos Disponíveis + Gabinetes)
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _timerProgresso?.cancel();
    _timeoutFlagsTransicao?.cancel();
    _transformationController.dispose();
    super.dispose();
  }
}
