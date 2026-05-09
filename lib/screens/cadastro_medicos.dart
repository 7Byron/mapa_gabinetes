import 'dart:async';
import '../utils/app_theme.dart';
import 'package:flutter/material.dart';

// Services
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/alocacao.dart';
import '../models/gabinete.dart';
import '../services/medico_salvar_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/disponibilidade_remocao.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';
import '../services/disponibilidade_unica_service.dart';
import '../services/cadastro_medico_salvar_service.dart';
import '../services/alocacao_disponibilidade_remocao_service.dart';
import '../services/excecao_serie_criacao_service.dart';
import '../services/disponibilidade_data_gestao_service.dart';
import '../services/gabinete_service.dart';
import '../services/realocacao_serie_service.dart';

// Widgets
import '../widgets/disponibilidades_grid.dart';
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/formulario_medico.dart';
import '../widgets/dialogo_excecao_serie.dart';
import '../widgets/dialogo_excecao_periodo.dart';
import '../widgets/date_picker_customizado.dart';
import '../widgets/excecoes_card.dart';
import '../widgets/medico_appbar_title.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/series_helper.dart';
import '../utils/cadastro_medicos_helper.dart';
import '../utils/alocacao_medicos_logic.dart';
// import '../utils/ui_modificar_gabinete_cartao.dart'; // Comentado - não usado no momento
// import '../utils/debug_log_file.dart'; // Comentado - usado apenas na instrumentação de debug
import 'alocacao_medicos_screen.dart';

class CadastroMedico extends StatefulWidget {
  final Medico? medico;
  final Unidade? unidade;

  const CadastroMedico({super.key, this.medico, this.unidade});

  @override
  CadastroMedicoState createState() => CadastroMedicoState();
}

