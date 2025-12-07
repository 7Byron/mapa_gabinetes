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
import '../utils/alocacao_medicos_logic.dart';

// Models
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../models/unidade.dart';

// Services
import '../services/password_service.dart';

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

class AlocacaoMedicosState extends State<AlocacaoMedicos> {
  bool isCarregando = true;
  Timer? _debounceTimer; // Timer para debounce das atualizações dos listeners
  DateTime selectedDate = DateTime.now();
  bool _ignorarPrimeirasAtualizacoesListeners = false; // Flag para ignorar primeiras atualizações dos listeners

  // Controle de layout responsivo
  bool mostrarColunaEsquerda = true; // Para ecrãs pequenos

  // Dados principais
  List<Gabinete> gabinetes = [];
  List<Medico> medicos = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Medico> medicosDisponiveis = [];

  // Dados da clínica
  List<Map<String, String>> feriados = [];
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

  Future<void> _restartDayListeners() async {
    await _dispSub?.cancel();
    await _alocSub?.cancel();

    final firestore = FirebaseFirestore.instance;
    final inicio =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final fim = inicio.add(const Duration(days: 1));
    final startIso = inicio.toIso8601String();
    final endIso = fim.toIso8601String();

    // Usar médicos já carregados em vez de fazer query novamente
    // Isso evita queries desnecessárias ao mudar de dia
    final medicoIds = medicos.map((m) => m.id).toSet();
    
    // Criar mapa de médicos para busca rápida
    final medicosMap = <String, Medico>{};
    for (final m in medicos) {
      medicosMap[m.id] = m;
    }

    _dispSub = firestore
        .collectionGroup('registos')
        .where('data', isGreaterThanOrEqualTo: startIso)
        .where('data', isLessThan: endIso)
        .snapshots()
        .listen((snap) async {
      final dispDia = <Disponibilidade>[];
      final novosMedicosIds = <String>{};
      
      for (final doc in snap.docs) {
        final d = Disponibilidade.fromMap(doc.data());
        // Verificar se o médico pertence à unidade
        if (medicoIds.contains(d.medicoId)) {
          dispDia.add(d);
          // Se o médico não está na lista local, marcar para carregar
          if (!medicosMap.containsKey(d.medicoId)) {
            novosMedicosIds.add(d.medicoId);
          }
        }
      }
      
      // Se houver novos médicos com disponibilidades, carregá-los
      // Mas apenas se realmente necessário (evitar queries desnecessárias)
      if (novosMedicosIds.isNotEmpty && mounted) {
        // Carregar médicos em paralelo para melhor performance
        final novosMedicos = <Medico>[];
        final ocupantesRef = firestore
            .collection('unidades')
            .doc(widget.unidade.id)
            .collection('ocupantes');
        
        final futures = novosMedicosIds.map((medicoId) async {
          try {
            final medicoDoc = await ocupantesRef.doc(medicoId).get();
            if (medicoDoc.exists) {
              final dados = medicoDoc.data() as Map<String, dynamic>;
              return Medico(
                id: dados['id'] ?? medicoId,
                nome: dados['nome'] ?? '',
                especialidade: dados['especialidade'] ?? '',
                observacoes: dados['observacoes'],
                disponibilidades: const [],
                ativo: dados['ativo'] ?? true,
              );
            }
          } catch (e) {
            debugPrint('Erro ao carregar médico $medicoId: $e');
          }
          return null;
        });
        
        final resultados = await Future.wait(futures);
        novosMedicos.addAll(resultados.whereType<Medico>());
        
        if (novosMedicos.isNotEmpty && mounted) {
      setState(() {
            medicos.addAll(novosMedicos);
            for (final m in novosMedicos) {
              medicosMap[m.id] = m;
            }
          });
        }
      }
      if (!mounted) return;
      // Atualizar lista local sem setState imediato
      // IMPORTANTE: Não remover disponibilidades geradas de séries (ID começa com 'serie_')
      // Apenas remover disponibilidades do Firestore (que não são geradas de séries)
        disponibilidades.removeWhere((d) =>
            d.data.year == inicio.year &&
            d.data.month == inicio.month &&
          d.data.day == inicio.day &&
          !d.id.startsWith('serie_')); // Preservar disponibilidades geradas de séries
      
      // Adicionar novas disponibilidades do Firestore
        disponibilidades.addAll(dispDia);
      
      // NÃO recarregar disponibilidades de séries aqui - elas já são geradas dinamicamente
      // em _carregarDisponibilidadesUnidade e são preservadas acima (não removidas)
      // Recarregar aqui causaria múltiplas chamadas desnecessárias e lentidão
      
      final doDia = disponibilidades.where((d) {
        final dd = DateTime(d.data.year, d.data.month, d.data.day);
        return dd == inicio;
      }).toList();
      AlocacaoMedicosLogic.updateCacheForDay(
          day: inicio, disponibilidades: doDia);
      // Agendar atualização com debounce para evitar atualizações parciais
      // quando disponibilidades e alocações chegam em momentos diferentes
      // Ignorar se estamos no meio do carregamento inicial
      if (!_ignorarPrimeirasAtualizacoesListeners) {
        _agendarAtualizacaoMedicosDisponiveis();
      }
    });

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
      final alocDia = snap.docs.map((d) => Alocacao.fromMap(d.data())).toList();
      if (!mounted) return;
      // IMPORTANTE: Remover apenas alocações do Firestore para este dia, não as geradas dinamicamente
      // Alocações geradas dinamicamente têm ID começando com "serie_"
      alocacoes.removeWhere((a) =>
          a.data.year == inicio.year &&
          a.data.month == inicio.month &&
          a.data.day == inicio.day &&
          !a.id.startsWith('serie_')); // Manter alocações geradas dinamicamente
      // Adicionar alocações do Firestore (têm prioridade sobre geradas dinamicamente)
      alocacoes.addAll(alocDia);
      
      final doDia = alocacoes.where((a) {
        final ad = DateTime(a.data.year, a.data.month, a.data.day);
        return ad == inicio;
      }).toList();
      AlocacaoMedicosLogic.updateCacheForDay(day: inicio, alocacoes: doDia);
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
    _carregarDadosIniciais();
    // Carregar passwords em background (não bloqueia a UI)
    _carregarPasswordsDoFirebase();
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
    try {
      // FASE 1: Carregar dados essenciais primeiro (gabinetes, médicos, disponibilidades e alocações)
      // NÃO chamar setState() nos callbacks individuais para evitar atualizações parciais
      // que causam o efeito de cartões aparecendo na área branca e depois sendo movidos
      await AlocacaoMedicosLogic.carregarDadosIniciais(
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        onGabinetes: (g) {
          gabinetes = g;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onMedicos: (m) {
          medicos = m;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onDisponibilidades: (d) {
          disponibilidades = d;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        onAlocacoes: (a) {
          alocacoes = a;
          // Não chamar setState() aqui - será chamado depois que todos os dados estiverem prontos
        },
        unidade: widget.unidade,
        dataFiltroDia: selectedDate,
        reloadStatic: recarregarMedicos, // Força recarregar médicos se solicitado
      );

      // FASE 2: Carregar dados secundários em paralelo (não bloqueiam a UI)
      // Carregar feriados, horários e configurações em paralelo
      await Future.wait([
        _carregarFeriados(),
        _carregarHorariosEConfiguracoes(),
      ]);

      // Iniciar listeners ANTES de atualizar a UI
      // Isso evita que os listeners disparem atualizações imediatamente após serem iniciados
      _ignorarPrimeirasAtualizacoesListeners = true;
      await _restartDayListeners();
      
      // Não aguardar - os listeners já têm os dados do cache ou do carregamento inicial
      // O delay estava causando lentidão desnecessária
      _ignorarPrimeirasAtualizacoesListeners = false;

      // Atualizar UI UMA ÚNICA VEZ após TODOS os dados estarem carregados e listeners iniciados
      // Isso evita múltiplas atualizações parciais que causam o efeito de cartões aparecendo/desaparecendo
      if (mounted) {
        setState(() {
          // Inicializar filtros de piso com todos os setores selecionados por padrão
          _inicializarFiltrosPiso();
          // Verificar se a clínica está fechada
          _verificarClinicaFechada();
          // Desligar progress bar
          isCarregando = false;
        });
        // Atualizar médicos disponíveis (agora com todos os dados carregados)
        // Chamar fora do setState porque é assíncrono e atualiza o estado internamente
        // IMPORTANTE: Sempre chamar, mesmo quando dados vêm do cache, para verificar exceções
        debugPrint('🔄 Chamando _atualizarMedicosDisponiveis após carregar dados iniciais...');
        await _atualizarMedicosDisponiveis();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');
      if (mounted) {
        setState(() {
          isCarregando = false;
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

        // Carrega apenas o ano atual por padrão (otimização)
        final anoAtual = DateTime.now().year.toString();
        final anoRef = feriadosRef.doc(anoAtual);
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

    // Verificar se o dia específico está configurado para encerrar
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
      mensagemClinicaFechada = 'Clínica encerrada às ${diasSemana[diaSemana]}s';
      return;
    }

    // Verificar se é feriado e se está configurado para encerrar em feriados
    final dataFormatada = DateFormat('yyyy-MM-dd').format(selectedDate);
    final feriado = feriados.firstWhere(
      (f) => f['data'] == dataFormatada,
      orElse: () => <String, String>{},
    );

    if (feriado.containsKey('id') && feriado['id']!.isNotEmpty) {
      if (encerraFeriados) {
        clinicaFechada = true;
        mensagemClinicaFechada =
            'Clínica encerrada - Feriado: ${feriado['descricao'] ?? ''}';
        return;
      }
    }

    // Verificar horários tradicionais (fallback)
    final horariosDoDia = horariosClinica[diaSemana] ?? [];
    if (horariosDoDia.isEmpty) {
      clinicaFechada = true;
      mensagemClinicaFechada = 'Clínica encerrada neste dia.';
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

  Future<void> _atualizarMedicosDisponiveis() async {
    debugPrint('🔍 _atualizarMedicosDisponiveis chamado para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
    debugPrint('  📊 Total de disponibilidades: ${disponibilidades.length}');
    debugPrint('  📊 Total de médicos: ${medicos.length}');

    final medicosAlocados = alocacoes
        .where((a) =>
            DateFormat('yyyy-MM-dd').format(a.data) ==
            DateFormat('yyyy-MM-dd').format(selectedDate))
        .map((a) => a.medicoId)
        .toSet();

    debugPrint('  📊 Médicos alocados: ${medicosAlocados.length}');

    // Carregar exceções canceladas para o dia selecionado
    // Isso garante que médicos com exceções canceladas não apareçam na caixa "para alocar"
    debugPrint('  🔄 Carregando exceções canceladas...');
    final datasComExcecoesCanceladas = await AlocacaoMedicosLogic.extrairExcecoesCanceladasParaDia(
      widget.unidade.id,
      selectedDate,
    );
    debugPrint('  🚫 Exceções canceladas encontradas: ${datasComExcecoesCanceladas.length}');
    for (final key in datasComExcecoesCanceladas) {
      debugPrint('    - $key');
    }

    // Filtra médicos que:
    // 1. Não estão alocados no dia selecionado
    // 2. Têm disponibilidade para o dia selecionado
    // 3. NÃO têm exceção cancelada para esse dia
    final selectedDateNormalized =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (mounted) {
      setState(() {
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
          final dataKey = '${m.id}_${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
          if (datasComExcecoesCanceladas.contains(dataKey)) {
            debugPrint('🚫 Filtrando médico ${m.nome} (${m.id}) - tem exceção cancelada para ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
            return false; // Não mostrar se tem exceção cancelada
          }

      // Verifica se tem disponibilidade para o dia selecionado
      final disponibilidadesDoMedico = disponibilidades.where((d) {
        final dd = DateTime(d.data.year, d.data.month, d.data.day);
            return d.medicoId == m.id && dd == selectedDateNormalized;
      }).toList();

          // FILTRAR: Só mostrar se tiver disponibilidade E o médico estiver ativo
          return disponibilidadesDoMedico.isNotEmpty && m.ativo;
    }).toList();

        debugPrint('  ✅ Médicos disponíveis após filtro: ${medicosDisponiveis.length}');
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
          orElse: () =>
              Medico(id: '', nome: '', especialidade: '', disponibilidades: [], ativo: false),
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
    setState(() {
      selectedDate = newDate;
      isCarregando = true;
    });
    _verificarClinicaFechada();
    // Recarregar dados do dia (usa cache quando disponível)
    _carregarDadosIniciais();
  }

  Future<void> _alocarMedico(String medicoId, String gabineteId,
      {DateTime? dataEspecifica, List<String>? horarios}) async {
    try {
      await AlocacaoMedicosLogic.alocarMedico(
        selectedDate: dataEspecifica ?? selectedDate,
        medicoId: medicoId,
        gabineteId: gabineteId,
        alocacoes: alocacoes,
        disponibilidades: disponibilidades,
        onAlocacoesChanged: () {
          _carregarDadosIniciais();
        },
        unidade: widget.unidade,
        horariosForcados: horarios,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alocar médico: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _desalocarMedicoComPergunta(String medicoId) async {
    final medico = medicos.firstWhere((m) => m.id == medicoId);
    
    // Encontrar todas as alocações do médico no dia selecionado
    final dataAlvo = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
    var disponibilidade = disponibilidades.where(
      (d) =>
          d.medicoId == medicoId &&
          d.data.year == selectedDate.year &&
          d.data.month == selectedDate.month &&
          d.data.day == selectedDate.day,
    ).isNotEmpty 
        ? disponibilidades.where(
            (d) =>
                d.medicoId == medicoId &&
                d.data.year == selectedDate.year &&
                d.data.month == selectedDate.month &&
                d.data.day == selectedDate.day,
          ).first
        : null;

    // BUSCAR TODAS AS ALOCAÇÕES DO MÉDICO DO FIREBASE (não apenas a lista local)
    // para verificar se há uma série completa
    debugPrint('🔍 Buscando todas as alocações do médico $medicoId do Firebase...');
    final alocacoesMedicoFirebase = await AlocacaoMedicosLogic.buscarAlocacoesMedico(
      widget.unidade,
      medicoId,
      anoEspecifico: selectedDate.year,
    );
    debugPrint('  📊 Total de alocações do médico no Firebase: ${alocacoesMedicoFirebase.length}');
    
    // Verificar se há outras alocações do mesmo médico em datas futuras ou passadas
    // que possam indicar uma série
    final dataAlvoNormalizada = DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
    
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
    debugPrint('  📅 Data alvo: ${dataAlvo.day}/${dataAlvo.month}/${dataAlvo.year}');
    debugPrint('  📊 Alocações futuras encontradas: ${alocacoesFuturas.length}');
    debugPrint('  📊 Alocações passadas encontradas: ${alocacoesPassadas.length}');
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
      final dispSerieList = disponibilidades.where((d) => 
        d.medicoId == medicoId && 
        (d.tipo == 'Semanal' || d.tipo == 'Quinzenal' || d.tipo == 'Mensal' || d.tipo.startsWith('Consecutivo'))
      ).toList();
      
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
        debugPrint('  ⚠️ Nenhuma disponibilidade de série encontrada, tentando inferir do padrão das alocações...');
        // Tentar inferir o tipo da série analisando o padrão das alocações
        if (alocacoesFuturas.isNotEmpty) {
          final primeiraFutura = alocacoesFuturas.first;
          final primeiraFuturaDate = DateTime(primeiraFutura.data.year, primeiraFutura.data.month, primeiraFutura.data.day);
          final diasDiferenca = primeiraFuturaDate.difference(dataAlvoNormalizada).inDays;
          
          if (diasDiferenca == 7 || diasDiferenca % 7 == 0) {
            tipoSerie = 'Semanal';
            debugPrint('  ✅ Tipo inferido: Semanal (diferença de $diasDiferenca dias)');
          } else if (diasDiferenca == 14 || diasDiferenca % 14 == 0) {
            tipoSerie = 'Quinzenal';
            debugPrint('  ✅ Tipo inferido: Quinzenal (diferença de $diasDiferenca dias)');
          } else if (primeiraFuturaDate.day == dataAlvoNormalizada.day) {
            tipoSerie = 'Mensal';
            debugPrint('  ✅ Tipo inferido: Mensal (mesmo dia do mês)');
          }
          
          // Atualizar a disponibilidade com o tipo inferido
          if (tipoSerie != 'Única') {
            disponibilidade = disponibilidade ?? Disponibilidade(
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
              debugPrint('  🔄 Tipo atualizado de "Única" para "$tipoSerie" (inferido)');
            }
          }
        }
      }
    } else if (disponibilidade == null || disponibilidade.medicoId.isEmpty) {
      debugPrint('  ⚠️ Disponibilidade não encontrada no dia selecionado');
      disponibilidade = disponibilidade ?? Disponibilidade(
        id: '',
        medicoId: '',
        data: DateTime(1900, 1, 1),
        horarios: [],
        tipo: 'Única',
      );
    } else {
      debugPrint('  ✅ Disponibilidade encontrada no dia: tipo = ${disponibilidade.tipo}');
    }
    
    // Garantir que disponibilidade não é null
    final disponibilidadeFinal = disponibilidade ?? Disponibilidade(
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
    debugPrint('  📊 Total de alocações do médico: ${alocacoes.where((a) => a.medicoId == medicoId).length}');
    debugPrint('  📊 Todas as alocações do médico:');
    for (var a in alocacoes.where((a) => a.medicoId == medicoId).take(10)) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      debugPrint('    - ${aDate.day}/${aDate.month}/${aDate.year} (gabinete: ${a.gabineteId})');
    }
    
    // Se é tipo único E não há alocações futuras/passadas (não pode ser série), apenas confirmar
    // Caso contrário (tipo série OU pode ser série), sempre perguntar se quer desalocar apenas o dia ou toda a série
    if (!eTipoSerie && tipoDisponibilidade == 'Única' && !podeSerSerie) {
      debugPrint('  ℹ️ Disponibilidade única sem alocações futuras/passadas - apenas confirmar');
      // Para disponibilidade única, apenas confirmar
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
      debugPrint('  ❓ Mostrando diálogo para escolher entre desalocar apenas o dia ou toda a série');
      // Para disponibilidade em série ou quando há alocações futuras/passadas, perguntar se quer desalocar apenas um dia ou toda a série
      String mensagem;
      if (podeSerSerie && tipoDisponibilidade == 'Única') {
        mensagem = 'Este médico tem outras alocações em datas futuras ou passadas.\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série?';
      } else {
        mensagem = 'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série a partir deste?';
      }
      
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
      await AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
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
      await AlocacaoMedicosLogic.desalocarMedicoSerie(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao desalocar série: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyStateOrContent() {
    // Se não há dados, mostrar estado vazio
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
    final gabinetesFiltrados = AlocacaoMedicosLogic.filtrarGabinetesPorUI(
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
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar já vem estilizado pelo theme
      appBar: CustomAppBar(
        title:
            'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
      ),
      drawer: CustomDrawer(
        onRefresh: () => _carregarDadosIniciais(recarregarMedicos: true), // Recarrega tudo, incluindo médicos
        unidade: widget.unidade, // Passa a unidade para personalizar o drawer
        isAdmin: widget.isAdmin, // Passa informação se é administrador
      ),
      // Corpo com cor de fundo suave e layout responsivo
      body: Stack(
        children: [
          Container(
            color: Colors.grey.shade200,
            child: _deveUsarLayoutResponsivo(context)
                ? _buildLayoutResponsivo()
                : _buildLayoutDesktop(),
          ),
          if (isCarregando)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
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
              : _buildColunaDireita(),
        ),
      ],
    );
  }

  // Layout desktop para ecrãs grandes
  Widget _buildLayoutDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda: DatePicker + Filtros
        Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: SingleChildScrollView(
            child: _buildColunaEsquerda(),
          ),
        ),

        // Coluna Direita: Médicos Disponíveis e Gabinetes
        Expanded(
          child: _buildColunaDireita(),
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
    _debounceTimer?.cancel();
    _dispSub?.cancel();
    _alocSub?.cancel();
    super.dispose();
  }
}
