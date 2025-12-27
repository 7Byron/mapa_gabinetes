import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Se criou o custom_drawer.dart
import '../widgets/custom_drawer.dart';

// Widgets locais
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/gabinetes_section.dart';
import '../widgets/medicos_disponiveis_section.dart';
import '../widgets/filtros_section.dart';
import '../widgets/pesquisa_section.dart';

// Lógica separada
import '../utils/alocacao_medicos_logic.dart' as logic;

// Models
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';

// Services
import '../services/password_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';

/// Tela principal de alocação de médicos aos gabinetes
/// Permite arrastar médicos disponíveis para gabinetes específicos
/// Inclui verificação de dias de encerramento e exibe mensagem quando clínica está fechada
/// Interface responsiva com largura máxima de 600px para melhor usabilidade

class AlocacaoMedicos extends StatefulWidget {
  final Unidade unidade;
  final bool isAdmin; // Novo parâmetro para indicar se é administrador

  const AlocacaoMedicos({
    super.key,
    required this.unidade,
    this.isAdmin = false, // Por defeito é utilizador normal
  });

  @override
  State<AlocacaoMedicos> createState() => AlocacaoMedicosState();
}

class AlocacaoMedicosState extends State<AlocacaoMedicos>
    with WidgetsBindingObserver {
  bool isCarregando = true;
  double progressoCarregamento = 0.0; // Progresso de 0.0 a 1.0
  String mensagemProgresso =
      'A iniciar...'; // Mensagem de status do carregamento
  Timer? _debounceTimer;
  Timer?
      _debounceRegeneracaoSeries; // Timer para debounce das atualizações dos listeners
  Timer?
      _debounceAtualizarMedicosDisponiveis; // Timer para debounce de atualização de médicos disponíveis
  Timer?
      _timeoutFlagsTransicao; // Timer para limpar flags presas automaticamente
  DateTime selectedDate = DateTime.now();
  bool _ignorarPrimeirasAtualizacoesListeners =
      false; // Flag para ignorar primeiras atualizações dos listeners
  bool _jaRecarregouAoVoltar =
      false; // Flag para evitar múltiplos recarregamentos
  bool _isProcessandoAlocacao =
      false; // Flag para evitar múltiplas atualizações durante alocação/realocação
  // NOVO: Controle de transição para melhorar comportamento visual
  String?
      _medicoEmTransicao; // ID do médico que está sendo movido durante transição

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

  // Listeners em tempo real do dia atual
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dispSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alocSub;
  bool _listenerPausado =
      false; // Flag para pausar listener completamente durante transição

  Future<void> _restartDayListeners() async {
    await _dispSub?.cancel();
    await _alocSub?.cancel();

    final firestore = FirebaseFirestore.instance;
    final inicio =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final fim = inicio.add(const Duration(days: 1));
    final startIso = inicio.toIso8601String();
    final endIso = fim.toIso8601String();

    // NOVO MODELO: Não há mais disponibilidades individuais no Firestore
    // As disponibilidades são geradas dinamicamente a partir de séries
    // O listener de séries será implementado se necessário, mas por enquanto
    // recarregamos os dados quando necessário (ao mudar de dia, etc.)
    _dispSub =
        null; // Listener desativado - disponibilidades são geradas dinamicamente

    final ano = inicio.year.toString();
    _alocSub = firestore
        .collection('unidades')
        .doc(widget.unidade.id)
        .collection('alocacoes')
        .doc(ano)
        .collection('registos')
        .where('data', isGreaterThanOrEqualTo: startIso)
        .where('data', isLessThan: endIso)
        .snapshots()
        .listen((snap) {
      // CORREÇÃO CRÍTICA: Verificar pausa ANTES de processar qualquer dado
      // Isso previne que atualizações do Firestore sobrescrevam a atualização otimista
      if (_isProcessandoAlocacao ||
          _medicoEmTransicao != null ||
          _listenerPausado) {
        debugPrint(
            '⚠️ [LISTENER] PAUSADO: _isProcessandoAlocacao=$_isProcessandoAlocacao, _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');
        debugPrint(
            '⚠️ [LISTENER] Ignorando atualização do Firestore para preservar atualização otimista');

        return;
      }

      if (!mounted) return;

      final alocDia = snap.docs.map((d) => Alocacao.fromMap(d.data())).toList();
      debugPrint(
          '📥 [LISTENER] Processando ${alocDia.length} alocações do Firestore');

      // IMPORTANTE: Usar Map para evitar duplicatas ao mesclar alocações
      // Criar um Map com todas as alocações atuais (incluindo geradas de séries)
      final alocacoesMap = <String, Alocacao>{};

      // CORREÇÃO CRÍTICA: Preservar atualização otimista ANTES de processar Firestore
      // Primeiro, adicionar TODAS as alocações atuais ao Map (preservar todas)
      // MAS dar prioridade especial às alocações otimistas do médico em transição
      final alocacoesOtimistas = <String>[];
      final alocacoesReais = <String>[];
      for (final aloc in alocacoes) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        // Se é uma alocação otimista (médico em transição), marcar para preservar
        if (_medicoEmTransicao != null && aloc.medicoId == _medicoEmTransicao) {
          debugPrint(
              '🔵 [LISTENER] Preservando alocação otimista: ${aloc.id} (médico: ${aloc.medicoId})');
        }
        if (aloc.id.startsWith('otimista_')) {
          alocacoesOtimistas.add('${aloc.medicoId}_${aloc.gabineteId}');
        } else {
          alocacoesReais.add('${aloc.medicoId}_${aloc.gabineteId}');
        }
        alocacoesMap[chave] = aloc;
      }

      // Depois, adicionar novas alocações do Firestore ao Map
      // IMPORTANTE: Alocações do Firestore têm prioridade sobre geradas de séries
      // Para alocações otimistas: substituir pela real quando chegar do servidor
      int adicionadas = 0;
      int substituidas = 0;

      for (final aloc in alocDia) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';

        final alocExistente = alocacoesMap[chave];

        // CORREÇÃO MELHORADA: Se existe uma alocação otimista e chegou a real do Firestore,
        // substituir a otimista pela real (mesmo gabinete = mesma alocação, só atualizar ID)
        if (alocExistente != null && alocExistente.id.startsWith('otimista_')) {
          // Alocação otimista encontrada - substituir pela real do Firestore
          alocacoesMap[chave] = aloc;
          substituidas++;
          debugPrint(
              '✅ [LISTENER] Substituindo alocação otimista pela real: ${alocExistente.id} -> ${aloc.id}');

          continue;
        }

        // CORREÇÃO CRÍTICA: Se não encontrou no Map, verificar se há uma alocação correspondente na lista original
        // que corresponde a esta alocação do Firestore (mesmo médico, gabinete e data)
        // Isso pode acontecer se o listener processar antes de a alocação estar no Map, ou se foi movida pela atualização otimista
        if (alocExistente == null) {
          final alocacaoCorrespondente = alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              final alocDate =
                  DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
              // Verificar se corresponde (mesmo médico, gabinete e data), independentemente do ID
              return a.medicoId == aloc.medicoId &&
                  a.gabineteId == aloc.gabineteId &&
                  aDate == alocDate;
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

          if (alocacaoCorrespondente.id.isNotEmpty) {
            // Encontrou alocação correspondente - substituir pela real do Firestore
            alocacoesMap[chave] = aloc;
            substituidas++;
            debugPrint(
                '✅ [LISTENER] Substituindo alocação correspondente pela real (encontrada na lista): ${alocacaoCorrespondente.id} -> ${aloc.id}');

            continue;
          }
        }

        // CORREÇÃO CRÍTICA: Se há transição em andamento e a alocação do Firestore
        // tem gabinete diferente da otimista, preservar a otimista (realocação em progresso)
        if (_medicoEmTransicao != null && aloc.medicoId == _medicoEmTransicao) {
          if (alocExistente != null &&
              alocExistente.gabineteId != aloc.gabineteId &&
              alocExistente.id.startsWith('otimista_')) {
            // Alocação otimista tem gabinete diferente - preservar a otimista
            debugPrint(
                '🔵 [LISTENER] Preservando alocação otimista (gabinete diferente): ${alocExistente.gabineteId} vs ${aloc.gabineteId}');
            continue; // Não substituir
          }
        }

        if (!alocacoesMap.containsKey(chave)) {
          // Não existe, adicionar
          alocacoesMap[chave] = aloc;
          adicionadas++;
        } else if (alocacoesMap[chave]!.id.startsWith('serie_')) {
          // Existe mas é de série, substituir pela do Firestore (prioridade)
          alocacoesMap[chave] = aloc;
          substituidas++;
        } else {
          // Já existe e não é de série, substituir pela do Firestore (atualização)
          alocacoesMap[chave] = aloc;
          substituidas++;
        }
      }

      // CORREÇÃO CRÍTICA: NÃO remover alocações geradas de séries
      // Alocações de séries não estão no Firestore (são geradas dinamicamente)
      // Se removermos, elas desaparecem quando o listener é acionado
      // Calcular quais alocações foram removidas (estavam nas alocações antigas mas não estão no Firestore)
      final chavesFirestore = alocDia.map((aloc) {
        return '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
      }).toSet();

      final chavesAntigas = alocacoes.map((aloc) {
        return '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
      }).toSet();

      final chavesRemovidas = chavesAntigas.difference(chavesFirestore);

      int removidas = 0;
      for (final chave in chavesRemovidas) {
        // Verificar se é uma alocação gerada de série (começa com 'serie_')
        // Se for, NÃO remover - essas são geradas dinamicamente e não estão no Firestore
        final alocacao = alocacoesMap[chave];
        if (alocacao != null) {
          if (alocacao.id.startsWith('serie_')) {
            // Manter alocação gerada de série - não remover
            debugPrint(
                '✅ Preservando alocação gerada de série: ${alocacao.id} (médico: ${alocacao.medicoId}, gabinete: ${alocacao.gabineteId})');
          } else if (alocacao.id.startsWith('otimista_')) {
            // CORREÇÃO: Se é uma alocação otimista que não está no Firestore,
            // verificar se ainda está em transição. Se não, remover (erro ou cancelamento)

            if (_medicoEmTransicao != null &&
                alocacao.medicoId == _medicoEmTransicao) {
              // Ainda em transição - preservar otimista
              debugPrint(
                  '🔵 [LISTENER] Preservando alocação otimista em transição: ${alocacao.id}');
            } else {
              // Não está mais em transição e não está no Firestore - remover (erro)
              alocacoesMap.remove(chave);
              removidas++;
              debugPrint(
                  '🗑️ Removendo alocação otimista não confirmada: ${alocacao.id} (médico: ${alocacao.medicoId})');
            }
          } else {
            // Remover apenas alocações "Única" que não estão mais no Firestore
            alocacoesMap.remove(chave);
            removidas++;
            debugPrint(
                '🗑️ Removendo alocação apagada do Firebase: ${alocacao.id} (médico: ${alocacao.medicoId})');
          }
        }
      }

      if (adicionadas > 0 || substituidas > 0 || removidas > 0) {
        debugPrint(
            '📊 Listener Alocações: $adicionadas adicionadas, $substituidas substituídas, $removidas removidas');
      }

      // Atualizar lista de alocações com o Map (sem duplicatas)
      final antes = alocacoes.length;
      alocacoes.clear();
      alocacoes.addAll(alocacoesMap.values);
      final depois = alocacoes.length;

      // CORREÇÃO MELHORADA: Atualizar UI imediatamente se houve mudanças significativas
      // Isso garante que quando a alocação otimista é substituída pela real, a UI seja atualizada suavemente
      if (mounted && (adicionadas > 0 || substituidas > 0 || removidas > 0)) {
        // Se não está em processamento, atualizar UI imediatamente
        // Se está em processamento, a UI será atualizada quando o processamento terminar
        if (!_isProcessandoAlocacao && !_listenerPausado) {
          setState(() {
            // Estado já foi atualizado acima (alocacoes.clear/addAll)
            // Este setState apenas força o rebuild da UI
          });
        }
      }

      // CORREÇÃO: Ignorar regeneração durante operações de alocação para evitar "piscar"
      if (_isProcessandoAlocacao ||
          _medicoEmTransicao != null ||
          _listenerPausado) {
        debugPrint(
            '⚠️ Ignorando regeneração de séries durante alocação/transição');
        return;
      }

      // CORREÇÃO CRÍTICA: Regenerar alocações de séries após processar listener
      // Isso garante que alocações de séries alocadas sejam sempre exibidas,
      // mesmo quando o listener do Firestore é acionado
      // (alocações de séries não são salvas no Firestore, são geradas dinamicamente)
      // CORREÇÃO: Usar debounce para evitar múltiplas regenerações rápidas
      _debounceRegeneracaoSeries?.cancel();
      _debounceRegeneracaoSeries = Timer(const Duration(milliseconds: 200), () {
        _regenerarAlocacoesSeries().then((alocacoesSeries) {
          if (!mounted) return;

          // CORREÇÃO: Verificar novamente se não está processando (pode ter mudado)
          if (_isProcessandoAlocacao || _medicoEmTransicao != null) {
            debugPrint(
                '⚠️ Ignorando atualização de séries durante alocação/transição');
            return;
          }

          // CORREÇÃO CRÍTICA: Remover alocações antigas de séries antes de adicionar novas
          // Isso garante que quando uma exceção muda o gabinete, a alocação antiga é removida
          // A chave de mesclagem inclui o gabineteId, então precisamos remover manualmente
          // todas as alocações de séries do mesmo médico/data antes de adicionar as novas

          // Criar um conjunto de chaves de séries para identificar quais remover
          final chavesSeriesParaRemover = <String>{};
          for (final aloc in alocacoesSeries) {
            // Criar chave sem gabineteId para identificar todas as alocações da mesma série/data
            final chaveSemGabinete =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
            chavesSeriesParaRemover.add(chaveSemGabinete);
          }

          // Adicionar alocações geradas de séries ao Map
          final alocacoesMapAtualizado = <String, Alocacao>{};

          // CORREÇÃO CRÍTICA: Preservar atualização otimista durante regeneração
          // Primeiro, adicionar todas as alocações atuais, EXCETO alocações de séries que serão regeneradas
          // MAS preservar alocações otimistas do médico em transição
          for (final aloc in alocacoes) {
            // CORREÇÃO: Se é uma alocação otimista do médico em transição, SEMPRE preservar
            if (_medicoEmTransicao != null &&
                aloc.medicoId == _medicoEmTransicao) {
              final chave =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
              alocacoesMapAtualizado[chave] = aloc;
              debugPrint(
                  '✅ Preservando alocação otimista durante regeneração: ${aloc.id}');
              continue;
            }

            // Se é uma alocação de série que será regenerada, não adicionar agora
            if (aloc.id.startsWith('serie_')) {
              final chaveSemGabinete =
                  '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
              if (chavesSeriesParaRemover.contains(chaveSemGabinete)) {
                // Esta alocação de série será regenerada, pular para evitar duplicação
                continue;
              }
            }

            final chave =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
            alocacoesMapAtualizado[chave] = aloc;
          }

          // Depois, adicionar/atualizar com alocações geradas de séries
          // Isso substitui qualquer alocação antiga da mesma série/data
          for (final aloc in alocacoesSeries) {
            final chave =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
            // Alocações geradas de séries têm prioridade sobre alocações "Única" do Firestore
            // para o mesmo médico/data/gabinete
            alocacoesMapAtualizado[chave] = aloc;
          }

          // Atualizar lista final
          final antesRegen = alocacoes.length;
          alocacoes.clear();
          alocacoes.addAll(alocacoesMapAtualizado.values);
          final depoisRegen = alocacoes.length;

          if (antesRegen != depoisRegen) {
            debugPrint(
                '🔄 Alocações regeneradas: $antesRegen -> $depoisRegen (${alocacoesSeries.length} de séries)');
          }

          // CORREÇÃO CRÍTICA: Atualizar médicos disponíveis após regenerar alocações
          // Isso garante que médicos alocados não apareçam como disponíveis
          // CORREÇÃO: Ignorar se está processando alocação para evitar "piscar"
          // CORREÇÃO: Usar debounce para evitar múltiplas chamadas
          if (mounted &&
              !_isProcessandoAlocacao &&
              _medicoEmTransicao == null &&
              !_listenerPausado) {
            _debounceAtualizarMedicosDisponiveis?.cancel();
            _debounceAtualizarMedicosDisponiveis =
                Timer(const Duration(milliseconds: 300), () {
              if (mounted &&
                  !_isProcessandoAlocacao &&
                  _medicoEmTransicao == null &&
                  !_listenerPausado) {
                _atualizarMedicosDisponiveis().catchError((e) {
                  debugPrint(
                      '❌ Erro ao atualizar médicos disponíveis após regenerar alocações: $e');
                });
              }
            });
          }

          // CORREÇÃO CRÍTICA: NÃO atualizar UI durante transição para evitar "piscar"
          // A atualização otimista já atualizou a UI, então não precisamos atualizar novamente aqui
          if (mounted &&
              !_isProcessandoAlocacao &&
              _medicoEmTransicao == null &&
              !_listenerPausado) {
            setState(() {
              // Forçar rebuild apenas se não há transição em andamento
            });
          } else {
            debugPrint(
                '⚠️ Ignorando setState durante regeneração de séries (transição em andamento)');
          }
        }); // Fechar .then()
      }); // Fechar Timer

      if (antes != depois) {
        debugPrint(
            '📊 Listener Alocações: Alocações atualizadas: $antes -> $depois (diferença: ${depois - antes})');
      }

      final doDia = alocacoes.where((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        return ad == inicio;
      }).toList();
      logic.AlocacaoMedicosLogic.updateCacheForDay(
          day: inicio, alocacoes: doDia);
      // Agendar atualização com debounce para evitar atualizações parciais
      // quando disponibilidades e alocações chegam em momentos diferentes
      // Ignorar se estamos no meio do carregamento inicial
      if (!_ignorarPrimeirasAtualizacoesListeners) {
        _agendarAtualizacaoMedicosDisponiveis();
      }
    });
  }

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
    WidgetsBinding.instance.addObserver(this);
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
    // Quando o app volta ao foco (resumed), invalidar cache e recarregar
    // CORREÇÃO CRÍTICA: NÃO recarregar durante operações de alocação/realocação
    // Isso causa "piscar" massivo e interfere com atualizações otimistas
    if (state == AppLifecycleState.resumed) {
      if (!_isProcessandoAlocacao &&
          _medicoEmTransicao == null &&
          !_listenerPausado) {
        _invalidarCacheERecarregar();
      } else {
        debugPrint(
            '⚠️ [LIFECYCLE] Ignorando recarregamento: _isProcessandoAlocacao=$_isProcessandoAlocacao, _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // CORREÇÃO: Quando a tela volta ao foco (ex: voltar do ecrã de edição),
    // invalidar cache e recarregar dados para garantir dados atualizados
    // Isso resolve o problema de cartões não aparecerem ao voltar do ecrã de edição
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !_jaRecarregouAoVoltar) {
      // Usar postFrameCallback para garantir que só recarrega após o build completo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route.isCurrent) {
          _jaRecarregouAoVoltar = true;
          _invalidarCacheERecarregar();
          // Resetar flag após um delay para permitir recarregamento futuro
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _jaRecarregouAoVoltar = false;
            }
          });
        }
      });
    }
  }

  /// Invalida cache e recarrega dados quando a tela volta ao foco
  void _invalidarCacheERecarregar() {
    // Tela está ativa - invalidar cache de disponibilidades e alocações do dia atual
    // e também invalidar cache de séries para garantir que novas séries apareçam
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(selectedDate);

    // CORREÇÃO CRÍTICA: Invalidar cache de séries para TODOS os médicos e anos
    // Isso garante que novas séries criadas apareçam imediatamente
    final anoAtual = selectedDate.year;
    // Invalidar cache de séries para o ano atual e próximo ano (força recarregamento)
    logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(anoAtual, 1, 1));
    logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(anoAtual + 1, 1, 1));

    // CORREÇÃO: NÃO invalidar cache de TODOS os médicos - isso causa "piscar" massivo
    // Apenas invalidar cache do dia atual e anos relevantes é suficiente
    // Invalidar cache de séries apenas quando necessário (ex: após criar nova série)

    // CORREÇÃO CRÍTICA: Invalidar cache de médicos ativos quando volta do ecrã de cadastro
    // Isso garante que novos médicos ou médicos com disponibilidades recém-criadas apareçam
    logic.AlocacaoMedicosLogic.invalidateMedicosAtivosCache(
        unidadeId: widget.unidade.id);
    debugPrint(
        '🔄 Cache de médicos ativos invalidado para unidade ${widget.unidade.id}');

    debugPrint(
        '🔄 Tela voltou ao foco - cache invalidado para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} e todas as séries');

    // CORREÇÃO CRÍTICA: Recarregar dados quando volta ao foco
    // Forçar recarregamento de médicos para garantir que novos médicos apareçam
    // Isso garante que novas séries criadas apareçam imediatamente
    _carregarDadosIniciais(recarregarMedicos: true);
  }

  Future<void> _carregarPasswordsDoFirebase() async {
    try {
      // Carrega as passwords do Firebase para cache local
      await PasswordService.loadPasswordsFromFirebase(widget.unidade.id);
    } catch (e) {
      // Silencioso - não é crítico para a UI
    }
  }

  Future<void> _carregarDadosIniciais({bool recarregarMedicos = false}) async {
    // CORREÇÃO CRÍTICA: Invalidar cache ANTES de recarregar dados
    // Isso garante que quando uma série é alocada, os dados sejam recarregados do servidor
    // e não do cache antigo
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(selectedDate);
    final anoAtual = selectedDate.year;
    // Invalidar cache de séries para o ano atual para garantir dados atualizados
    logic.AlocacaoMedicosLogic.invalidateCacheFromDate(
        DateTime(anoAtual, 1, 1));

    try {
      // Inicializar progresso
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.0;
          mensagemProgresso = 'A verificar configurações...';
        });
      }

      // FASE 0: Carregar dados de encerramento PRIMEIRO (feriados, dias de encerramento, horários)
      // Isso permite verificar se a clínica está encerrada ANTES de carregar dados do Firestore
      await Future.wait([
        _carregarFeriados(),
        _carregarDiasEncerramento(),
        _carregarHorariosEConfiguracoes(),
      ]);

      // Verificar se a clínica está encerrada ANTES de carregar dados do Firestore
      _verificarClinicaFechada();

      debugPrint(
          '🔍 Verificação de encerramento: clinicaFechada=$clinicaFechada, mensagem="$mensagemClinicaFechada"');
      debugPrint('  - Feriados carregados: ${feriados.length}');
      debugPrint(
          '  - Dias de encerramento carregados: ${diasEncerramento.length}');
      debugPrint('  - encerraFeriados: $encerraFeriados');
      debugPrint(
          '  - Data selecionada: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');

      if (clinicaFechada) {
        // Clínica está encerrada - não carregar dados do Firestore
        debugPrint(
            '🚫 Clínica encerrada - pulando carregamento de dados do Firestore');
        // Cancelar listeners se estiverem ativos
        await _dispSub?.cancel();
        await _alocSub?.cancel();
        if (mounted) {
          setState(() {
            // Limpar dados existentes
            disponibilidades.clear();
            alocacoes.clear();
            medicosDisponiveis.clear();
            // Desligar progress bar
            isCarregando = false;
            progressoCarregamento = 0.0;
            mensagemProgresso = 'A iniciar...';
          });
        }
        return; // Sair sem carregar mais nada - NÃO chamar carregarDadosIniciais
      }

      // FASE 1: Carregar exceções canceladas UMA ÚNICA VEZ (otimização de performance)
      // Isso evita carregar exceções múltiplas vezes em diferentes métodos
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.1;
          mensagemProgresso = 'A verificar exceções...';
        });
      }
      final datasComExcecoesCanceladas =
          await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
        widget.unidade.id,
        selectedDate,
      );
      debugPrint(
          '⚡ Exceções canceladas carregadas: ${datasComExcecoesCanceladas.length}');

      // FASE 2: Carregar dados essenciais (gabinetes, médicos, disponibilidades e alocações)
      // Só chega aqui se a clínica NÃO estiver encerrada
      // NÃO chamar setState() nos callbacks individuais para evitar atualizações parciais
      // que causam o efeito de cartões aparecendo na área branca e depois sendo movidos
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.2;
          mensagemProgresso = 'A carregar dados...';
        });
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
            debugPrint(
                '⚠️ Preservando ${gabinetes.length} gabinetes existentes (lista vazia recebida durante mudança de data)');
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
            debugPrint(
                '⚠️ Preservando ${medicos.length} médicos existentes (lista vazia recebida durante mudança de data)');
            return;
          }
          // Atualizar normalmente se:
          // 1. Estamos recarregando dados estáticos (recarregarMedicos = true), OU
          // 2. Recebemos dados não vazios, OU
          // 3. Não havia dados antes (medicos.isEmpty)
          medicos = m;
          debugPrint(
              '👥 Médicos carregados: ${m.length} total, ${m.where((med) => med.ativo).length} ativos');
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onDisponibilidades: (d) {
          disponibilidades = d;
          debugPrint('📋 Disponibilidades carregadas: ${d.length} total');
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
                // Já existe no servidor - não precisa preservar otimista
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
          final alocacoesOtimistasPreservadas =
              alocacoes.where((a) => a.id.startsWith('otimista_')).length;
          debugPrint(
              '✅ Alocações mescladas: ${alocacoes.length} total ($alocacoesOtimistasPreservadas otimistas preservadas)');

          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        unidade: widget.unidade,
        dataFiltroDia: selectedDate,
        reloadStatic:
            recarregarMedicos, // Força recarregar médicos se solicitado
        excecoesCanceladas:
            datasComExcecoesCanceladas, // Passar exceções já carregadas
      );

      // Iniciar listeners ANTES de atualizar a UI
      // Isso evita que os listeners disparem atualizações imediatamente após serem iniciados
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.8;
          mensagemProgresso = 'A configurar atualizações em tempo real...';
        });
      }
      _ignorarPrimeirasAtualizacoesListeners = true;
      await _restartDayListeners();

      // Não aguardar - os listeners já têm os dados do cache ou do carregamento inicial
      // O delay estava causando lentidão desnecessária
      _ignorarPrimeirasAtualizacoesListeners = false;

      // Atualizar médicos disponíveis (agora com todos os dados carregados)
      if (mounted) {
        setState(() {
          progressoCarregamento = 0.9;
          mensagemProgresso = 'A processar médicos disponíveis...';
        });
      }
      // Chamar fora do setState porque é assíncrono e atualiza o estado internamente
      // IMPORTANTE: Sempre chamar, mesmo quando dados vêm do cache, para verificar exceções
      // CORREÇÃO: Forçar recarregamento de alocações após carregar dados iniciais
      // Isso garante que alocações de séries sejam geradas corretamente

      // CORREÇÃO CRÍTICA: Regenerar alocações de séries ANTES de atualizar médicos disponíveis
      // Isso garante que médicos com alocações de séries não apareçam como disponíveis
      debugPrint(
          '🔄 Regenerando alocações de séries antes de atualizar médicos disponíveis...');
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

        // CORREÇÃO: Se é uma alocação otimista do médico em transição, SEMPRE preservar
        if (_medicoEmTransicao != null && aloc.medicoId == _medicoEmTransicao) {
          alocacoesAtualizadas.add(aloc);
          debugPrint(
              '✅ Preservando alocação otimista durante regeneração em _carregarDadosIniciais: ${aloc.id}');
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

      // CORREÇÃO: Atualizar médicos disponíveis apenas se não estiver processando alocação
      // Isso evita múltiplas atualizações durante drag and drop
      // CORREÇÃO: Usar debounce para evitar múltiplas chamadas
      if (!_isProcessandoAlocacao &&
          _medicoEmTransicao == null &&
          !_listenerPausado) {
        _debounceAtualizarMedicosDisponiveis?.cancel();
        _debounceAtualizarMedicosDisponiveis =
            Timer(const Duration(milliseconds: 300), () {
          if (mounted &&
              !_isProcessandoAlocacao &&
              _medicoEmTransicao == null &&
              !_listenerPausado) {
            debugPrint(
                '🔄 Chamando _atualizarMedicosDisponiveis após regenerar alocações de séries...');
            _atualizarMedicosDisponiveis().catchError((e) {
              debugPrint('❌ Erro ao atualizar médicos disponíveis: $e');
            });
          }
        });
      } else {
        debugPrint(
            '⚠️ Ignorando _atualizarMedicosDisponiveis durante processamento de alocação/transição');
      }

      // CORREÇÃO: Atualizar UI apenas se não estiver processando alocação
      // Isso evita múltiplas atualizações durante drag and drop
      if (mounted && !_isProcessandoAlocacao) {
        setState(() {
          // Inicializar filtros de piso com todos os setores selecionados por padrão
          _inicializarFiltrosPiso();
          // Verificar novamente se a clínica está fechada (já foi verificado antes, mas garantir)
          _verificarClinicaFechada();
          // Completar carregamento
          progressoCarregamento = 1.0;
          mensagemProgresso = 'Concluído!';
          // Desligar progress bar após um pequeno delay para mostrar 100%
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isProcessandoAlocacao) {
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
          progressoCarregamento = 0.0;
          mensagemProgresso = 'A iniciar...';
        });
      }
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
    // Verificar tanto em diasEncerramento quanto em feriados (se configurado como feriado)
    debugPrint(
        '  🔍 Verificando ${diasEncerramento.length} dias de encerramento para $dataFormatada');
    for (final d in diasEncerramento) {
      final dataDia = d['data'] as String? ?? '';
      debugPrint(
          '    - Dia de encerramento: $dataDia (motivo: ${d['motivo']})');
    }

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
          // Se não conseguir fazer parse, comparar strings diretamente
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
      debugPrint(
          '🚫 Clínica encerrada: Dia específico de encerramento encontrado - $dataFormatada');
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
      debugPrint(
          '🚫 Clínica encerrada: Dia da semana configurado - ${diasSemana[diaSemana]}');
      return;
    }

    // TERCEIRO: Verificar se é feriado e se está configurado para encerrar em feriados
    debugPrint(
        '  🔍 Verificando ${feriados.length} feriados para $dataFormatada');
    for (final f in feriados) {
      debugPrint('    - Feriado: ${f['data']} - ${f['descricao']}');
    }

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
          // Se não conseguir fazer parse, comparar strings diretamente
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
        debugPrint(
            '🚫 Clínica encerrada: Feriado configurado - ${feriado['descricao']} (data: ${feriado['data']})');
        return;
      }
    }

    // QUARTO: Verificar horários tradicionais (fallback)
    final horariosDoDia = horariosClinica[diaSemana] ?? [];
    if (horariosDoDia.isEmpty) {
      clinicaFechada = true;
      mensagemClinicaFechada = 'Sem horários';
      debugPrint(
          '🚫 Clínica encerrada: Sem horários configurados para o dia da semana');
      return;
    }

    clinicaFechada = false;
    mensagemClinicaFechada = '';
  }

  /// Agenda a atualização de médicos disponíveis com debounce
  /// Isso evita atualizações parciais quando disponibilidades e alocações
  /// chegam em momentos diferentes dos listeners
  void _agendarAtualizacaoMedicosDisponiveis() {
    // Cancelar timer anterior se existir
    _debounceTimer?.cancel();

    // Agendar nova atualização após um delay maior
    // Isso permite que ambos os listeners (disponibilidades e alocações)
    // processem seus dados antes de atualizar a UI
    // Aumentado para 400ms para evitar o comportamento de "piscar" quando alocamos séries
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        // Chamar assincronamente para não bloquear o listener
        _atualizarMedicosDisponiveis().catchError((e) {
          debugPrint('❌ Erro ao atualizar médicos disponíveis no listener: $e');
        });
      }
    });
  }

  /// Regenera alocações de séries para o dia atual
  /// Isso garante que alocações de séries alocadas sejam sempre exibidas
  Future<List<Alocacao>> _regenerarAlocacoesSeries() async {
    try {
      final dataInicio =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final dataFim = dataInicio.add(const Duration(days: 1));

      // OTIMIZAÇÃO CRÍTICA: Usar apenas médicos que já têm séries alocadas no cache
      // Isso evita carregar séries de todos os médicos quando só precisa das séries alocadas
      final anoParaCache = selectedDate.year;
      final medicosComSeriesAlocadasNoCache =
          logic.AlocacaoMedicosLogic.obterMedicosComSeriesAlocadasNoCache(
              anoParaCache);

      // Se não encontrou médicos no cache, verificar se há alocações existentes
      // Se não há alocações, não precisa processar nenhum médico
      if (medicosComSeriesAlocadasNoCache.isEmpty) {
        // Verificar se há alocações para o dia atual
        final alocacoesDoDia = alocacoes.where((a) {
          final ad = DateTime(a.data.year, a.data.month, a.data.day);
          final sd =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          return ad == sd;
        }).toList();

        if (alocacoesDoDia.isEmpty) {
          // Não há alocações e não há séries alocadas no cache
          // Não precisa processar nenhum médico
          debugPrint(
              '⚡ OTIMIZAÇÃO: Nenhuma alocação para o dia, pulando regeneração de alocações de séries');
          return <Alocacao>[];
        }
      }

      // OTIMIZAÇÃO: Se não encontrou médicos no cache, verificar se há alocações de séries
      // Se não há alocações de séries, não precisa processar nenhum médico
      List<String> medicoIds;
      if (medicosComSeriesAlocadasNoCache.isNotEmpty) {
        // Usar médicos do cache
        medicoIds = medicosComSeriesAlocadasNoCache;
      } else {
        // Verificar se há alocações de séries (que começam com "serie_")
        final alocacoesSeriesDoDia = alocacoes.where((a) {
          final ad = DateTime(a.data.year, a.data.month, a.data.day);
          final sd =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          return ad == sd && a.id.startsWith('serie_');
        }).toList();

        if (alocacoesSeriesDoDia.isEmpty) {
          // Não há alocações de séries para o dia, não precisa processar nenhum médico
          debugPrint(
              '⚡ OTIMIZAÇÃO: Nenhuma alocação de série para o dia, pulando regeneração');
          return <Alocacao>[];
        }

        // Se há alocações de séries, extrair os médicos dessas alocações
        final medicosDasAlocacoes =
            alocacoesSeriesDoDia.map((a) => a.medicoId).toSet().toList();
        medicoIds = medicosDasAlocacoes;
        debugPrint(
            '⚡ OTIMIZAÇÃO: Processando apenas ${medicosDasAlocacoes.length} médicos com alocações de séries (de ${medicos.where((m) => m.ativo).length} total)');
      }

      final alocacoesGeradas = <Alocacao>[];

      for (final medicoId in medicoIds) {
        // OTIMIZAÇÃO: Tentar usar cache primeiro antes de carregar do servidor
        final cacheFoiInvalidado =
            logic.AlocacaoMedicosLogic.cacheFoiInvalidado(
                medicoId, anoParaCache);

        // CORREÇÃO: Verificar se o médico teve cache invalidado para qualquer ano
        // Se sim, considerar que o cache foi invalidado também para este ano
        // Isso é importante quando invalida com null (todos os anos)
        // Se o médico tem cache invalidado para qualquer ano, forçar recarregamento do servidor
        final medicoTemCacheInvalidado =
            logic.AlocacaoMedicosLogic.medicoTemCacheInvalidado(medicoId);
        final cacheFoiInvalidadoParaMedico =
            cacheFoiInvalidado || medicoTemCacheInvalidado;

        List<SerieRecorrencia> series;
        List<ExcecaoSerie> excecoes;

        // Verificar se há cache disponível
        final cachedData = logic.AlocacaoMedicosLogic.obterSeriesDoCache(
            medicoId, anoParaCache);
        // CORREÇÃO: Não usar cache se foi invalidado para este ano OU se o médico tem cache invalidado
        if (cachedData != null && !cacheFoiInvalidadoParaMedico) {
          series = (cachedData['series'] as List).cast<SerieRecorrencia>();
          excecoes = (cachedData['excecoes'] as List).cast<ExcecaoSerie>();

          // Filtrar apenas séries com gabineteId (alocadas) e exceções do dia
          series = series
              .where((s) =>
                  s.ativo && s.gabineteId != null && s.gabineteId!.isNotEmpty)
              .toList();
          excecoes = excecoes
              .where((e) =>
                  e.data.year == dataInicio.year &&
                  e.data.month == dataInicio.month &&
                  e.data.day == dataInicio.day)
              .toList();

          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('  📦 Usando cache para $medicoId: ${series.length} séries alocadas');
        } else {
          // Debug quando cache foi invalidado
          if (cacheFoiInvalidadoParaMedico) {
            debugPrint(
                '🔄 Cache invalidado para médico $medicoId (ano: $anoParaCache) - forçando recarregamento do servidor');
            debugPrint(
                '   📅 Carregando exceções para data: ${dataInicio.day}/${dataInicio.month}/${dataInicio.year}');
          }

          // Carregar séries do servidor apenas se não há cache
          final seriesCarregadas = await SerieService.carregarSeries(
            medicoId,
            unidade: widget.unidade,
            dataInicio: null,
            dataFim: dataInicio.add(const Duration(days: 1)),
          );

          // Filtrar apenas séries com gabineteId (alocadas)
          series = seriesCarregadas
              .where((s) =>
                  s.ativo && s.gabineteId != null && s.gabineteId!.isNotEmpty)
              .toList();

          if (series.isEmpty) {
            continue;
          }

          // Carregar exceções apenas para o dia atual
          // CORREÇÃO: Forçar servidor quando cache foi invalidado para garantir exceções recém-criadas
          final excecoesCarregadas = await SerieService.carregarExcecoes(
            medicoId,
            unidade: widget.unidade,
            dataInicio: dataInicio,
            dataFim: dataFim,
            forcarServidor:
                cacheFoiInvalidadoParaMedico, // Forçar servidor se cache foi invalidado
          );

          // Debug: mostrar exceções carregadas
          if (cacheFoiInvalidadoParaMedico) {
            final excecoesComGabinete =
                excecoesCarregadas.where((e) => e.gabineteId != null).toList();
            debugPrint(
                '📋 Exceções carregadas do servidor: ${excecoesCarregadas.length} total, ${excecoesComGabinete.length} com gabinete');
            for (final ex in excecoesComGabinete) {
              debugPrint(
                  '   📋 Exceção: série=${ex.serieId}, data=${ex.data.day}/${ex.data.month}/${ex.data.year}, gabinete=${ex.gabineteId}');
            }
          }

          // Filtrar exceções apenas para o dia atual
          excecoes = excecoesCarregadas
              .where((e) =>
                  e.data.year == dataInicio.year &&
                  e.data.month == dataInicio.month &&
                  e.data.day == dataInicio.day)
              .toList();

          if (cacheFoiInvalidadoParaMedico) {
            debugPrint(
                '📋 Exceções filtradas para o dia: ${excecoes.length} (${excecoes.where((e) => e.gabineteId != null).length} com gabinete)');
          }
        }

        // Filtrar apenas séries com gabineteId != null (já filtrado acima, mas manter para compatibilidade)
        final seriesComGabinete = series
            .where((s) => s.gabineteId != null && s.gabineteId!.isNotEmpty)
            .toList();

        if (seriesComGabinete.isEmpty) {
          continue;
        }

        // Gerar alocações dinamicamente
        final alocsGeradas = SerieGenerator.gerarAlocacoes(
          series: seriesComGabinete,
          excecoes: excecoes,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

        alocacoesGeradas.addAll(alocsGeradas);
      }

      debugPrint(
          '🔄 Alocações de séries regeneradas: ${alocacoesGeradas.length} para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
      return alocacoesGeradas;
    } catch (e) {
      debugPrint('❌ Erro ao regenerar alocações de séries: $e');
      return [];
    }
  }

  Future<void> _atualizarMedicosDisponiveis() async {
    // CORREÇÃO CRÍTICA: Não atualizar durante transições para evitar "piscar"
    if (_isProcessandoAlocacao ||
        _medicoEmTransicao != null ||
        _listenerPausado) {
      debugPrint(
          '⚠️ [ATUALIZAR-MÉDICOS] Ignorando: _isProcessandoAlocacao=$_isProcessandoAlocacao, _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');

      return;
    }

    debugPrint(
        '🔍 _atualizarMedicosDisponiveis chamado para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
    debugPrint('  📊 Total de disponibilidades: ${disponibilidades.length}');
    debugPrint('  📊 Total de médicos: ${medicos.length}');

    // CORREÇÃO CRÍTICA: Incluir médico em transição como alocado
    // Isso previne que apareça na caixa de médicos disponíveis durante movimento
    final medicosAlocados = alocacoes
        .where((a) =>
            DateFormat('yyyy-MM-dd').format(a.data) ==
            DateFormat('yyyy-MM-dd').format(selectedDate))
        .map((a) => a.medicoId)
        .toSet();

    // Se há transição em andamento, garantir que o médico não apareça como disponível
    if (_medicoEmTransicao != null) {
      medicosAlocados.add(_medicoEmTransicao!);
      debugPrint(
          '  🔒 Médico em transição $_medicoEmTransicao marcado como alocado');
    }

    debugPrint('  📊 Médicos alocados: ${medicosAlocados.length}');

    // Carregar exceções canceladas para o dia selecionado
    // Isso garante que médicos com exceções canceladas não apareçam na caixa "para alocar"

    debugPrint('  🔄 Carregando exceções canceladas...');
    final datasComExcecoesCanceladas =
        await logic.AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      widget.unidade.id,
      selectedDate,
    );

    debugPrint(
        '  🚫 Exceções canceladas encontradas: ${datasComExcecoesCanceladas.length}');
    for (final key in datasComExcecoesCanceladas) {
      debugPrint('    - $key');
    }

    // Filtra médicos que:
    // 1. Não estão alocados no dia selecionado
    // 2. Têm disponibilidade para o dia selecionado
    // 3. NÃO têm exceção cancelada para esse dia
    final selectedDateNormalized =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    // OTIMIZAÇÃO: Em vez de iterar sobre todos os médicos, primeiro criar um Set
    // de IDs de médicos que têm disponibilidade para o dia (iterando apenas sobre disponibilidades)
    final medicosComDisponibilidade = <String>{};
    for (final d in disponibilidades) {
      final dd = DateTime(d.data.year, d.data.month, d.data.day);
      if (dd == selectedDateNormalized) {
        medicosComDisponibilidade.add(d.medicoId);
        // Mensagem de debug removida para reduzir ruído no terminal
        // debugPrint('  ✅ Médico ${d.medicoId} tem disponibilidade: ${d.tipo} - ${d.id} - ${d.data.day}/${d.data.month}/${d.data.year} - horários: ${d.horarios}');
      }
    }

    if (mounted) {
      setState(() {
        // OTIMIZAÇÃO: Agora iterar apenas sobre médicos que têm disponibilidade
        // (muito menos iterações: de 155 para ~10)
        medicosDisponiveis = medicos.where((m) {
          // FILTRAR: Não mostrar médicos inativos
          if (!m.ativo) {
            return false;
          }

          // Verifica se não está alocado
          if (medicosAlocados.contains(m.id)) {
            return false;
          }

          // Verifica se tem exceção cancelada para esse dia
          final dataKey =
              '${m.id}_${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
          if (datasComExcecoesCanceladas.contains(dataKey)) {
            debugPrint(
                '🚫 Filtrando médico ${m.nome} (${m.id}) - tem exceção cancelada para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
            return false; // Não mostrar se tem exceção cancelada
          }

          // OTIMIZAÇÃO: Verificar apenas se o médico está no Set de médicos com disponibilidade
          // (muito mais rápido que iterar sobre todas as disponibilidades)
          return medicosComDisponibilidade.contains(m.id);
        }).toList();

        debugPrint(
            '  ✅ Médicos disponíveis após filtro: ${medicosDisponiveis.length}');
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

  void _onDateChanged(DateTime newDate) {
    // CORREÇÃO: Invalidar cache do dia anterior e do novo dia para garantir dados atualizados
    // Isso garante que quando o usuário cria uma nova série e muda de dia, os dados sejam recarregados
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(selectedDate);
    logic.AlocacaoMedicosLogic.invalidateCacheForDay(newDate);

    setState(() {
      selectedDate = newDate;
      isCarregando = true;
      progressoCarregamento = 0.0;
      mensagemProgresso = 'A iniciar...';
      // CORREÇÃO CRÍTICA: Limpar dados do dia anterior antes de carregar novos dados
      // Isso evita que dados de um dia sejam transportados para outro dia
      disponibilidades.clear();
      alocacoes.clear();
      medicosDisponiveis.clear();
    });

    // Recarregar dados do dia (cache foi invalidado, então vai recarregar)
    // A verificação de encerramento será feita dentro de _carregarDadosIniciais
    _carregarDadosIniciais();
  }

  Future<void> _alocarMedico(String medicoId, String gabineteId,
      {DateTime? dataEspecifica, List<String>? horarios}) async {
    // CORREÇÃO: Evitar múltiplas atualizações durante operação
    if (_isProcessandoAlocacao) {
      debugPrint(
          '⚠️ Já está processando uma alocação, ignorando chamada duplicada');
      return;
    }

    // CORREÇÃO CRÍTICA: Se há uma transição em andamento para outro médico, aguardar
    if (_medicoEmTransicao != null && _medicoEmTransicao != medicoId) {
      debugPrint(
          '⚠️ Aguardando transição anterior terminar antes de alocar médico $medicoId');
      // Aguardar um pouco e tentar novamente
      await Future.delayed(const Duration(milliseconds: 500));
      if (_medicoEmTransicao != null && _medicoEmTransicao != medicoId) {
        debugPrint(
            '❌ Transição anterior ainda em andamento, cancelando alocação');
        return;
      }
    }

    final dataAlvo = dataEspecifica ?? selectedDate;
    final dataAlvoNormalizada =
        DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

    try {
      _isProcessandoAlocacao = true;

      // NOVO: Atualização otimista ANTES de salvar no Firestore
      // Isso faz o cartão aparecer no gabinete instantaneamente, evitando "piscar"
      debugPrint(
          '🟢 [ALOCAÇÃO] Executando atualização otimista: médico=$medicoId, gabinete=$gabineteId');

      // PAUSAR listener para prevenir interferência durante operação
      _listenerPausado = true;
      _medicoEmTransicao = medicoId;

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

      // CORREÇÃO CRÍTICA: Verificar se já existe uma alocação no gabinete destino (após atualização otimista)
      // Se já existe, não remover nem adicionar novamente para evitar duplicação
      final alocacoesNoDestino = alocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteId &&
            aDate == dataAlvoNormalizada;
      }).toList();

      if (alocacoesNoDestino.isNotEmpty) {
        debugPrint(
            '⚠️ [ALOCAÇÃO] Alocação já existe no destino (após atualização otimista), apenas sincronizando com Firestore. IDs existentes: ${alocacoesNoDestino.map((a) => a.id).join(", ")}');

        // CORREÇÃO: A alocação já está no destino (atualização otimista), mas ainda precisa ser salva no Firestore
        // Não criar nova alocação otimista, apenas salvar a existente no Firestore
        // Salvar no Firestore sem criar nova alocação otimista
        try {
          await logic.AlocacaoMedicosLogic.alocarMedico(
            selectedDate: dataAlvo,
            medicoId: medicoId,
            gabineteId: gabineteId,
            alocacoes: alocacoes,
            disponibilidades: disponibilidades,
            onAlocacoesChanged: () {},
            unidade: widget.unidade,
            horariosForcados: horarios,
          );
          debugPrint(
              '✅ [ALOCAÇÃO] Alocação sincronizada com Firestore (sem criar duplicado)');
        } catch (e) {
          debugPrint('❌ [ALOCAÇÃO] Erro ao sincronizar: $e');
        }

        // Aguardar um pouco para garantir que o Firestore salvou
        await Future.delayed(const Duration(milliseconds: 200));

        // Reativar listener e limpar flags
        _listenerPausado = false;
        _medicoEmTransicao = null;
        _isProcessandoAlocacao = false;
        return;
      }

      // CORREÇÃO CRÍTICA: Remover apenas alocações que NÃO estão no gabinete destino
      // Se a atualização otimista já moveu a alocação para o destino, não remover essa
      alocacoes.removeWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        // Remover apenas se:
        // 1. É do mesmo médico e mesmo dia, E
        // 2. NÃO está no gabinete destino (para preservar a atualização otimista)
        return a.medicoId == medicoId &&
            aDate == dataAlvoNormalizada &&
            a.gabineteId != gabineteId;
      });

      // Criar nova alocação otimista (ID temporário, será substituído pelo ID real do Firestore)
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final dataStr =
          '${dataAlvoNormalizada.year}${dataAlvoNormalizada.month.toString().padLeft(2, '0')}${dataAlvoNormalizada.day.toString().padLeft(2, '0')}';
      final alocacaoOtimista = Alocacao(
        id: 'otimista_${timestamp}_${medicoId}_${gabineteId}_$dataStr',
        medicoId: medicoId,
        gabineteId: gabineteId,
        data: dataAlvoNormalizada,
        horarioInicio: horarioInicio,
        horarioFim: horarioFim,
      );

      // Adicionar alocação otimista localmente
      alocacoes.add(alocacaoOtimista);

      // Atualizar UI imediatamente para mostrar o cartão no gabinete

      if (mounted) {
        setState(() {
          // Estado já foi atualizado acima (alocacoes.add)
        });
      }

      debugPrint(
          '✅ [ALOCAÇÃO] Atualização otimista concluída - cartão deve aparecer no gabinete');

      // Pequeno delay para garantir que a UI foi atualizada
      await Future.delayed(const Duration(milliseconds: 50));

      // Agora salvar no Firestore
      await logic.AlocacaoMedicosLogic.alocarMedico(
        selectedDate: dataAlvo,
        medicoId: medicoId,
        gabineteId: gabineteId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        onAlocacoesChanged: () {
          // CORREÇÃO: NÃO recarregar durante processamento - será feito no final
          // Isso evita múltiplas atualizações que causam "piscar"
        },
        unidade: widget.unidade,
        horariosForcados: horarios,
      );

      // CORREÇÃO: Aguardar tempo suficiente para garantir que o Firestore salvou completamente
      // Reduzido para evitar bloqueios longos
      await Future.delayed(const Duration(milliseconds: 300));

      // CORREÇÃO MELHORADA: Em vez de recarregar tudo, apenas aguardar que o listener do Firestore
      // atualize a alocação otimista com o ID real do servidor
      // Isso evita o "piscar" causado por recarregamento completo
      // O listener vai substituir a alocação otimista pela real quando receber do Firestore

      // Aguardar um pouco para que o listener do Firestore processe a atualização
      await Future.delayed(const Duration(milliseconds: 200));

      // REATIVAR listener e limpar flags
      // O listener do Firestore vai atualizar a alocação otimista com o ID real
      debugPrint(
          '🟢 [ALOCAÇÃO] Reativando listener e limpando flags: _listenerPausado=false, _medicoEmTransicao=null');
      _listenerPausado = false;
      _medicoEmTransicao = null;
      debugPrint('✅ [ALOCAÇÃO] Flags limpas após alocação bem-sucedida');
    } catch (e) {
      debugPrint('❌ Erro ao alocar médico: $e');

      // Em caso de erro, reverter atualização otimista
      if (_medicoEmTransicao != null) {
        debugPrint('🔄 Revertendo atualização otimista devido a erro');
        // Reativar listener e recarregar dados para reverter estado
        _listenerPausado = false;
        _medicoEmTransicao = null;
        try {
          await _carregarDadosIniciais();
        } catch (e2) {
          debugPrint('❌ Erro ao recarregar dados após erro: $e2');
        }
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
      // CORREÇÃO CRÍTICA: SEMPRE limpar flags no finally para evitar bloqueios
      // Isso garante que mesmo em caso de erro, o app não fica bloqueado
      debugPrint(
          '🔴 [ALOCAÇÃO] FINALLY: Limpando todas as flags (garantia absoluta)');
      debugPrint(
          '🔴 [ALOCAÇÃO] Estado antes: _isProcessandoAlocacao=$_isProcessandoAlocacao, _listenerPausado=$_listenerPausado, _medicoEmTransicao=$_medicoEmTransicao');
      _isProcessandoAlocacao = false;
      _listenerPausado = false;
      _medicoEmTransicao = null;
      debugPrint(
          '✅ [ALOCAÇÃO] FINALLY: Todas as flags limpas: _isProcessandoAlocacao=false, _listenerPausado=false, _medicoEmTransicao=null');
    }
  }

  /// Limpa as flags de transição após realocação concluída
  /// Isso garante que o listener seja reativado e a UI volte ao normal
  void _limparFlagsTransicao() {
    debugPrint(
        '🔴 [LIMPAR-FLAGS] Limpando flags de transição: _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');

    // Cancelar timeout se ainda estiver ativo
    _timeoutFlagsTransicao?.cancel();
    _timeoutFlagsTransicao = null;

    _medicoEmTransicao = null;
    _listenerPausado = false;
    debugPrint(
        '✅ [LIMPAR-FLAGS] Flags limpas: _medicoEmTransicao=null, _listenerPausado=false');
  }

  /// Atualização otimista durante realocação - atualiza estado local imediatamente
  /// para feedback visual instantâneo antes das operações no Firestore
  void _realocacaoOtimista(String medicoId, String gabineteOrigem,
      String gabineteDestino, DateTime data) {
    debugPrint(
        '🔵 [OTIMISTA] INÍCIO: médico=$medicoId, origem=$gabineteOrigem, destino=$gabineteDestino');
    debugPrint(
        '🔵 [OTIMISTA] Estado atual: _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');

    // CORREÇÃO CRÍTICA: Verificar se já há uma transição em andamento
    // Isso previne bloqueios quando o usuário tenta mover o mesmo cartão múltiplas vezes
    if (_medicoEmTransicao != null && _medicoEmTransicao != medicoId) {
      debugPrint(
          '⚠️ [OTIMISTA] Já há transição para médico $_medicoEmTransicao, ignorando nova transição para $medicoId');
      return;
    }

    // Se é a mesma transição, permitir (pode ser chamado múltiplas vezes)
    if (_medicoEmTransicao == medicoId && _listenerPausado) {
      debugPrint(
          '⚠️ [OTIMISTA] Transição já em andamento para este médico, continuando...');
      return;
    }

    // PAUSAR listener completamente para prevenir interferência
    debugPrint(
        '🟢 [OTIMISTA] DEFININDO FLAGS: _listenerPausado=true, _medicoEmTransicao=$medicoId');
    _listenerPausado = true;

    // Marcar transição para prevenir atualizações do listener
    _medicoEmTransicao = medicoId;

    // CORREÇÃO CRÍTICA: Adicionar timeout para limpar flags presas automaticamente após 10 segundos
    // Isso garante que mesmo se algo der errado, as flags serão limpas
    _timeoutFlagsTransicao?.cancel();
    _timeoutFlagsTransicao = Timer(const Duration(seconds: 10), () {
      if (_medicoEmTransicao == medicoId || _listenerPausado) {
        debugPrint(
            '⚠️ [TIMEOUT] Limpando flags presas após 10 segundos: _medicoEmTransicao=$_medicoEmTransicao, _listenerPausado=$_listenerPausado');
        _limparFlagsTransicao();
      }
    });

    debugPrint(
        '🟢 [OTIMISTA] Flags definidas - listener pausado, médico em transição marcado');

    // Encontrar todas as alocações do médico no dia do gabinete de origem
    final alocacoesParaMover = alocacoes.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate.year == data.year &&
          aDate.month == data.month &&
          aDate.day == data.day;
    }).toList();

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
    // Isso garante que o médico não apareça na caixa de disponíveis durante transição
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

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    final medico = medicos.firstWhere((m) => m.id == medicoId);

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

    final alocacao = alocacoesDoDia.first;

    // Encontrar o nome do gabinete
    final gabinete = gabinetes.firstWhere(
      (g) => g.id == alocacao.gabineteId,
      orElse: () => Gabinete(
        id: '',
        nome: 'Gabinete Desconhecido',
        setor: '',
        especialidadesPermitidas: [],
      ),
    );

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

      // Se a lista local tem informações suficientes, usar ela
      // (a lista local já contém todas as alocações do dia selecionado e pode ter outras)
      if (alocacoesLocaisDoMedicoTodas.length > 1 || podeSerSerieLocal) {
        debugPrint(
            '⚡ Usando lista local para verificação (${alocacoesLocaisDoMedicoTodas.length} alocações encontradas)');
        alocacoesMedicoFirebase = alocacoesLocaisDoMedicoTodas;
      } else {
        // Apenas buscar no Firebase se realmente necessário
        debugPrint(
            '🔍 Buscando todas as alocações do médico $medicoId do Firebase...');
        alocacoesMedicoFirebase =
            await logic.AlocacaoMedicosLogic.buscarAlocacoesMedico(
          widget.unidade,
          medicoId,
          anoEspecifico: selectedDate.year,
        );
        debugPrint(
            '  📊 Total de alocações do médico no Firebase: ${alocacoesMedicoFirebase.length}');
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

    // Se é tipo único E não há alocações futuras/passadas (não pode ser série), apenas confirmar
    // Caso contrário (tipo série OU pode ser série), sempre perguntar se quer desalocar apenas o dia ou toda a série
    if (!eTipoSerie && tipoDisponibilidade == 'Única' && !podeSerSerie) {
      debugPrint(
          '  ℹ️ Disponibilidade única sem alocações futuras/passadas - apenas confirmar');
      // Para disponibilidade única, apenas confirmar
      if (!mounted) return;
      final confirmacao = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Desalocação'),
          content: Text(
            'Tem certeza que deseja desalocar ${medico.nome} do ${gabinete.nome}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Desalocar'),
            ),
          ],
        ),
      );

      if (confirmacao == true) {
        escolha = '1dia';
      }
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
      await logic.AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
        selectedDate: selectedDate,
        medicoId: medicoId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: () {
          _carregarDadosIniciais();
        },
        unidade: widget.unidade,
      );
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
    try {
      await logic.AlocacaoMedicosLogic.desalocarMedicoSerie(
        medicoId: medicoId,
        dataRef: selectedDate,
        tipo: tipo,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        medicos: medicos,
        medicosDisponiveis: medicosDisponiveis,
        onAlocacoesChanged: () {
          _carregarDadosIniciais();
        },
        unidade: widget.unidade,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao desalocar série: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyStateOrContent() {
    // Se está carregando, não mostrar nada aqui (o overlay principal já mostra a barra de progresso)
    // Isso evita duplicação de barras de progresso
    if (isCarregando) {
      return const SizedBox
          .shrink(); // Widget vazio - o overlay principal mostra o progresso
    }

    // Se não está carregando E não há dados, mostrar estado vazio
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

        // Seção de médicos disponíveis - apenas para administradores
        if (widget.isAdmin) ...[
          Container(
            constraints: const BoxConstraints(minHeight: 85),
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                final medicoId = details.data;
                // Verifica se o médico realmente está alocado antes de aceitar o cartão
                final estaAlocado =
                    alocacoes.any((a) => a.medicoId == medicoId);
                if (!estaAlocado) {
                  debugPrint(
                      'Médico $medicoId NÃO está alocado, ignorando desalocação.');
                  return false;
                }
                debugPrint(
                    'Médico $medicoId está alocado, aceitando para desalocar.');
                return true;
              },
              onAcceptWithDetails: (details) async {
                final medicoId = details.data;
                // Agora só será chamado para médicos alocados
                await _desalocarMedicoComPergunta(medicoId);
              },
              builder: (context, candidateData, rejectedData) {
                return MedicosDisponiveisSection(
                  medicosDisponiveis: medicosDisponiveis,
                  disponibilidades: disponibilidades,
                  selectedDate: selectedDate,
                  onDesalocarMedico: (mId) => _desalocarMedicoDiaUnico(mId),
                );
              },
            ),
          ),
        ] else ...[
          // Para utilizadores não-administradores, mostrar mensagem informativa
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modo de visualização: Apenas administradores podem fazer alterações nas alocações.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

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
            ),
          ),
        ),
      ],
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
    // Não é mais necessário com Transform.scale direto
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
      ),
      drawer: CustomDrawer(
        onRefresh: () => _carregarDadosIniciais(
            recarregarMedicos: true), // Recarrega tudo, incluindo médicos
        unidade: widget.unidade, // Passa a unidade para personalizar o drawer
        isAdmin: widget.isAdmin, // Passa informação se é administrador
      ),
      // Corpo com cor de fundo suave e layout responsivo
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Container principal sem zoom - mantém barra lateral visível
              Container(
                color: Colors.grey.shade200,
                child: _deveUsarLayoutResponsivo(context)
                    ? _buildLayoutResponsivo()
                    : _buildLayoutDesktop(),
              ),
              if (isCarregando)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mensagem de status
                          Text(
                            mensagemProgresso,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade200),
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
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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

  // Conteúdo da coluna esquerda (DatePicker + Filtros + Pesquisa)
  Widget _buildColunaEsquerda() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // DatePicker
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: CalendarioDisponibilidades(
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
                // Quando o usuário navega no calendário, atualizar a data selecionada
                setState(() {
                  selectedDate = visibleDate;
                });
                _onDateChanged(visibleDate);
              },
            ),
          ),

          // Filtros
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 12),
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

          // Pesquisa
          PesquisaSection(
            pesquisaNome: pesquisaNome,
            pesquisaEspecialidade: pesquisaEspecialidade,
            opcoesNome: _getOpcoesPesquisaNome(),
            opcoesEspecialidade: _getOpcoesPesquisaEspecialidade(),
            onPesquisaNomeChanged: _aplicarPesquisaNome,
            onPesquisaEspecialidadeChanged: _aplicarPesquisaEspecialidade,
            onLimparPesquisa: _limparPesquisa,
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
    _debounceRegeneracaoSeries?.cancel();
    _dispSub?.cancel();
    _alocSub?.cancel();
    _transformationController.dispose();
    super.dispose();
  }
}