class CadastroMedicoState extends State<CadastroMedico> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false; // mostra progress enquanto grava
  double progressoSaving = 0.0;
  String mensagemSaving = 'A guardar...';
  bool _navegandoAoSair = false; // evita retirar overlay antes do pop
  bool _atualizandoHorarios =
      false; // mostra progress enquanto atualiza horários
  double progressoAtualizandoHorarios = 0.0;
  String mensagemAtualizandoHorarios = 'A atualizar horários...';
  bool _criandoExcecao = false; // mostra progress enquanto cria exceções
  double progressoCriandoExcecao = 0.0;
  String mensagemCriandoExcecao = 'A criar exceção...';
  bool _alocandoGabinete = false; // mostra progress enquanto aloca gabinete
  double progressoAlocandoGabinete = 0.0;
  String mensagemAlocandoGabinete = 'A alocar gabinete...';

  // Mantém o ID do médico numa variável interna
  late String _medicoId;

  // Médico atual sendo editado (pode mudar via dropdown)
  Medico? _medicoAtual;

  // Disponibilidades e datas selecionadas
  List<Disponibilidade> disponibilidades = [];
  List<DateTime> diasSelecionados = [];
  int? _anoVisualizado; // Ano atualmente visualizado no calendário
  DateTime? _dataCalendario; // Data atual do calendário para forçar atualização

  // Alocações e gabinetes para exibir número do gabinete nos cartões
  List<Alocacao> alocacoes = [];
  List<Gabinete> gabinetes = [];

  // Séries de recorrência (novo modelo)
  List<SerieRecorrencia> series = [];
  List<ExcecaoSerie> excecoes = [];

  // Lista de médicos para o dropdown
  List<Medico> _listaMedicos = [];
  bool _carregandoMedicos = false;
  final TextEditingController _medicoAutocompleteController =
      TextEditingController();

  // Controllers de texto
  TextEditingController especialidadeController = TextEditingController();
  TextEditingController nomeController = TextEditingController();
  TextEditingController observacoesController = TextEditingController();

  // Estado do campo ativo
  bool _medicoAtivo = true;

  bool isLoadingDisponibilidades = false;
  double progressoCarregamentoDisponibilidades = 0.0;
  String mensagemCarregamentoDisponibilidades =
      'A carregar disponibilidades...';

  // Progress bar para carregamento inicial completo (disponibilidades, alocações e gabinetes)
  bool _isCarregandoInicial = false;
  double _progressoCarregamentoInicial = 0.0;
  String _mensagemCarregamentoInicial = 'A iniciar...';

  // Variáveis para rastrear mudanças
  bool _houveMudancas = false;
  String _nomeOriginal = '';
  String _especialidadeOriginal = '';
  String _observacoesOriginal = '';
  List<Disponibilidade> _disponibilidadesOriginal = [];

  @override
  void initState() {
    super.initState();

    // Se vier "medico" no construtor, usamos o ID dele; senão, criamos um novo
    _medicoId =
        widget.medico?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Inicializar médico atual
    _medicoAtual = widget.medico;

    if (widget.medico != null) {
      // Editando um médico existente - carregar dados do médico passado
      // mas depois recarregar do Firestore para garantir dados atualizados
      nomeController.text = widget.medico!.nome;
      especialidadeController.text = widget.medico!.especialidade;
      observacoesController.text = widget.medico!.observacoes ?? '';
      _medicoAutocompleteController.text = widget.medico!.nome;
      _medicoAtivo = widget.medico!.ativo; // Carregar estado ativo do médico

      // Recarregar médico do Firestore para garantir dados atualizados (especialmente o campo ativo)
      _recarregarMedicoDoFirestore(widget.medico!.id);

      // Carregar disponibilidades, alocações e gabinetes com progress bar
      _anoVisualizado = DateTime.now().year;
      _dataCalendario = DateTime.now();

      _carregarDadosIniciaisCompleto(widget.medico!.id);

      // Guarda os valores originais
      _nomeOriginal = widget.medico!.nome;
      _especialidadeOriginal = widget.medico!.especialidade;
      _observacoesOriginal = widget.medico!.observacoes ?? '';
    }

    // Adiciona listeners para detectar mudanças
    nomeController.addListener(_verificarMudancas);
    especialidadeController.addListener(_verificarMudancas);
    observacoesController.addListener(_verificarMudancas);

    // Carregar lista de médicos para o dropdown
    _carregarListaMedicos();
  }

  /// Recarrega um médico do Firestore para garantir dados atualizados
  Future<void> _recarregarMedicoDoFirestore(String medicoId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      DocumentReference medicoRef;

      if (widget.unidade != null) {
        medicoRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes')
            .doc(medicoId);
      } else {
        medicoRef = firestore.collection('medicos').doc(medicoId);
      }

      final doc = await medicoRef.get(const GetOptions(source: Source.server));
      if (doc.exists && mounted) {
        final dados = doc.data() as Map<String, dynamic>;
        final ativoAtualizado = dados['ativo'] ?? true;

        debugPrint(
            '🔄 [RECARREGAR-MÉDICO] Médico $medicoId: ativo no Firestore=$ativoAtualizado, ativo local=$_medicoAtivo, houveMudancas=$_houveMudancas');

        // Sempre atualizar o campo ativo do Firestore quando recarregar
        // (mas apenas se não houver mudanças não salvas do usuário)
        if (!_houveMudancas) {
          if (_medicoAtivo != ativoAtualizado) {
            debugPrint(
                '✅ [RECARREGAR-MÉDICO] Atualizando campo ativo de $_medicoAtivo para $ativoAtualizado');
            setState(() {
              _medicoAtivo = ativoAtualizado;
              // Atualizar também o médico atual
              if (_medicoAtual != null) {
                _medicoAtual = Medico(
                  id: _medicoAtual!.id,
                  nome: _medicoAtual!.nome,
                  especialidade: _medicoAtual!.especialidade,
                  observacoes: _medicoAtual!.observacoes,
                  disponibilidades: _medicoAtual!.disponibilidades,
                  ativo: ativoAtualizado,
                );
              }
            });
          } else {
            debugPrint(
                'ℹ️ [RECARREGAR-MÉDICO] Campo ativo já está sincronizado: $ativoAtualizado');
          }
        } else {
          debugPrint(
              '⚠️ [RECARREGAR-MÉDICO] Ignorando atualização: usuário já fez mudanças (houveMudancas=$_houveMudancas)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao recarregar médico do Firestore: $e');
    }
  }

  /// Carrega a lista de médicos para o dropdown
  Future<void> _carregarListaMedicos() async {
    setState(() => _carregandoMedicos = true);
    try {
      final medicos = await buscarMedicos(unidade: widget.unidade);
      // Ordenar alfabeticamente por nome (sem acentos)
      medicos.sort((a, b) {
        final nomeA = CadastroMedicosHelper.normalizarString(a.nome);
        final nomeB = CadastroMedicosHelper.normalizarString(b.nome);
        return nomeA.compareTo(nomeB);
      });
      setState(() {
        _listaMedicos = medicos;
        _carregandoMedicos = false;
      });
    } catch (e) {
      setState(() => _carregandoMedicos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar lista de médicos: $e')),
        );
      }
    }
  }

  bool _jaRecarregouAoVoltar = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quando a tela volta ao foco, recarregar o médico do Firestore
    // para garantir que o campo ativo está atualizado
    if (widget.medico != null && !_jaRecarregouAoVoltar) {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        _jaRecarregouAoVoltar = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _recarregarMedicoDoFirestore(widget.medico!.id);
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
  }

  /// Verifica se houve mudanças nos dados
  void _verificarMudancas() {
    final nomeAtual = nomeController.text.trim();
    final especialidadeAtual = especialidadeController.text.trim();
    final observacoesAtual = observacoesController.text.trim();

    bool mudancas = false;

    // Verifica mudanças nos campos de texto
    if (nomeAtual != _nomeOriginal ||
        especialidadeAtual != _especialidadeOriginal ||
        observacoesAtual != _observacoesOriginal) {
      mudancas = true;
    }

    // CORREÇÃO CRÍTICA: Verificar mudanças nas disponibilidades "Única" primeiro
    // mesmo quando múltiplas séries são criadas rapidamente
    final disponibilidadesUnicas =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            disponibilidades, _medicoId);
    final disponibilidadesUnicasOriginal =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            _disponibilidadesOriginal, _medicoId);

    // Verificar se há disponibilidades "Única" novas ou removidas
    final temUnicasNovas = disponibilidadesUnicas.any((d) =>
        !disponibilidadesUnicasOriginal.any((orig) =>
            orig.id == d.id &&
            orig.data.year == d.data.year &&
            orig.data.month == d.data.month &&
            orig.data.day == d.data.day &&
            CadastroMedicosHelper.listasIguais(orig.horarios, d.horarios)));
    final temUnicasRemovidas = disponibilidadesUnicasOriginal.any((orig) =>
        !disponibilidadesUnicas.any((d) =>
            d.id == orig.id &&
            d.data.year == orig.data.year &&
            d.data.month == orig.data.month &&
            d.data.day == orig.data.day &&
            CadastroMedicosHelper.listasIguais(d.horarios, orig.horarios)));

    if (temUnicasNovas || temUnicasRemovidas) {
      mudancas = true;
    }

    // CORREÇÃO: Verificar mudanças nas disponibilidades usando comparação por ID
    if (!mudancas &&
        disponibilidades.length != _disponibilidadesOriginal.length) {
      mudancas = true;
    } else if (!mudancas) {
      // Verificar se todas as disponibilidades atuais existem nas originais
      for (final disp in disponibilidades) {
        final existeOriginal = _disponibilidadesOriginal.any((orig) =>
            orig.id == disp.id &&
            orig.data.year == disp.data.year &&
            orig.data.month == disp.data.month &&
            orig.data.day == disp.data.day &&
            orig.tipo == disp.tipo &&
            CadastroMedicosHelper.listasIguais(orig.horarios, disp.horarios));
        if (!existeOriginal) {
          mudancas = true;
          break;
        }
      }

      // Verificar se alguma disponibilidade original foi removida
      if (!mudancas) {
        for (final orig in _disponibilidadesOriginal) {
          final existeAtual = disponibilidades.any((disp) =>
              disp.id == orig.id &&
              disp.data.year == orig.data.year &&
              disp.data.month == orig.data.month &&
              disp.data.day == orig.data.day &&
              disp.tipo == orig.tipo &&
              CadastroMedicosHelper.listasIguais(disp.horarios, orig.horarios));
          if (!existeAtual) {
            mudancas = true;
            break;
          }
        }
      }
    }
    setState(() {
      _houveMudancas = mudancas;
    });
  }

  /// Salva automaticamente antes de sair (se houver mudanças)
  Future<bool> _confirmarSaida() async {
    // CORREÇÃO CRÍTICA: Verificar se há cartões únicos não salvos
    // Mesmo que _houveMudancas seja false, se há cartões únicos, precisamos salvar
    // IMPORTANTE: Recalcular disponibilidades únicas para garantir lista atualizada
    final disponibilidadesUnicasAtualizadas =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            disponibilidades, _medicoId);
    final disponibilidadesUnicasOriginal =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            _disponibilidadesOriginal, _medicoId);

    // CORREÇÃO: Verificar se há disponibilidades "Única" que não estão nas originais
    // Usar comparação mais robusta que verifica ID, data completa e horários
    disponibilidadesUnicasAtualizadas.any((d) {
      final existeOriginal = disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          CadastroMedicosHelper.listasIguais(orig.horarios, d.horarios));
      return !existeOriginal;
    });
    // CORREÇÃO CRÍTICA: Sempre forçar verificação de mudanças antes de sair
    // IMPORTANTE: Chamar _verificarMudancas() novamente para garantir estado atualizado
    // (já foi chamado no PopScope, mas garantir novamente aqui)
    _verificarMudancas();

    // CORREÇÃO: Recalcular disponibilidades únicas após verificar mudanças
    final disponibilidadesUnicasRecalculadas =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            disponibilidades, _medicoId);

    // Atualizar temUnicasNaoSalvas após verificar mudanças novamente
    final temUnicasNaoSalvasAtualizado =
        disponibilidadesUnicasRecalculadas.any((d) {
      final existeOriginal = disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          CadastroMedicosHelper.listasIguais(orig.horarios, d.horarios));

      return !existeOriginal;
    });

    if (!temUnicasNaoSalvasAtualizado && !_houveMudancas) {
      return true; // Pode sair sem salvar se não houve mudanças
    }

    // Se chegou aqui, há mudanças ou disponibilidades "Única" não salvas
    // Atualizar flag para garantir salvamento
    setState(() {
      _houveMudancas = true;
    });

    // CORREÇÃO: Sempre salvar se há disponibilidades "Única" não salvas
    // Usar a versão atualizada da verificação com lista atualizada
    // Verificação de mudanças já feita acima

    // Salvar automaticamente antes de sair
    await _salvarMedico();
    // Já fizemos pop dentro de _salvarMedico; não deixar o PopScope fazer novo pop
    return false;
  }

  /// Salva automaticamente antes de mudar de médico (se houver mudanças)
  Future<bool> _confirmarMudancaMedico() async {
    if (!_houveMudancas) {
      return true; // Pode mudar sem salvar se não houve mudanças
    }

    // Salvar automaticamente antes de mudar
    final salvou = await _salvarMedicoSemSair();
    return salvou; // Retorna true se salvou com sucesso
  }

  /// Navega para a página de alocação, salvando antes se houver mudanças
  /// Salva antes de navegar para o mapa (usado pelos cartões)
  Future<bool> _salvarAntesDeNavegarParaMapa() async {
    // CORREÇÃO CRÍTICA: Sempre verificar mudanças e disponibilidades únicas
    // Antes de qualquer outra operação, para garantir que sejam capturadas corretamente
    _verificarMudancas();

    // CORREÇÃO CRÍTICA: Capturar disponibilidades únicas ANTES de qualquer validação
    // que possa modificar a lista (fazendo cópia profunda)
    final todasDisponibilidadesCopia =
        CadastroMedicosHelper.criarCopiaProfundaDisponibilidades(
            disponibilidades);
    final disponibilidadesUnicasParaVerificar =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            todasDisponibilidadesCopia, _medicoId);

    // CORREÇÃO RADICAL: Se há disponibilidades únicas na lista, SEMPRE salvar, mesmo que _houveMudancas seja false
    // porque pode ser que as disponibilidades únicas tenham sido criadas mas a flag não foi atualizada
    final deveSalvar =
        _houveMudancas || disponibilidadesUnicasParaVerificar.isNotEmpty;

    if (!deveSalvar) {
      return true; // Não há mudanças, pode navegar
    }

    // Validar formulário antes de salvar
    if (!_formKey.currentState!.validate()) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Por favor, corrija os erros no formulário antes de continuar'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Verificar se o nome foi preenchido
    if (nomeController.text.trim().isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduza o nome do médico antes de continuar'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Salvar antes de navegar
    return await _salvarMedicoSemSair();
  }

  Future<void> _navegarParaAlocacao() async {
    // CORREÇÃO CRÍTICA: Sempre verificar mudanças e disponibilidades únicas
    // Antes de qualquer outra operação, para garantir que sejam capturadas corretamente
    _verificarMudancas();

    // CORREÇÃO CRÍTICA: Capturar disponibilidades únicas ANTES de qualquer validação
    // que possa modificar a lista (fazendo cópia profunda)
    final todasDisponibilidadesCopia =
        CadastroMedicosHelper.criarCopiaProfundaDisponibilidades(
            disponibilidades);
    final disponibilidadesUnicasParaVerificar =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            todasDisponibilidadesCopia, _medicoId);

    final disponibilidadesUnicasOriginal =
        CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
            _disponibilidadesOriginal, _medicoId);

    final temUnicasNaoSalvas = disponibilidadesUnicasParaVerificar.any((d) {
      return !disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          CadastroMedicosHelper.listasIguais(orig.horarios, d.horarios));
    });

    // CORREÇÃO CRÍTICA: SEMPRE salvar se há disponibilidades únicas na lista, independentemente de _houveMudancas
    // Se há disponibilidades únicas, sempre salvar para garantir que sejam persistidas
    debugPrint(
        '🔍 [_navegarParaAlocacao] Verificando salvamento: _houveMudancas=$_houveMudancas, temUnicasNaoSalvas=$temUnicasNaoSalvas, totalUnicas=${disponibilidadesUnicasParaVerificar.length}');

    // CORREÇÃO RADICAL: Se há disponibilidades únicas na lista, SEMPRE salvar, mesmo que _houveMudancas seja false
    // porque pode ser que as disponibilidades únicas tenham sido criadas mas a flag não foi atualizada
    final deveSalvar =
        _houveMudancas || disponibilidadesUnicasParaVerificar.isNotEmpty;

    if (deveSalvar) {
      debugPrint(
          '✅ [_navegarParaAlocacao] Vai salvar antes de navegar (mudanças: $_houveMudancas, únicas: ${disponibilidadesUnicasParaVerificar.length})');
      if (widget.unidade == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Não é possível navegar para alocação: unidade não definida'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validar formulário antes de salvar
      if (!_formKey.currentState!.validate()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Por favor, corrija os erros no formulário antes de continuar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Verificar se o nome foi preenchido
      if (nomeController.text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Introduza o nome do médico antes de continuar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Salvar antes de navegar
      final salvou = await _salvarMedicoSemSair();
      if (!salvou) {
        // Se não salvou com sucesso, não navegar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Erro ao salvar. Não foi possível navegar para alocação.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Verificar se unidade está disponível
    if (widget.unidade == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Não é possível navegar para alocação: unidade não definida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navegar para a página de alocação
    // Se chegou até aqui (tela de editar médico), o usuário é administrador
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AlocacaoMedicos(
            unidade: widget.unidade!,
            isAdmin:
                true, // Se chegou até a tela de editar médico, é administrador
          ),
        ),
      );
    }
  }

  /// Carrega os dados de um novo médico
  Future<void> _carregarMedico(Medico medico) async {
    // CORREÇÃO CRÍTICA: NÃO definir _isCarregandoInicial aqui
    // Isso será feito dentro de _carregarDadosIniciaisCompleto
    // Se definirmos aqui, _carregarDadosIniciaisCompleto vai ver que já está carregando e retornar sem fazer nada

    // Guardar o ID do médico anterior para detectar mudança
    final medicoAnteriorId = _medicoAtual?.id;

    setState(() {
      _medicoAtual = medico;
      _medicoId = medico.id;
      nomeController.text = medico.nome;
      especialidadeController.text = medico.especialidade;
      observacoesController.text = medico.observacoes ?? '';
      _medicoAutocompleteController.text = medico.nome;
      _medicoAtivo = medico.ativo; // Carregar estado ativo do médico

      // Limpar dados antigos
      disponibilidades.clear();
      diasSelecionados.clear();
      series.clear();
      excecoes.clear();
      alocacoes.clear(); // Limpar também alocações

      // Guarda os valores originais
      _nomeOriginal = medico.nome;
      _especialidadeOriginal = medico.especialidade;
      _observacoesOriginal = medico.observacoes ?? '';
      _disponibilidadesOriginal.clear();
      _houveMudancas = false;

      // Carregar disponibilidades do ano atual por padrão
      _anoVisualizado = DateTime.now().year;
      _dataCalendario = DateTime.now();
    });

    try {
      // OTIMIZAÇÃO: Executar recarregar médico e carregar gabinetes em paralelo (se necessário)
      // Recarregar médico do Firestore para garantir dados atualizados (especialmente campo ativo)
      final recarregarMedicoFuture = _recarregarMedicoDoFirestore(medico.id);

      // Carregar gabinetes em paralelo se ainda não estiverem carregados
      Future<List<Gabinete>> carregarGabinetesFuture;
      if (gabinetes.isEmpty) {
        carregarGabinetesFuture = buscarGabinetes(unidade: widget.unidade);
      } else {
        carregarGabinetesFuture = Future.value(gabinetes);
      }

      // Aguardar ambas as operações em paralelo
      await Future.wait([
        recarregarMedicoFuture,
        carregarGabinetesFuture,
      ]);

      // Se gabinetes foram carregados, atualizar a lista
      if (gabinetes.isEmpty) {
        final gabinetesCarregados = await carregarGabinetesFuture;
        if (mounted) {
          setState(() {
            gabinetes = gabinetesCarregados;
          });
        }
      }

      // Carregar disponibilidades, alocações e gabinetes com progress bar completa
      // Passar informação se é mudança de médico para exibir mensagem apropriada
      await _carregarDadosIniciaisCompleto(medico.id,
          isMudancaMedico:
              medicoAnteriorId != null && medicoAnteriorId != medico.id);
    } catch (e) {
      debugPrint('❌ Erro ao carregar médico: $e');
      if (mounted) {
        setState(() {
          _isCarregandoInicial = false;
          _progressoCarregamentoInicial = 0.0;
          _mensagemCarregamentoInicial = 'A iniciar...';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Trata a mudança de médico no dropdown
  Future<void> _mudarMedico(Medico? novoMedico) async {
    if (novoMedico == null) return;

    // Se for o mesmo médico, não fazer nada
    if (_medicoAtual != null && novoMedico.id == _medicoAtual!.id) {
      return;
    }

    // Salvar automaticamente se houver mudanças (mantém o overlay de salvamento)
    final podeMudar = await _confirmarMudancaMedico();
    if (!podeMudar) {
      // Se não salvou (erro), não mudar
      return;
    }

    // Desativar o overlay de salvamento antes de carregar o novo médico
    // A função _carregarMedico vai ativar a progress bar completa de carregamento
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }

    // Carregar o novo médico (vai ativar progress bar completa de carregamento)
    await _carregarMedico(novoMedico);
  }

  /// Mostra diálogo para apagar médico
  Future<void> _mostrarDialogoApagarMedico() async {
    if (_medicoAtual == null) return;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apagar Médico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Tem certeza que deseja apagar o médico "${_medicoAtual!.nome}"?'),
              const SizedBox(height: 16),
              const Text(
                'Esta ação irá remover:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Todas as disponibilidades'),
              const Text('• Todas as séries de recorrência'),
              const Text('• Todas as exceções'),
              const Text('• Todas as alocações futuras'),
              const SizedBox(height: 16),
              const Text(
                'Esta ação não pode ser desfeita!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (resultado == true) {
      await _apagarMedico(_medicoAtual!.id);
    }
  }

  /// Apaga um médico e todos os seus dados
  Future<void> _apagarMedico(String medicoId) async {
    try {
      setState(() => _saving = true);

      final firestore = FirebaseFirestore.instance;
      CollectionReference ocupantesRef;
      CollectionReference disponibilidadesRef;
      CollectionReference seriesRef;
      CollectionReference excecoesRef;

      if (widget.unidade != null) {
        ocupantesRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
        disponibilidadesRef =
            ocupantesRef.doc(medicoId).collection('disponibilidades');
        seriesRef = ocupantesRef.doc(medicoId).collection('series');
        excecoesRef = ocupantesRef.doc(medicoId).collection('excecoes');
      } else {
        ocupantesRef = firestore.collection('medicos');
        disponibilidadesRef =
            ocupantesRef.doc(medicoId).collection('disponibilidades');
        seriesRef = ocupantesRef.doc(medicoId).collection('series');
        excecoesRef = ocupantesRef.doc(medicoId).collection('excecoes');
      }

      // 1. Apagar todas as disponibilidades
      int disponibilidadesRemovidas = 0;
      final anosSnapshot = await disponibilidadesRef.get();
      for (final anoDoc in anosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final todosRegistos = await registosRef.get();
        for (final doc in todosRegistos.docs) {
          await doc.reference.delete();
          disponibilidadesRemovidas++;
        }
        await anoDoc.reference.delete();
      }

      // 2. Apagar todas as séries
      int seriesRemovidas = 0;
      final seriesSnapshot = await seriesRef.get();
      for (final doc in seriesSnapshot.docs) {
        await doc.reference.delete();
        seriesRemovidas++;
      }

      // 3. Apagar todas as exceções de forma mais robusta
      int excecoesRemovidas = 0;
      try {
        final excecoesAnosSnapshot = await excecoesRef.get();
        for (final anoDoc in excecoesAnosSnapshot.docs) {
          final registosRef = anoDoc.reference.collection('registos');
          final todosRegistos = await registosRef.get();
          // Apagar todos os registos primeiro
          for (final doc in todosRegistos.docs) {
            try {
              await doc.reference.delete();
              excecoesRemovidas++;
            } catch (e) {
              debugPrint('Erro ao apagar exceção ${doc.id}: $e');
              // Continuar mesmo se houver erro em um documento
            }
          }
          // Apagar o documento do ano se estiver vazio ou mesmo que não esteja
          try {
            final registosRestantes = await registosRef.get();
            if (registosRestantes.docs.isEmpty) {
              await anoDoc.reference.delete();
            } else {
              // Se ainda houver registos, forçar apagar todos novamente
              for (final doc in registosRestantes.docs) {
                await doc.reference.delete();
              }
              await anoDoc.reference.delete();
            }
          } catch (e) {
            debugPrint('Erro ao apagar documento de ano ${anoDoc.id}: $e');
          }
        }
        // Garantir que todas as exceções foram apagadas - verificar novamente
        final verificacaoFinal = await excecoesRef.get();
        for (final anoDoc in verificacaoFinal.docs) {
          final registosRef = anoDoc.reference.collection('registos');
          final registosFinais = await registosRef.get();
          for (final doc in registosFinais.docs) {
            await doc.reference.delete();
            excecoesRemovidas++;
          }
          await anoDoc.reference.delete();
        }
      } catch (e) {
        debugPrint('Erro ao apagar exceções: $e');
        // Continuar mesmo se houver erro para tentar apagar o resto
      }

      // 4. Apagar alocações do médico
      int alocacoesRemovidas = 0;
      if (widget.unidade != null) {
        final unidadeId = widget.unidade!.id;
        final anosParaVerificar = [
          DateTime.now().year,
          DateTime.now().year + 1
        ];

        for (final ano in anosParaVerificar) {
          try {
            final alocacoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('alocacoes')
                .doc(ano.toString())
                .collection('registos');

            final todasAlocacoes =
                await alocacoesRef.where('medicoId', isEqualTo: medicoId).get();

            for (final doc in todasAlocacoes.docs) {
              await doc.reference.delete();
              alocacoesRemovidas++;
            }
          } catch (e) {
            debugPrint('Erro ao apagar alocações do ano $ano: $e');
          }
        }
      }

      // 5. Apagar o documento do médico em "ocupantes" APÓS garantir que todas as subcoleções foram apagadas
      try {
        // Verificar se ainda existem subcoleções antes de apagar o documento
        final disponibilidadesRestantes = await disponibilidadesRef.get();
        final seriesRestantes = await seriesRef.get();
        final excecoesRestantes = await excecoesRef.get();

        if (disponibilidadesRestantes.docs.isEmpty &&
            seriesRestantes.docs.isEmpty &&
            excecoesRestantes.docs.isEmpty) {
          await ocupantesRef.doc(medicoId).delete();
          debugPrint('✅ Documento do médico apagado em ocupantes: $medicoId');
        } else {
          debugPrint(
              '⚠️ Ainda existem subcoleções, mas apagando documento mesmo assim');
          await ocupantesRef.doc(medicoId).delete();
        }
      } catch (e) {
        debugPrint('Erro ao apagar documento do médico: $e');
        rethrow;
      }

      // Remover da lista local
      setState(() {
        _listaMedicos.removeWhere((m) => m.id == medicoId);
        if (_medicoAtual?.id == medicoId) {
          _medicoAtual = null;
          _medicoId = DateTime.now().millisecondsSinceEpoch.toString();
          nomeController.clear();
          especialidadeController.clear();
          observacoesController.clear();
          disponibilidades.clear();
          diasSelecionados.clear();
          series.clear();
          excecoes.clear();
          _medicoAutocompleteController.clear();
        }
        _saving = false;
      });

      // Invalidar cache
      // AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(2000, 1, 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Médico apagado com sucesso: $disponibilidadesRemovidas disponibilidade(s), '
              '$seriesRemovidas série(s), $excecoesRemovidas exceção(ões) e '
              '$alocacoesRemovidas alocação(ões) removidas.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Recarregar lista de médicos
      await _carregarListaMedicos();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          progressoSaving = 0.0;
          mensagemSaving = 'A guardar...';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mostra diálogo de confirmação antes de criar novo
  /// Salva automaticamente antes de criar novo médico (se houver mudanças)
  Future<bool> _confirmarNovo() async {
    if (!_houveMudancas) {
      return true; // Pode criar novo sem salvar se não houve mudanças
    }

    // Salvar automaticamente antes de criar novo
    await _salvarMedico();
    return true;
  }

  /// Carrega todos os dados iniciais (disponibilidades, alocações e gabinetes) com progress bar
  Future<void> _carregarDadosIniciaisCompleto(String medicoId,
      {bool isMudancaMedico = false}) async {
    if (!mounted) return;

    // CORREÇÃO CRÍTICA: Proteção contra execuções concorrentes
    // Se já está carregando, não iniciar novo carregamento
    if (_isCarregandoInicial) {
      debugPrint(
          '⚠️ [PROTEÇÃO] _carregarDadosIniciaisCompleto já está em execução, ignorando chamada duplicada');
      return;
    }

    // Ativar progress bar inicial
    // CORREÇÃO: Definir mensagem apropriada baseada no contexto (mudança de médico ou carregamento inicial)
    final mensagemInicial =
        isMudancaMedico ? 'A mudar médico...' : 'A iniciar...';
    setState(() {
      _isCarregandoInicial = true;
      _progressoCarregamentoInicial = 0.0;
      _mensagemCarregamentoInicial = mensagemInicial;
    });

    try {
      final anoParaCarregar = _anoVisualizado ?? DateTime.now().year;

      // Garantir que _anoVisualizado está definido no estado
      if (mounted && _anoVisualizado == null) {
        setState(() {
          _anoVisualizado = anoParaCarregar;
        });
      }

      // OTIMIZAÇÃO: Verificar se gabinetes já estão carregados (pode ter sido carregado em paralelo antes)
      // Se não estiverem, carregar agora
      if (gabinetes.isEmpty) {
        // Atualizar progresso: Carregando gabinetes (5%)
        if (mounted) {
          setState(() {
            _progressoCarregamentoInicial = 0.05;
            _mensagemCarregamentoInicial = 'A carregar gabinetes...';
          });
        }

        gabinetes = await buscarGabinetes(unidade: widget.unidade);
      } else {
        // Gabinetes já carregados, atualizar progresso direto para 15%
        if (mounted) {
          setState(() {
            _progressoCarregamentoInicial = 0.15;
            _mensagemCarregamentoInicial = 'A carregar dados...';
          });
        }
      }

      // OTIMIZAÇÃO: Executar alocações e início do carregamento de séries em paralelo
      // Atualizar progresso após carregar gabinetes (15%)
      if (mounted && gabinetes.isEmpty == false) {
        setState(() {
          _progressoCarregamentoInicial = 0.15;
          _mensagemCarregamentoInicial = 'A carregar alocações e séries...';
        });
      }

      // Carregar alocações e séries em paralelo (séries precisam começar cedo para otimizar)
      final alocacoesFuture = AlocacaoMedicosLogic.buscarAlocacoesMedico(
        widget.unidade,
        medicoId,
        anoEspecifico: anoParaCarregar,
      );

      // Iniciar carregamento de séries em paralelo (se ainda não estiverem carregadas)
      final seriesJaCarregadas =
          series.isNotEmpty && series.first.medicoId == medicoId;
      final seriesFuture = seriesJaCarregadas
          ? Future.value(series)
          : SerieService.carregarSeries(
              medicoId,
              unidade: widget.unidade,
              forcarServidor: true,
            );

      // Aguardar ambos em paralelo
      final resultados = await Future.wait([
        alocacoesFuture,
        seriesFuture,
      ]);

      final alocacoesCarregadas = resultados[0] as List<Alocacao>;
      final seriesCarregadas = resultados[1] as List<SerieRecorrencia>;

      // Atualizar séries no estado se foram carregadas
      if (!seriesJaCarregadas && seriesCarregadas.isNotEmpty) {
        if (mounted) {
          setState(() {
            if (series.isEmpty ||
                (series.isNotEmpty && series.first.medicoId != medicoId)) {
              series = seriesCarregadas;
            } else {
              // Mesclar com séries existentes
              for (final serieCarregada in seriesCarregadas) {
                if (!series.any((s) => s.id == serieCarregada.id)) {
                  series.add(serieCarregada);
                }
              }
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          // Filtrar alocações do ano específico
          alocacoes = alocacoesCarregadas
              .where((a) => a.data.year == anoParaCarregar)
              .toList();
          // Atualizar progresso após carregar alocações e séries (25%)
          _progressoCarregamentoInicial = 0.25;
          _mensagemCarregamentoInicial = 'A carregar disponibilidades...';
        });
      }

      // Carregar disponibilidades - desativar temporariamente a progress bar interna
      // para usar apenas a progress bar externa
      final isLoadingOriginal = isLoadingDisponibilidades;

      // Desativar progress bar interna durante carregamento inicial
      if (mounted) {
        setState(() {
          isLoadingDisponibilidades = false;
        });
      }

      // Carregar disponibilidades - esta função pode demorar mais, então vamos
      // atualizar o progresso baseado em callbacks ou após cada etapa principal
      try {
        // Aguardar carregamento de disponibilidades com callback de progresso
        await _carregarDisponibilidadesFirestore(
          medicoId,
          ano: anoParaCarregar,
          onProgressoExterno: (progresso, mensagem) {
            if (mounted && _isCarregandoInicial) {
              // Mapear progresso interno (0-1) para 25%-92% do progresso total
              // Quando progresso = 1.0, deve resultar em 92% do progresso total
              // Fórmula: 25% + (progresso * 67%) = 25% + 67% = 92% quando progresso = 1.0
              final progressoTotal = 0.25 + (progresso * 0.67);

              setState(() {
                _progressoCarregamentoInicial =
                    progressoTotal.clamp(0.25, 0.92);
                _mensagemCarregamentoInicial = mensagem;
              });
            }
          },
        );
      } catch (e) {
        debugPrint('❌ Erro ao carregar disponibilidades: $e');
        // Em caso de erro, avançar para próximo estágio mesmo assim
        if (mounted && _isCarregandoInicial) {
          setState(() {
            _progressoCarregamentoInicial = 0.95;
            _mensagemCarregamentoInicial = 'A finalizar...';
          });
        }
      } finally {
        // Restaurar estado original
        isLoadingDisponibilidades = isLoadingOriginal;
      }

      // Atualizar para 95% após disponibilidades (processamento final)
      if (mounted && _isCarregandoInicial) {
        setState(() {
          _progressoCarregamentoInicial = 0.95;
          _mensagemCarregamentoInicial = 'A finalizar...';
        });
      }

      // Verificação final rápida: garantir que alocações e gabinetes estão carregados
      // (normalmente já estão, mas verificar rapidamente se necessário)
      if ((alocacoes.isEmpty || gabinetes.isEmpty) &&
          mounted &&
          _isCarregandoInicial) {
        try {
          if (gabinetes.isEmpty) {
            gabinetes = await buscarGabinetes(unidade: widget.unidade);
          }
          if (alocacoes.isEmpty) {
            final alocacoesCarregadas =
                await AlocacaoMedicosLogic.buscarAlocacoesMedico(
              widget.unidade,
              medicoId,
              anoEspecifico: anoParaCarregar,
            );
            if (mounted) {
              setState(() {
                alocacoes = alocacoesCarregadas
                    .where((a) => a.data.year == anoParaCarregar)
                    .toList();
              });
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao recarregar alocações/gabinetes: $e');
        }
      }

      // Finalizar - ir para 100% apenas no momento final e desativar imediatamente
      if (mounted && _isCarregandoInicial) {
        // Garantir que todos os dados estão atualizados antes de finalizar
        // Verificar se _anoVisualizado está definido
        _anoVisualizado ??= DateTime.now().year;

        // Verificar se disponibilidades estão carregadas
        if (disponibilidades.isEmpty) {
          debugPrint(
              '⚠️ AVISO: Disponibilidades vazias após carregamento inicial!');
        }

        // Debug: verificar estado após concluir
        final disponibilidadesAno = _anoVisualizado != null
            ? disponibilidades
                .where((d) => d.data.year == _anoVisualizado)
                .toList()
            : disponibilidades;
        debugPrint(
            '✅ Carregamento inicial concluído - Disponibilidades: ${disponibilidades.length} total, ${disponibilidadesAno.length} para o ano $_anoVisualizado, Alocações: ${alocacoes.length}, Gabinetes: ${gabinetes.length}');

        // Ir para 100% e desativar imediatamente (sem delay)
        // Usar Timer.run para garantir que a desativação aconteça no próximo microtask
        setState(() {
          _progressoCarregamentoInicial = 1.0;
          _mensagemCarregamentoInicial = 'Concluído!';
        });

        // Desativar imediatamente no próximo microtask (praticamente instantâneo, sem delay)
        Timer.run(() {
          if (mounted && _isCarregandoInicial) {
            setState(() {
              _isCarregandoInicial = false;
              _progressoCarregamentoInicial = 0.0;
              _mensagemCarregamentoInicial = 'A iniciar...';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');
      if (mounted) {
        setState(() {
          _isCarregandoInicial = false;
          _progressoCarregamentoInicial = 0.0;
          _mensagemCarregamentoInicial = 'A iniciar...';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _carregarDisponibilidadesFirestore(String medicoId,
      {int? ano,
      Function(double, String)? onProgressoExterno,
      bool forcarRecarregamentoSeries = false}) async {
    // Carrega o ano especificado ou o ano atual por padrão
    final anoParaCarregar = ano ?? DateTime.now().year;

    // Se estiver no carregamento inicial, não mostrar progress bar interna
    // (usa a progress bar externa completa)
    final mostrarProgressoInterno =
        !_isCarregandoInicial && onProgressoExterno == null;

    // SEMPRE mostrar barra de progresso ao carregar (mas apenas se não estiver no carregamento inicial e não houver callback externo)
    if (mostrarProgressoInterno && mounted) {
      setState(() {
        isLoadingDisponibilidades = true;
        progressoCarregamentoDisponibilidades = 0.0;
        mensagemCarregamentoDisponibilidades = 'A iniciar...';
      });
    }

    // Se houver callback externo, chamar no início
    if (onProgressoExterno != null) {
      onProgressoExterno(0.0, 'A iniciar...');
    }

    // OTIMIZAÇÃO: Se já temos séries carregadas para este médico, não recarregar séries
    // Mas sempre gerar disponibilidades para o novo ano se mudou o ano
    // IMPORTANTE: Não usar _anoVisualizado aqui porque ele já foi atualizado antes desta função ser chamada
    // CORREÇÃO: Se forcarRecarregamentoSeries é true, sempre recarregar do servidor
    final seriesJaCarregadas = !forcarRecarregamentoSeries &&
        series.isNotEmpty &&
        series.first.medicoId == medicoId;

    // #region agent log (COMENTADO - pode ser reativado se necessário)

//    try {
//      final logEntry = {
//        'timestamp': DateTime.now().millisecondsSinceEpoch,
//        'location': 'cadastro_medicos.dart:_carregarDisponibilidadesFirestore',
//        'message': 'Verificando séries já carregadas',
//        'data': {
//          'medicoId': medicoId,
//          'forcarRecarregamentoSeries': forcarRecarregamentoSeries,
//          'seriesJaCarregadas': seriesJaCarregadas,
//          'totalSeriesLocal': series.length,
//          'seriesIdsLocal': series.map((s) => s.id).toList(),
//          'seriesGabineteIdsLocal': series.map((s) => s.gabineteId).toList(),
//          'hypothesisId': 'D'
//        },
//        'sessionId': 'debug-session',
//        'runId': 'run1',
//      };
//      writeLogToFile(jsonEncode(logEntry));
//    } catch (e) {}

// #endregion

    // NOVO MODELO: Apenas séries - carregar séries e gerar disponibilidades dinamicamente
    final disponibilidades = <Disponibilidade>[];
    try {
      // OTIMIZAÇÃO: Gerar apenas para o ano necessário (não precisa do ano inteiro se só mudou o mês)
      final dataInicio = DateTime(anoParaCarregar, 1, 1);
      final dataFim = DateTime(anoParaCarregar + 1, 1, 1);

      List<SerieRecorrencia> seriesCarregadas;

      if (!seriesJaCarregadas) {
        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades = 0.2;
            mensagemCarregamentoDisponibilidades = 'A carregar séries...';
          });
        }

        // Atualizar progresso externo se houver callback
        if (onProgressoExterno != null) {
          onProgressoExterno(0.15, 'A carregar séries...');
        }

        // Carregar séries do médico (carregar TODAS as séries ativas, não apenas do ano)
        // CORREÇÃO CRÍTICA: Forçar busca do servidor quando carregar pela primeira vez
        // para garantir que dados recém-salvos sejam carregados após reabrir a aplicação
        seriesCarregadas = await SerieService.carregarSeries(
          medicoId,
          unidade: widget.unidade,
          forcarServidor:
              true, // Forçar servidor para garantir dados atualizados
          // Não filtrar por data para carregar todas as séries ativas
        );

        // Atualizar progresso após carregar séries (esta operação pode demorar)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.50, 'A carregar exceções...');
        }

        // #region agent log (COMENTADO - pode ser reativado se necessário)

//        try {
//          final logEntry = {
//            'timestamp': DateTime.now().millisecondsSinceEpoch,
//            'location': 'cadastro_medicos.dart:863',
//            'message': '🟢 [HYP-D] Séries carregadas do servidor',
//            'data': {
//              'medicoId': medicoId,
//              'totalSeries': seriesCarregadas.length,
//              'seriesIds': seriesCarregadas.map((s) => s.id).toList(),
//              'seriesTipo': seriesCarregadas.map((s) => s.tipo).toList(),
//              'seriesDataInicio':
//                  seriesCarregadas.map((s) => s.dataInicio.toString()).toList(),
//              'hypothesisId': 'D'
//            },
//            'sessionId': 'debug-session',
//            'runId': 'run1',
//          };
//          writeLogToFile(jsonEncode(logEntry));
//        } catch (e) {}

// #endregion
      } else {
        // Usar séries já carregadas
        seriesCarregadas = series;

        // #region agent log (COMENTADO - pode ser reativado se necessário)

//        try {
//          final logEntry = {
//            'timestamp': DateTime.now().millisecondsSinceEpoch,
//            'location': 'cadastro_medicos.dart:866',
//            'message':
//                '🟡 [HYP-D] Usando séries já carregadas (NÃO recarregou do servidor)',
//            'data': {
//              'medicoId': medicoId,
//              'totalSeries': seriesCarregadas.length,
//              'seriesIds': seriesCarregadas.map((s) => s.id).toList(),
//              'seriesTipo': seriesCarregadas.map((s) => s.tipo).toList(),
//              'seriesDataInicio':
//                  seriesCarregadas.map((s) => s.dataInicio.toString()).toList(),
//              'hypothesisId': 'D'
//            },
//            'sessionId': 'debug-session',
//            'runId': 'run1',
//          };
//          writeLogToFile(jsonEncode(logEntry));
//        } catch (e) {}

// #endregion
      }

      if (!seriesJaCarregadas) {
        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades = 0.5;
            mensagemCarregamentoDisponibilidades = 'A carregar exceções...';
          });
        }

        // Atualizar progresso externo se houver callback (exceções são rápidas)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.55, 'A carregar exceções...');
        }

        // CORREÇÃO CRÍTICA: Se forcarRecarregamentoSeries é true, substituir completamente as séries
        // para garantir que séries atualizadas (ex: com novo gabineteId) substituam as antigas
        if (forcarRecarregamentoSeries) {
          // #region agent log (COMENTADO - pode ser reativado se necessário)

//          try {
//            final logEntry = {
//              'timestamp': DateTime.now().millisecondsSinceEpoch,
//              'location':
//                  'cadastro_medicos.dart:_carregarDisponibilidadesFirestore-substituir-series',
//              'message':
//                  'Substituindo séries completamente (forcarRecarregamentoSeries=true)',
//              'data': {
//                'medicoId': medicoId,
//                'seriesAntesTamanho': series.length,
//                'seriesCarregadasTamanho': seriesCarregadas.length,
//                'seriesCarregadasIds':
//                    seriesCarregadas.map((s) => s.id).toList(),
//                'seriesCarregadasGabineteIds':
//                    seriesCarregadas.map((s) => s.gabineteId).toList(),
//                'hypothesisId': 'H'
//              },
//              'sessionId': 'debug-session',
//              'runId': 'run1',
//            };
//            writeLogToFile(jsonEncode(logEntry));
//          } catch (e) {}

// #endregion

          // Substituir completamente para garantir dados atualizados
          setState(() {
            series = seriesCarregadas;
          });
        } else if (series.isEmpty ||
            (series.isNotEmpty && series.first.medicoId != medicoId)) {
          // Atualizar lista de séries no estado (apenas na primeira carga ou se mudou o médico)
          setState(() {
            series = seriesCarregadas;
          });
          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('✅ Séries carregadas: ${seriesCarregadas.length}');
        } else {
          // Se já temos séries do mesmo médico, atualizar séries existentes e adicionar novas
          setState(() {
            for (final serieCarregada in seriesCarregadas) {
              final index = series.indexWhere((s) => s.id == serieCarregada.id);
              if (index != -1) {
                // Substituir série existente (pode ter sido atualizada)
                series[index] = serieCarregada;
              } else {
                // Adicionar nova série
                series.add(serieCarregada);
              }
            }
          });
        }
      }

      if (seriesCarregadas.isNotEmpty) {
        // OTIMIZAÇÃO: Carregar exceções apenas se necessário (se mudou o ano ou não temos exceções)
        List<ExcecaoSerie> excecoesCarregadas;
        List<Disponibilidade> dispsUnicas = []; // Inicializar com lista vazia
        final excecoesJaCarregadas = excecoes.isNotEmpty &&
            excecoes.any((e) => e.data.year == anoParaCarregar);

        // Se mudou o ano, sempre carregar exceções do novo ano
        // Se só mudou o mês, usar exceções já carregadas
        if (!excecoesJaCarregadas) {
          if (mostrarProgressoInterno && mounted) {
            setState(() {
              progressoCarregamentoDisponibilidades =
                  seriesJaCarregadas ? 0.3 : 0.5;
              mensagemCarregamentoDisponibilidades = 'A carregar exceções...';
            });
          }

          // Atualizar progresso externo se houver callback
          if (onProgressoExterno != null) {
            onProgressoExterno(
                seriesJaCarregadas ? 0.45 : 0.50, 'A carregar exceções...');
          }

          // OTIMIZAÇÃO: Carregar exceções e disponibilidades únicas em paralelo
          // Carregar exceções do médico no período
          final excecoesFuture = SerieService.carregarExcecoes(
            medicoId,
            unidade: widget.unidade,
            dataInicio: dataInicio,
            dataFim: dataFim,
          );

          // OTIMIZAÇÃO: Remover apenas disponibilidades do ano atual antes de carregar (pode fazer em paralelo)
          // IMPORTANTE: Não remover disponibilidades "Única" - elas são salvas no Firestore
          this.disponibilidades.removeWhere((d) =>
              d.id.startsWith('serie_') &&
              d.medicoId == medicoId &&
              d.data.year == anoParaCarregar);

          // Carregar disponibilidades "Única" do Firestore em paralelo com exceções
          final dispsUnicasFuture =
              DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
            medicoId,
            anoParaCarregar,
            widget.unidade,
          );

          // Aguardar ambas as operações em paralelo
          final resultados = await Future.wait([
            excecoesFuture,
            dispsUnicasFuture,
          ]);

          final excecoesDoFirestore = resultados[0] as List<ExcecaoSerie>;
          dispsUnicas = resultados[1] as List<Disponibilidade>;

          // Atualizar progresso após carregar exceções e disponibilidades únicas
          if (onProgressoExterno != null) {
            onProgressoExterno(0.75, 'A processar disponibilidades...');
          }

          // CORREÇÃO CRÍTICA: Mesclar exceções do Firestore com exceções locais (recém-criadas)
          // para não perder exceções que foram adicionadas localmente mas ainda não foram salvas
          final excecoesMap = <String, ExcecaoSerie>{};

          // Primeiro, adicionar exceções locais do ano (têm prioridade)
          for (final excecaoLocal in excecoes) {
            if (excecaoLocal.data.year == anoParaCarregar) {
              final chave =
                  '${excecaoLocal.serieId}_${excecaoLocal.data.year}-${excecaoLocal.data.month}-${excecaoLocal.data.day}';
              excecoesMap[chave] = excecaoLocal;
            }
          }

          // Depois, adicionar exceções do Firestore do ano (só se não existir local)
          for (final excecaoFirestore in excecoesDoFirestore) {
            if (excecaoFirestore.data.year == anoParaCarregar) {
              final chave =
                  '${excecaoFirestore.serieId}_${excecaoFirestore.data.year}-${excecaoFirestore.data.month}-${excecaoFirestore.data.day}';
              if (!excecoesMap.containsKey(chave)) {
                excecoesMap[chave] = excecaoFirestore;
              }
            }
          }

          excecoesCarregadas = excecoesMap.values.toList();

          // Atualizar lista de exceções no estado (mesclando, não substituindo)
          if (mounted) {
            setState(() {
              // Mesclar exceções: manter exceções de outros anos e adicionar/atualizar do ano atual
              final excecoesOutrosAnos = excecoes
                  .where((e) => e.data.year != anoParaCarregar)
                  .toList();
              excecoes = [...excecoesOutrosAnos, ...excecoesCarregadas];
              if (mostrarProgressoInterno) {
                progressoCarregamentoDisponibilidades =
                    seriesJaCarregadas ? 0.6 : 0.7;
              }
            });
          }
        } else {
          // CORREÇÃO: Usar TODAS as exceções locais (incluindo recém-criadas) do ano
          // Não apenas filtrar, mas garantir que temos todas as exceções atualizadas
          excecoesCarregadas =
              excecoes.where((e) => e.data.year == anoParaCarregar).toList();

          // OTIMIZAÇÃO: Remover apenas disponibilidades do ano atual
          this.disponibilidades.removeWhere((d) =>
              d.id.startsWith('serie_') &&
              d.medicoId == medicoId &&
              d.data.year == anoParaCarregar);

          // Carregar disponibilidades "Única" do Firestore (mesmo se exceções já estiverem carregadas)
          dispsUnicas =
              await DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
            medicoId,
            anoParaCarregar,
            widget.unidade,
          );

          if (mostrarProgressoInterno && mounted) {
            setState(() {
              progressoCarregamentoDisponibilidades =
                  seriesJaCarregadas ? 0.6 : 0.7;
            });
          }

          // Atualizar progresso externo se houver callback
          if (onProgressoExterno != null) {
            onProgressoExterno(0.75, 'A processar disponibilidades...');
          }
        }

        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.7 : 0.75;
            mensagemCarregamentoDisponibilidades =
                'A gerar disponibilidades...';
          });
        }

        // Atualizar progresso externo se houver callback (gerar disponibilidades pode demorar)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.78, 'A gerar disponibilidades...');
        }

        // #region agent log (COMENTADO - pode ser reativado se necessário)

//        try {
//          final logEntry = {
//            'timestamp': DateTime.now().millisecondsSinceEpoch,
//            'location': 'cadastro_medicos.dart:1014',
//            'message': '🔵 [HYP-C] Gerando disponibilidades - ANTES',
//            'data': {
//              'medicoId': medicoId,
//              'totalSeries': seriesCarregadas.length,
//              'seriesTipo': seriesCarregadas.map((s) => s.tipo).toList(),
//              'seriesIds': seriesCarregadas.map((s) => s.id).toList(),
//              'seriesDataInicio':
//                  seriesCarregadas.map((s) => s.dataInicio.toString()).toList(),
//              'periodoInicio': dataInicio.toString(),
//              'periodoFim': dataFim.toString(),
//              'hypothesisId': 'C'
//            },
//            'sessionId': 'debug-session',
//            'runId': 'run1',
//          };
//          writeLogToFile(jsonEncode(logEntry));
//        } catch (e) {}

// #endregion

        final dispsGeradas = SerieGenerator.gerarDisponibilidades(
          series: seriesCarregadas,
          excecoes: excecoesCarregadas,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

        // Atualizar progresso após gerar disponibilidades (organizar pode demorar)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.85, 'A organizar dados...');
        }

        // #region agent log (COMENTADO - pode ser reativado se necessário)

//        try {
//          final logEntry = {
//            'timestamp': DateTime.now().millisecondsSinceEpoch,
//            'location': 'cadastro_medicos.dart:1030',
//            'message': '🟢 [HYP-C] Disponibilidades geradas - DEPOIS',
//            'data': {
//              'medicoId': medicoId,
//              'totalDisponibilidades': dispsGeradas.length,
//              'tipos': dispsGeradas.map((d) => d.tipo).toList(),
//              'datas': dispsGeradas.map((d) => d.data.toString()).toList(),
//              'hypothesisId': 'C'
//            },
//            'sessionId': 'debug-session',
//            'runId': 'run1',
//          };
//          writeLogToFile(jsonEncode(logEntry));
//        } catch (e) {}

// #endregion

        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.80 : 0.85;
            mensagemCarregamentoDisponibilidades = 'A processar dados...';
          });
        }

        // NOVO MODELO: Apenas séries - adicionar disponibilidades geradas
        // As exceções já são aplicadas automaticamente na geração
        // Usar um Map para garantir unicidade baseado em (medicoId, data, tipo)
        final disponibilidadesUnicas = <String, Disponibilidade>{};

        // Adicionar disponibilidades existentes de outros anos
        for (final disp in this.disponibilidades) {
          final chave = CadastroMedicosHelper.gerarChaveDisponibilidade(disp);
          disponibilidadesUnicas[chave] = disp;
        }

        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.85 : 0.88;
            mensagemCarregamentoDisponibilidades = 'A organizar dados...';
          });
        }

        // Atualizar progresso externo se houver callback (organizar dados)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.88, 'A organizar dados...');
        }

        // Adicionar disponibilidades geradas de séries
        for (final dispGerada in dispsGeradas) {
          final chave =
              '${dispGerada.medicoId}_${dispGerada.data.year}-${dispGerada.data.month}-${dispGerada.data.day}_${dispGerada.tipo}';
          disponibilidadesUnicas[chave] = dispGerada;
        }

        // CORREÇÃO: Adicionar disponibilidades "Única" carregadas do Firestore
        // IMPORTANTE: As disponibilidades únicas já adicionadas localmente (ainda não salvas)
        // têm prioridade sobre as do Firestore para a mesma chave
        for (final dispUnica in dispsUnicas) {
          final chave =
              '${dispUnica.medicoId}_${dispUnica.data.year}-${dispUnica.data.month}-${dispUnica.data.day}_${dispUnica.tipo}';
          // Só adicionar se não existe ainda (para não sobrescrever disponibilidades não salvas)
          if (!disponibilidadesUnicas.containsKey(chave)) {
            disponibilidadesUnicas[chave] = dispUnica;
          } else {
            debugPrint(
                '⚠️ Disponibilidade única já existe localmente (não salva), preservando: $chave');
          }
        }

        // Atualizar progresso após mesclar disponibilidades (ordenar é rápido)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.90, 'A ordenar dados...');
        }

        // OTIMIZAÇÃO: Ordenar durante a construção da lista (mais eficiente)
        // Converter para lista e ordenar de uma vez
        final listaOrdenada = disponibilidadesUnicas.values.toList();
        listaOrdenada.sort((a, b) => a.data.compareTo(b.data));

        if (mostrarProgressoInterno && mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.95 : 0.96;
            mensagemCarregamentoDisponibilidades = 'A finalizar...';
          });
        }

        // Atualizar progresso externo após ordenar (finalização é rápida)
        if (onProgressoExterno != null) {
          onProgressoExterno(0.92, 'A finalizar...');
        }

        // CORREÇÃO CRÍTICA: Mesclar com disponibilidades existentes que não são do ano atual
        // Manter disponibilidades "Única" que ainda não foram salvas (não estão no Firestore)
        final disponibilidadesFinais =
            CadastroMedicosHelper.mesclarDisponibilidadesComAno(
          this.disponibilidades,
          listaOrdenada,
          medicoId,
          anoParaCarregar,
        );

        // Atualizar lista completa
        // CORREÇÃO CRÍTICA: Preservar disponibilidades únicas não salvas mesmo quando há séries
        final listaFinal = disponibilidadesFinais.values.toList();
        listaFinal.sort((a, b) => a.data.compareTo(b.data));

        // DEBUG: Verificar quantas disponibilidades únicas estão sendo preservadas
        final unicasAntes = disponibilidades
            .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
            .length;
        final unicasDepois = listaFinal
            .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
            .length;
        if (unicasAntes != unicasDepois) {
          debugPrint(
              '⚠️ PERDA DE DISPONIBILIDADES ÚNICAS: antes=$unicasAntes, depois=$unicasDepois');
        }

        disponibilidades.clear();
        disponibilidades.addAll(listaFinal);
      } else {
        // Se não há séries, ainda precisamos carregar disponibilidades "Única"
        if (onProgressoExterno != null) {
          onProgressoExterno(0.50, 'A carregar disponibilidades únicas...');
        }

        try {
          final dispsUnicas =
              await DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
            medicoId,
            anoParaCarregar,
            widget.unidade,
          );

          if (onProgressoExterno != null) {
            onProgressoExterno(0.70, 'A processar disponibilidades...');
          }

          // CORREÇÃO CRÍTICA: Mesclar com disponibilidades existentes (incluindo as que ainda não foram salvas)
          // Não limpar a lista completamente, apenas mesclar para não perder disponibilidades não salvas
          final listaOrdenada = CadastroMedicosHelper.mesclarApenasUnicas(
            this.disponibilidades,
            dispsUnicas,
            medicoId,
          );

          // CORREÇÃO CRÍTICA: Preservar disponibilidades únicas não salvas mesmo quando não há séries
          // Atualizar a lista completa
          // DEBUG: Verificar quantas disponibilidades únicas estão sendo preservadas
          final unicasAntes = disponibilidades
              .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
              .length;
          final unicasDepois = listaOrdenada
              .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
              .length;
          if (unicasAntes != unicasDepois) {
            debugPrint(
                '⚠️ PERDA DE DISPONIBILIDADES ÚNICAS (sem séries): antes=$unicasAntes, depois=$unicasDepois');
          }

          if (onProgressoExterno != null) {
            onProgressoExterno(0.90, 'A finalizar...');
          }

          disponibilidades.clear();
          disponibilidades.addAll(listaOrdenada);
        } catch (e) {
          // Erro ao carregar disponibilidades únicas - continuar sem elas
          debugPrint('❌ Erro ao carregar disponibilidades únicas: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar séries e gerar disponibilidades: $e');
    }

    // Atualizar progresso interno apenas se estiver mostrando
    if (mostrarProgressoInterno && mounted) {
      // Atualizar progresso para 98% antes de finalizar
      setState(() {
        progressoCarregamentoDisponibilidades = 0.98;
        mensagemCarregamentoDisponibilidades = 'A concluir...';
      });
    }

    // Atualizar progresso externo para 98% se houver callback
    if (onProgressoExterno != null) {
      onProgressoExterno(0.98, 'A concluir...');
    }

    // Atualizar os dados - SEMPRE atualizar, independente de mostrarProgressoInterno
    // CORREÇÃO CRÍTICA: Antes de substituir a lista, preservar disponibilidades únicas não salvas
    final unicasNaoSalvas = this
        .disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
        .toList();

    if (mounted) {
      setState(() {
        // Substituir a lista, mas depois adicionar de volta as únicas não salvas
        this.disponibilidades = disponibilidades;

        // Adicionar de volta as disponibilidades únicas não salvas
        for (final unica in unicasNaoSalvas) {
          final chave =
              '${unica.medicoId}_${unica.data.year}-${unica.data.month}-${unica.data.day}_${unica.tipo}';
          final jaExiste = this.disponibilidades.any((d) {
            final dChave =
                '${d.medicoId}_${d.data.year}-${d.data.month}-${d.data.day}_${d.tipo}';
            return dChave == chave;
          });
          if (!jaExiste) {
            this.disponibilidades.add(unica);
            debugPrint(
                '🔒 Restaurada disponibilidade única não salva: ${unica.data.day}/${unica.data.month}/${unica.data.year}');
          }
        }

        // Atualiza os dias selecionados baseado nas disponibilidades carregadas
        diasSelecionados = this.disponibilidades.map((d) => d.data).toList();
        _anoVisualizado =
            anoParaCarregar; // Guarda o ano visualizado (IMPORTANTE: sempre definir)

        // Debug: verificar se disponibilidades foram atualizadas
        final disponibilidadesFiltradas = this
            .disponibilidades
            .where((d) => d.data.year == anoParaCarregar)
            .toList();
        debugPrint(
            '✅ Disponibilidades atualizadas: ${this.disponibilidades.length} total, ${disponibilidadesFiltradas.length} para o ano $anoParaCarregar');

        // Atualizar progresso interno apenas se estiver mostrando
        if (mostrarProgressoInterno) {
          progressoCarregamentoDisponibilidades = 1.0;
          mensagemCarregamentoDisponibilidades = 'Concluído!';
        }
      });

      // Atualizar progresso externo ao concluir (apenas se ainda estiver ativo)
      // O callback interno pode ter chegado a 92% máximo, então vamos garantir que chegue a 95%
      if (onProgressoExterno != null) {
        // Já chamado com 0.95 dentro do callback, mas vamos garantir que chegue a 95% se necessário
        // O callback mapeia 1.0 para 92%, então não precisamos fazer nada aqui
        // A atualização para 95% será feita na função _carregarDadosIniciaisCompleto após retornar
      }
    }

    // Desligar progresso interno após concluir (apenas se estava mostrando)
    if (mostrarProgressoInterno && mounted) {
      setState(() {
        isLoadingDisponibilidades = false;
        progressoCarregamentoDisponibilidades = 0.0;
        mensagemCarregamentoDisponibilidades = 'A carregar disponibilidades...';

        // CORREÇÃO: Guardar disponibilidades originais de forma síncrona
        // quando o usuário cria novas disponibilidades
        // IMPORTANTE: Incluir também as disponibilidades únicas não salvas
        _disponibilidadesOriginal = this
            .disponibilidades
            .map((d) => Disponibilidade.fromMap(d.toMap()))
            .toList();

        // DEBUG: Verificar se disponibilidades únicas foram preservadas
        final unicasAposCarregamento = this
            .disponibilidades
            .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
            .length;
        if (unicasNaoSalvas.isNotEmpty) {
          debugPrint(
              '🔍 Após carregar: $unicasAposCarregamento disponibilidades únicas na lista (${unicasNaoSalvas.length} deveriam ser preservadas)');
        }
      });
    }

    // Carregar alocações e gabinetes após carregar disponibilidades
    // Só carregar em background se não estiver no carregamento inicial (já foi carregado)
    if (!_isCarregandoInicial) {
      _carregarAlocacoesEGabinetes(medicoId, ano: anoParaCarregar)
          .catchError((error) {
        debugPrint('⚠️ Erro ao carregar alocações e gabinetes: $error');
      });
    }
  }

  /// Carrega alocações do médico e lista de gabinetes para exibir número do gabinete nos cartões
  Future<void> _carregarAlocacoesEGabinetes(String medicoId, {int? ano}) async {
    try {
      final anoParaCarregar = ano ?? DateTime.now().year;

      // Carregar gabinetes (carregar apenas uma vez, não precisa recarregar sempre)
      if (gabinetes.isEmpty) {
        gabinetes = await buscarGabinetes(unidade: widget.unidade);
      }

      // Aguardar um pouco para garantir que o Firestore sincronizou após alocação
      await Future.delayed(const Duration(milliseconds: 500));

      // Carregar alocações do médico para o ano específico
      final alocacoesCarregadas =
          await AlocacaoMedicosLogic.buscarAlocacoesMedico(
        widget.unidade,
        medicoId,
        anoEspecifico: anoParaCarregar,
      );

      if (mounted) {
        setState(() {
          // Filtrar alocações do ano específico do Firestore
          final alocacoesDoFirestore = alocacoesCarregadas
              .where((a) => a.data.year == anoParaCarregar)
              .toList();

          // Mesclar com alocações locais (evitar perder alocações recém-criadas)
          // Usar um Map para evitar duplicatas (chave: medicoId_data_gabineteId)
          final Map<String, Alocacao> alocacoesMap = {};

          // Primeiro, adicionar alocações do Firestore
          for (final aloc in alocacoesDoFirestore) {
            final chave =
                '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
            alocacoesMap[chave] = aloc;
          }

          // CORREÇÃO CRÍTICA: NÃO mesclar com alocações locais após desalocar série
          // As alocações locais podem ter dados antigos que devem ser descartados
          // Apenas usar alocações do Firestore para garantir sincronização correta

          // Atualizar lista de alocações
          alocacoes = alocacoesMap.values.toList();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar alocações e gabinetes: $e');
      // Continuar sem alocações se houver erro
    }
  }

  /// Callback quando o gabinete de uma disponibilidade é alterado
  Future<void> _onGabineteChanged(
      Disponibilidade disponibilidade, String? novoGabineteId) async {
    if (_medicoAtual == null) return;

    // Iniciar progressbar
    if (mounted) {
      setState(() {
        _alocandoGabinete = true;
        progressoAlocandoGabinete = 0.0;
        mensagemAlocandoGabinete = 'A iniciar...';
      });
    }

    try {
      final dataNormalizada = DateTime(
        disponibilidade.data.year,
        disponibilidade.data.month,
        disponibilidade.data.day,
      );

      // Verificar se é uma série ou disponibilidade única
      final isSerie = disponibilidade.id.startsWith('serie_') ||
          disponibilidade.tipo != 'Única';

      // Extrair o ID da série (se for série)
      String? serieId;
      if (isSerie) {
        // É uma série: extrair o ID da série
        if (disponibilidade.id.startsWith('serie_')) {
          // Extrair ID da série do ID da disponibilidade
          serieId =
              SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id);
        }

        // Se não encontrou pelo ID, buscar na lista de séries
        if (serieId == null || !series.any((s) => s.id == serieId)) {
          // Buscar série que corresponde a esta data, tipo e padrão
          SerieRecorrencia? serieCorrespondente;
          for (final serie in series) {
            if (serie.medicoId != _medicoAtual!.id ||
                serie.tipo != disponibilidade.tipo) {
              continue;
            }
            if (serie.dataInicio
                .isAfter(dataNormalizada.add(const Duration(days: 1)))) {
              continue;
            }
            if (serie.dataFim != null &&
                serie.dataFim!.isBefore(
                    dataNormalizada.subtract(const Duration(days: 1)))) {
              continue;
            }
            if (!SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
                dataNormalizada, serie)) {
              continue;
            }
            serieCorrespondente = serie;
            break;
          }

          if (serieCorrespondente != null) {
            serieId = serieCorrespondente.id;
          }
        }

        if (serieId != null && serieId.isNotEmpty) {
          if (novoGabineteId == null) {
            // Desalocar: perguntar se quer desalocar só o dia ou toda a série
            if (!mounted) return;

            final escolha = await showDialog<String>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Desalocar gabinete'),
                  content: Text(
                    'Esta alocação faz parte de uma série "${disponibilidade.tipo}".\n\n'
                    'Deseja desalocar apenas o dia ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year} '
                    'ou deste dia para a frente?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('1dia'),
                      child: const Text('Apenas este dia'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('serie'),
                      child: const Text('Para a frente'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancelar'),
                    ),
                  ],
                );
              },
            );

            // Se o usuário cancelou, não fazer nada
            if (escolha == null) {
              if (mounted) {
                setState(() {
                  _alocandoGabinete = false;
                  progressoAlocandoGabinete = 0.0;
                  mensagemAlocandoGabinete = 'A alocar gabinete...';
                });
              }
              return;
            }

            if (mounted) {
              setState(() {
                progressoAlocandoGabinete = 0.3;
                mensagemAlocandoGabinete = 'A desalocar...';
              });
            }

            if (escolha == '1dia') {
              // Desalocar apenas este dia: criar exceção de gabinete (não cancelada, apenas remove gabinete)
              // O médico continua disponível mas sem gabinete neste dia específico

              // CORREÇÃO: Atualizar UI imediatamente - remover alocação da lista local
              alocacoes.removeWhere((a) {
                final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                return a.medicoId == _medicoAtual!.id &&
                    aDate == dataNormalizada;
              });

              if (mounted) {
                setState(() {
                  // Criar nova referência da lista para forçar detecção de mudança
                  alocacoes = List<Alocacao>.from(alocacoes);
                });
              }

              await DisponibilidadeSerieService.removerGabineteDataSerie(
                serieId: serieId,
                medicoId: _medicoAtual!.id,
                data: dataNormalizada,
                unidade: widget.unidade,
              );
            } else if (escolha == 'serie') {
              // CORREÇÃO: Desalocar toda a série A PARTIR desta data: manter gabinete nas datas anteriores
              // Buscar alocação atual para obter o gabinete origem
              final alocacaoAtual = alocacoes.firstWhere(
                (a) {
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                  return a.medicoId == _medicoAtual!.id &&
                      aDate == dataNormalizada;
                },
                orElse: () => Alocacao(
                  id: '',
                  medicoId: '',
                  gabineteId: '',
                  data: DateTime(1900),
                  horarioInicio: '',
                  horarioFim: '',
                ),
              );

              // Obter gabinete origem da alocação atual ou da série
              final gabineteOrigem = alocacaoAtual.gabineteId.isNotEmpty
                  ? alocacaoAtual.gabineteId
                  : series
                          .firstWhere(
                            (s) => s.id == serieId,
                            orElse: () => SerieRecorrencia(
                              id: '',
                              medicoId: '',
                              dataInicio: DateTime(1900),
                              tipo: '',
                              horarios: [],
                              gabineteId: null,
                              parametros: {},
                              ativo: false,
                            ),
                          )
                          .gabineteId ??
                      '';

              if (gabineteOrigem.isNotEmpty) {
                // CORREÇÃO: Atualização otimista da UI - remover alocações localmente ANTES de chamar serviço
                // Encontrar a série para obter informações necessárias
                final serieEncontrada = series.firstWhere(
                  (s) => s.id == serieId,
                  orElse: () => SerieRecorrencia(
                    id: '',
                    medicoId: '',
                    dataInicio: DateTime(1900),
                    tipo: '',
                    horarios: [],
                    gabineteId: null,
                    parametros: {},
                    ativo: false,
                  ),
                );

                // Função para verificar se data corresponde à série
                bool verificarSeDataCorrespondeSerie(
                    DateTime data, SerieRecorrencia serie) {
                  switch (serie.tipo) {
                    case 'Semanal':
                      return data.weekday == serie.dataInicio.weekday;
                    case 'Quinzenal':
                      final diff = data.difference(serie.dataInicio).inDays;
                      return diff >= 0 &&
                          diff % 14 == 0 &&
                          data.weekday == serie.dataInicio.weekday;
                    case 'Mensal':
                      return data.weekday == serie.dataInicio.weekday;
                    case 'Consecutivo':
                      final numeroDias =
                          serie.parametros['numeroDias'] as int? ?? 5;
                      final diff = data.difference(serie.dataInicio).inDays;
                      return diff >= 0 && diff < numeroDias;
                    default:
                      return true;
                  }
                }

                // Remover alocações localmente para datas >= dataRef
                // As alocações de séries têm ID no formato 'serie_${serieId}_${dataKey}'
                final serieIdPrefix = 'serie_${serieId}_';
                alocacoes.removeWhere((a) {
                  // Verificar se é alocação desta série
                  if (!a.id.startsWith(serieIdPrefix)) return false;

                  // Verificar se é do médico correto
                  if (a.medicoId != _medicoAtual!.id) return false;

                  // Normalizar data da alocação
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);

                  // Remover apenas se data >= dataRef e corresponde ao padrão da série
                  if (aDate.isBefore(dataNormalizada)) return false;

                  // Verificar se data corresponde ao padrão da série
                  return verificarSeDataCorrespondeSerie(
                      aDate, serieEncontrada);
                });

                // Atualizar UI imediatamente
                if (mounted) {
                  setState(() {
                    // Criar nova referência da lista para forçar detecção de mudança
                    alocacoes = List<Alocacao>.from(alocacoes);
                  });
                  // CORREÇÃO CRÍTICA: Aguardar um frame para garantir que o setState foi processado
                  // antes de continuar, forçando rebuild completo do DisponibilidadesGrid
                  await Future.delayed(Duration.zero);
                }

                // Desalocar série a partir da data, mantendo gabinete nas datas anteriores
                await DisponibilidadeSerieService.desalocarSerieAPartirDeData(
                  serieId: serieId,
                  medicoId: _medicoAtual!.id,
                  dataRef: dataNormalizada,
                  gabineteOrigem: gabineteOrigem,
                  verificarSeDataCorrespondeSerie:
                      verificarSeDataCorrespondeSerie,
                  unidade: widget.unidade,
                );
              } else {
                // CORREÇÃO: Mesmo sem gabinete origem, desalocar apenas a partir da data (não toda a série)
                // Encontrar a série para obter informações necessárias
                final serieEncontrada = series.firstWhere(
                  (s) => s.id == serieId,
                  orElse: () => SerieRecorrencia(
                    id: '',
                    medicoId: '',
                    dataInicio: DateTime(1900),
                    tipo: '',
                    horarios: [],
                    gabineteId: null,
                    parametros: {},
                    ativo: false,
                  ),
                );

                // Função para verificar se data corresponde à série
                bool verificarSeDataCorrespondeSerie(
                    DateTime data, SerieRecorrencia serie) {
                  switch (serie.tipo) {
                    case 'Semanal':
                      return data.weekday == serie.dataInicio.weekday;
                    case 'Quinzenal':
                      final diff = data.difference(serie.dataInicio).inDays;
                      return diff >= 0 &&
                          diff % 14 == 0 &&
                          data.weekday == serie.dataInicio.weekday;
                    case 'Mensal':
                      return data.weekday == serie.dataInicio.weekday;
                    case 'Consecutivo':
                      final numeroDias =
                          serie.parametros['numeroDias'] as int? ?? 5;
                      final diff = data.difference(serie.dataInicio).inDays;
                      return diff >= 0 && diff < numeroDias;
                    default:
                      return true;
                  }
                }

                // CORREÇÃO: Remover apenas alocações >= dataRef (não toda a série)
                // As alocações de séries têm ID no formato 'serie_${serieId}_${dataKey}'
                final serieIdPrefix = 'serie_${serieId}_';
                alocacoes = alocacoes.where((a) {
                  // Verificar se é alocação desta série
                  if (!a.id.startsWith(serieIdPrefix)) return true;
                  if (a.medicoId != _medicoAtual!.id) return true;

                  // Normalizar data da alocação
                  final aDate = DateTime(a.data.year, a.data.month, a.data.day);

                  // Remover apenas se data >= dataRef e corresponde ao padrão da série
                  if (aDate.isBefore(dataNormalizada)) {
                    return true; // Manter datas anteriores
                  }

                  // Verificar se data corresponde ao padrão da série
                  return !verificarSeDataCorrespondeSerie(
                      aDate, serieEncontrada); // Manter se não corresponde
                }).toList();

                // Atualizar UI imediatamente
                if (mounted) {
                  setState(() {
                    // Criar nova referência da lista para forçar detecção de mudança
                    alocacoes = List<Alocacao>.from(alocacoes);
                  });
                  await Future.delayed(Duration.zero);
                }

                // CORREÇÃO: Criar exceções APENAS para datas >= dataRef para desalocar apenas a partir da data
                // IMPORTANTE: Como não há gabinete origem, criar exceções com gabineteId: null (sem gabinete)
                // NÃO afetar datas anteriores a dataRef
                final dataFimSerie = serieEncontrada.dataFim ??
                    DateTime(dataNormalizada.year + 1, 12, 31);

                // Carregar exceções existentes APENAS a partir de dataRef (não desde dataInicioSerie)
                // Isso garante que não afetamos datas anteriores
                final excecoesExistentes = await SerieService.carregarExcecoes(
                  _medicoAtual!.id,
                  unidade: widget.unidade,
                  dataInicio: dataNormalizada,
                  dataFim: dataFimSerie,
                  serieId: serieId,
                  forcarServidor: true,
                );

                // Criar mapa de exceções por data
                final excecoesPorData = <String, ExcecaoSerie>{};
                for (final excecao in excecoesExistentes) {
                  if (excecao.serieId == serieId && !excecao.cancelada) {
                    final dataKey =
                        '${excecao.data.year}-${excecao.data.month}-${excecao.data.day}';
                    excecoesPorData[dataKey] = excecao;
                  }
                }

                // Criar exceções com gabineteId: null APENAS para datas >= dataRef que correspondem à série
                DateTime dataAtual = dataNormalizada;
                while (!dataAtual.isAfter(dataFimSerie)) {
                  if (verificarSeDataCorrespondeSerie(
                      dataAtual, serieEncontrada)) {
                    final dataKey =
                        '${dataAtual.year}-${dataAtual.month}-${dataAtual.day}';
                    final excecaoExistente = excecoesPorData[dataKey];

                    if (excecaoExistente == null) {
                      // Criar exceção sem gabinete para esta data (apenas datas >= dataRef)
                      await DisponibilidadeSerieService
                          .removerGabineteDataSerie(
                        serieId: serieId,
                        medicoId: _medicoAtual!.id,
                        data: dataAtual,
                        unidade: widget.unidade,
                      );
                    } else if (excecaoExistente.gabineteId != null) {
                      // Atualizar exceção existente para remover gabinete (apenas datas >= dataRef)
                      await DisponibilidadeSerieService
                          .removerGabineteDataSerie(
                        serieId: serieId,
                        medicoId: _medicoAtual!.id,
                        data: dataAtual,
                        unidade: widget.unidade,
                      );
                    }
                  }
                  dataAtual = dataAtual.add(const Duration(days: 1));
                }
              }
            }

            // CORREÇÃO CRÍTICA: Remover chamadas duplicadas de invalidação de cache
            // invalidateCacheParaSerie já é chamado dentro de desalocarSerie (linha 632)
            // e já invalida cache para todos os dias que a série afeta
            // Não precisamos chamar invalidateCacheForDay/invalidateCacheFromDate novamente
            // Apenas invalidar cache de séries (já feito dentro de desalocarSerie, mas garantir aqui também)
            final unidadeIdDesalocar =
                widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
            SerieService.invalidateCacheSeries(
                unidadeIdDesalocar, _medicoAtual!.id);

            if (escolha == 'serie') {
              // CORREÇÃO CRÍTICA: Invalidar cache ANTES de recarregar alocações do servidor
              // Isso garante que os dados são recarregados do Firestore, não do cache
              if (_medicoAtual != null && _anoVisualizado != null) {
                // Invalidar cache para todo o ano para garantir dados atualizados
                AlocacaoMedicosLogic.invalidateCacheFromDate(
                    DateTime(_anoVisualizado!, 1, 1));
              }
              // Aguardar um pouco para garantir que o Firestore sincronizou
              await Future.delayed(const Duration(milliseconds: 500));
              if (_medicoAtual != null && _anoVisualizado != null && mounted) {
                setState(() {
                  progressoAlocandoGabinete = 0.85;
                  mensagemAlocandoGabinete = 'A sincronizar dados...';
                });
                // Recarregar alocações do servidor para garantir sincronização
                await _carregarAlocacoesEGabinetes(_medicoAtual!.id,
                    ano: _anoVisualizado);
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 1.0;
                    mensagemAlocandoGabinete = 'Concluído!';
                  });
                  await Future.delayed(const Duration(milliseconds: 300));
                }
              }
            }

            if (mounted) {
              setState(() {
                _alocandoGabinete = false;
                progressoAlocandoGabinete = 0.0;
                mensagemAlocandoGabinete = 'A alocar gabinete...';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(escolha == '1dia'
                      ? 'Gabinete removido deste dia com sucesso'
                      : 'Gabinete removido da série com sucesso'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            return; // Retornar aqui - já terminou
          } else {
            // Mudar gabinete: perguntar se quer mudar só este dia ou toda a série
            // Verificar se já existe alocação para obter gabinete origem
            final alocacaoAtual = alocacoes.firstWhere(
              (a) {
                final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                return a.medicoId == _medicoAtual!.id &&
                    aDate == dataNormalizada;
              },
              orElse: () => Alocacao(
                id: '',
                medicoId: '',
                gabineteId: '',
                data: DateTime(1900),
                horarioInicio: '',
                horarioFim: '',
              ),
            );

            // Verificar se já existe exceção (cartão já foi desemparelhado)
            bool temExcecao = false;
            if (alocacaoAtual.id.isNotEmpty &&
                alocacaoAtual.id.startsWith('serie_')) {
              try {
                final excecoes = await SerieService.carregarExcecoes(
                  _medicoAtual!.id,
                  unidade: widget.unidade,
                  dataInicio: dataNormalizada,
                  dataFim: dataNormalizada,
                  serieId: serieId,
                  forcarServidor: false,
                );

                final excecaoExistente = excecoes.firstWhere(
                  (e) =>
                      e.serieId == serieId &&
                      e.data.year == dataNormalizada.year &&
                      e.data.month == dataNormalizada.month &&
                      e.data.day == dataNormalizada.day &&
                      !e.cancelada,
                  orElse: () => ExcecaoSerie(
                    id: '',
                    serieId: '',
                    data: DateTime(1900, 1, 1),
                  ),
                );

                temExcecao = excecaoExistente.id.isNotEmpty;
              } catch (e) {
                debugPrint('⚠️ Erro ao verificar exceção: $e');
              }
            }

            if (!mounted) return;

            final escolha = await showDialog<String>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(temExcecao
                      ? 'Mudar gabinete do cartão?'
                      : 'Mudar gabinete da série?'),
                  content: Text(
                    temExcecao
                        ? 'Este cartão da série já foi alocado desemparelhado da série.\n\n'
                            'Deseja mudar apenas este cartão para o novo gabinete?'
                        : 'Esta alocação faz parte de uma série "${disponibilidade.tipo}".\n\n'
                            'Deseja mudar apenas o dia ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year} '
                            'ou toda a série a partir deste dia para o novo gabinete?',
                  ),
                  actions: [
                    if (!temExcecao) ...[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('1dia'),
                        child: const Text('Apenas este dia'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('serie'),
                        child: const Text('Toda a série a partir deste dia'),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('1dia'),
                        child: const Text('Sim, mudar cartão'),
                      ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancelar'),
                    ),
                  ],
                );
              },
            );

            // Se o usuário cancelou, não fazer nada
            if (escolha == null) {
              if (mounted) {
                setState(() {
                  _alocandoGabinete = false;
                  progressoAlocandoGabinete = 0.0;
                  mensagemAlocandoGabinete = 'A alocar gabinete...';
                });
              }
              return;
            }

            if (mounted) {
              setState(() {
                progressoAlocandoGabinete = 0.3;
                mensagemAlocandoGabinete = 'A processar...';
              });
            }

            if (escolha == '1dia') {
              // Mudar apenas este dia: criar/atualizar exceção de gabinete
              // O médico continua disponível mas em outro gabinete neste dia específico

              // CORREÇÃO: Atualizar UI imediatamente - atualizar/criar alocação localmente
              final alocacaoIndex = alocacoes.indexWhere((a) {
                final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                return a.medicoId == _medicoAtual!.id &&
                    aDate == dataNormalizada;
              });

              if (alocacaoIndex != -1) {
                // Atualizar alocação existente
                alocacoes[alocacaoIndex] = Alocacao(
                  id: alocacoes[alocacaoIndex].id,
                  medicoId: alocacoes[alocacaoIndex].medicoId,
                  gabineteId: novoGabineteId, // Novo gabinete
                  data: alocacoes[alocacaoIndex].data,
                  horarioInicio: alocacoes[alocacaoIndex].horarioInicio,
                  horarioFim: alocacoes[alocacaoIndex].horarioFim,
                );
              } else {
                // Criar nova alocação (cartão estava sem gabinete)
                final dataKey =
                    '${dataNormalizada.year}-${dataNormalizada.month}-${dataNormalizada.day}';
                final novaAlocacao = Alocacao(
                  id: 'serie_${serieId}_$dataKey',
                  medicoId: _medicoAtual!.id,
                  gabineteId: novoGabineteId,
                  data: dataNormalizada,
                  horarioInicio: disponibilidade.horarios.isNotEmpty
                      ? disponibilidade.horarios[0]
                      : '08:00',
                  horarioFim: disponibilidade.horarios.length > 1
                      ? disponibilidade.horarios[1]
                      : '15:00',
                );
                alocacoes.add(novaAlocacao);
              }

              if (mounted) {
                setState(() {
                  // Criar nova referência da lista para forçar detecção de mudança
                  alocacoes = List<Alocacao>.from(alocacoes);
                });
              }

              await DisponibilidadeSerieService.modificarGabineteDataSerie(
                serieId: serieId,
                medicoId: _medicoAtual!.id,
                data: dataNormalizada,
                novoGabineteId: novoGabineteId,
                unidade: widget.unidade,
              );

              // Fechar progress bar e mostrar feedback
              if (mounted) {
                setState(() {
                  progressoAlocandoGabinete = 1.0;
                  mensagemAlocandoGabinete = 'Concluído!';
                });
              }
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted) return;
              setState(() {
                _alocandoGabinete = false;
                progressoAlocandoGabinete = 0.0;
                mensagemAlocandoGabinete = 'A alocar gabinete...';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gabinete alterado neste dia com sucesso'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            } else if (escolha == 'serie') {
              // Mudar toda a série: atualizar gabinete da série
              // Flag para indicar se foi realocação (usado depois para fechar progressbar)
              bool foiRealocacao = false;

              // CORREÇÃO: Validar horários antes de atribuir gabinete
              final serieEncontrada = series.firstWhere(
                (s) => s.id == serieId,
                orElse: () => SerieRecorrencia(
                  id: '',
                  medicoId: '',
                  dataInicio: DateTime(1900),
                  tipo: '',
                  horarios: [],
                  gabineteId: null,
                  parametros: {},
                  ativo: false,
                ),
              );

              // Verificar se a série tem horários configurados
              if (serieEncontrada.id.isNotEmpty &&
                  (serieEncontrada.horarios.isEmpty ||
                      serieEncontrada.horarios.length < 2)) {
                if (mounted) {
                  setState(() {
                    _alocandoGabinete = false;
                    progressoAlocandoGabinete = 0.0;
                    mensagemAlocandoGabinete = 'A alocar gabinete...';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Introduza as horas de inicio e fim primeiro!'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                return;
              }

              final gabineteOrigem = alocacaoAtual.gabineteId.isNotEmpty
                  ? alocacaoAtual.gabineteId
                  : serieEncontrada.gabineteId ?? '';

              if (gabineteOrigem.isNotEmpty &&
                  gabineteOrigem != novoGabineteId) {
                // CORREÇÃO: Realocar toda a série de um gabinete para outro
                // Fazer update otimista ANTES de chamar realocar para evitar desaparecimento dos cartões

                // Atualizar progressbar
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 0.2;
                    mensagemAlocandoGabinete = 'A atualizar interface...';
                  });
                }

                // Update otimista: atualizar gabinetes localmente
                final serieIndex = series.indexWhere((s) => s.id == serieId);
                if (serieIndex != -1 && _anoVisualizado != null) {
                  final serieAtual = series[serieIndex];
                  final serieAtualizada = SerieRecorrencia(
                    id: serieAtual.id,
                    medicoId: serieAtual.medicoId,
                    dataInicio: serieAtual.dataInicio,
                    dataFim: serieAtual.dataFim,
                    tipo: serieAtual.tipo,
                    horarios: serieAtual.horarios,
                    gabineteId: novoGabineteId,
                    parametros: serieAtual.parametros,
                    ativo: serieAtual.ativo,
                  );

                  // Carregar exceções para o ano
                  final dataInicio = DateTime(_anoVisualizado!, 1, 1);
                  final dataFim = DateTime(_anoVisualizado! + 1, 1, 1);
                  final excecoes = await SerieService.carregarExcecoes(
                    _medicoAtual!.id,
                    unidade: widget.unidade,
                    dataInicio: dataInicio,
                    dataFim: dataFim,
                    serieId: serieId,
                  );

                  // Gerar alocações localmente
                  final novasAlocacoes = SerieGenerator.gerarAlocacoes(
                    series: [serieAtualizada],
                    excecoes: excecoes,
                    dataInicio: dataInicio,
                    dataFim: dataFim,
                  );

                  if (mounted) {
                    setState(() {
                      // Atualizar série localmente
                      series[serieIndex] = serieAtualizada;

                      // Remover alocações antigas desta série (com gabinete origem)
                      final serieIdPrefix = 'serie_${serieId}_';
                      alocacoes.removeWhere((a) =>
                          a.id.startsWith(serieIdPrefix) &&
                          a.medicoId == _medicoAtual!.id &&
                          a.data.year == _anoVisualizado);

                      // Adicionar novas alocações (com novo gabinete)
                      alocacoes.addAll(novasAlocacoes);

                      // Criar nova referência da lista para forçar detecção de mudança
                      alocacoes = List<Alocacao>.from(alocacoes);
                    });
                  }
                }

                // Atualizar progressbar
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 0.3;
                    mensagemAlocandoGabinete = 'A processar no servidor...';
                  });
                }

                // Agora chamar realocar para sincronizar com o servidor
                if (!mounted) return;
                await RealocacaoSerieService.realocar(
                  medicoId: _medicoAtual!.id,
                  gabineteOrigem: gabineteOrigem,
                  gabineteDestino: novoGabineteId,
                  dataRef: dataNormalizada,
                  tipoSerie: disponibilidade.tipo,
                  alocacoes: alocacoes,
                  unidade: widget.unidade,
                  context: context,
                  onRealocacaoOtimista: null,
                  onAtualizarEstado: () async {
                    // CORREÇÃO: Não recarregar disponibilidades - já fizemos update otimista
                    // Apenas recarregar alocações para garantir sincronização com servidor
                    // #region agent log (COMENTADO - pode ser reativado se necessário)

//                    try {
//                      final logEntry = {
//                        'timestamp': DateTime.now().millisecondsSinceEpoch,
//                        'location':
//                            'cadastro_medicos.dart:onAtualizarEstado-realocacao',
//                        'message':
//                            'onAtualizarEstado chamado - recarregando apenas alocações',
//                        'data': {
//                          'medicoId': _medicoAtual?.id,
//                          'anoVisualizado': _anoVisualizado,
//                          'totalAlocacoesAntes': alocacoes.length,
//                          'hypothesisId': 'P2'
//                        },
//                        'sessionId': 'debug-session',
//                        'runId': 'run1',
//                      };
//                      writeLogToFile(jsonEncode(logEntry));
//                    } catch (e) {}

// #endregion
                    if (_medicoAtual != null &&
                        _anoVisualizado != null &&
                        mounted) {
                      setState(() {
                        progressoAlocandoGabinete = 0.85;
                        mensagemAlocandoGabinete = 'A sincronizar dados...';
                      });
                      // CORREÇÃO: Apenas recarregar alocações, NÃO disponibilidades
                      // As disponibilidades já foram atualizadas otimisticamente
                      await _carregarAlocacoesEGabinetes(_medicoAtual!.id,
                          ano: _anoVisualizado);
                      if (mounted) {
                        setState(() {
                          progressoAlocandoGabinete = 0.95;
                          mensagemAlocandoGabinete = 'A concluir...';
                        });
                      }
                      // NÃO chamar _carregarDisponibilidadesFirestore - já fizemos update otimista
                    }
                  },
                  onProgresso: (progresso, mensagem) {
                    if (mounted) {
                      setState(() {
                        // CORREÇÃO: Mapear progresso linearmente de 0.3 a 0.85 (deixar 0.85-1.0 para recarregar)
                        // Progresso do serviço vai de 0.0 a 1.0
                        progressoAlocandoGabinete = 0.3 + (progresso * 0.55);
                        mensagemAlocandoGabinete = mensagem;
                      });
                    }
                  },
                  onRealocacaoConcluida: () {
                    // CORREÇÃO: Fechar progressbar apenas DEPOIS de tudo estar completo
                    if (mounted) {
                      setState(() {
                        progressoAlocandoGabinete = 1.0;
                        mensagemAlocandoGabinete = 'Concluído!';
                      });
                      // Aguardar um pouco para mostrar 100% antes de fechar
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _alocandoGabinete = false;
                            progressoAlocandoGabinete = 0.0;
                            mensagemAlocandoGabinete = 'A alocar gabinete...';
                          });
                        }
                      });
                    }
                  },
                  verificarSeDataCorrespondeSerie: (data, serie) {
                    // Implementar lógica de verificação baseada no tipo
                    switch (serie.tipo) {
                      case 'Semanal':
                        return data.weekday == serie.dataInicio.weekday;
                      case 'Quinzenal':
                        final diff = data.difference(serie.dataInicio).inDays;
                        return diff >= 0 &&
                            diff % 14 == 0 &&
                            data.weekday == serie.dataInicio.weekday;
                      case 'Mensal':
                        // Verificar se é o mesmo dia da semana e ocorrência no mês
                        return data.weekday == serie.dataInicio.weekday;
                      case 'Consecutivo':
                        final numeroDias =
                            serie.parametros['numeroDias'] as int? ?? 5;
                        final diff = data.difference(serie.dataInicio).inDays;
                        return diff >= 0 && diff < numeroDias;
                      default:
                        return true;
                    }
                  },
                );
              } else {
                // Se não há gabinete origem ou é o mesmo, apenas atualizar a série
                // CORREÇÃO: Para atribuição inicial (sem gabinete origem), fazer update otimista ANTES de chamar alocarSerie
                // para que os cartões não desapareçam e apenas o campo gabinete seja atualizado

                // Atualizar progressbar
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 0.2;
                    mensagemAlocandoGabinete = 'A atualizar interface...';
                  });
                }

                // CORREÇÃO: Atribuição inicial - fazer update otimista ANTES de chamar alocarSerie
                // 1. Atualizar série localmente com novo gabineteId
                // 2. Carregar exceções para o ano
                // 3. Gerar alocações localmente usando SerieGenerator
                // 4. Adicionar alocações à lista local
                // 5. NÃO recarregar tudo - apenas atualizar o necessário

                final serieIndex = series.indexWhere((s) => s.id == serieId);
                if (serieIndex != -1) {
                  // Atualizar série localmente
                  final serieAtualizada = SerieRecorrencia(
                    id: series[serieIndex].id,
                    medicoId: series[serieIndex].medicoId,
                    dataInicio: series[serieIndex].dataInicio,
                    dataFim: series[serieIndex].dataFim,
                    tipo: series[serieIndex].tipo,
                    horarios: series[serieIndex].horarios,
                    gabineteId: novoGabineteId,
                    parametros: series[serieIndex].parametros,
                    ativo: series[serieIndex].ativo,
                  );

                  if (_anoVisualizado != null) {
                    // Atualizar progressbar
                    if (mounted) {
                      setState(() {
                        progressoAlocandoGabinete = 0.3;
                        mensagemAlocandoGabinete = 'A carregar exceções...';
                      });
                    }

                    // Carregar exceções para o ano
                    final dataInicio = DateTime(_anoVisualizado!, 1, 1);
                    final dataFim = DateTime(_anoVisualizado! + 1, 1, 1);
                    final excecoes = await SerieService.carregarExcecoes(
                      _medicoAtual!.id,
                      unidade: widget.unidade,
                      dataInicio: dataInicio,
                      dataFim: dataFim,
                      serieId: serieId,
                    );

                    // Atualizar progressbar
                    if (mounted) {
                      setState(() {
                        progressoAlocandoGabinete = 0.4;
                        mensagemAlocandoGabinete = 'A gerar alocações...';
                      });
                    }

                    // Gerar alocações localmente
                    final novasAlocacoes = SerieGenerator.gerarAlocacoes(
                      series: [serieAtualizada],
                      excecoes: excecoes,
                      dataInicio: dataInicio,
                      dataFim: dataFim,
                    );

                    if (mounted) {
                      setState(() {
                        // Atualizar série na lista local
                        series[serieIndex] = serieAtualizada;

                        // Remover alocações antigas desta série (se houver)
                        final serieIdPrefix = 'serie_${serieId}_';
                        alocacoes.removeWhere((a) =>
                            a.id.startsWith(serieIdPrefix) &&
                            a.medicoId == _medicoAtual!.id &&
                            a.data.year == _anoVisualizado);

                        // Adicionar novas alocações
                        alocacoes.addAll(novasAlocacoes);

                        // Criar nova referência da lista para forçar detecção de mudança
                        alocacoes = List<Alocacao>.from(alocacoes);
                      });
                    }
                  } else {
                    // Se não há ano visualizado, apenas atualizar a série localmente
                    if (mounted) {
                      setState(() {
                        series[serieIndex] = serieAtualizada;
                      });
                    }
                  }
                }

                // Atualizar progressbar
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 0.5;
                    mensagemAlocandoGabinete = 'A salvar no servidor...';
                  });
                }

                // CORREÇÃO: Antes de alocar a série, remover/atualizar exceções com gabineteId: null
                // para datas >= dataNormalizada (se o utilizador está a alocar "a partir de uma data")
                // Essas exceções foram criadas quando desalocamos "a partir de uma data"
                if (_anoVisualizado != null) {
                  final dataFimSerie = serieEncontrada.dataFim ??
                      DateTime(_anoVisualizado! + 1, 12, 31);

                  // Carregar exceções para datas >= dataNormalizada
                  final excecoesFuturas = await SerieService.carregarExcecoes(
                    _medicoAtual!.id,
                    unidade: widget.unidade,
                    dataInicio: dataNormalizada,
                    dataFim: dataFimSerie,
                    serieId: serieId,
                    forcarServidor: true,
                  );

                  // Função para verificar se data corresponde à série
                  bool verificarSeDataCorrespondeSerie(
                      DateTime data, SerieRecorrencia serie) {
                    switch (serie.tipo) {
                      case 'Semanal':
                        return data.weekday == serie.dataInicio.weekday;
                      case 'Quinzenal':
                        final diff = data.difference(serie.dataInicio).inDays;
                        return diff >= 0 &&
                            diff % 14 == 0 &&
                            data.weekday == serie.dataInicio.weekday;
                      case 'Mensal':
                        return data.weekday == serie.dataInicio.weekday;
                      case 'Consecutivo':
                        final numeroDias =
                            serie.parametros['numeroDias'] as int? ?? 5;
                        final diff = data.difference(serie.dataInicio).inDays;
                        return diff >= 0 && diff < numeroDias;
                      default:
                        return true;
                    }
                  }

                  // Atualizar exceções com gabineteId: null para ter o novo gabineteId
                  DateTime dataAtual = dataNormalizada;
                  while (!dataAtual.isAfter(dataFimSerie)) {
                    if (verificarSeDataCorrespondeSerie(
                        dataAtual, serieEncontrada)) {
                      final excecaoExistente = excecoesFuturas.firstWhere(
                        (e) =>
                            e.serieId == serieId &&
                            e.data.year == dataAtual.year &&
                            e.data.month == dataAtual.month &&
                            e.data.day == dataAtual.day &&
                            !e.cancelada,
                        orElse: () => ExcecaoSerie(
                          id: '',
                          serieId: '',
                          data: DateTime(1900, 1, 1),
                        ),
                      );

                      // Se há exceção com gabineteId: null, atualizar para o novo gabineteId
                      if (excecaoExistente.id.isNotEmpty &&
                          excecaoExistente.gabineteId == null) {
                        await DisponibilidadeSerieService
                            .modificarGabineteDataSerie(
                          serieId: serieId,
                          medicoId: _medicoAtual!.id,
                          data: dataAtual,
                          novoGabineteId: novoGabineteId,
                          unidade: widget.unidade,
                        );
                      }
                    }
                    dataAtual = dataAtual.add(const Duration(days: 1));
                  }
                }

                // Agora chamar alocarSerie para salvar no Firestore
                await DisponibilidadeSerieService.alocarSerie(
                  serieId: serieId,
                  medicoId: _medicoAtual!.id,
                  gabineteId: novoGabineteId,
                  unidade: widget.unidade,
                );

                // Atualizar progressbar
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 0.9;
                    mensagemAlocandoGabinete = 'A concluir...';
                  });
                }
              }

              // Invalidar cache após mudar
              AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
              AlocacaoMedicosLogic.invalidateCacheFromDate(
                  DateTime(dataNormalizada.year, 1, 1));

              // CORREÇÃO: Para mudança de cartão único (escolha == '1dia'),
              // não recarregar tudo porque já fizemos atualização otimista localmente
              // Para mudança de série, apenas recarregar se foi realocação (gabinete origem diferente)
              // Se foi apenas atribuição (sem gabinete origem), não recarregar porque já fizemos update otimista
              // O código de atribuição inicial já foi movido para ANTES de chamar alocarSerie (linha 2706)
              // para que os cartões não desapareçam e apenas o campo gabinete seja atualizado
              // Para realocação, o progressbar será fechado no callback onRealocacaoConcluida (linha 2769)

              // Só fechar progressbar aqui se NÃO foi realocação (atribuição inicial ou 1dia)
              // Para realocação, o progressbar será fechado no callback onRealocacaoConcluida dentro do bloco de realocação
              if (!foiRealocacao) {
                if (mounted) {
                  setState(() {
                    progressoAlocandoGabinete = 1.0;
                    mensagemAlocandoGabinete = 'Concluído!';
                  });
                  // Aguardar um pouco para mostrar 100% antes de fechar
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted) {
                    setState(() {
                      _alocandoGabinete = false;
                      progressoAlocandoGabinete = 0.0;
                      mensagemAlocandoGabinete = 'A alocar gabinete...';
                    });
                  }
                }
              }
              // Para realocação, o progressbar será fechado no callback onRealocacaoConcluida
            }
          }
        }
      }

      // Se chegou aqui e não processou como série, tratar como disponibilidade única
      // (Se não é série OU é série mas não encontrou o ID para processar)
      if (!isSerie || serieId == null || serieId.isEmpty) {
        if (novoGabineteId == null) {
          // Desalocar: buscar e remover alocação
          if (mounted) {
            setState(() {
              progressoAlocandoGabinete = 0.3;
              mensagemAlocandoGabinete = 'A desalocar...';
            });
          }

          final alocacaoAtual = alocacoes.firstWhere(
            (a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              return a.medicoId == _medicoAtual!.id && aDate == dataNormalizada;
            },
            orElse: () => Alocacao(
              id: '',
              medicoId: '',
              gabineteId: '',
              data: DateTime(1900),
              horarioInicio: '',
              horarioFim: '',
            ),
          );

          if (alocacaoAtual.id.isNotEmpty) {
            // CORREÇÃO: Atualizar UI imediatamente - remover alocação da lista local
            // ANTES de chamar o serviço, para evitar rebuild completo
            alocacoes.removeWhere((a) {
              final aDate = DateTime(a.data.year, a.data.month, a.data.day);
              return a.medicoId == _medicoAtual!.id && aDate == dataNormalizada;
            });

            if (mounted) {
              setState(() {
                // Criar nova referência da lista para forçar detecção de mudança
                alocacoes = List<Alocacao>.from(alocacoes);
              });
            }

            // Remover alocação do Firestore
            await AlocacaoMedicosLogic.desalocarMedicoDiaUnico(
              selectedDate: dataNormalizada,
              medicoId: _medicoAtual!.id,
              alocacoes: alocacoes,
              disponibilidades: disponibilidades,
              medicos: [_medicoAtual!],
              medicosDisponiveis: [],
              onAlocacoesChanged: () {
                // Já atualizamos a UI localmente acima, não precisa fazer nada aqui
              },
              unidade: widget.unidade,
            );
          }

          // Invalidar cache após desalocar
          AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
          AlocacaoMedicosLogic.invalidateCacheFromDate(
              DateTime(dataNormalizada.year, 1, 1));

          // CORREÇÃO: Não recarregar tudo - já atualizamos a UI localmente
          // Apenas fechar progress bar e mostrar mensagem
          if (mounted) {
            setState(() {
              progressoAlocandoGabinete = 1.0;
              mensagemAlocandoGabinete = 'Concluído!';
            });
          }

          // Aguardar um pouco para mostrar 100% antes de esconder
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          setState(() {
            _alocandoGabinete = false;
            progressoAlocandoGabinete = 0.0;
            mensagemAlocandoGabinete = 'A alocar gabinete...';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gabinete removido com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Alocar: criar alocação única
          if (mounted) {
            setState(() {
              progressoAlocandoGabinete = 0.3;
              mensagemAlocandoGabinete = 'A alocar gabinete...';
            });
          }

          // Invalidar cache antes de alocar
          AlocacaoMedicosLogic.invalidateCacheForDay(dataNormalizada);
          AlocacaoMedicosLogic.invalidateCacheFromDate(
              DateTime(dataNormalizada.year, 1, 1));

          // CORREÇÃO: alocarMedico já adiciona a alocação localmente,
          // então não precisamos recarregar tudo - apenas atualizar a UI via onAlocacoesChanged
          await AlocacaoMedicosLogic.alocarMedico(
            selectedDate: dataNormalizada,
            medicoId: _medicoAtual!.id,
            gabineteId: novoGabineteId,
            alocacoes: alocacoes,
            disponibilidades: disponibilidades,
            onAlocacoesChanged: () {
              if (mounted) {
                setState(() {
                  // Criar novas referências das listas para forçar detecção de mudança
                  alocacoes = List<Alocacao>.from(alocacoes);
                  disponibilidades =
                      List<Disponibilidade>.from(disponibilidades);
                });
              }
            },
            horariosForcados: disponibilidade.horarios,
            unidade: widget.unidade,
          );

          // CORREÇÃO: Não recarregar tudo - alocarMedico já atualizou a lista localmente
          // Apenas fechar progress bar e mostrar mensagem
          if (mounted) {
            setState(() {
              progressoAlocandoGabinete = 1.0;
              mensagemAlocandoGabinete = 'Concluído!';
            });
          }

          // Aguardar um pouco para mostrar 100% antes de esconder
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          setState(() {
            _alocandoGabinete = false;
            progressoAlocandoGabinete = 0.0;
            mensagemAlocandoGabinete = 'A alocar gabinete...';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gabinete alocado com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao alterar gabinete: $e');
      if (mounted) {
        setState(() {
          _alocandoGabinete = false;
          progressoAlocandoGabinete = 0.0;
          mensagemAlocandoGabinete = 'A alocar gabinete...';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar gabinete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Lê as disponibilidades no banco para este médico e ordena por data
  // Future<void> _carregarDisponibilidadesSalvas(String medicoId) async {
  //   final dbDisponibilidades =
  //       await DatabaseHelper.buscarDisponibilidades(medicoId);
  //   setState(() {
  //     disponibilidades = dbDisponibilidades;
  //     // **Ordena** por data para ficar sempre cronológico
  //     disponibilidades.sort((a, b) => a.data.compareTo(b.data));
  //   });
  //   _atualizarDiasSelecionados();
  // }

  /// Adiciona data(s) no calendário (única, semanal, quinzenal, mensal), depois **ordena**.
  /// Agora cria séries de recorrência para tipos recorrentes
  Future<void> _adicionarData(DateTime date, String tipo) async {
    // Se for tipo recorrente, criar série ao invés de cartões individuais
    if (tipo != 'Única' && !tipo.startsWith('Consecutivo:')) {
      final resultado =
          await DisponibilidadeDataGestaoService.criarSerieRecorrente(
        context,
        date,
        tipo,
        _medicoId,
        widget.unidade,
      );

      if (resultado['sucesso'] == true) {
        final serieCriada = resultado['serie'] as SerieRecorrencia;

        setState(() {
          series.add(serieCriada);
        });

        DisponibilidadeDataGestaoService.adicionarDisponibilidadesAListas(
          resultado['disponibilidades'] as List<Disponibilidade>,
          disponibilidades,
          diasSelecionados,
        );

        // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
        // Isso garante que quando o utilizador navega para qualquer dia da série,
        // os dados serão recarregados do servidor e estarão atualizados
        // NOTA: invalidateCacheParaSerie já é chamado dentro de criarSerieRecorrente,
        // mas garantimos aqui também para máxima confiabilidade
        AlocacaoMedicosLogic.invalidateCacheParaSerie(serieCriada,
            unidade: widget.unidade);

        // CORREÇÃO: Recarregar alocações após criar nova série para evitar usar cache de série antiga
        // A nova série não tem gabinete (gabineteId: null), então não deve aparecer com gabinetes da série apagada
        if (_medicoAtual != null && _anoVisualizado != null) {
          await _carregarAlocacoesEGabinetes(_medicoAtual!.id,
              ano: _anoVisualizado);
        }

        _verificarMudancas();
      }
    } else if (tipo.startsWith('Consecutivo:')) {
      final resultado =
          await DisponibilidadeDataGestaoService.criarSerieConsecutiva(
        context,
        date,
        tipo,
        _medicoId,
        widget.unidade,
      );

      if (resultado['sucesso'] == true) {
        final serieCriada = resultado['serie'] as SerieRecorrencia;

        setState(() {
          series.add(serieCriada);
        });

        DisponibilidadeDataGestaoService.adicionarDisponibilidadesAListas(
          resultado['disponibilidades'] as List<Disponibilidade>,
          disponibilidades,
          diasSelecionados,
        );

        // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
        // Isso garante que quando o utilizador navega para qualquer dia da série,
        // os dados serão recarregados do servidor e estarão atualizados
        // NOTA: invalidateCacheParaSerie já é chamado dentro de criarSerieConsecutiva,
        // mas garantimos aqui também para máxima confiabilidade
        AlocacaoMedicosLogic.invalidateCacheParaSerie(serieCriada,
            unidade: widget.unidade);

        // CORREÇÃO: Recarregar alocações após criar nova série para evitar usar cache de série antiga
        // A nova série não tem gabinete (gabineteId: null), então não deve aparecer com gabinetes da série apagada
        if (_medicoAtual != null && _anoVisualizado != null) {
          await _carregarAlocacoesEGabinetes(_medicoAtual!.id,
              ano: _anoVisualizado);
        }

        _verificarMudancas();
      }
    } else {
      // Única: criar cartão individual (compatibilidade)
      final geradas =
          DisponibilidadeDataGestaoService.criarDisponibilidadesUnicas(
        date,
        tipo,
        _medicoId,
      );

      bool adicionouNova = false;
      for (final novaDisp in geradas) {
        if (!diasSelecionados.any((d) =>
            d.year == novaDisp.data.year &&
            d.month == novaDisp.data.month &&
            d.day == novaDisp.data.day)) {
          disponibilidades.add(novaDisp);
          diasSelecionados.add(novaDisp.data);
          adicionouNova = true;
        }
      }

      if (adicionouNova) {
        disponibilidades.sort((a, b) => a.data.compareTo(b.data));
        setState(() {});

        _verificarMudancas();

        if (!_houveMudancas) {
          final temUnicasNovas =
              CadastroMedicosHelper.filtrarDisponibilidadesUnicas(
                      disponibilidades, _medicoId)
                  .any((d) => !_disponibilidadesOriginal.any((orig) =>
                      orig.id == d.id &&
                      orig.data.year == d.data.year &&
                      orig.data.month == d.data.month &&
                      orig.data.day == d.data.day &&
                      CadastroMedicosHelper.listasIguais(
                          orig.horarios, d.horarios)));

          if (temUnicasNovas) {
            setState(() {
              _houveMudancas = true;
            });
          }
        }
      }
    }
  }

  /// Remove data(s) do calendário, depois ordena a lista
  Future<void> _removerData(DateTime date, {bool removeSerie = false}) async {
    // Encontrar a disponibilidade na data antes de remover
    final disponibilidadeNaData = disponibilidades.firstWhere(
      (d) =>
          d.data.year == date.year &&
          d.data.month == date.month &&
          d.data.day == date.day,
      orElse: () => Disponibilidade(
        id: '',
        medicoId: _medicoId,
        data: date,
        horarios: [],
        tipo: 'Única',
      ),
    );

    final dataNormalizada = DateTime(date.year, date.month, date.day);
    List<ExcecaoSerie> excecoesCanceladasParaAtualizar = [];
    String? serieIdExcecoesParaAtualizar;

    // Se está removendo a série inteira, encontrar e remover do Firestore
    SerieRecorrencia? serieParaRemover;
    if (removeSerie) {
      // Se a disponibilidade é de uma série, encontrar e remover a série do Firestore
      if (disponibilidadeNaData.tipo != 'Única') {
        final serieEncontrada =
            DisponibilidadeDataGestaoService.encontrarSeriePorDisponibilidade(
          disponibilidadeNaData,
          series,
          date,
        );

        if (serieEncontrada != null && serieEncontrada.id.isNotEmpty) {
          serieParaRemover = serieEncontrada;
          final removerSeriePorCompleto =
              !dataNormalizada.isAfter(serieEncontrada.dataInicio);

          if (removerSeriePorCompleto) {
            final sucesso =
                await DisponibilidadeDataGestaoService.removerSerieDoFirestore(
              context,
              serieEncontrada,
              _medicoId,
              widget.unidade,
            );

            if (sucesso) {
              setState(() {
                series.removeWhere((s) => s.id == serieEncontrada.id);

                // CORREÇÃO: Remover alocações locais relacionadas à série apagada
                // As alocações de séries têm ID no formato 'serie_${serieId}_${dataKey}'
                final serieIdPrefix = 'serie_${serieEncontrada.id}_';
                alocacoes.removeWhere((a) => a.id.startsWith(serieIdPrefix));
              });
            }
          } else {
            final dataFimEncerramento =
                dataNormalizada.subtract(const Duration(days: 1));
            final serieAtualizada = SerieRecorrencia(
              id: serieEncontrada.id,
              medicoId: serieEncontrada.medicoId,
              dataInicio: serieEncontrada.dataInicio,
              dataFim: dataFimEncerramento,
              tipo: serieEncontrada.tipo,
              horarios: serieEncontrada.horarios,
              gabineteId: serieEncontrada.gabineteId,
              parametros: serieEncontrada.parametros,
              ativo: serieEncontrada.ativo,
            );

            await SerieService.salvarSerie(serieAtualizada,
                unidade: widget.unidade);

            setState(() {
              final index =
                  series.indexWhere((s) => s.id == serieEncontrada.id);
              if (index != -1) {
                series[index] = serieAtualizada;
              }

              // Remover alocações locais da série a partir da data selecionada
              final serieIdPrefix = 'serie_${serieEncontrada.id}_';
              alocacoes.removeWhere((a) {
                if (!a.id.startsWith(serieIdPrefix)) return false;
                final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                return !aDate.isBefore(dataNormalizada);
              });
            });
          }

          // Invalidar cache e recarregar alocações após atualizar série
          if (_medicoAtual != null && _anoVisualizado != null) {
            AlocacaoMedicosLogic.invalidateCacheFromDate(
                DateTime(_anoVisualizado!, 1, 1));
            await _carregarAlocacoesEGabinetes(_medicoAtual!.id,
                ano: _anoVisualizado);
          }
        }
      }
    } else {
      // Removendo apenas uma data (não a série inteira)
      // Se for uma disponibilidade única, remover do Firestore
      if (disponibilidadeNaData.tipo == 'Única' &&
          widget.unidade != null &&
          disponibilidadeNaData.id.isNotEmpty) {
        try {
          await AlocacaoDisponibilidadeRemocaoService
              .removerAlocacoesEDisponibilidadesPorData(
            widget.unidade!.id,
            _medicoId,
            date,
          );
          debugPrint(
              '✅ Disponibilidade única removida do Firestore: ${disponibilidadeNaData.id}, data: ${date.day}/${date.month}/${date.year}');
        } catch (e) {
          debugPrint(
              '❌ Erro ao remover disponibilidade única do Firestore: $e');
          // Continuar mesmo se houver erro - ainda vamos remover da lista local
        }
      } else if (disponibilidadeNaData.id.isNotEmpty) {
        final serieEncontrada =
            DisponibilidadeDataGestaoService.encontrarSeriePorDisponibilidade(
          disponibilidadeNaData,
          series,
          date,
        );

        if (serieEncontrada != null && serieEncontrada.id.isNotEmpty) {
          try {
            excecoesCanceladasParaAtualizar =
                await DisponibilidadeSerieService.cancelarDataSerie(
              serieId: serieEncontrada.id,
              medicoId: _medicoId,
              data: dataNormalizada,
              unidade: widget.unidade,
            );
            serieIdExcecoesParaAtualizar = serieEncontrada.id;

            if (widget.unidade != null) {
              await AlocacaoDisponibilidadeRemocaoService
                  .removerAlocacoesEDisponibilidadesPorData(
                widget.unidade!.id,
                _medicoId,
                dataNormalizada,
              );
            }

            debugPrint(
                '✅ Data de série cancelada no Firestore: série=${serieEncontrada.id}, data: ${date.day}/${date.month}/${date.year}');
          } catch (e) {
            debugPrint('❌ Erro ao cancelar data de série no Firestore: $e');
            // Continuar com a remoção local para manter a resposta da UI.
          }
        }
      }
    }

    setState(() {
      if (serieIdExcecoesParaAtualizar != null) {
        excecoes.removeWhere(
          (e) =>
              e.serieId == serieIdExcecoesParaAtualizar &&
              e.data.year == dataNormalizada.year &&
              e.data.month == dataNormalizada.month &&
              e.data.day == dataNormalizada.day,
        );
        excecoes.addAll(excecoesCanceladasParaAtualizar);
      }

      final removerComoSerie = removeSerie && serieParaRemover != null;
      disponibilidades = removerDisponibilidade(
        disponibilidades,
        dataNormalizada,
        removeSerie: removerComoSerie,
        serie: serieParaRemover,
      );
      // Re-atualiza a lista de dias
      diasSelecionados = disponibilidades.map((d) => d.data).toList();

      // **Ordena** novamente, só para garantir
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    });

    // Verifica mudanças após remover dados
    _verificarMudancas();

    // Invalidar cache de séries para garantir que não apareçam ao recarregar
    if (removeSerie && _medicoAtual != null) {
      // AlocacaoMedicosLogic.invalidateCacheFromDate(date);
    }
  }

  /// Mostra diálogo para encerrar todas as séries a partir de uma data
  Future<void> _mostrarDialogoEncerrarSeries() async {
    DateTime? dataEncerramento;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Encerrar Todas as Séries'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecione a data a partir da qual todas as séries serão encerradas. '
                    'O histórico anterior será mantido.',
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      dataEncerramento != null
                          ? 'Data: ${DateFormat('dd/MM/yyyy').format(dataEncerramento!)}'
                          : 'Selecionar data',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final data = await showDatePickerCustomizado(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (data != null) {
                        setState(() {
                          dataEncerramento = data;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: dataEncerramento != null
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true && dataEncerramento != null) {
      await _encerrarTodasSeries(dataEncerramento!);
    }
  }

  /// Encerra todas as séries a partir de uma data específica
  Future<void> _encerrarTodasSeries(DateTime dataEncerramento) async {
    try {
      int seriesEncerradas = 0;

      for (final serie in series) {
        // Só encerra séries que ainda estão ativas e não têm data fim
        if (serie.ativo &&
            (serie.dataFim == null ||
                (serie.dataFim != null &&
                    serie.dataFim!.isAfter(dataEncerramento)))) {
          final dataFimEncerramento = dataEncerramento
              .subtract(const Duration(days: 1)); // Encerra no dia anterior
          final serieAtualizada = SerieRecorrencia(
            id: serie.id,
            medicoId: serie.medicoId,
            dataInicio: serie.dataInicio,
            dataFim: dataFimEncerramento,
            tipo: serie.tipo,
            horarios: serie.horarios,
            gabineteId: serie.gabineteId,
            parametros: serie.parametros,
            ativo: serie.ativo,
          );

          // Atualizar na lista local
          final index = series.indexWhere((s) => s.id == serie.id);
          if (index != -1) {
            setState(() {
              series[index] = serieAtualizada;
            });
          }

          seriesEncerradas++;
        }
      }

      if (seriesEncerradas > 0) {
        _verificarMudancas();

        // Recarregar disponibilidades para refletir o encerramento
        if (_medicoAtual != null && _anoVisualizado != null) {
          await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
              ano: _anoVisualizado);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '$seriesEncerradas série(s) encerrada(s) a partir de ${DateFormat('dd/MM/yyyy').format(dataEncerramento)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma série ativa para encerrar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encerrar séries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mostra diálogo para transformar/substituir uma série
  /// Permite encerrar a série atual e criar uma nova com tipo/frequência diferente
  Future<void> _mostrarDialogoTransformarSerie(
      SerieRecorrencia serieAtual) async {
    DateTime? dataEncerramento;
    DateTime? dataNovaSerie;
    String? novoTipo;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Transformar/Substituir Série'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Série atual: ${serieAtual.tipo}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                        'Início: ${DateFormat('dd/MM/yyyy').format(serieAtual.dataInicio)}'),
                    const SizedBox(height: 16),
                    const Text(
                      '1. Selecione quando encerrar a série atual:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        dataEncerramento != null
                            ? 'Encerrar em: ${DateFormat('dd/MM/yyyy').format(dataEncerramento!)}'
                            : 'Selecionar data de encerramento',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final data = await showDatePickerCustomizado(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: serieAtual.dataInicio,
                          lastDate: DateTime(2100),
                        );
                        if (data != null) {
                          setState(() {
                            dataEncerramento = data;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Selecione o novo tipo de série:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: novoTipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo da nova série',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Semanal', child: Text('Semanal')),
                        DropdownMenuItem(
                            value: 'Quinzenal', child: Text('Quinzenal')),
                        DropdownMenuItem(
                            value: 'Mensal', child: Text('Mensal')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          novoTipo = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '3. Selecione quando começar a nova série:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        dataNovaSerie != null
                            ? 'Iniciar em: ${DateFormat('dd/MM/yyyy').format(dataNovaSerie!)}'
                            : 'Selecionar data de início',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final data = await showDatePickerCustomizado(
                          context: context,
                          initialDate: dataEncerramento ?? DateTime.now(),
                          firstDate: dataEncerramento ?? DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (data != null) {
                          setState(() {
                            dataNovaSerie = data;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: dataEncerramento != null &&
                          novoTipo != null &&
                          dataNovaSerie != null &&
                          dataNovaSerie!.isAfter(dataEncerramento!)
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true &&
        dataEncerramento != null &&
        novoTipo != null &&
        dataNovaSerie != null) {
      await _transformarSerie(
          serieAtual, dataEncerramento!, novoTipo!, dataNovaSerie!);
    }
  }

  /// Transforma uma série: encerra a atual e cria uma nova
  Future<void> _transformarSerie(
    SerieRecorrencia serieAtual,
    DateTime dataEncerramento,
    String novoTipo,
    DateTime dataNovaSerie,
  ) async {
    try {
      // 1. Encerrar série atual
      final dataFimEncerramento =
          dataEncerramento.subtract(const Duration(days: 1));
      final serieEncerrada = SerieRecorrencia(
        id: serieAtual.id,
        medicoId: serieAtual.medicoId,
        dataInicio: serieAtual.dataInicio,
        dataFim: dataFimEncerramento,
        tipo: serieAtual.tipo,
        horarios: serieAtual.horarios,
        gabineteId: serieAtual.gabineteId,
        parametros: serieAtual.parametros,
        ativo: serieAtual.ativo,
      );

      // Atualizar na lista local
      final index = series.indexWhere((s) => s.id == serieAtual.id);
      if (index != -1) {
        setState(() {
          series[index] = serieEncerrada;
        });
      }

      // 2. Criar nova série
      final novaSerie = await DisponibilidadeSerieService.criarSerie(
        medicoId: _medicoId,
        dataInicial: dataNovaSerie,
        tipo: novoTipo,
        horarios: serieAtual.horarios, // Manter os mesmos horários
        unidade: widget.unidade,
        dataFim: null, // Nova série infinita
      );

      setState(() {
        series.add(novaSerie);
      });

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que ambas as séries afetam
      // Série encerrada e nova série
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieEncerrada,
          unidade: widget.unidade);
      AlocacaoMedicosLogic.invalidateCacheParaSerie(novaSerie,
          unidade: widget.unidade);

      // Gerar cartões visuais para a nova série
      final geradas = criarDisponibilidadesSerie(
        dataNovaSerie,
        novoTipo,
        medicoId: _medicoId,
        limitarAoAno: true,
      );

      for (final novaDisp in geradas) {
        if (!diasSelecionados.any((d) =>
            d.year == novaDisp.data.year &&
            d.month == novaDisp.data.month &&
            d.day == novaDisp.data.day)) {
          disponibilidades.add(novaDisp);
          diasSelecionados.add(novaDisp.data);
        }
      }

      disponibilidades.sort((a, b) => a.data.compareTo(b.data));

      // Recarregar disponibilidades
      if (_medicoAtual != null && _anoVisualizado != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      _verificarMudancas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Série transformada: ${serieAtual.tipo} encerrada em ${DateFormat('dd/MM/yyyy').format(dataEncerramento)}, '
              'nova série $novoTipo iniciada em ${DateFormat('dd/MM/yyyy').format(dataNovaSerie)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao transformar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Encerra uma série específica
  Future<void> _encerrarSerie(SerieRecorrencia serie) async {
    DateTime? dataEncerramento;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Encerrar Série'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Série: ${serie.tipo}'),
                  Text(
                      'Início: ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                  const SizedBox(height: 16),
                  const Text('Selecione a data de encerramento:'),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(
                      dataEncerramento != null
                          ? 'Data: ${DateFormat('dd/MM/yyyy').format(dataEncerramento!)}'
                          : 'Selecionar data',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final data = await showDatePickerCustomizado(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: serie.dataInicio,
                        lastDate: DateTime(2100),
                      );
                      if (data != null) {
                        setState(() {
                          dataEncerramento = data;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: dataEncerramento != null
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == true && dataEncerramento != null) {
      try {
        final dataFimEncerramento = dataEncerramento!
            .subtract(const Duration(days: 1)); // Encerra no dia anterior
        final serieAtualizada = SerieRecorrencia(
          id: serie.id,
          medicoId: serie.medicoId,
          dataInicio: serie.dataInicio,
          dataFim: dataFimEncerramento,
          tipo: serie.tipo,
          horarios: serie.horarios,
          gabineteId: serie.gabineteId,
          parametros: serie.parametros,
          ativo: serie.ativo,
        );

        // Atualizar na lista local
        final index = series.indexWhere((s) => s.id == serie.id);
        if (index != -1) {
          setState(() {
            series[index] = serieAtualizada;
          });
        }

        _verificarMudancas();

        // Recarregar disponibilidades
        if (widget.medico != null && _anoVisualizado != null) {
          await _carregarDisponibilidadesFirestore(widget.medico!.id,
              ano: _anoVisualizado);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Série encerrada a partir de ${DateFormat('dd/MM/yyyy').format(dataEncerramento!)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao encerrar série: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Cria exceção de período geral (remove todos os cartões no período, independente das séries)
  Future<void> _criarExcecaoPeriodoGeral(
      DateTime dataInicio, DateTime dataFim) async {
    // Iniciar barra de progresso
    if (mounted) {
      setState(() {
        _criandoExcecao = true;
        progressoCriandoExcecao = 0.0;
        mensagemCriandoExcecao = 'A iniciar...';
      });
    }

    try {
      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.2;
          mensagemCriandoExcecao = 'A criar exceções...';
        });
      }
      // Usar serviço para criar exceções
      await ExcecaoSerieCriacaoService.criarExcecoesParaPeriodoGeral(
        series,
        excecoes,
        dataInicio,
        dataFim,
        _medicoId,
        (excecao) async {
          // Salvar no Firestore
          await SerieService.salvarExcecao(excecao, _medicoId,
              unidade: widget.unidade);

          setState(() {
            final index = excecoes.indexWhere((e) => e.id == excecao.id);
            if (index == -1) {
              excecoes.add(excecao);
            } else {
              excecoes[index] = excecao;
            }
          });
        },
      );

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.5;
          mensagemCriandoExcecao = 'A remover alocações...';
        });
      }
      // Remover alocações e disponibilidades do Firestore para as datas do período
      if (widget.unidade != null && _medicoAtual != null) {
        await AlocacaoDisponibilidadeRemocaoService
            .removerAlocacoesEDisponibilidades(
          widget.unidade!.id,
          _medicoAtual!.id,
          dataInicio,
          dataFim,
        );

        // Remover também da lista local de disponibilidades
        DateTime dataAtual = dataInicio;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          final inicio =
              DateTime(dataAtual.year, dataAtual.month, dataAtual.day);
          setState(() {
            disponibilidades.removeWhere((d) =>
                d.tipo == 'Única' &&
                d.data.year == inicio.year &&
                d.data.month == inicio.month &&
                d.data.day == inicio.day);
            _disponibilidadesOriginal.removeWhere((d) =>
                d.tipo == 'Única' &&
                d.data.year == inicio.year &&
                d.data.month == inicio.month &&
                d.data.day == inicio.day);
          });
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.7;
          mensagemCriandoExcecao = 'A processar...';
        });
      }
      // CORREÇÃO: Aguardar mais tempo para garantir que o Firestore processou todas as remoções
      // e que a Cloud Function teve tempo de atualizar a vista diária
      await Future.delayed(const Duration(milliseconds: 1500));

      // Invalidar cache de séries para este médico e ano
      if (widget.unidade != null && _medicoAtual != null) {}

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.9;
          mensagemCriandoExcecao = 'A recarregar disponibilidades...';
        });
      }
      // Recarregar disponibilidades para refletir as exceções
      if (widget.unidade != null && _medicoAtual != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      _verificarMudancas();

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 1.0;
          mensagemCriandoExcecao = 'Concluído!';
        });
        // Aguardar um pouco para mostrar 100% antes de esconder
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _criandoExcecao = false;
          progressoCriandoExcecao = 0.0;
          mensagemCriandoExcecao = 'A criar exceção...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _criandoExcecao = false;
          progressoCriandoExcecao = 0.0;
          mensagemCriandoExcecao = 'A criar exceção...';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar exceção de período: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cria exceção para cancelar um período de uma série (ex: férias)
  Future<void> _criarExcecaoPeriodo(
      SerieRecorrencia serie, DateTime dataInicio, DateTime dataFim) async {
    // Iniciar barra de progresso
    if (mounted) {
      setState(() {
        _criandoExcecao = true;
        progressoCriandoExcecao = 0.0;
        mensagemCriandoExcecao = 'A iniciar...';
      });
    }

    try {
      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.2;
          mensagemCriandoExcecao = 'A criar exceções...';
        });
      }
      // Usar serviço para criar exceções
      await ExcecaoSerieCriacaoService.criarExcecoesParaPeriodoSerie(
        serie,
        excecoes,
        dataInicio,
        dataFim,
        _medicoId,
        (excecao) async {
          // Salvar no Firestore
          await SerieService.salvarExcecao(excecao, _medicoId,
              unidade: widget.unidade);

          setState(() {
            final index = excecoes.indexWhere((e) => e.id == excecao.id);
            if (index == -1) {
              excecoes.add(excecao);
            } else {
              excecoes[index] = excecao;
            }
          });
        },
      );

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.5;
          mensagemCriandoExcecao = 'A remover alocações...';
        });
      }
      // Remover alocações e disponibilidades do Firestore para as datas com exceções
      if (widget.unidade != null && _medicoAtual != null) {
        // Filtrar apenas datas dentro do período da série
        DateTime dataAtual = dataInicio;
        DateTime? dataInicioFiltrada;
        DateTime? dataFimFiltrada;

        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          if (dataAtual.isAfter(
                  serie.dataInicio.subtract(const Duration(days: 1))) &&
              (serie.dataFim == null ||
                  dataAtual
                      .isBefore(serie.dataFim!.add(const Duration(days: 1))))) {
            dataInicioFiltrada ??= dataAtual;
            dataFimFiltrada = dataAtual;
          }
          dataAtual = dataAtual.add(const Duration(days: 1));
        }

        if (dataInicioFiltrada != null && dataFimFiltrada != null) {
          await AlocacaoDisponibilidadeRemocaoService
              .removerAlocacoesEDisponibilidades(
            widget.unidade!.id,
            _medicoAtual!.id,
            dataInicioFiltrada,
            dataFimFiltrada,
          );
        }
      }

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.7;
          mensagemCriandoExcecao = 'A processar...';
        });
      }
      // Aguardar um pouco para garantir que o Firestore processou todas as exceções
      await Future.delayed(const Duration(milliseconds: 200));

      // Invalidar cache de séries para este médico e ano

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 0.9;
          mensagemCriandoExcecao = 'A recarregar disponibilidades...';
        });
      }
      // Recarregar disponibilidades para refletir as exceções
      // IMPORTANTE: Isso vai recarregar as exceções do Firestore e gerar disponibilidades sem as datas canceladas
      if (widget.unidade != null && _medicoAtual != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      _verificarMudancas();

      if (mounted) {
        setState(() {
          progressoCriandoExcecao = 1.0;
          mensagemCriandoExcecao = 'Concluído!';
        });
        // Aguardar um pouco para mostrar 100% antes de esconder
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _criandoExcecao = false;
          progressoCriandoExcecao = 0.0;
          mensagemCriandoExcecao = 'A criar exceção...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _criandoExcecao = false;
          progressoCriandoExcecao = 0.0;
          mensagemCriandoExcecao = 'A criar exceção...';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar exceção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cancela uma série a partir de uma data específica (encerra a série)
  Future<void> _cancelarSerieApartirDeData(
      SerieRecorrencia serie, DateTime dataCancelamento) async {
    try {
      // Verificar se a série já tem data fim e se a nova data é depois
      if (serie.dataFim != null && serie.dataFim!.isBefore(dataCancelamento)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('A série já foi encerrada antes da data selecionada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Encerrar série no dia anterior à data de cancelamento
      final dataFimEncerramento =
          dataCancelamento.subtract(const Duration(days: 1));

      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: dataFimEncerramento,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: serie.gabineteId,
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      // Atualizar na lista local
      final index = series.indexWhere((s) => s.id == serie.id);
      if (index != -1) {
        setState(() {
          series[index] = serieAtualizada;
        });
      }

      // Salvar no Firestore
      await SerieService.salvarSerie(serieAtualizada, unidade: widget.unidade);

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada,
          unidade: widget.unidade);

      _verificarMudancas();

      // Recarregar disponibilidades para refletir o encerramento
      if (widget.unidade != null &&
          _medicoAtual != null &&
          _anoVisualizado != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Série cancelada a partir de ${DateFormat('dd/MM/yyyy').format(dataCancelamento)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Remove uma exceção
  Future<void> _removerExcecao(ExcecaoSerie excecao) async {
    try {
      // Remover do Firestore
      await SerieService.removerExcecao(excecao.id, _medicoId, excecao.data,
          unidade: widget.unidade);

      // Remover da lista local
      setState(() {
        excecoes.removeWhere((e) => e.id == excecao.id);
      });

      // NÃO recarregar disponibilidades aqui - será feito em lote se necessário
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover exceção: $e'),
          backgroundColor: Colors.red,
        ),
      );
      rethrow;
    }
  }

  /// Remove múltiplas exceções de uma vez (otimizado)
  Future<void> _removerExcecoesEmLote(
      List<ExcecaoSerie> excecoesParaRemover) async {
    if (excecoesParaRemover.isEmpty) return;

    try {
      setState(() => _saving = true);

      // Remover todas do Firestore em paralelo
      await Future.wait(
        excecoesParaRemover.map((excecao) => SerieService.removerExcecao(
            excecao.id, _medicoId, excecao.data,
            unidade: widget.unidade)),
      );

      // Remover todas da lista local de uma vez
      final idsParaRemover = excecoesParaRemover.map((e) => e.id).toSet();
      setState(() {
        excecoes.removeWhere((e) => idsParaRemover.contains(e.id));
      });

      // Recarregar disponibilidades UMA VEZ após remover todas as exceções
      if (_medicoAtual != null && _anoVisualizado != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      setState(() {
        _saving = false;
        progressoSaving = 0.0;
        mensagemSaving = 'A guardar...';
      });
    } catch (e) {
      setState(() {
        _saving = false;
        progressoSaving = 0.0;
        mensagemSaving = 'A guardar...';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover exceções: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Atualiza a série com os novos horários quando o usuário edita um cartão
  Future<void> _atualizarSerieComHorarios(
      Disponibilidade disponibilidade, List<String> horarios) async {
    // CORREÇÃO: Se for série Única, salvar diretamente no Firestore
    if (disponibilidade.tipo == 'Única') {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Salvando disponibilidade...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 1),
            ),
          );
        }

        // Salvar disponibilidade única diretamente no Firestore
        final firestore = FirebaseFirestore.instance;
        final unidadeId = CadastroMedicosHelper.obterUnidadeId(widget.unidade);
        final ano = disponibilidade.data.year.toString();
        final disponibilidadesRef = firestore
            .collection('unidades')
            .doc(unidadeId)
            .collection('ocupantes')
            .doc(_medicoId)
            .collection('disponibilidades')
            .doc(ano)
            .collection('registos');

        // Atualizar horários da disponibilidade
        final dispAtualizada = Disponibilidade(
          id: disponibilidade.id,
          medicoId: disponibilidade.medicoId,
          data: disponibilidade.data,
          horarios: horarios,
          tipo: disponibilidade.tipo,
        );

        await disponibilidadesRef
            .doc(disponibilidade.id)
            .set(dispAtualizada.toMap());

        debugPrint(
            '✅ Disponibilidade única salva ao editar horários: ID=${disponibilidade.id}, data=${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year}');

        // Atualizar na lista local
        setState(() {
          final index =
              disponibilidades.indexWhere((d) => d.id == disponibilidade.id);
          if (index != -1) {
            disponibilidades[index] = dispAtualizada;
          }
        });

        // Atualizar _disponibilidadesOriginal para evitar detecção de mudanças incorreta
        setState(() {
          final indexOriginal = _disponibilidadesOriginal
              .indexWhere((d) => d.id == disponibilidade.id);
          if (indexOriginal != -1) {
            _disponibilidadesOriginal[indexOriginal] = dispAtualizada;
          }
        });

        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Para séries recorrentes, continuar com a lógica existente
    setState(() {
      _atualizandoHorarios = true;
      progressoAtualizandoHorarios = 0.0;
      mensagemAtualizandoHorarios = 'A iniciar...';
    });

    try {
      if (mounted) {
        setState(() {
          progressoAtualizandoHorarios = 0.3;
          mensagemAtualizandoHorarios = 'A localizar série...';
        });
      }
      // Encontrar a série correspondente baseado na data e tipo
      SerieRecorrencia? serieEncontrada;

      // Tentar extrair o ID da série do ID da disponibilidade
      // Formato: 'serie_{serieId}_{dataKey}' onde:
      // - serieId é 'serie_1234567890' (formato sempre consistente)
      // - dataKey é '2025-12-02' (formato YYYY-MM-DD)
      // Então o formato completo é: 'serie_serie_1234567890_2025-12-02'
      if (disponibilidade.id.startsWith('serie_')) {
        // Estratégia 1: Usar helper para extrair o ID da série
        final serieIdFinal =
            SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id);

        // Tentar encontrar série com ID exato
        serieEncontrada = series.firstWhere(
          (s) => s.id == serieIdFinal && s.ativo,
          orElse: () => SerieRecorrencia(
            id: '',
            medicoId: '',
            dataInicio: DateTime.now(),
            tipo: '',
            horarios: [],
          ),
        );

        // Estratégia 2: Se não encontrou, tentar correspondência parcial
        if (serieEncontrada.id.isEmpty) {
          for (final serie in series) {
            // Verificar se o ID da disponibilidade contém o ID da série
            // e se a série está ativa
            if (disponibilidade.id.contains(serie.id) && serie.ativo) {
              // Verificação adicional: garantir que a data corresponde ao período da série
              if (serie.dataFim == null ||
                  serie.dataFim!.isAfter(disponibilidade.data)) {
                if (serie.dataInicio.isBefore(
                    disponibilidade.data.add(const Duration(days: 1)))) {
                  serieEncontrada = serie;
                  break;
                }
              }
            }
          }
        }
      }

      // Se não encontrou pelo ID, buscar por tipo, data e padrão de recorrência
      if (serieEncontrada == null || serieEncontrada.id.isEmpty) {
        for (final serie in series) {
          if (serie.tipo != disponibilidade.tipo || !serie.ativo) continue;

          // Verificar se a data está dentro do período da série
          if (serie.dataFim != null &&
              serie.dataFim!.isBefore(disponibilidade.data)) {
            continue;
          }
          if (serie.dataInicio.isAfter(disponibilidade.data)) continue;

          // Verificar se a data corresponde ao padrão da série
          if (SeriesHelper.verificarDataCorrespondeAoPadraoSerie(
              disponibilidade.data, serie)) {
            serieEncontrada = serie;
            break;
          }
        }
      }

      if (serieEncontrada != null) {
        // Criar uma cópia com os novos horários
        final serieAtualizada = SerieRecorrencia(
          id: serieEncontrada.id,
          medicoId: serieEncontrada.medicoId,
          dataInicio: serieEncontrada.dataInicio,
          dataFim: serieEncontrada.dataFim,
          tipo: serieEncontrada.tipo,
          horarios: horarios,
          gabineteId: serieEncontrada.gabineteId,
          parametros: serieEncontrada.parametros,
          ativo: serieEncontrada.ativo,
        );

        // Atualizar na lista local
        setState(() {
          final index = series.indexWhere((s) => s.id == serieAtualizada.id);
          if (index != -1) {
            series[index] = serieAtualizada;
          }
        });

        if (mounted) {
          setState(() {
            progressoAtualizandoHorarios = 0.6;
            mensagemAtualizandoHorarios = 'A guardar no servidor...';
          });
        }

        // Salvar no Firestore imediatamente
        await SerieService.salvarSerie(serieAtualizada,
            unidade: widget.unidade);

        // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
        // Isso garante que quando o utilizador navega para qualquer dia da série,
        // os dados serão recarregados do servidor e estarão atualizados
        AlocacaoMedicosLogic.invalidateCacheParaSerie(serieAtualizada,
            unidade: widget.unidade);

        debugPrint(
            '✅ Série atualizada com novos horários: ${serieAtualizada.id}');

        // CORREÇÃO: Atualizar horários localmente nas disponibilidades SEM recarregar tudo
        // Isso evita o rebuild completo da UI - apenas atualiza os horários nos cartões
        if (mounted) {
          setState(() {
            // Atualizar todas as disponibilidades que pertencem a esta série
            for (int i = 0; i < disponibilidades.length; i++) {
              final disp = disponibilidades[i];
              // Verificar se a disponibilidade pertence a esta série
              if (disp.id.startsWith('serie_') &&
                  disp.tipo == serieAtualizada.tipo) {
                // Extrair ID da série da disponibilidade
                final serieIdDaDisp =
                    SeriesHelper.extrairSerieIdDeDisponibilidade(disp.id);
                // Se corresponde à série atualizada, atualizar os horários
                if (serieIdDaDisp == serieAtualizada.id) {
                  disponibilidades[i] = Disponibilidade(
                    id: disp.id,
                    medicoId: disp.medicoId,
                    data: disp.data,
                    horarios: horarios, // Atualizar com os novos horários
                    tipo: disp.tipo,
                  );
                }
              }
            }
            // Criar nova referência da lista para forçar detecção de mudança
            disponibilidades = List<Disponibilidade>.from(disponibilidades);

            progressoAtualizandoHorarios = 1.0;
            mensagemAtualizandoHorarios = 'Concluído!';

            // Desligar progress bar após um pequeno delay para mostrar 100%
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _atualizandoHorarios = false;
                  progressoAtualizandoHorarios = 0.0;
                  mensagemAtualizandoHorarios = 'A atualizar horários...';
                });
              }
            });
          });
        }
      } else {
        debugPrint('⚠️ Série não encontrada para atualizar horários');
        if (mounted) {
          setState(() {
            _atualizandoHorarios = false;
            progressoAtualizandoHorarios = 0.0;
            mensagemAtualizandoHorarios = 'A atualizar horários...';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar série com horários: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _atualizandoHorarios = false;
          progressoAtualizandoHorarios = 0.0;
          mensagemAtualizandoHorarios = 'A atualizar horários...';
        });
      }
    }
  }

  Future<void> _salvarMedico() async {
    if (!_formKey.currentState!.validate()) {
      return; // Não salva se o formulário for inválido
    }

    // Verifica se o nome foi preenchido
    if (nomeController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Introduza o nome do médico')),
        );
      }
      return; // Interrompe o processo de salvar
    }

    try {
      setState(() => _saving = true);

      final resultado =
          await CadastroMedicoSalvarService.salvarMedicoCompletoComTudo(
        context,
        _medicoId,
        nomeController.text,
        especialidadeController.text,
        observacoesController.text,
        disponibilidades,
        series,
        excecoes,
        _disponibilidadesOriginal,
        widget.unidade,
        ativo: _medicoAtivo,
      );

      if (!mounted) return;

      if (!resultado['sucesso']) {
        return; // Erro já foi mostrado pelo serviço
      }

      // Verificar se o valor foi realmente salvo no Firestore
      // Aguardar um pouco para garantir que o Firestore processou
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final firestore = FirebaseFirestore.instance;
        DocumentReference medicoRef;
        if (widget.unidade != null) {
          medicoRef = firestore
              .collection('unidades')
              .doc(widget.unidade!.id)
              .collection('ocupantes')
              .doc(_medicoId);
        } else {
          medicoRef = firestore.collection('medicos').doc(_medicoId);
        }
        final docVerificacao =
            await medicoRef.get(const GetOptions(source: Source.server));
        if (docVerificacao.exists) {
          final dadosVerificacao =
              docVerificacao.data() as Map<String, dynamic>;
          final ativoSalvo = dadosVerificacao['ativo'] ?? true;
          debugPrint(
              '🔍 [VERIFICAÇÃO-PÓS-SALVAR] Valor salvo no Firestore: ativo=$ativoSalvo, esperado=$_medicoAtivo');
          if (ativoSalvo != _medicoAtivo) {
            debugPrint(
                '⚠️ [VERIFICAÇÃO-PÓS-SALVAR] DISCREPÂNCIA! Valor no Firestore ($ativoSalvo) diferente do esperado ($_medicoAtivo)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [VERIFICAÇÃO-PÓS-SALVAR] Erro ao verificar: $e');
      }

      // Reseta as mudanças após salvar com sucesso
      _nomeOriginal = nomeController.text.trim();
      _especialidadeOriginal = especialidadeController.text.trim();
      _observacoesOriginal = observacoesController.text.trim();
      _disponibilidadesOriginal = List.from(disponibilidades);
      setState(() {
        _houveMudancas = false;
        // Atualizar médico atual após salvar
        _medicoAtual = Medico(
          id: _medicoId,
          nome: nomeController.text,
          especialidade: especialidadeController.text,
          observacoes: observacoesController.text,
          disponibilidades: disponibilidades,
          ativo: _medicoAtivo,
        );
        // Atualizar médico na lista local também
        final index = _listaMedicos.indexWhere((m) => m.id == _medicoId);
        if (index != -1) {
          _listaMedicos[index] = _medicoAtual!;
        }
      });

      // Retorna à lista sem flicker: agenda o pop para o próximo frame
      _navegandoAoSair = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar registo: $e')),
      );
    } finally {
      if (mounted && !_navegandoAoSair) {
        setState(() {
          _saving = false;
          progressoSaving = 0.0;
          mensagemSaving = 'A guardar...';
        });
      }
    }
  }

  /// Salva o médico atual sem sair da página
  Future<bool> _salvarMedicoSemSair() async {
    if (!_formKey.currentState!.validate()) {
      return false; // Não salva se o formulário for inválido
    }

    // Verifica se o nome foi preenchido
    if (nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduza o nome do médico')),
      );
      return false; // Interrompe o processo de salvar
    }

    try {
      setState(() => _saving = true);

      final resultado =
          await CadastroMedicoSalvarService.salvarMedicoCompletoComTudo(
        context,
        _medicoId,
        nomeController.text,
        especialidadeController.text,
        observacoesController.text,
        disponibilidades,
        series,
        excecoes,
        _disponibilidadesOriginal,
        widget.unidade,
        ativo: _medicoAtivo,
      );

      if (!mounted) return false;

      if (!resultado['sucesso']) {
        return false; // Erro já foi mostrado pelo serviço
      }

      // Reseta as mudanças após salvar com sucesso
      _nomeOriginal = nomeController.text.trim();
      _especialidadeOriginal = especialidadeController.text.trim();
      _observacoesOriginal = observacoesController.text.trim();
      _disponibilidadesOriginal = List.from(disponibilidades);
      setState(() {
        _houveMudancas = false;
        // Atualizar médico atual após salvar
        _medicoAtual = Medico(
          id: _medicoId,
          nome: nomeController.text,
          especialidade: especialidadeController.text,
          observacoes: observacoesController.text,
          disponibilidades: disponibilidades,
          ativo: _medicoAtivo,
        );
        // Atualizar médico na lista local também
        final index = _listaMedicos.indexWhere((m) => m.id == _medicoId);
        if (index != -1) {
          _listaMedicos[index] = _medicoAtual!;
        }
        progressoSaving = 1.0;
        mensagemSaving = 'Concluído!';
        // Desligar progress bar após um pequeno delay para mostrar 100%
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _saving = false;
              progressoSaving = 0.0;
              mensagemSaving = 'A guardar...';
            });
          }
        });
      });

      return true; // Indica que foi salvo com sucesso
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar registo: $e')),
      );
      return false;
    } finally {
      // Garantir que o loading seja desativado mesmo em caso de erro
      if (mounted && _saving) {
        setState(() {
          _saving = false;
          progressoSaving = 0.0;
          mensagemSaving = 'A guardar...';
        });
      }
    }
  }

  /// Salva o médico e carrega os dados para mostrar a tela de edição completa
  Future<void> _salvarECriarDisponibilidades() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verifica se o nome foi preenchido
    if (nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduza o nome do médico')),
      );
      return;
    }

    final medico = Medico(
      id: _medicoId,
      nome: nomeController.text,
      especialidade: especialidadeController.text,
      observacoes: observacoesController.text,
      disponibilidades: [],
      ativo: _medicoAtivo,
    );

    try {
      setState(() {
        _saving = true;
        progressoSaving = 0.0;
        mensagemSaving = 'A iniciar...';
      });

      if (mounted) {
        setState(() {
          progressoSaving = 0.5;
          mensagemSaving = 'A guardar médico...';
        });
      }

      // Salvar médico
      await salvarMedicoCompleto(
        medico,
        unidade: widget.unidade,
        disponibilidadesOriginais: [],
      );

      if (!mounted) return;

      // Atualizar estado para mostrar a tela de edição completa
      _nomeOriginal = nomeController.text.trim();
      _especialidadeOriginal = especialidadeController.text.trim();
      _observacoesOriginal = observacoesController.text.trim();
      _disponibilidadesOriginal.clear();

      setState(() {
        _houveMudancas = false;
        _medicoAtual = medico;
        _anoVisualizado = DateTime.now().year;
        _dataCalendario = DateTime.now();
      });

      if (mounted) {
        setState(() {
          progressoSaving = 0.9;
          mensagemSaving = 'A carregar disponibilidades...';
        });
      }

      // Carregar disponibilidades do médico recém-criado
      await _carregarDisponibilidadesFirestore(medico.id, ano: _anoVisualizado);

      if (!mounted) return;

      setState(() {
        progressoSaving = 1.0;
        mensagemSaving = 'Concluído!';
        // Desligar progress bar após um pequeno delay para mostrar 100%
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _saving = false;
              progressoSaving = 0.0;
              mensagemSaving = 'A guardar...';
            });
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar médico: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          progressoSaving = 0.0;
          mensagemSaving = 'A guardar...';
        });
      }
    }
  }

  /// Reseta campos para criação de um novo registo
  void _criarNovo() async {
    // Salvar automaticamente se houver mudanças (mantém o overlay de salvamento)
    final podeCriar = await _confirmarNovo();
    if (podeCriar) {
      setState(() {
        _medicoAtual = null;
        _medicoId = DateTime.now().millisecondsSinceEpoch.toString();
        nomeController.clear();
        especialidadeController.clear();
        observacoesController.clear();
        _medicoAutocompleteController.clear();
        disponibilidades.clear();
        diasSelecionados.clear();
        series.clear();
        excecoes.clear();

        // Reseta os valores originais
        _nomeOriginal = '';
        _especialidadeOriginal = '';
        _observacoesOriginal = '';
        _disponibilidadesOriginal.clear();
        _houveMudancas = false;

        // Resetar ano visualizado
        _anoVisualizado = DateTime.now().year;
        _dataCalendario = DateTime.now();

        // Desativar o overlay após resetar
        _saving = false;
      });
    }
  }

  /// Constrói a tela simplificada para criação de novo médico
  Widget _buildTelaCriacaoSimplificada() {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FormularioMedico(
                nomeController: nomeController,
                especialidadeController: especialidadeController,
                observacoesController: observacoesController,
                unidade: widget.unidade,
                ativo: _medicoAtivo,
                onAtivoChanged: (novoValor) async {
                  setState(() {
                    _medicoAtivo = novoValor;
                    _houveMudancas = true;
                  });
                  // Salvar automaticamente quando o switch muda
                  if (widget.medico != null &&
                      nomeController.text.trim().isNotEmpty) {
                    await _salvarMedicoSemSair();
                  }
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saving ? null : _salvarECriarDisponibilidades,
                icon: const Icon(Icons.calendar_today),
                label: const Text(
                  'Criar Disponibilidades',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyAppTheme.roxo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  minimumSize: const Size(250, 50),
                ),
              ),
              if (_saving) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // CORREÇÃO CRÍTICA: Forçar verificação de mudanças antes de confirmar saída
        _verificarMudancas();

        final podeSair = await _confirmarSaida();
        if (podeSair && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leadingWidth: widget.unidade != null ? 112.0 : 56.0,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botão de voltar
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
              // Ícone para navegar para a página de alocação
              if (widget.unidade != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navegarParaAlocacao(),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.map, color: Colors.white, size: 22),
                    ),
                  ),
                ),
            ],
          ),
          title: MedicoAppBarTitle(
            medicoAtual: _medicoAtual,
            anoVisualizado: _anoVisualizado,
            listaMedicos: _listaMedicos,
            carregandoMedicos: _carregandoMedicos,
            medicoAutocompleteController: _medicoAutocompleteController,
            onMedicoSelecionado: _mudarMedico,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              tooltip: 'Salvar',
              onPressed: () => _salvarMedicoSemSair(),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Novo médico',
              onPressed: () => _criarNovo(),
            ),
            if (_medicoAtual != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'Apagar médico',
                onPressed: () => _mostrarDialogoApagarMedico(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Image.asset(
                'images/am_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Progress bar horizontal no topo quando carregando disponibilidades (mais suave)
            // Mas não mostrar se está carregando inicial (usa overlay completo)
            if (isLoadingDisponibilidades &&
                !_saving &&
                !_atualizandoHorarios &&
                !_criandoExcecao &&
                !_isCarregandoInicial)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progressoCarregamentoDisponibilidades,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(MyAppTheme.roxo),
                  minHeight: 3,
                ),
              ),
            // Sempre mostrar o conteúdo (não esconder durante carregamento de disponibilidades)
            // Mas esconder durante carregamento inicial completo
            if (!_isCarregandoInicial)
              Padding(
                padding: EdgeInsets.only(
                  top: (isLoadingDisponibilidades &&
                          !_saving &&
                          !_atualizandoHorarios &&
                          !_criandoExcecao &&
                          !_alocandoGabinete &&
                          !_isCarregandoInicial)
                      ? 3
                      : 0,
                  left: 8.0,
                  right: 8.0,
                  bottom: 16.0,
                ),
                child: Form(
                  key: _formKey,
                  child: _medicoAtual == null
                      ? _buildTelaCriacaoSimplificada()
                      : (isLargeScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Coluna esquerda (dados do médico + calendário)
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 300),
                                  child: SingleChildScrollView(
                                    clipBehavior: Clip.none,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FormularioMedico(
                                            nomeController: nomeController,
                                            especialidadeController:
                                                especialidadeController,
                                            observacoesController:
                                                observacoesController,
                                            unidade: widget.unidade,
                                            ativo: _medicoAtivo,
                                            onAtivoChanged: (novoValor) {
                                              setState(() {
                                                _medicoAtivo = novoValor;
                                                _houveMudancas = true;
                                              });
                                            },
                                          ),
                                          CalendarioDisponibilidades(
                                            diasSelecionados: diasSelecionados,
                                            onAdicionarData: _adicionarData,
                                            onRemoverData: (date, removeSerie) {
                                              _removerData(date,
                                                  removeSerie: removeSerie);
                                            },
                                            dataCalendario: _dataCalendario,
                                            onViewChanged: (visibleDate) {
                                              // Quando o usuário navega no calendário, atualizar a data do calendário
                                              if (_medicoAtual != null) {
                                                final anoAnterior =
                                                    _anoVisualizado;
                                                setState(() {
                                                  _dataCalendario = visibleDate;
                                                  _anoVisualizado =
                                                      visibleDate.year;
                                                });

                                                // OTIMIZAÇÃO: Só recarregar se mudou o ano (não apenas o mês)
                                                if (anoAnterior !=
                                                    visibleDate.year) {
                                                  // Mudou o ano - recarregar dados e mostrar progressbar
                                                  _carregarDisponibilidadesFirestore(
                                                    _medicoAtual!.id,
                                                    ano: visibleDate.year,
                                                  );
                                                }
                                                // Se só mudou o mês (mesmo ano), não fazer nada
                                                // Os dados já estão carregados, apenas atualizar a visualização
                                              }
                                            },
                                          ),
                                          // Seção de Exceções (abaixo do calendário)
                                          // CORREÇÃO: Filtrar apenas exceções de disponibilidade (cancelada: true)
                                          // Exceções de gabinete (cancelada: false) não devem aparecer aqui
                                          ExcecoesCard(
                                            series: series,
                                            excecoes: excecoes
                                                .where((e) => e.cancelada)
                                                .toList(),
                                            onCriarExcecaoPeriodoGeral:
                                                _criarExcecaoPeriodoGeral,
                                            onCriarExcecaoPeriodo:
                                                _criarExcecaoPeriodo,
                                            onCancelarSerie:
                                                _cancelarSerieApartirDeData,
                                            onRemoverExcecoesEmLote:
                                                _removerExcecoesEmLote,
                                            isMobile: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Coluna direita (grid das disponibilidades)
                                Expanded(
                                  flex: 1,
                                  child: SingleChildScrollView(
                                    child: DisponibilidadesGrid(
                                      disponibilidades: _anoVisualizado != null
                                          ? disponibilidades
                                              .where((d) =>
                                                  d.data.year ==
                                                  _anoVisualizado)
                                              .toList()
                                          : disponibilidades,
                                      onRemoverData: (date, removeSerie) {
                                        _removerData(date,
                                            removeSerie: removeSerie);
                                      },
                                      onChanged: _verificarMudancas,
                                      onAtualizarSerie: (disp, horarios) {
                                        _atualizarSerieComHorarios(
                                            disp, horarios);
                                      },
                                      alocacoes: _anoVisualizado != null
                                          ? alocacoes
                                              .where((a) =>
                                                  a.data.year ==
                                                  _anoVisualizado)
                                              .toList()
                                          : alocacoes,
                                      gabinetes: gabinetes,
                                      unidade: widget.unidade,
                                      onGabineteChanged: _onGabineteChanged,
                                      series: series,
                                      onNavegarParaMapa:
                                          _salvarAntesDeNavegarParaMapa,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              clipBehavior: Clip.none,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FormularioMedico(
                                      nomeController: nomeController,
                                      especialidadeController:
                                          especialidadeController,
                                      observacoesController:
                                          observacoesController,
                                      unidade: widget.unidade,
                                      ativo: _medicoAtivo,
                                      onAtivoChanged: (novoValor) {
                                        setState(() {
                                          _medicoAtivo = novoValor;
                                          _houveMudancas = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Botão para criar exceções em séries
                                    if (series.isNotEmpty)
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Séries de Recorrência',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  // Botão para encerrar todas as séries
                                                  TextButton.icon(
                                                    icon: const Icon(
                                                        Icons.stop_circle,
                                                        color: Colors.red),
                                                    label: const Text(
                                                        'Encerrar séries a partir de...'),
                                                    onPressed: () async {
                                                      await _mostrarDialogoEncerrarSeries();
                                                    },
                                                  ),
                                                ],
                                              ),
                                              // Botão destacado para criar exceções (férias)
                                              if (series.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8.0),
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(
                                                        Icons.block,
                                                        color: Colors.white),
                                                    label: const Text(
                                                        'Criar Exceção (Férias/Interrupção)'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.orange,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 12),
                                                    ),
                                                    onPressed: () async {
                                                      // Mostrar diálogo para escolher tipo de exceção
                                                      final tipoExcecao =
                                                          await showDialog<
                                                              String>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              'Tipo de Exceção'),
                                                          content: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              ListTile(
                                                                leading: const Icon(
                                                                    Icons
                                                                        .calendar_today,
                                                                    color: Colors
                                                                        .orange),
                                                                title: const Text(
                                                                    'Exceção de Período'),
                                                                subtitle:
                                                                    const Text(
                                                                        'Remove todos os cartões no período selecionado (ex: congresso, férias)'),
                                                                onTap: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        'periodo'),
                                                              ),
                                                              const Divider(),
                                                              ListTile(
                                                                leading: const Icon(
                                                                    Icons
                                                                        .repeat,
                                                                    color: Colors
                                                                        .blue),
                                                                title: const Text(
                                                                    'Exceção de Série'),
                                                                subtitle:
                                                                    const Text(
                                                                        'Remove cartões de uma série específica'),
                                                                onTap: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        'serie'),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                      if (!context.mounted) {
                                                        return;
                                                      }

                                                      if (tipoExcecao ==
                                                          'periodo') {
                                                        // Criar exceção de período geral
                                                        // CORREÇÃO: Para exceções de período, permitir selecionar QUALQUER data
                                                        // A exceção removerá todos os cartões no período, mesmo que não existam cartões em algumas datas
                                                        // Por isso, não limitamos o intervalo - permitimos qualquer data
                                                        await showDialog(
                                                          context: context,
                                                          builder: (context) =>
                                                              DialogoExcecaoPeriodo(
                                                            // Passar null para permitir seleção de qualquer data
                                                            // O diálogo usará DateTime(2020) e DateTime(2100) como padrões
                                                            dataInicialMinima:
                                                                null,
                                                            dataFinalMaxima:
                                                                null,
                                                            onConfirmar:
                                                                (dataInicio,
                                                                    dataFim) {
                                                              _criarExcecaoPeriodoGeral(
                                                                  dataInicio,
                                                                  dataFim);
                                                            },
                                                          ),
                                                        );
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                      } else if (tipoExcecao ==
                                                          'serie') {
                                                        // Comportamento original: criar exceção para uma série específica
                                                        if (series.isEmpty) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Não há séries cadastradas'),
                                                              backgroundColor:
                                                                  Colors.orange,
                                                            ),
                                                          );
                                                          return;
                                                        }

                                                        if (series.length ==
                                                            1) {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (context) =>
                                                                DialogoExcecaoSerie(
                                                              serie:
                                                                  series.first,
                                                              onConfirmar:
                                                                  (dataInicio,
                                                                      dataFim) {
                                                                _criarExcecaoPeriodo(
                                                                    series
                                                                        .first,
                                                                    dataInicio,
                                                                    dataFim);
                                                              },
                                                              onCancelarSerie:
                                                                  (dataFim) {
                                                                _cancelarSerieApartirDeData(
                                                                    series
                                                                        .first,
                                                                    dataFim);
                                                              },
                                                            ),
                                                          );
                                                        } else {
                                                          // Se houver múltiplas séries, mostrar diálogo para escolher
                                                          final serieEscolhida =
                                                              await showDialog<
                                                                  SerieRecorrencia>(
                                                            context: context,
                                                            builder:
                                                                (context) =>
                                                                    AlertDialog(
                                                              title: const Text(
                                                                  'Selecionar Série'),
                                                              content: SizedBox(
                                                                width: double
                                                                    .maxFinite,
                                                                child: ListView
                                                                    .builder(
                                                                  shrinkWrap:
                                                                      true,
                                                                  itemCount:
                                                                      series
                                                                          .length,
                                                                  itemBuilder:
                                                                      (context,
                                                                          index) {
                                                                    final serie =
                                                                        series[
                                                                            index];
                                                                    String
                                                                        descricaoDia =
                                                                        '';
                                                                    if (serie.tipo ==
                                                                            'Semanal' ||
                                                                        serie.tipo ==
                                                                            'Quinzenal') {
                                                                      final diasSemana =
                                                                          [
                                                                        'Segunda',
                                                                        'Terça',
                                                                        'Quarta',
                                                                        'Quinta',
                                                                        'Sexta',
                                                                        'Sábado',
                                                                        'Domingo'
                                                                      ];
                                                                      descricaoDia =
                                                                          ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                                                                    } else if (serie
                                                                            .tipo ==
                                                                        'Mensal') {
                                                                      final diasSemana =
                                                                          [
                                                                        'Segunda',
                                                                        'Terça',
                                                                        'Quarta',
                                                                        'Quinta',
                                                                        'Sexta',
                                                                        'Sábado',
                                                                        'Domingo'
                                                                      ];
                                                                      descricaoDia =
                                                                          ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                                                                    }
                                                                    return ListTile(
                                                                      title: Text(
                                                                          '${serie.tipo}$descricaoDia'),
                                                                      subtitle:
                                                                          Text(
                                                                              'Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                                                                      onTap: () => Navigator.pop(
                                                                          context,
                                                                          serie),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                          if (!context
                                                              .mounted) {
                                                            return;
                                                          }
                                                          if (serieEscolhida !=
                                                              null) {
                                                            await showDialog(
                                                              context: context,
                                                              builder: (context) =>
                                                                  DialogoExcecaoSerie(
                                                                serie:
                                                                    serieEscolhida,
                                                                onConfirmar:
                                                                    (dataInicio,
                                                                        dataFim) {
                                                                  _criarExcecaoPeriodo(
                                                                      serieEscolhida,
                                                                      dataInicio,
                                                                      dataFim);
                                                                },
                                                                onCancelarSerie:
                                                                    (dataFim) {
                                                                  _cancelarSerieApartirDeData(
                                                                      serieEscolhida,
                                                                      dataFim);
                                                                },
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                              const SizedBox(height: 8),
                                              ...series.map((serie) {
                                                // Determinar dia da semana para séries semanais/quinzenais
                                                String descricaoDia = '';
                                                if (serie.tipo == 'Semanal' ||
                                                    serie.tipo == 'Quinzenal') {
                                                  final diasSemana = [
                                                    'Segunda',
                                                    'Terça',
                                                    'Quarta',
                                                    'Quinta',
                                                    'Sexta',
                                                    'Sábado',
                                                    'Domingo'
                                                  ];
                                                  descricaoDia =
                                                      ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                                                } else if (serie.tipo ==
                                                    'Mensal') {
                                                  final diasSemana = [
                                                    'Segunda',
                                                    'Terça',
                                                    'Quarta',
                                                    'Quinta',
                                                    'Sexta',
                                                    'Sábado',
                                                    'Domingo'
                                                  ];
                                                  descricaoDia =
                                                      ' (${diasSemana[serie.dataInicio.weekday - 1]})';
                                                }

                                                return Card(
                                                  margin: const EdgeInsets
                                                      .symmetric(vertical: 4.0),
                                                  child: ListTile(
                                                    title: Text(
                                                        '${serie.tipo}$descricaoDia - ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                                                    subtitle: Text(
                                                      serie.dataFim != null
                                                          ? 'Até ${DateFormat('dd/MM/yyyy').format(serie.dataFim!)}'
                                                          : 'Série infinita',
                                                    ),
                                                    trailing: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        // Botão para criar exceção - mais visível
                                                        Tooltip(
                                                          message:
                                                              'Criar exceção (ex: férias)',
                                                          child: ElevatedButton
                                                              .icon(
                                                            icon: const Icon(
                                                                Icons.block,
                                                                size: 18),
                                                            label: const Text(
                                                                'Exceção'),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.orange,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              minimumSize:
                                                                  const Size(
                                                                      0, 32),
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              await showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) =>
                                                                        DialogoExcecaoSerie(
                                                                  serie: serie,
                                                                  onConfirmar:
                                                                      (dataInicio,
                                                                          dataFim) {
                                                                    _criarExcecaoPeriodo(
                                                                        serie,
                                                                        dataInicio,
                                                                        dataFim);
                                                                  },
                                                                  onCancelarSerie:
                                                                      (dataFim) {
                                                                    _cancelarSerieApartirDeData(
                                                                        serie,
                                                                        dataFim);
                                                                  },
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons.swap_horiz,
                                                              color:
                                                                  Colors.blue),
                                                          tooltip:
                                                              'Transformar/Substituir série',
                                                          onPressed: () async {
                                                            await _mostrarDialogoTransformarSerie(
                                                                serie);
                                                          },
                                                        ),
                                                        if (serie.dataFim ==
                                                            null)
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.stop,
                                                                color:
                                                                    Colors.red),
                                                            tooltip:
                                                                'Encerrar esta série',
                                                            onPressed:
                                                                () async {
                                                              await _encerrarSerie(
                                                                  serie);
                                                            },
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    CalendarioDisponibilidades(
                                      diasSelecionados: diasSelecionados,
                                      onAdicionarData: _adicionarData,
                                      onRemoverData: (date, removeSerie) {
                                        _removerData(date,
                                            removeSerie: removeSerie);
                                      },
                                      dataCalendario: _dataCalendario,
                                      onViewChanged: (visibleDate) {
                                        // Quando o usuário navega no calendário, atualizar a data do calendário
                                        if (_medicoAtual != null) {
                                          final anoAnterior = _anoVisualizado;
                                          setState(() {
                                            _dataCalendario = visibleDate;
                                            _anoVisualizado = visibleDate.year;
                                          });

                                          // OTIMIZAÇÃO: Só recarregar se mudou o ano (não apenas o mês)
                                          if (anoAnterior != visibleDate.year) {
                                            // Mudou o ano - recarregar dados e mostrar progressbar
                                            _carregarDisponibilidadesFirestore(
                                              _medicoAtual!.id,
                                              ano: visibleDate.year,
                                            );
                                          }
                                          // Se só mudou o mês (mesmo ano), não fazer nada
                                          // Os dados já estão carregados, apenas atualizar a visualização
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Seção de Exceções (versão mobile, abaixo do calendário)
                                    // CORREÇÃO: Filtrar apenas exceções de disponibilidade (cancelada: true)
                                    // Exceções de gabinete (cancelada: false) não devem aparecer aqui
                                    ExcecoesCard(
                                      series: series,
                                      excecoes: excecoes
                                          .where((e) => e.cancelada)
                                          .toList(),
                                      onCriarExcecaoPeriodoGeral:
                                          _criarExcecaoPeriodoGeral,
                                      onCriarExcecaoPeriodo:
                                          _criarExcecaoPeriodo,
                                      onCancelarSerie:
                                          _cancelarSerieApartirDeData,
                                      onRemoverExcecoesEmLote:
                                          _removerExcecoesEmLote,
                                      onRemoverExcecao: _removerExcecao,
                                      isMobile: true,
                                    ),
                                    const SizedBox(height: 24),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxHeight: 300),
                                      child: DisponibilidadesGrid(
                                        disponibilidades:
                                            _anoVisualizado != null
                                                ? disponibilidades
                                                    .where((d) =>
                                                        d.data.year ==
                                                        _anoVisualizado)
                                                    .toList()
                                                : disponibilidades,
                                        onRemoverData: (date, removeSerie) {
                                          _removerData(date,
                                              removeSerie: removeSerie);
                                        },
                                        onChanged: _verificarMudancas,
                                        onAtualizarSerie: (disp, horarios) {
                                          _atualizarSerieComHorarios(
                                              disp, horarios);
                                        },
                                        alocacoes: _anoVisualizado != null
                                            ? alocacoes
                                                .where((a) =>
                                                    a.data.year ==
                                                    _anoVisualizado)
                                                .toList()
                                            : alocacoes,
                                        gabinetes: gabinetes,
                                        unidade: widget.unidade,
                                        onGabineteChanged: _onGabineteChanged,
                                        series: series,
                                        onNavegarParaMapa:
                                            _salvarAntesDeNavegarParaMapa,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Botão de Salvar removido, pois salvamos ao sair
                                  ],
                                ),
                              ),
                            )),
                ),
              ),
            // Overlay de carregamento inicial completo (disponibilidades, alocações e gabinetes)
            if (_isCarregandoInicial)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mensagem de status
                        Text(
                          _mensagemCarregamentoInicial,
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
                                  value: _progressoCarregamentoInicial,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.blue),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Percentagem
                              Text(
                                '${(_progressoCarregamentoInicial * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
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
            // Overlay de salvamento (semi-transparente como na tela de alocação)
            if (_saving && !_isCarregandoInicial)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mensagem de status
                        Text(
                          mensagemSaving,
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
                                  value: progressoSaving,
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
                                '${(progressoSaving * 100).toInt()}%',
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
            // Overlay de carregamento de disponibilidades apenas quando realmente necessário (mudança de ano)
            // Usa LinearProgressIndicator no topo para mudanças simples
            // Overlay completo apenas se demorar muito tempo
            if (_atualizandoHorarios)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mensagem de status
                        Text(
                          mensagemAtualizandoHorarios,
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
                                  value: progressoAtualizandoHorarios,
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
                                '${(progressoAtualizandoHorarios * 100).toInt()}%',
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
            // Overlay de criação de exceções
            if (_criandoExcecao)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mensagem de status
                        Text(
                          mensagemCriandoExcecao,
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
                                  value: progressoCriandoExcecao,
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
                                '${(progressoCriandoExcecao * 100).toInt()}%',
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
            // Overlay de alocação de gabinete
            if (_alocandoGabinete)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mensagem de status
                        Text(
                          mensagemAlocandoGabinete,
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
                                  value: progressoAlocandoGabinete,
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
                                '${(progressoAlocandoGabinete * 100).toInt()}%',
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
        ),
      ),
    );
  }

  /// Normaliza string removendo acentos e convertendo para minúsculas
  /// para ordenação e pesquisa corretas

  @override
  void dispose() {
    // Remove os listeners dos controllers
    nomeController.removeListener(_verificarMudancas);
    especialidadeController.removeListener(_verificarMudancas);
    observacoesController.removeListener(_verificarMudancas);

    // Dispose dos controllers
    nomeController.dispose();
    especialidadeController.dispose();
    observacoesController.dispose();
    _medicoAutocompleteController.dispose();

    super.dispose();
  }
}
