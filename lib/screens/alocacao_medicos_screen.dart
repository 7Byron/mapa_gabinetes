import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Se criou o custom_drawer.dart
import '../widgets/custom_drawer.dart';

// Widgets locais
import '../widgets/date_picker_section.dart';
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
  DateTime selectedDate = DateTime.now();

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

  // Pesquisa
  String? pesquisaNome;
  String? pesquisaEspecialidade;
  Set<String> medicosDestacados =
      {}; // IDs dos médicos destacados pela pesquisa

  // Método para alternar entre colunas em ecrãs pequenos
  void _alternarColuna() {
    setState(() {
      mostrarColunaEsquerda = !mostrarColunaEsquerda;
    });
  }

  // Método para verificar se deve usar layout responsivo
  bool _deveUsarLayoutResponsivo(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
    _carregarPasswordsDoFirebase();
  }

  Future<void> _carregarPasswordsDoFirebase() async {
    try {
      // Carrega as passwords do Firebase para cache local
      await PasswordService.loadPasswordsFromFirebase(widget.unidade.id);
      print(
          '✅ Passwords carregadas do Firebase para unidade: ${widget.unidade.id}');
    } catch (e) {
      print('⚠️ Erro ao carregar passwords do Firebase: $e');
    }
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      // Carrega do banco via logic
      await AlocacaoMedicosLogic.carregarDadosIniciais(
        gabinetes: gabinetes,
        medicos: medicos,
        disponibilidades: disponibilidades,
        alocacoes: alocacoes,
        onGabinetes: (g) => gabinetes = g,
        onMedicos: (m) => medicos = m,
        onDisponibilidades: (d) => disponibilidades = d,
        onAlocacoes: (a) {
          alocacoes = a;
          setState(() {});
        },
        unidade: widget.unidade,
      );

      // Carregar feriados do Firestore (nova estrutura por ano)
      debugPrint('Carregando feriados do Firestore...');
      try {
        CollectionReference feriadosRef;
        feriadosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade.id)
            .collection('feriados');

        // Carrega apenas o ano atual por padrão (otimização)
        final anoAtual = DateTime.now().year.toString();
        final anoRef = feriadosRef.doc(anoAtual);
        final registosRef = anoRef.collection('registos');

        try {
          final registosSnapshot = await registosRef.get();
          feriados = registosSnapshot.docs.map((doc) {
            final data = doc.data();
            return <String, String>{
              'id': doc.id,
              'data': data['data'] as String? ?? '',
              'descricao': data['descricao'] as String? ?? '',
            };
          }).toList();
          debugPrint(
              'Feriados carregados do ano $anoAtual: ${feriados.length}');
        } catch (e) {
          debugPrint('⚠️ Erro ao carregar feriados do ano $anoAtual: $e');
          // Fallback: tenta carregar de todos os anos
          final anosSnapshot = await feriadosRef.get();
          feriados = [];
          for (final anoDoc in anosSnapshot.docs) {
            final registosRef = anoDoc.reference.collection('registos');
            final registosSnapshot = await registosRef.get();
            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              feriados.add(<String, String>{
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
              });
            }
          }
          debugPrint('Feriados carregados (fallback): ${feriados.length}');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar feriados: $e');
        feriados = []; // Lista vazia se não conseguir carregar
      }

      // Carregar horários da clínica do Firestore (com tratamento de erro)
      debugPrint('Carregando horários da clínica do Firestore...');
      try {
        CollectionReference horariosRef;
        horariosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade.id)
            .collection('horarios_clinica');

        final horariosSnapshot = await horariosRef.get();
        horariosClinica = {};
        for (final doc in horariosSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final diaSemana = data['diaSemana'] as int? ?? 0;
          final horaAbertura = data['horaAbertura'] as String? ?? '';
          final horaFecho = data['horaFecho'] as String? ?? '';
          if (horaAbertura.isNotEmpty && horaFecho.isNotEmpty) {
            horariosClinica[diaSemana] = [horaAbertura, horaFecho];
          }
        }
        debugPrint(
            'Horários da clínica carregados: ${horariosClinica.length} dias');

        // Carregar configurações de encerramento
        debugPrint('Carregando configurações de encerramento...');
        try {
          final configDoc = await horariosRef.doc('config').get();
          if (configDoc.exists) {
            final configData = configDoc.data() as Map<String, dynamic>;
            nuncaEncerra = configData['nuncaEncerra'] as bool? ?? false;
            encerraFeriados = configData['encerraFeriados'] as bool? ?? false;

            // Carregar configurações por dia
            for (int i = 1; i <= 7; i++) {
              encerraDias[i] = configData['encerraDia$i'] as bool? ?? false;
            }
            debugPrint('Configurações de encerramento carregadas');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao carregar configurações de encerramento: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao carregar horários da clínica: $e');
        horariosClinica = {}; // Mapa vazio se não conseguir carregar
      }

      // Verificar se a clínica está fechada
      _verificarClinicaFechada();

      // Atualizar médicos disponíveis
      _atualizarMedicosDisponiveis();

      // Inicializar filtros de piso com todos os setores selecionados por padrão
      _inicializarFiltrosPiso();

      setState(() {
        isCarregando = false;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');
      setState(() {
        isCarregando = false;
      });
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

  void _atualizarMedicosDisponiveis() {
    debugPrint('🔄 Atualizando médicos disponíveis...');
    debugPrint(
        '📅 Data selecionada: ${DateFormat('dd/MM/yyyy').format(selectedDate)}');
    debugPrint('👥 Total de médicos: ${medicos.length}');
    debugPrint('📋 Total de disponibilidades: ${disponibilidades.length}');

    final medicosAlocados = alocacoes
        .where((a) =>
            DateFormat('yyyy-MM-dd').format(a.data) ==
            DateFormat('yyyy-MM-dd').format(selectedDate))
        .map((a) => a.medicoId)
        .toSet();

    debugPrint('🚫 Médicos alocados: ${medicosAlocados.length}');
    for (final medicoId in medicosAlocados) {
      final medico = medicos.firstWhere((m) => m.id == medicoId,
          orElse: () => Medico(
              id: '',
              nome: 'Desconhecido',
              especialidade: '',
              disponibilidades: []));
      debugPrint('  - ${medico.nome}');
    }

    // Filtra médicos que:
    // 1. Não estão alocados no dia selecionado
    // 2. Têm disponibilidade para o dia selecionado
    medicosDisponiveis = medicos.where((m) {
      // Verifica se não está alocado
      if (medicosAlocados.contains(m.id)) {
        debugPrint('❌ ${m.nome} está alocado, removendo da lista');
        return false;
      }

      // Verifica se tem disponibilidade para o dia selecionado
      final disponibilidadesDoMedico = disponibilidades.where((d) {
        final dd = DateTime(d.data.year, d.data.month, d.data.day);
        final sd =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        return d.medicoId == m.id && dd == sd;
      }).toList();

      if (disponibilidadesDoMedico.isEmpty) {
        debugPrint(
            '❌ ${m.nome} não tem disponibilidade para ${DateFormat('dd/MM/yyyy').format(selectedDate)}');
        return false;
      }

      debugPrint(
          '✅ ${m.nome} tem ${disponibilidadesDoMedico.length} disponibilidade(s) para ${DateFormat('dd/MM/yyyy').format(selectedDate)}');
      for (final disp in disponibilidadesDoMedico) {
        debugPrint('  - Horários: ${disp.horarios.join(', ')}');
      }

      return true;
    }).toList();

    debugPrint('🎯 Médicos disponíveis finais: ${medicosDisponiveis.length}');
    for (final medico in medicosDisponiveis) {
      debugPrint('- ${medico.nome} (${medico.especialidade})');
    }

    // Debug específico para o Dr. Francisco
    final drFrancisco = medicosDisponiveis
        .where((m) => m.nome.toLowerCase().contains('francisco'))
        .toList();
    if (drFrancisco.isNotEmpty) {
      debugPrint('✅ Dr. Francisco está na lista de médicos disponíveis!');
    } else {
      debugPrint('❌ Dr. Francisco NÃO está na lista de médicos disponíveis!');
      debugPrint('🔍 Verificando por que...');
      final todosMedicos = medicos
          .where((m) => m.nome.toLowerCase().contains('francisco'))
          .toList();
      if (todosMedicos.isNotEmpty) {
        debugPrint('  - Dr. Francisco existe na lista geral de médicos');
        final dispDrFrancisco = disponibilidades
            .where((d) => d.medicoId == todosMedicos.first.id)
            .toList();
        debugPrint(
            '  - Disponibilidades do Dr. Francisco: ${dispDrFrancisco.length}');
        for (final disp in dispDrFrancisco) {
          debugPrint(
              '    - ${disp.data.day}/${disp.data.month}/${disp.data.year} - Horários: ${disp.horarios.join(', ')}');
        }
      } else {
        debugPrint('  - Dr. Francisco NÃO existe na lista geral de médicos!');
      }
    }
  }

  void _inicializarFiltrosPiso() {
    // Inicializar todos os filtros de piso como selecionados por padrão
    if (gabinetes.isNotEmpty) {
      final todosSetores = gabinetes.map((g) => g.setor).toSet().toList();
      pisosSelecionados = List<String>.from(todosSetores);
      debugPrint(
          '✅ Filtros de piso inicializados: ${pisosSelecionados.join(', ')}');
    } else {
      debugPrint(
          '⚠️ Nenhum gabinete encontrado para inicializar filtros de piso');
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
              Medico(id: '', nome: '', especialidade: '', disponibilidades: []),
        );
        if (medico.id.isNotEmpty &&
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
    print(
        '🔄 _onDateChanged chamado com data: ${newDate.day}/${newDate.month}/${newDate.year}');
    setState(() {
      selectedDate = newDate;
      print(
          '📅 Data selecionada atualizada para: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
      _verificarClinicaFechada();
      _atualizarMedicosDisponiveis();
    });
  }

  Future<void> _alocarMedico(String medicoId, String gabineteId,
      {DateTime? dataEspecifica}) async {
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
    final alocacao = alocacoes.firstWhere((a) => a.medicoId == medicoId);

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
    final disponibilidade = disponibilidades.firstWhere(
      (d) =>
          d.medicoId == medicoId &&
          d.data.year == selectedDate.year &&
          d.data.month == selectedDate.month &&
          d.data.day == selectedDate.day,
      orElse: () => Disponibilidade(
        id: '',
        medicoId: '',
        data: DateTime(1900, 1, 1),
        horarios: [],
        tipo: 'Única',
      ),
    );

    String? escolha;
    if (disponibilidade.tipo == 'Única') {
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
      // Para disponibilidade em série, perguntar se quer desalocar apenas um dia ou toda a série
      escolha = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Desalocação'),
          content: Text(
            'Esta disponibilidade é do tipo "${disponibilidade.tipo}".\n'
            'Deseja desalocar apenas este dia (${selectedDate.day}/${selectedDate.month}) '
            'ou todos os dias da série a partir deste?',
          ),
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
      await _desalocarMedicoSerie(medicoId, disponibilidade.tipo);
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
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCarregando) {
      return Scaffold(
        appBar: CustomAppBar(
            title:
                'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // AppBar já vem estilizado pelo theme
      appBar: CustomAppBar(
        title:
            'Mapa de ${widget.unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
      ),
      drawer: CustomDrawer(
        onRefresh: _carregarDadosIniciais, // Passa o callback para o drawer
        unidade: widget.unidade, // Passa a unidade para personalizar o drawer
        isAdmin: widget.isAdmin, // Passa informação se é administrador
      ),
      // Corpo com cor de fundo suave e layout responsivo
      body: Container(
        color: Colors.grey.shade200,
        child: _deveUsarLayoutResponsivo(context)
            ? _buildLayoutResponsivo()
            : _buildLayoutDesktop(),
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
            child: DatePickerSection(
              selectedDate: selectedDate,
              onDateChanged: _onDateChanged,
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
}
