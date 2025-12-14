import 'dart:async';
import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';

// Services
import '../models/disponibilidade.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../services/medico_salvar_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/disponibilidade_remocao.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';

// Widgets
import '../widgets/disponibilidades_grid.dart';
import '../widgets/calendario_disponibilidades.dart';
import '../widgets/formulario_medico.dart';
import '../widgets/dialogo_excecao_serie.dart';
import '../widgets/dialogo_excecao_periodo.dart';
import '../widgets/date_picker_customizado.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/alocacao_medicos_logic.dart';
import 'alocacao_medicos_screen.dart';
import '../services/password_service.dart';

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

  // Mantém o ID do médico numa variável interna
  late String _medicoId;

  // Médico atual sendo editado (pode mudar via dropdown)
  Medico? _medicoAtual;

  // Disponibilidades e datas selecionadas
  List<Disponibilidade> disponibilidades = [];
  List<DateTime> diasSelecionados = [];
  int? _anoVisualizado; // Ano atualmente visualizado no calendário
  DateTime? _dataCalendario; // Data atual do calendário para forçar atualização

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

  bool isLoadingDisponibilidades = false;
  double progressoCarregamentoDisponibilidades = 0.0;
  String mensagemCarregamentoDisponibilidades =
      'A carregar disponibilidades...';

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
      // Editando um médico existente
      nomeController.text = widget.medico!.nome;
      especialidadeController.text = widget.medico!.especialidade;
      observacoesController.text = widget.medico!.observacoes ?? '';
      _medicoAutocompleteController.text = widget.medico!.nome;
      // Carregar disponibilidades do ano atual por padrão
      _anoVisualizado = DateTime.now().year;
      _dataCalendario = DateTime.now();
      _carregarDisponibilidadesFirestore(widget.medico!.id,
          ano: _anoVisualizado);

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

  /// Carrega a lista de médicos para o dropdown
  Future<void> _carregarListaMedicos() async {
    setState(() => _carregandoMedicos = true);
    try {
      final medicos = await buscarMedicos(unidade: widget.unidade);
      // Ordenar alfabeticamente por nome
      medicos
          .sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
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
    // Isso garante que disponibilidades "Única" novas sejam sempre detectadas,
    // mesmo quando múltiplas séries são criadas rapidamente
    final disponibilidadesUnicas = disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();
    final disponibilidadesUnicasOriginal = _disponibilidadesOriginal
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();

    // Verificar se há disponibilidades "Única" novas ou removidas
    final temUnicasNovas = disponibilidadesUnicas.any((d) =>
        !disponibilidadesUnicasOriginal.any((orig) =>
            orig.id == d.id &&
            orig.data.year == d.data.year &&
            orig.data.month == d.data.month &&
            orig.data.day == d.data.day &&
            _listasIguais(orig.horarios, d.horarios)));
    final temUnicasRemovidas = disponibilidadesUnicasOriginal.any((orig) =>
        !disponibilidadesUnicas.any((d) =>
            d.id == orig.id &&
            d.data.year == orig.data.year &&
            d.data.month == orig.data.month &&
            d.data.day == orig.data.day &&
            _listasIguais(d.horarios, orig.horarios)));

    if (temUnicasNovas || temUnicasRemovidas) {
      mudancas = true;
    }

    // CORREÇÃO: Verificar mudanças nas disponibilidades usando comparação por ID
    // Isso garante que disponibilidades "Única" novas sejam detectadas
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
            _listasIguais(orig.horarios, disp.horarios));
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
              _listasIguais(disp.horarios, orig.horarios));
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

  bool _listasIguais(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Salva automaticamente antes de sair (se houver mudanças)
  Future<bool> _confirmarSaida() async {
    // CORREÇÃO CRÍTICA: Verificar se há cartões únicos não salvos
    // Mesmo que _houveMudancas seja false, se há cartões únicos, precisamos salvar
    // IMPORTANTE: Recalcular disponibilidades únicas para garantir lista atualizada
    final disponibilidadesUnicasAtualizadas = disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();
    final disponibilidadesUnicasOriginal = _disponibilidadesOriginal
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();

    // CORREÇÃO: Verificar se há disponibilidades "Única" que não estão nas originais
    // Usar comparação mais robusta que verifica ID, data completa e horários
    final temUnicasNaoSalvas = disponibilidadesUnicasAtualizadas.any((d) {
      final existeOriginal = disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          _listasIguais(orig.horarios, d.horarios));
      return !existeOriginal;
    });
    // CORREÇÃO CRÍTICA: Sempre forçar verificação de mudanças antes de sair
    // Isso garante que _houveMudancas esteja atualizado mesmo quando múltiplas séries são criadas
    // IMPORTANTE: Chamar _verificarMudancas() novamente para garantir estado atualizado
    // (já foi chamado no PopScope, mas garantir novamente aqui)
    _verificarMudancas();

    // CORREÇÃO: Recalcular disponibilidades únicas após verificar mudanças
    // Isso garante que temos a lista mais atualizada (pode ter mudado desde a primeira verificação)
    final disponibilidadesUnicasRecalculadas = disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();

    // Atualizar temUnicasNaoSalvas após verificar mudanças novamente
    final temUnicasNaoSalvasAtualizado =
        disponibilidadesUnicasRecalculadas.any((d) {
      final existeOriginal = disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          _listasIguais(orig.horarios, d.horarios));

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
    if (temUnicasNaoSalvasAtualizado || _houveMudancas) {
      final unicasNaoSalvas = disponibilidadesUnicasRecalculadas
          .where((d) => !disponibilidadesUnicasOriginal.any((orig) =>
              orig.id == d.id &&
              orig.data.year == d.data.year &&
              orig.data.month == d.data.month &&
              orig.data.day == d.data.day &&
              _listasIguais(orig.horarios, d.horarios)))
          .toList();
      for (final disp in unicasNaoSalvas) {}
    }

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
  Future<void> _navegarParaAlocacao() async {
    // Verificar se há mudanças não salvas
    _verificarMudancas();

    // Verificar se há disponibilidades "Única" não salvas
    final disponibilidadesUnicasAtualizadas = disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();
    final disponibilidadesUnicasOriginal = _disponibilidadesOriginal
        .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
        .toList();

    final temUnicasNaoSalvas = disponibilidadesUnicasAtualizadas.any((d) {
      return !disponibilidadesUnicasOriginal.any((orig) =>
          orig.id == d.id &&
          orig.data.year == d.data.year &&
          orig.data.month == d.data.month &&
          orig.data.day == d.data.day &&
          _listasIguais(orig.horarios, d.horarios));
    });

    // Se houver mudanças ou disponibilidades não salvas, salvar antes de navegar
    if (_houveMudancas || temUnicasNaoSalvas) {
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
    setState(() {
      _medicoAtual = medico;
      _medicoId = medico.id;
      nomeController.text = medico.nome;
      especialidadeController.text = medico.especialidade;
      observacoesController.text = medico.observacoes ?? '';
      _medicoAutocompleteController.text = medico.nome;

      // Limpar dados antigos
      disponibilidades.clear();
      diasSelecionados.clear();
      series.clear();
      excecoes.clear();

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

    // Carregar disponibilidades do novo médico
    await _carregarDisponibilidadesFirestore(medico.id, ano: _anoVisualizado);
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

    // Manter o overlay de salvamento enquanto carrega o novo médico
    // Carregar o novo médico
    await _carregarMedico(novoMedico);

    // Desativar o overlay após carregar
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
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

      // 3. Apagar todas as exceções
      int excecoesRemovidas = 0;
      final excecoesAnosSnapshot = await excecoesRef.get();
      for (final anoDoc in excecoesAnosSnapshot.docs) {
        final registosRef = anoDoc.reference.collection('registos');
        final todosRegistos = await registosRef.get();
        for (final doc in todosRegistos.docs) {
          await doc.reference.delete();
          excecoesRemovidas++;
        }
        await anoDoc.reference.delete();
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
        }
      }

      // 5. Apagar o documento do médico
      await ocupantesRef.doc(medicoId).delete();

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
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(2000, 1, 1));

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

  Future<void> _carregarDisponibilidadesFirestore(String medicoId,
      {int? ano}) async {
    // Carrega o ano especificado ou o ano atual por padrão
    final anoParaCarregar = ano ?? DateTime.now().year;

    // SEMPRE mostrar barra de progresso ao carregar (mesmo que seja rápido)
    setState(() {
      isLoadingDisponibilidades = true;
      progressoCarregamentoDisponibilidades = 0.0;
      mensagemCarregamentoDisponibilidades = 'A iniciar...';
    });

    // OTIMIZAÇÃO: Se já temos séries carregadas para este médico, não recarregar séries
    // Mas sempre gerar disponibilidades para o novo ano se mudou o ano
    // IMPORTANTE: Não usar _anoVisualizado aqui porque ele já foi atualizado antes desta função ser chamada
    final seriesJaCarregadas =
        series.isNotEmpty && series.first.medicoId == medicoId;

    // NOVO MODELO: Apenas séries - carregar séries e gerar disponibilidades dinamicamente
    final disponibilidades = <Disponibilidade>[];
    try {
      // OTIMIZAÇÃO: Gerar apenas para o ano necessário (não precisa do ano inteiro se só mudou o mês)
      final dataInicio = DateTime(anoParaCarregar, 1, 1);
      final dataFim = DateTime(anoParaCarregar + 1, 1, 1);

      List<SerieRecorrencia> seriesCarregadas;

      if (!seriesJaCarregadas) {
        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades = 0.2;
            mensagemCarregamentoDisponibilidades = 'A carregar séries...';
          });
        }

        // Carregar séries do médico (carregar TODAS as séries ativas, não apenas do ano)
        seriesCarregadas = await SerieService.carregarSeries(
          medicoId,
          unidade: widget.unidade,
          // Não filtrar por data para carregar todas as séries ativas
        );
      } else {
        // Usar séries já carregadas
        seriesCarregadas = series;
      }

      if (!seriesJaCarregadas) {
        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades = 0.5;
            mensagemCarregamentoDisponibilidades = 'A carregar exceções...';
          });
        }

        // Atualizar lista de séries no estado (apenas na primeira carga ou se mudou o médico)
        if (series.isEmpty ||
            (series.isNotEmpty && series.first.medicoId != medicoId)) {
          setState(() {
            series = seriesCarregadas;
          });
          // Mensagem de debug removida para reduzir ruído no terminal
          // debugPrint('✅ Séries carregadas: ${seriesCarregadas.length}');
        } else {
          // Se já temos séries do mesmo médico, mesclar com as novas (evitar duplicatas)
          for (final serieCarregada in seriesCarregadas) {
            if (!series.any((s) => s.id == serieCarregada.id)) {
              setState(() {
                series.add(serieCarregada);
              });
            }
          }
        }
      }

      if (seriesCarregadas.isNotEmpty) {
        // OTIMIZAÇÃO: Carregar exceções apenas se necessário (se mudou o ano ou não temos exceções)
        List<ExcecaoSerie> excecoesCarregadas;
        final excecoesJaCarregadas = excecoes.isNotEmpty &&
            excecoes.any((e) => e.data.year == anoParaCarregar);

        // Se mudou o ano, sempre carregar exceções do novo ano
        // Se só mudou o mês, usar exceções já carregadas
        if (!excecoesJaCarregadas) {
          if (mounted) {
            setState(() {
              progressoCarregamentoDisponibilidades =
                  seriesJaCarregadas ? 0.3 : 0.5;
              mensagemCarregamentoDisponibilidades = 'A carregar exceções...';
            });
          }

          // Carregar exceções do médico no período
          excecoesCarregadas = await SerieService.carregarExcecoes(
            medicoId,
            unidade: widget.unidade,
            dataInicio: dataInicio,
            dataFim: dataFim,
          );

          // Atualizar lista de exceções no estado
          if (mounted) {
            setState(() {
              excecoes = excecoesCarregadas;
              progressoCarregamentoDisponibilidades =
                  seriesJaCarregadas ? 0.5 : 0.6;
            });
          }
        } else {
          // Usar exceções já carregadas
          excecoesCarregadas =
              excecoes.where((e) => e.data.year == anoParaCarregar).toList();

          if (mounted) {
            setState(() {
              progressoCarregamentoDisponibilidades =
                  seriesJaCarregadas ? 0.4 : 0.6;
            });
          }
        }

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.6 : 0.7;
            mensagemCarregamentoDisponibilidades =
                'A gerar disponibilidades...';
          });
        }

        // OTIMIZAÇÃO: Remover apenas disponibilidades do ano atual, não todas
        // Isso é mais eficiente quando só mudou o mês
        // IMPORTANTE: Não remover disponibilidades "Única" - elas são salvas no Firestore
        final disponibilidadesAntigas = this
            .disponibilidades
            .where((d) =>
                d.id.startsWith('serie_') &&
                d.medicoId == medicoId &&
                d.data.year == anoParaCarregar)
            .toList();

        this.disponibilidades.removeWhere((d) =>
            d.id.startsWith('serie_') &&
            d.medicoId == medicoId &&
            d.data.year == anoParaCarregar);

        // CORREÇÃO: Carregar disponibilidades "Única" do Firestore
        List<Disponibilidade> dispsUnicas = [];
        try {
          final firestore = FirebaseFirestore.instance;
          final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
          final disponibilidadesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('ocupantes')
              .doc(medicoId)
              .collection('disponibilidades')
              .doc(anoParaCarregar.toString())
              .collection('registos');

          final snapshot =
              await disponibilidadesRef.where('tipo', isEqualTo: 'Única').get();

          dispsUnicas = snapshot.docs
              .map((doc) => Disponibilidade.fromMap(doc.data()))
              .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
              .toList();
        } catch (e) {
          // Erro ao carregar disponibilidades únicas - continuar sem elas
        }

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades = 0.75;
            mensagemCarregamentoDisponibilidades =
                'A gerar disponibilidades...';
          });
        }

        // Gerar disponibilidades dinamicamente a partir das séries (com exceções aplicadas)
        // Atualizar progresso antes de gerar (pode demorar)
        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.65 : 0.75;
            mensagemCarregamentoDisponibilidades =
                'A gerar disponibilidades...';
          });
        }

        final dispsGeradas = SerieGenerator.gerarDisponibilidades(
          series: seriesCarregadas,
          excecoes: excecoesCarregadas,
          dataInicio: dataInicio,
          dataFim: dataFim,
        );

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.80 : 0.85;
            mensagemCarregamentoDisponibilidades = 'A processar dados...';
          });
        }

        for (final excecao in excecoesCarregadas) {}

        // NOVO MODELO: Apenas séries - adicionar disponibilidades geradas
        // As exceções já são aplicadas automaticamente na geração
        // Usar um Map para garantir unicidade baseado em (medicoId, data, tipo)
        final disponibilidadesUnicas = <String, Disponibilidade>{};

        // Adicionar disponibilidades existentes de outros anos
        for (final disp in this.disponibilidades) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          disponibilidadesUnicas[chave] = disp;
        }

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.85 : 0.88;
            mensagemCarregamentoDisponibilidades = 'A organizar dados...';
          });
        }

        // Adicionar disponibilidades geradas de séries
        for (final dispGerada in dispsGeradas) {
          final chave =
              '${dispGerada.medicoId}_${dispGerada.data.year}-${dispGerada.data.month}-${dispGerada.data.day}_${dispGerada.tipo}';
          disponibilidadesUnicas[chave] = dispGerada;
        }

        // CORREÇÃO: Adicionar disponibilidades "Única" carregadas do Firestore
        for (final dispUnica in dispsUnicas) {
          final chave =
              '${dispUnica.medicoId}_${dispUnica.data.year}-${dispUnica.data.month}-${dispUnica.data.day}_${dispUnica.tipo}';
          disponibilidadesUnicas[chave] = dispUnica;
        }

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.90 : 0.92;
            mensagemCarregamentoDisponibilidades = 'A ordenar dados...';
          });
        }

        // OTIMIZAÇÃO: Ordenar durante a construção da lista (mais eficiente)
        // Converter para lista e ordenar de uma vez
        final listaOrdenada = disponibilidadesUnicas.values.toList();
        listaOrdenada.sort((a, b) => a.data.compareTo(b.data));

        if (mounted) {
          setState(() {
            progressoCarregamentoDisponibilidades =
                seriesJaCarregadas ? 0.95 : 0.96;
            mensagemCarregamentoDisponibilidades = 'A finalizar...';
          });
        }

        // CORREÇÃO: Mesclar com disponibilidades existentes que não são do ano atual
        // Manter disponibilidades "Única" que ainda não foram salvas (não estão no Firestore)
        final disponibilidadesFinais = <String, Disponibilidade>{};

        // Primeiro, adicionar todas as disponibilidades existentes que não são do ano atual
        // ou que são "Única" (podem não estar salvas ainda)
        for (final disp in this.disponibilidades) {
          if (disp.data.year != anoParaCarregar || disp.tipo == 'Única') {
            final chave =
                '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
            disponibilidadesFinais[chave] = disp;
          }
        }

        // Depois, adicionar as disponibilidades geradas/ordenadas (séries do ano atual + únicas do Firestore)
        for (final disp in listaOrdenada) {
          final chave =
              '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
          disponibilidadesFinais[chave] = disp;
        }

        // Atualizar lista completa
        final listaFinal = disponibilidadesFinais.values.toList();
        listaFinal.sort((a, b) => a.data.compareTo(b.data));
        disponibilidades.clear();
        disponibilidades.addAll(listaFinal);
      } else {
        // Se não há séries, ainda precisamos carregar disponibilidades "Única"
        List<Disponibilidade> dispsUnicas = [];
        try {
          final firestore = FirebaseFirestore.instance;
          final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
          final disponibilidadesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('ocupantes')
              .doc(medicoId)
              .collection('disponibilidades')
              .doc(anoParaCarregar.toString())
              .collection('registos');

          final snapshot =
              await disponibilidadesRef.where('tipo', isEqualTo: 'Única').get();

          dispsUnicas = snapshot.docs
              .map((doc) => Disponibilidade.fromMap(doc.data()))
              .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
              .toList();

          // CORREÇÃO: Mesclar com disponibilidades existentes (incluindo as que ainda não foram salvas)
          // Não limpar a lista completamente, apenas mesclar para não perder disponibilidades não salvas
          final disponibilidadesUnicas = <String, Disponibilidade>{};

          // Primeiro, adicionar todas as disponibilidades existentes (incluindo não salvas)
          for (final disp in this.disponibilidades) {
            final chave =
                '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
            disponibilidadesUnicas[chave] = disp;
          }

          // Depois, adicionar/sobrescrever com as do Firestore (já salvas)
          for (final dispUnica in dispsUnicas) {
            final chave =
                '${dispUnica.medicoId}_${dispUnica.data.year}-${dispUnica.data.month}-${dispUnica.data.day}_${dispUnica.tipo}';
            disponibilidadesUnicas[chave] = dispUnica;
          }

          // Atualizar apenas as disponibilidades "Única", mantendo as de séries
          final disponibilidadesFinais = <Disponibilidade>[];

          // Manter todas as disponibilidades de séries
          for (final disp in this.disponibilidades) {
            if (disp.id.startsWith('serie_')) {
              disponibilidadesFinais.add(disp);
            }
          }

          // Adicionar todas as disponibilidades "Única" (mescladas)
          disponibilidadesFinais.addAll(
              disponibilidadesUnicas.values.where((d) => d.tipo == 'Única'));

          final listaOrdenada = disponibilidadesFinais.toList();
          listaOrdenada.sort((a, b) => a.data.compareTo(b.data));

          // Atualizar a lista completa
          disponibilidades.clear();
          disponibilidades.addAll(listaOrdenada);
        } catch (e) {
          // Erro ao carregar disponibilidades únicas - continuar sem elas
        }
      }
    } catch (e) {
      print('❌ Erro ao carregar séries e gerar disponibilidades: $e');
    }

    // Atualizar estado - garantir que a barra de progresso seja visível até o final
    if (mounted) {
      // Atualizar progresso para 98% antes de finalizar
      setState(() {
        progressoCarregamentoDisponibilidades = 0.98;
        mensagemCarregamentoDisponibilidades = 'A concluir...';
      });

      // Pequeno delay para processar
      await Future.delayed(const Duration(milliseconds: 30));

      // Atualizar os dados
      if (mounted) {
        setState(() {
          this.disponibilidades = disponibilidades;
          // Atualiza os dias selecionados baseado nas disponibilidades carregadas
          diasSelecionados = disponibilidades.map((d) => d.data).toList();
          _anoVisualizado = anoParaCarregar; // Guarda o ano visualizado
          // Chegar a 100% e depois desligar
          progressoCarregamentoDisponibilidades = 1.0;
          mensagemCarregamentoDisponibilidades = 'Concluído!';
        });
      }

      // Pequeno delay para mostrar 100%
      await Future.delayed(const Duration(milliseconds: 50));

      // Desligar após mostrar 100%
      if (mounted) {
        setState(() {
          isLoadingDisponibilidades = false;
          progressoCarregamentoDisponibilidades = 0.0;
          mensagemCarregamentoDisponibilidades =
              'A carregar disponibilidades...';

          // CORREÇÃO: Guardar disponibilidades originais de forma síncrona
          // Isso garante que _disponibilidadesOriginal esteja sempre atualizada
          // quando o usuário cria novas disponibilidades
          _disponibilidadesOriginal = disponibilidades
              .map((d) => Disponibilidade.fromMap(d.toMap()))
              .toList();
        });
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
      // Criar série de recorrência
      try {
        final serie = await DisponibilidadeSerieService.criarSerie(
          medicoId: _medicoId,
          dataInicial: date,
          tipo: tipo,
          horarios: [], // Horários serão definidos depois
          unidade: widget.unidade,
          dataFim: null, // Série infinita
        );

        setState(() {
          series.add(serie);
        });

        // CORREÇÃO: Invalidar cache do dia de início da série para garantir que apareça no ecrã de alocação
        AlocacaoMedicosLogic.invalidateCacheForDay(date);
        // Invalidar também cache de séries para este médico e ano
        final anoSerie = date.year;
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoId, anoSerie);
        // Invalidar cache de todo o ano para garantir que apareça em todos os dias relevantes
        AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));

        // Gerar cartões visuais para o ano atual (para mostrar na UI)
        final geradas = criarDisponibilidadesSerie(
          date,
          tipo,
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

        // CORREÇÃO: Verificar mudanças após adicionar série recorrente
        // Isso garante que se uma disponibilidade "Única" foi adicionada antes,
        // ela seja detectada quando esta série é criada
        _verificarMudancas();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Série $tipo criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (tipo.startsWith('Consecutivo:')) {
      // Consecutivo também cria série
      final numeroDiasStr = tipo.split(':')[1];
      final numeroDias = int.tryParse(numeroDiasStr) ?? 5;

      try {
        final serie = await DisponibilidadeSerieService.criarSerie(
          medicoId: _medicoId,
          dataInicial: date,
          tipo: 'Consecutivo',
          horarios: [],
          unidade: widget.unidade,
          dataFim: date.add(Duration(days: numeroDias - 1)),
        );

        setState(() {
          series.add(serie);
        });

        // CORREÇÃO: Invalidar cache para garantir que apareça no ecrã de alocação
        AlocacaoMedicosLogic.invalidateCacheForDay(date);
        final anoSerie = date.year;
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoId, anoSerie);
        // Invalidar cache de todo o ano para garantir que apareça em todos os dias relevantes
        AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));

        // Gerar cartões visuais
        final geradas = criarDisponibilidadesSerie(
          date,
          tipo,
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
        _verificarMudancas();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Série Consecutiva criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Única: criar cartão individual (compatibilidade)
      final geradas = criarDisponibilidadesSerie(
        date,
        tipo,
        medicoId: _medicoId,
        limitarAoAno: true,
      );

      bool adicionouNova = false;
      for (final novaDisp in geradas) {
        if (!diasSelecionados.any((d) =>
            d.year == novaDisp.data.year &&
            d.month == novaDisp.data.month &&
            d.day == novaDisp.data.day)) {
          // CORREÇÃO: Adicionar à lista ANTES do setState para garantir que está disponível
          // quando _verificarMudancas() for chamado
          disponibilidades.add(novaDisp);
          diasSelecionados.add(novaDisp.data);
          adicionouNova = true;

          setState(() {
            // Apenas atualizar UI - dados já foram adicionados acima
          });
        }
      }

      if (adicionouNova) {
        // Ordenar disponibilidades antes de verificar mudanças
        disponibilidades.sort((a, b) => a.data.compareTo(b.data));

        setState(() {
          // Apenas atualizar UI - dados já foram ordenados acima
        });

        // CORREÇÃO CRÍTICA: Verificar mudanças IMEDIATAMENTE após adicionar
        // Não usar addPostFrameCallback porque pode ser muito tarde quando múltiplas séries são criadas
        // Chamar de forma síncrona para garantir detecção imediata
        // IMPORTANTE: Chamar DEPOIS do setState para garantir que a lista está atualizada
        _verificarMudancas();

        // CORREÇÃO ADICIONAL: Forçar atualização de _houveMudancas se detectou mudanças
        // Isso garante que mesmo que _verificarMudancas() não tenha atualizado corretamente,
        // a flag será atualizada aqui
        if (!_houveMudancas) {
          // Verificar novamente especificamente para disponibilidades "Única"
          final temUnicasNovas = disponibilidades
              .where((d) => d.tipo == 'Única' && d.medicoId == _medicoId)
              .any((d) => !_disponibilidadesOriginal.any((orig) =>
                  orig.id == d.id &&
                  orig.data.year == d.data.year &&
                  orig.data.month == d.data.month &&
                  orig.data.day == d.data.day &&
                  _listasIguais(orig.horarios, d.horarios)));

          if (temUnicasNovas) {
            setState(() {
              _houveMudancas = true;
            });
          }
        }
      }
    }

    // Atualiza cache do dia adicionado
    AlocacaoMedicosLogic.updateCacheForDay(
      day: DateTime(date.year, date.month, date.day),
      disponibilidades: disponibilidades,
    );
  }

  /// Remove data(s) do calendário, depois ordena a lista
  Future<void> _removerData(DateTime date, {bool removeSerie = false}) async {
    // Se está removendo a série inteira, encontrar e remover do Firestore
    if (removeSerie) {
      // Encontrar a disponibilidade na data para identificar a série
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

      // Se a disponibilidade é de uma série, encontrar e remover a série do Firestore
      if (disponibilidadeNaData.id.startsWith('serie_') &&
          disponibilidadeNaData.tipo != 'Única') {
        try {
          // Extrair o ID da série do ID da disponibilidade
          final dataKeyPattern = RegExp(r'_\d{4}-\d{2}-\d{2}$');
          final match = dataKeyPattern.firstMatch(disponibilidadeNaData.id);

          if (match != null) {
            final serieId = disponibilidadeNaData.id.substring(0, match.start);
            final serieIdFinal =
                serieId.startsWith('serie_') ? serieId : 'serie_$serieId';

            // Encontrar a série na lista local
            final serieEncontrada = series.firstWhere(
              (s) => s.id == serieIdFinal && s.ativo,
              orElse: () => SerieRecorrencia(
                id: '',
                medicoId: '',
                dataInicio: DateTime.now(),
                tipo: '',
                horarios: [],
              ),
            );

            // Se encontrou a série, remover do Firestore
            if (serieEncontrada.id.isNotEmpty) {
              await SerieService.removerSerie(
                serieEncontrada.id,
                _medicoId,
                unidade: widget.unidade,
                permanente: true, // Remover permanentemente
              );

              // CORREÇÃO: Invalidar cache para garantir que remoção apareça no ecrã de alocação
              final anoSerie = serieEncontrada.dataInicio.year;
              AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
                  _medicoId, anoSerie);
              AlocacaoMedicosLogic.invalidateCacheFromDate(
                  DateTime(anoSerie, 1, 1));

              // Remover da lista local
              setState(() {
                series.removeWhere((s) => s.id == serieEncontrada.id);
              });
            } else {
              // Se não encontrou pelo ID, tentar encontrar por tipo e data
              for (final serie in series) {
                if (serie.tipo == disponibilidadeNaData.tipo &&
                    serie.ativo &&
                    (serie.dataFim == null || serie.dataFim!.isAfter(date)) &&
                    serie.dataInicio
                        .isBefore(date.add(const Duration(days: 1)))) {
                  // Verificar se a data corresponde ao padrão da série
                  bool correspondeAoPadrao = false;
                  switch (serie.tipo) {
                    case 'Semanal':
                      correspondeAoPadrao =
                          date.weekday == serie.dataInicio.weekday;
                      break;
                    case 'Quinzenal':
                      final diffDias = date.difference(serie.dataInicio).inDays;
                      correspondeAoPadrao = diffDias >= 0 && diffDias % 14 == 0;
                      break;
                    case 'Mensal':
                      correspondeAoPadrao = date.day == serie.dataInicio.day;
                      break;
                    default:
                      correspondeAoPadrao = true;
                  }

                  if (correspondeAoPadrao) {
                    await SerieService.removerSerie(
                      serie.id,
                      _medicoId,
                      unidade: widget.unidade,
                      permanente: true,
                    );

                    // CORREÇÃO: Invalidar cache para garantir que remoção apareça no ecrã de alocação
                    final anoSerie = serie.dataInicio.year;
                    AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
                        _medicoId, anoSerie);
                    AlocacaoMedicosLogic.invalidateCacheFromDate(
                        DateTime(anoSerie, 1, 1));

                    setState(() {
                      series.removeWhere((s) => s.id == serie.id);
                    });

                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover série: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() {
      disponibilidades = removerDisponibilidade(
        disponibilidades,
        date,
        removeSerie: removeSerie,
      );
      // Re-atualiza a lista de dias
      diasSelecionados = disponibilidades.map((d) => d.data).toList();

      // **Ordena** novamente, só para garantir
      disponibilidades.sort((a, b) => a.data.compareTo(b.data));
    });

    // Verifica mudanças após remover dados
    _verificarMudancas();

    // Atualiza cache do dia removido
    AlocacaoMedicosLogic.updateCacheForDay(
      day: DateTime(date.year, date.month, date.day),
      disponibilidades: disponibilidades,
    );

    // Invalidar cache de séries para garantir que não apareçam ao recarregar
    if (removeSerie && _medicoAtual != null) {
      AlocacaoMedicosLogic.invalidateCacheFromDate(date);
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$seriesEncerradas série(s) encerrada(s) a partir de ${DateFormat('dd/MM/yyyy').format(dataEncerramento)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma série ativa para encerrar'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao encerrar séries: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      // CORREÇÃO: Invalidar cache para garantir que apareça no ecrã de alocação
      AlocacaoMedicosLogic.invalidateCacheForDay(dataNovaSerie);
      final anoSerie = dataNovaSerie.year;
      AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(_medicoId, anoSerie);
      // Invalidar cache de todo o ano para garantir que apareça em todos os dias relevantes
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao transformar série: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Série encerrada a partir de ${DateFormat('dd/MM/yyyy').format(dataEncerramento!)}'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encerrar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cria exceção de período geral (remove todos os cartões no período, independente das séries)
  Future<void> _criarExcecaoPeriodoGeral(
      DateTime dataInicio, DateTime dataFim) async {
    try {
      // Para cada série ativa, criar exceções para todas as datas do período que se aplicam à série
      int totalExcecoesCriadas = 0;

      for (final serie in series) {
        if (!serie.ativo) continue;

        DateTime dataAtual = dataInicio;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          // Verificar se a data está dentro da série
          if (dataAtual.isAfter(
                  serie.dataInicio.subtract(const Duration(days: 1))) &&
              (serie.dataFim == null ||
                  dataAtual
                      .isBefore(serie.dataFim!.add(const Duration(days: 1))))) {
            // Verificar se esta data corresponde à série (ex: se é semanal às quartas, só criar se for quarta)
            bool dataCorresponde = false;

            switch (serie.tipo) {
              case 'Semanal':
                // Verificar se é o mesmo dia da semana
                dataCorresponde = dataAtual.weekday == serie.dataInicio.weekday;
                break;
              case 'Quinzenal':
                // Verificar se a diferença em dias é múltiplo de 14
                final diff = dataAtual.difference(serie.dataInicio).inDays;
                dataCorresponde = diff >= 0 && diff % 14 == 0;
                break;
              case 'Mensal':
                // Verificar se é o mesmo dia do mês e mesma ocorrência do dia da semana
                final ocorrencia = _descobrirOcorrenciaNoMes(serie.dataInicio);
                final ocorrenciaAtual = _descobrirOcorrenciaNoMes(dataAtual);
                dataCorresponde =
                    dataAtual.weekday == serie.dataInicio.weekday &&
                        ocorrenciaAtual == ocorrencia;
                break;
              case 'Consecutivo':
                // Para consecutivo, verificar se está dentro do período consecutivo
                final numeroDias = serie.parametros['numeroDias'] as int? ?? 5;
                final diff = dataAtual.difference(serie.dataInicio).inDays;
                dataCorresponde = diff >= 0 && diff < numeroDias;
                break;
              default:
                // Para "Única", verificar se é a data exata
                dataCorresponde = dataAtual.year == serie.dataInicio.year &&
                    dataAtual.month == serie.dataInicio.month &&
                    dataAtual.day == serie.dataInicio.day;
            }

            if (dataCorresponde) {
              final excecaoId =
                  'excecao_${serie.id}_${dataAtual.millisecondsSinceEpoch}';

              // Verificar se já existe exceção para esta data
              final jaExiste = excecoes.any((e) =>
                  e.serieId == serie.id &&
                  e.data.year == dataAtual.year &&
                  e.data.month == dataAtual.month &&
                  e.data.day == dataAtual.day);

              if (!jaExiste) {
                final excecao = ExcecaoSerie(
                  id: excecaoId,
                  serieId: serie.id,
                  data: dataAtual,
                  cancelada: true,
                );

                // Salvar no Firestore
                await SerieService.salvarExcecao(excecao, _medicoId,
                    unidade: widget.unidade);

                setState(() {
                  excecoes.add(excecao);
                });

                totalExcecoesCriadas++;
              }
            }
          }

          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // Remover alocações e disponibilidades do Firestore para as datas do período
      // Isso garante que os cartões desapareçam do menu principal, quer estejam alocados ou não
      if (widget.unidade != null && _medicoAtual != null) {
        final firestore = FirebaseFirestore.instance;
        final unidadeId = widget.unidade!.id;
        DateTime dataAtual = dataInicio;

        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          final ano = dataAtual.year.toString();
          final inicio =
              DateTime(dataAtual.year, dataAtual.month, dataAtual.day);

          try {
            // Buscar e remover alocações do médico para esta data
            final alocacoesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('alocacoes')
                .doc(ano)
                .collection('registos');

            // Buscar alocações sem usar query composta (para evitar erro de índice)
            final todasAlocacoes = await alocacoesRef.get();
            final alocacoesParaRemover = todasAlocacoes.docs.where((doc) {
              final data = doc.data();
              final medicoIdAloc = data['medicoId']?.toString();
              final dataAloc = data['data']?.toString();
              if (medicoIdAloc != _medicoAtual!.id) return false;
              if (dataAloc == null) return false;
              try {
                final dataAlocDateTime = DateTime.parse(dataAloc);
                return dataAlocDateTime.year == inicio.year &&
                    dataAlocDateTime.month == inicio.month &&
                    dataAlocDateTime.day == inicio.day;
              } catch (e) {
                return false;
              }
            }).toList();

            // Remover todas as alocações encontradas
            for (final doc in alocacoesParaRemover) {
              await doc.reference.delete();
            }

            // CORREÇÃO CRÍTICA: Remover disponibilidades únicas do Firestore
            // As disponibilidades únicas são salvas em dois lugares:
            // 1. unidades/{unidadeId}/ocupantes/{medicoId}/disponibilidades/{ano}/registos
            // 2. unidades/{unidadeId}/dias/{dayKey}/disponibilidades (vista diária)

            // 1. Remover da coleção de ocupantes
            final disponibilidadesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('ocupantes')
                .doc(_medicoAtual!.id)
                .collection('disponibilidades')
                .doc(ano)
                .collection('registos');

            final todasDisponibilidades = await disponibilidadesRef.get();
            final disponibilidadesParaRemover =
                todasDisponibilidades.docs.where((doc) {
              final data = doc.data();
              final dataDisp = data['data']?.toString();
              final tipoDisp = data['tipo']?.toString();
              final medicoIdDisp = data['medicoId']?.toString();

              if (dataDisp == null ||
                  tipoDisp != 'Única' ||
                  medicoIdDisp != _medicoAtual!.id) {
                return false;
              }

              try {
                final dataDispDateTime = DateTime.parse(dataDisp);
                final corresponde = dataDispDateTime.year == inicio.year &&
                    dataDispDateTime.month == inicio.month &&
                    dataDispDateTime.day == inicio.day;
                return corresponde;
              } catch (e) {
                return false;
              }
            }).toList();

            // Remover todas as disponibilidades únicas encontradas
            for (final doc in disponibilidadesParaRemover) {
              await doc.reference.delete();

              // CORREÇÃO: Também remover da lista local de disponibilidades
              final dispId = doc.id;
              setState(() {
                disponibilidades.removeWhere((d) =>
                    d.id == dispId &&
                    d.tipo == 'Única' &&
                    d.data.year == inicio.year &&
                    d.data.month == inicio.month &&
                    d.data.day == inicio.day);
                _disponibilidadesOriginal.removeWhere((d) =>
                    d.id == dispId &&
                    d.tipo == 'Única' &&
                    d.data.year == inicio.year &&
                    d.data.month == inicio.month &&
                    d.data.day == inicio.day);
              });
            }

            // 2. Remover da vista diária (dias/{dayKey}/disponibilidades)
            final keyDia =
                '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
            final diasDisponibilidadesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('dias')
                .doc(keyDia)
                .collection('disponibilidades');

            final todasDisponibilidadesDias =
                await diasDisponibilidadesRef.get();
            final disponibilidadesDiasParaRemover =
                todasDisponibilidadesDias.docs.where((doc) {
              final data = doc.data();
              final medicoIdDisp = data['medicoId']?.toString();
              final tipoDisp = data['tipo']?.toString();
              if (medicoIdDisp != _medicoAtual!.id || tipoDisp != 'Única')
                return false;
              final dataDisp = data['data']?.toString();
              if (dataDisp == null) return false;
              try {
                final dataDispDateTime = DateTime.parse(dataDisp);
                return dataDispDateTime.year == inicio.year &&
                    dataDispDateTime.month == inicio.month &&
                    dataDispDateTime.day == inicio.day;
              } catch (e) {
                return false;
              }
            }).toList();

            // Remover todas as disponibilidades únicas da vista diária
            for (final doc in disponibilidadesDiasParaRemover) {
              await doc.reference.delete();
            }

            // Invalidar cache para esta data específica
            AlocacaoMedicosLogic.invalidateCacheFromDate(inicio);
          } catch (e) {
            // Erro ao remover disponibilidades - continuar
          }

          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // CORREÇÃO: Aguardar mais tempo para garantir que o Firestore processou todas as remoções
      // e que a Cloud Function teve tempo de atualizar a vista diária
      await Future.delayed(const Duration(milliseconds: 1500));

      // Invalidar cache de séries para este médico e ano
      if (widget.unidade != null && _medicoAtual != null) {
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoAtual!.id, _anoVisualizado);
        // Invalidar também o cache de disponibilidades do dia para forçar recarregamento no menu principal
        // Invalidar para todas as datas do período da exceção
        DateTime dataAtual = dataInicio;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          AlocacaoMedicosLogic.invalidateCacheForDay(dataAtual);
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // Recarregar disponibilidades para refletir as exceções
      if (widget.unidade != null && _medicoAtual != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      _verificarMudancas();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Exceção de período criada: $totalExcecoesCriadas exceção(ões) criada(s) para o período ${DateFormat('dd/MM/yyyy').format(dataInicio)} a ${DateFormat('dd/MM/yyyy').format(dataFim)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar exceção de período: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Descobre qual ocorrência do weekday no mês (ex: 1ª terça, 2ª terça)
  int _descobrirOcorrenciaNoMes(DateTime data) {
    final weekday = data.weekday;
    final ano = data.year;
    final mes = data.month;
    final dia = data.day;

    final weekdayDia1 = DateTime(ano, mes, 1).weekday;
    final offset = (weekday - weekdayDia1 + 7) % 7;
    final primeiroDesteMes = 1 + offset;
    final dif = dia - primeiroDesteMes;
    return 1 + (dif ~/ 7);
  }

  /// Cria exceção para cancelar um período de uma série (ex: férias)
  Future<void> _criarExcecaoPeriodo(
      SerieRecorrencia serie, DateTime dataInicio, DateTime dataFim) async {
    try {
      // Criar exceção para cada data do período
      DateTime dataAtual = dataInicio;
      int excecoesCriadas = 0;

      while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
        // Verificar se a data está dentro da série
        if (dataAtual
                .isAfter(serie.dataInicio.subtract(const Duration(days: 1))) &&
            (serie.dataFim == null ||
                dataAtual
                    .isBefore(serie.dataFim!.add(const Duration(days: 1))))) {
          final excecaoId =
              'excecao_${serie.id}_${dataAtual.millisecondsSinceEpoch}';

          // Verificar se já existe exceção para esta data
          final jaExiste = excecoes.any((e) =>
              e.serieId == serie.id &&
              e.data.year == dataAtual.year &&
              e.data.month == dataAtual.month &&
              e.data.day == dataAtual.day);

          if (!jaExiste) {
            final excecao = ExcecaoSerie(
              id: excecaoId,
              serieId: serie.id,
              data: dataAtual,
              cancelada: true,
            );

            // Salvar no Firestore
            await SerieService.salvarExcecao(excecao, _medicoId,
                unidade: widget.unidade);

            setState(() {
              excecoes.add(excecao);
            });

            excecoesCriadas++;
          }
        }

        dataAtual = dataAtual.add(const Duration(days: 1));
      }

      // Remover alocações e disponibilidades do Firestore para as datas com exceções
      // Isso garante que os cartões desapareçam do menu principal, quer estejam alocados ou não
      if (widget.unidade != null && _medicoAtual != null) {
        final firestore = FirebaseFirestore.instance;
        final unidadeId = widget.unidade!.id;
        DateTime dataAtual = dataInicio;

        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1)))) {
          // Verificar se a data está dentro da série e se foi criada uma exceção
          if (dataAtual.isAfter(
                  serie.dataInicio.subtract(const Duration(days: 1))) &&
              (serie.dataFim == null ||
                  dataAtual
                      .isBefore(serie.dataFim!.add(const Duration(days: 1))))) {
            final ano = dataAtual.year.toString();
            final inicio =
                DateTime(dataAtual.year, dataAtual.month, dataAtual.day);

            try {
              // Buscar e remover alocações do médico para esta data
              final alocacoesRef = firestore
                  .collection('unidades')
                  .doc(unidadeId)
                  .collection('alocacoes')
                  .doc(ano)
                  .collection('registos');

              // Buscar alocações sem usar query composta (para evitar erro de índice)
              final todasAlocacoes = await alocacoesRef.get();
              final alocacoesParaRemover = todasAlocacoes.docs.where((doc) {
                final data = doc.data();
                final medicoIdAloc = data['medicoId']?.toString();
                final dataAloc = data['data']?.toString();
                if (medicoIdAloc != _medicoAtual!.id) return false;
                if (dataAloc == null) return false;
                try {
                  final dataAlocDateTime = DateTime.parse(dataAloc);
                  return dataAlocDateTime.year == inicio.year &&
                      dataAlocDateTime.month == inicio.month &&
                      dataAlocDateTime.day == inicio.day;
                } catch (e) {
                  return false;
                }
              }).toList();

              // Remover todas as alocações encontradas
              for (final doc in alocacoesParaRemover) {
                await doc.reference.delete();
              }

              // Buscar e remover disponibilidades individuais do Firestore para esta data
              final disponibilidadesRef = firestore
                  .collection('unidades')
                  .doc(unidadeId)
                  .collection('ocupantes')
                  .doc(_medicoAtual!.id)
                  .collection('disponibilidades')
                  .doc(ano)
                  .collection('registos');

              final todasDisponibilidades = await disponibilidadesRef.get();
              final disponibilidadesParaRemover =
                  todasDisponibilidades.docs.where((doc) {
                final data = doc.data();
                final dataDisp = data['data']?.toString();
                if (dataDisp == null) return false;
                try {
                  final dataDispDateTime = DateTime.parse(dataDisp);
                  return dataDispDateTime.year == inicio.year &&
                      dataDispDateTime.month == inicio.month &&
                      dataDispDateTime.day == inicio.day;
                } catch (e) {
                  return false;
                }
              }).toList();

              // Remover todas as disponibilidades encontradas
              for (final doc in disponibilidadesParaRemover) {
                await doc.reference.delete();
              }

              // Invalidar cache para esta data específica
              AlocacaoMedicosLogic.invalidateCacheFromDate(inicio);
            } catch (e) {}
          }

          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // Aguardar um pouco para garantir que o Firestore processou todas as exceções
      await Future.delayed(const Duration(milliseconds: 200));

      // Invalidar cache de séries para este médico e ano
      if (widget.unidade != null && _medicoAtual != null) {
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoAtual!.id, _anoVisualizado);
        // Invalidar também o cache de disponibilidades do dia para forçar recarregamento no menu principal
        // Invalidar para todas as datas do período da exceção
        DateTime dataAtual = dataInicio;
        while (dataAtual.isBefore(dataFim.add(const Duration(days: 1))) &&
            dataAtual
                .isAfter(serie.dataInicio.subtract(const Duration(days: 1))) &&
            (serie.dataFim == null ||
                dataAtual
                    .isBefore(serie.dataFim!.add(const Duration(days: 1))))) {
          AlocacaoMedicosLogic.invalidateCacheForDay(dataAtual);
          dataAtual = dataAtual.add(const Duration(days: 1));
        }
      }

      // Recarregar disponibilidades para refletir as exceções
      // IMPORTANTE: Isso vai recarregar as exceções do Firestore e gerar disponibilidades sem as datas canceladas
      if (widget.unidade != null && _medicoAtual != null) {
        await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
            ano: _anoVisualizado);
      }

      _verificarMudancas();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Exceção criada para $excecoesCriadas dia(s): ${DateFormat('dd/MM/yyyy').format(dataInicio)} a ${DateFormat('dd/MM/yyyy').format(dataFim)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar exceção: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Agrupa exceções por período (datas consecutivas)
  List<Map<String, dynamic>> _agruparExcecoesPorPeriodo() {
    if (excecoes.isEmpty) return [];

    // Ordenar exceções por data
    final excecoesOrdenadas = List<ExcecaoSerie>.from(excecoes);
    excecoesOrdenadas.sort((a, b) => a.data.compareTo(b.data));

    final grupos = <Map<String, dynamic>>[];
    List<ExcecaoSerie>? grupoAtual;
    DateTime? dataFimGrupo;

    for (final excecao in excecoesOrdenadas) {
      if (grupoAtual == null) {
        // Iniciar novo grupo
        grupoAtual = [excecao];
        dataFimGrupo = excecao.data;
      } else {
        // Verificar se é data consecutiva (mesma série e data seguinte)
        final ultimaData = dataFimGrupo!;
        final dataEsperada = ultimaData.add(const Duration(days: 1));
        final mesmaSerie = grupoAtual.first.serieId == excecao.serieId;
        final dataConsecutiva = excecao.data.year == dataEsperada.year &&
            excecao.data.month == dataEsperada.month &&
            excecao.data.day == dataEsperada.day;

        if (mesmaSerie && dataConsecutiva) {
          // Adicionar ao grupo atual
          grupoAtual.add(excecao);
          dataFimGrupo = excecao.data;
        } else {
          // Finalizar grupo atual e iniciar novo
          final serie = series.firstWhere(
            (s) => s.id == grupoAtual!.first.serieId,
            orElse: () => series.isNotEmpty
                ? series.first
                : SerieRecorrencia(
                    id: '',
                    medicoId: '',
                    dataInicio: DateTime.now(),
                    tipo: '',
                    horarios: [],
                  ),
          );

          grupos.add({
            'excecoes': List<ExcecaoSerie>.from(grupoAtual),
            'serie': serie,
            'dataInicio': grupoAtual.first.data,
            'dataFim': dataFimGrupo,
            'isPeriodo': grupoAtual.length > 1,
          });

          grupoAtual = [excecao];
          dataFimGrupo = excecao.data;
        }
      }
    }

    // Adicionar último grupo
    if (grupoAtual != null && grupoAtual.isNotEmpty) {
      final serie = series.firstWhere(
        (s) => s.id == grupoAtual!.first.serieId,
        orElse: () => series.isNotEmpty
            ? series.first
            : SerieRecorrencia(
                id: '',
                medicoId: '',
                dataInicio: DateTime.now(),
                tipo: '',
                horarios: [],
              ),
      );

      grupos.add({
        'excecoes': grupoAtual,
        'serie': serie,
        'dataInicio': grupoAtual.first.data,
        'dataFim': dataFimGrupo!,
        'isPeriodo': grupoAtual.length > 1,
      });
    }

    return grupos;
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

      // Invalidar cache de séries para este médico e ano
      if (_medicoAtual != null && _anoVisualizado != null) {
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoAtual!.id, _anoVisualizado);
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${excecoesParaRemover.length} exceção(ões) removida(s) com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        progressoSaving = 0.0;
        mensagemSaving = 'A guardar...';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover exceções: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Disponibilidade salva!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

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
        // Estratégia 1: Usar regex para encontrar o dataKey no final
        final dataKeyPattern = RegExp(r'_\d{4}-\d{2}-\d{2}$');
        final match = dataKeyPattern.firstMatch(disponibilidade.id);

        if (match != null) {
          // Extrair o ID da série (tudo antes do underscore + dataKey)
          final serieId = disponibilidade.id.substring(0, match.start);
          // Remover o prefixo 'serie_' inicial se presente
          final serieIdFinal =
              serieId.startsWith('serie_') ? serieId : 'serie_$serieId';

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
        }

        // Estratégia 2: Se não encontrou, tentar correspondência parcial
        // Isso garante compatibilidade com formatos antigos ou variações
        if (serieEncontrada == null || serieEncontrada.id.isEmpty) {
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
          bool correspondeAoPadrao = false;

          switch (serie.tipo) {
            case 'Semanal':
              // Para semanal, verificar se o dia da semana corresponde
              correspondeAoPadrao =
                  disponibilidade.data.weekday == serie.dataInicio.weekday;
              break;
            case 'Quinzenal':
              // Para quinzenal, verificar se a diferença em dias é múltipla de 14
              final diffDias =
                  disponibilidade.data.difference(serie.dataInicio).inDays;
              correspondeAoPadrao = diffDias >= 0 && diffDias % 14 == 0;
              break;
            case 'Mensal':
              // Para mensal, verificar se o dia do mês corresponde
              correspondeAoPadrao =
                  disponibilidade.data.day == serie.dataInicio.day;
              break;
            default:
              // Para outros tipos, apenas verificar se está no período
              correspondeAoPadrao = true;
          }

          if (correspondeAoPadrao) {
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

        print('✅ Série atualizada com novos horários: ${serieAtualizada.id}');

        // CORREÇÃO: Invalidar cache para garantir que mudanças apareçam no ecrã de alocação
        final anoSerie = serieAtualizada.dataInicio.year;
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(
            _medicoId, anoSerie);
        AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));

        if (mounted) {
          setState(() {
            progressoAtualizandoHorarios = 0.8;
            mensagemAtualizandoHorarios = 'A atualizar disponibilidades...';
          });
        }

        // Recarregar disponibilidades para refletir os novos horários
        if (_medicoAtual != null && _anoVisualizado != null) {
          await _carregarDisponibilidadesFirestore(_medicoAtual!.id,
              ano: _anoVisualizado);
        }

        if (mounted) {
          setState(() {
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horários atualizados na série!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('⚠️ Série não encontrada para atualizar horários');
        if (mounted) {
          setState(() {
            _atualizandoHorarios = false;
            progressoAtualizandoHorarios = 0.0;
            mensagemAtualizandoHorarios = 'A atualizar horários...';
          });
        }
      }
    } catch (e) {
      print('❌ Erro ao atualizar série com horários: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar série: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduza o nome do médico')),
      );
      return; // Interrompe o processo de salvar
    }

    final medico = Medico(
      id: _medicoId,
      nome: nomeController.text, // Captura o nome
      especialidade: especialidadeController.text, // Captura a especialidade
      observacoes: observacoesController.text, // Captura observações
      disponibilidades:
          disponibilidades, // Adiciona as disponibilidades (para compatibilidade)
      ativo: true, // CORREÇÃO: Garantir que novos médicos sejam sempre ativos
    );

    try {
      setState(() => _saving = true);

      // Salvar médico e disponibilidades antigas (compatibilidade)
      await salvarMedicoCompleto(
        medico,
        unidade: widget.unidade,
        disponibilidadesOriginais: _disponibilidadesOriginal,
      );

      // Salvar séries de recorrência (novo modelo)
      for (final serie in series) {
        // Atualizar horários da série se foram modificados
        final serieComHorarios = SerieRecorrencia(
          id: serie.id,
          medicoId: serie.medicoId,
          dataInicio: serie.dataInicio,
          dataFim: serie.dataFim,
          tipo: serie.tipo,
          horarios: serie.horarios, // Manter horários da série
          gabineteId: serie.gabineteId,
          parametros: serie.parametros,
          ativo: serie.ativo,
        );
        await SerieService.salvarSerie(serieComHorarios,
            unidade: widget.unidade);
      }

      // CORREÇÃO: Salvar disponibilidades "Única" no Firestore
      // Disponibilidades "Única" não são séries, então precisam ser salvas diretamente
      final firestore = FirebaseFirestore.instance;
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      int unicasSalvas = 0;

      for (final disp in disponibilidades) {
        if (disp.tipo == 'Única' && disp.medicoId == _medicoId) {
          try {
            final ano = disp.data.year.toString();
            final disponibilidadesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('ocupantes')
                .doc(_medicoId)
                .collection('disponibilidades')
                .doc(ano)
                .collection('registos');

            await disponibilidadesRef.doc(disp.id).set(disp.toMap());
            unicasSalvas++;
          } catch (e) {
            // Erro ao salvar disponibilidade única - continuar com as outras
          }
        }
      }

      // CORREÇÃO CRÍTICA: Aguardar um pouco para dar tempo à Cloud Function atualizar a vista diária
      // Isso garante que quando invalidarmos o cache, os dados já estarão atualizados
      await Future.delayed(const Duration(milliseconds: 1000));

      // Salvar exceções
      for (final excecao in excecoes) {
        await SerieService.salvarExcecao(excecao, _medicoId,
            unidade: widget.unidade);
      }

      if (!mounted) return;

      // Reseta as mudanças após salvar com sucesso
      _nomeOriginal = nomeController.text.trim();
      _especialidadeOriginal = especialidadeController.text.trim();
      _observacoesOriginal = observacoesController.text.trim();
      _disponibilidadesOriginal = List.from(disponibilidades);
      setState(() {
        _houveMudancas = false;
        // Atualizar médico atual após salvar
        _medicoAtual = medico;
      });

      // CORREÇÃO CRÍTICA: Invalidar cache DEPOIS de salvar para garantir que será recarregado
      // Invalidar cache dos dias das disponibilidades
      for (final disp in disponibilidades) {
        final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
        AlocacaoMedicosLogic.invalidateCacheForDay(d);
      }

      // CORREÇÃO CRÍTICA: Invalidar cache de séries para TODOS os dias do ano atual
      // Isso garante que séries criadas apareçam em todos os dias relevantes
      final anoAtual = DateTime.now().year;
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoAtual, 1, 1));

      // CORREÇÃO ADICIONAL: Invalidar também cache de séries para o próximo ano
      // (caso haja séries que se estendam para o próximo ano)
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(anoAtual + 1, 1, 1));

      // CORREÇÃO: Invalidar cache de médicos ativos para garantir que o novo médico apareça na lista
      if (widget.unidade != null) {
        AlocacaoMedicosLogic.invalidateMedicosAtivosCache(
            unidadeId: widget.unidade!.id);

        // CORREÇÃO CRÍTICA: Invalidar também o cache de séries para o novo médico
        // Isso garante que as séries sejam recarregadas quando necessário
        // Invalidar para TODOS os anos para garantir que apareça em todos os dias
        AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(_medicoId, null);
      }

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

    final medico = Medico(
      id: _medicoId,
      nome: nomeController.text, // Captura o nome
      especialidade: especialidadeController.text, // Captura a especialidade
      observacoes: observacoesController.text, // Captura observações
      disponibilidades:
          disponibilidades, // Adiciona as disponibilidades (compatibilidade)
    );

    try {
      setState(() => _saving = true);

      // Salvar médico e disponibilidades antigas (compatibilidade)
      await salvarMedicoCompleto(
        medico,
        unidade: widget.unidade,
        disponibilidadesOriginais: _disponibilidadesOriginal,
      );

      // Salvar séries de recorrência (novo modelo)
      for (final serie in series) {
        final serieComHorarios = SerieRecorrencia(
          id: serie.id,
          medicoId: serie.medicoId,
          dataInicio: serie.dataInicio,
          dataFim: serie.dataFim,
          tipo: serie.tipo,
          horarios: serie.horarios,
          gabineteId: serie.gabineteId,
          parametros: serie.parametros,
          ativo: serie.ativo,
        );
        await SerieService.salvarSerie(serieComHorarios,
            unidade: widget.unidade);
      }

      // CORREÇÃO: Salvar disponibilidades "Única" no Firestore
      // Disponibilidades "Única" não são séries, então precisam ser salvas diretamente
      final firestore = FirebaseFirestore.instance;
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';

      int unicasSalvas = 0;

      for (final disp in disponibilidades) {
        if (disp.tipo == 'Única' && disp.medicoId == _medicoId) {
          try {
            final ano = disp.data.year.toString();
            final disponibilidadesRef = firestore
                .collection('unidades')
                .doc(unidadeId)
                .collection('ocupantes')
                .doc(_medicoId)
                .collection('disponibilidades')
                .doc(ano)
                .collection('registos');

            await disponibilidadesRef.doc(disp.id).set(disp.toMap());
            unicasSalvas++;
          } catch (e) {}
        }
      }

      // CORREÇÃO CRÍTICA: Aguardar um pouco para dar tempo à Cloud Function atualizar a vista diária
      // Isso garante que quando invalidarmos o cache, os dados já estarão atualizados
      await Future.delayed(const Duration(milliseconds: 1000));

      // Salvar exceções
      for (final excecao in excecoes) {
        await SerieService.salvarExcecao(excecao, _medicoId,
            unidade: widget.unidade);
      }

      if (!mounted) return false;

      // CORREÇÃO CRÍTICA: Invalidar cache ANTES de resetar mudanças
      // Invalidar cache dos dias das disponibilidades
      for (final disp in disponibilidades) {
        final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
        AlocacaoMedicosLogic.invalidateCacheForDay(d);
      }

      // CORREÇÃO CRÍTICA: Invalidar cache de séries para TODOS os anos relevantes
      // Isso garante que séries criadas apareçam em todos os dias relevantes
      final anoAtual = DateTime.now().year;
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoAtual, 1, 1));
      AlocacaoMedicosLogic.invalidateCacheFromDate(
          DateTime(anoAtual + 1, 1, 1));

      // Invalidar cache de séries para este médico (todos os anos)
      AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(_medicoId, null);

      // Reseta as mudanças após salvar com sucesso
      _nomeOriginal = nomeController.text.trim();
      _especialidadeOriginal = especialidadeController.text.trim();
      _observacoesOriginal = observacoesController.text.trim();
      _disponibilidadesOriginal = List.from(disponibilidades);
      setState(() {
        _houveMudancas = false;
        // Atualizar médico atual após salvar
        _medicoAtual = medico;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Médico criado com sucesso! Agora pode criar disponibilidades.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar médico: $e')),
      );
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
        // Isso garante que _houveMudancas esteja atualizado mesmo quando múltiplas séries são criadas
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _medicoAtual == null ? 'Novo Médico' : 'Editar Médico',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_medicoAtual != null && _listaMedicos.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: SizedBox(
                    width: 260,
                    child: _carregandoMedicos
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : Autocomplete<Medico>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              final texto =
                                  textEditingValue.text.toLowerCase().trim();
                              if (texto.isEmpty) {
                                return _listaMedicos;
                              }
                              return _listaMedicos.where((medico) =>
                                  medico.nome.toLowerCase().contains(texto));
                            },
                            displayStringForOption: (Medico medico) =>
                                medico.nome,
                            onSelected: (Medico medico) {
                              _mudarMedico(medico);
                            },
                            fieldViewBuilder: (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // Sincronizar com o controller local
                              if (textEditingController.text !=
                                  _medicoAutocompleteController.text) {
                                textEditingController.text =
                                    _medicoAutocompleteController.text;
                              }

                              // Criar um StatefulBuilder para atualizar o botão X
                              return StatefulBuilder(
                                builder: (context, setStateLocal) {
                                  // Adicionar listener para atualizar o botão X
                                  textEditingController.addListener(() {
                                    if (textEditingController.text !=
                                        _medicoAutocompleteController.text) {
                                      _medicoAutocompleteController.text =
                                          textEditingController.text;
                                    }
                                    setStateLocal(() {});
                                  });

                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Pesquisar médico...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                      isDense: true,
                                      suffixIcon: textEditingController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                size: 18,
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                              ),
                                              onPressed: () {
                                                textEditingController.clear();
                                                _medicoAutocompleteController
                                                    .clear();
                                                setStateLocal(() {});
                                                focusNode.requestFocus();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            )
                                          : null,
                                    ),
                                    onSubmitted: (String value) {
                                      onFieldSubmitted();
                                    },
                                  );
                                },
                              );
                            },
                            optionsViewBuilder: (
                              BuildContext context,
                              AutocompleteOnSelected<Medico> onSelected,
                              Iterable<Medico> options,
                            ) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8.0,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
                                      maxWidth: 300,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final Medico medico =
                                            options.elementAt(index);
                                        final bool isSelected =
                                            _medicoAtual != null &&
                                                medico.id == _medicoAtual!.id;
                                        return InkWell(
                                          onTap: () {
                                            onSelected(medico);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 12.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue.withOpacity(0.2)
                                                  : Colors.transparent,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    medico.nome,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isSelected
                                                          ? Colors.blue[900]
                                                          : Colors.black87,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check,
                                                    size: 18,
                                                    color: Colors.blue[900],
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
                            },
                          ),
                  ),
                ),
                if (_medicoAtual != null && _anoVisualizado != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    _anoVisualizado.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              tooltip: 'Salvar',
              onPressed: () => _salvarMedico(),
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
            // LinearProgressIndicator no topo quando carregando disponibilidades (mais suave)
            if (isLoadingDisponibilidades && !_saving && !_atualizandoHorarios)
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
            Padding(
              padding: EdgeInsets.only(
                top: (isLoadingDisponibilidades &&
                        !_saving &&
                        !_atualizandoHorarios)
                    ? 3
                    : 0,
                left: 16.0,
                right: 16.0,
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
                                      const SizedBox(height: 16),
                                      // Seção de Exceções (abaixo do calendário)
                                      if (series.isNotEmpty)
                                        Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 16),
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
                                                      'Exceções',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    // Botão para criar exceções
                                                    ElevatedButton.icon(
                                                      icon: const Icon(
                                                          Icons.block,
                                                          color: Colors.white,
                                                          size: 16),
                                                      label: const Text(
                                                          'Criar Exceção',
                                                          style: TextStyle(
                                                              fontSize: 12)),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.orange,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
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
                                                        } else if (tipoExcecao ==
                                                            'serie') {
                                                          // Comportamento original: criar exceção para uma série específica
                                                          if (series.isEmpty) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                    'Não há séries cadastradas'),
                                                                backgroundColor:
                                                                    Colors
                                                                        .orange,
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
                                                                serie: series
                                                                    .first,
                                                                onConfirmar:
                                                                    (dataInicio,
                                                                        dataFim) {
                                                                  _criarExcecaoPeriodo(
                                                                      series
                                                                          .first,
                                                                      dataInicio,
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
                                                                content:
                                                                    SizedBox(
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
                                                                            Text('Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                                                                        onTap: () => Navigator.pop(
                                                                            context,
                                                                            serie),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                            if (serieEscolhida !=
                                                                null) {
                                                              await showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) =>
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
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                if (excecoes.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  ..._agruparExcecoesPorPeriodo()
                                                      .map((grupo) {
                                                    final excecoesGrupo = grupo[
                                                            'excecoes']
                                                        as List<ExcecaoSerie>;
                                                    final serie = grupo['serie']
                                                        as SerieRecorrencia;
                                                    final dataInicio =
                                                        grupo['dataInicio']
                                                            as DateTime;
                                                    final dataFim =
                                                        grupo['dataFim']
                                                            as DateTime;
                                                    final isPeriodo =
                                                        grupo['isPeriodo']
                                                            as bool;

                                                    String textoData;
                                                    if (isPeriodo) {
                                                      textoData =
                                                          '${DateFormat('dd/MM/yyyy').format(dataInicio)} - ${DateFormat('dd/MM/yyyy').format(dataFim)}';
                                                    } else {
                                                      textoData = DateFormat(
                                                              'dd/MM/yyyy')
                                                          .format(dataInicio);
                                                    }

                                                    return ListTile(
                                                      dense: true,
                                                      title: Text(
                                                        '$textoData - ${serie.tipo}',
                                                        style: const TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                      subtitle: Text(
                                                        excecoesGrupo
                                                                .first.cancelada
                                                            ? 'Cancelada'
                                                            : 'Modificada',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: excecoesGrupo
                                                                  .first
                                                                  .cancelada
                                                              ? Colors.red
                                                              : Colors.orange,
                                                        ),
                                                      ),
                                                      trailing: IconButton(
                                                        icon: const Icon(
                                                            Icons.delete,
                                                            size: 18),
                                                        color: Colors.red,
                                                        onPressed: () async {
                                                          // Remover todas as exceções do grupo de uma vez
                                                          await _removerExcecoesEmLote(
                                                              excecoesGrupo);
                                                        },
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
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
                                                d.data.year == _anoVisualizado)
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
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FormularioMedico(
                                  nomeController: nomeController,
                                  especialidadeController:
                                      especialidadeController,
                                  observacoesController: observacoesController,
                                  unidade: widget.unidade,
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Séries de Recorrência',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.block,
                                                    color: Colors.white),
                                                label: const Text(
                                                    'Criar Exceção (Férias/Interrupção)'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                ),
                                                onPressed: () async {
                                                  // Mostrar diálogo para escolher tipo de exceção
                                                  final tipoExcecao =
                                                      await showDialog<String>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Tipo de Exceção'),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: const Icon(
                                                                Icons
                                                                    .calendar_today,
                                                                color: Colors
                                                                    .orange),
                                                            title: const Text(
                                                                'Exceção de Período'),
                                                            subtitle: const Text(
                                                                'Remove todos os cartões no período selecionado (ex: congresso, férias)'),
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    'periodo'),
                                                          ),
                                                          const Divider(),
                                                          ListTile(
                                                            leading: const Icon(
                                                                Icons.repeat,
                                                                color: Colors
                                                                    .blue),
                                                            title: const Text(
                                                                'Exceção de Série'),
                                                            subtitle: const Text(
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
                                                        dataInicialMinima: null,
                                                        dataFinalMaxima: null,
                                                        onConfirmar:
                                                            (dataInicio,
                                                                dataFim) {
                                                          _criarExcecaoPeriodoGeral(
                                                              dataInicio,
                                                              dataFim);
                                                        },
                                                      ),
                                                    );
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

                                                    if (series.length == 1) {
                                                      await showDialog(
                                                        context: context,
                                                        builder: (context) =>
                                                            DialogoExcecaoSerie(
                                                          serie: series.first,
                                                          onConfirmar:
                                                              (dataInicio,
                                                                  dataFim) {
                                                            _criarExcecaoPeriodo(
                                                                series.first,
                                                                dataInicio,
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
                                                        builder: (context) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              'Selecionar Série'),
                                                          content: SizedBox(
                                                            width: double
                                                                .maxFinite,
                                                            child: ListView
                                                                .builder(
                                                              shrinkWrap: true,
                                                              itemCount:
                                                                  series.length,
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
                                                                  subtitle: Text(
                                                                      'Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                                                                  onTap: () =>
                                                                      Navigator.pop(
                                                                          context,
                                                                          serie),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      );
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
                                            } else if (serie.tipo == 'Mensal') {
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
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4.0),
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
                                                      child:
                                                          ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons.block,
                                                            size: 18),
                                                        label: const Text(
                                                            'Exceção'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.orange,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          minimumSize:
                                                              const Size(0, 32),
                                                        ),
                                                        onPressed: () async {
                                                          await showDialog(
                                                            context: context,
                                                            builder: (context) =>
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
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.swap_horiz,
                                                          color: Colors.blue),
                                                      tooltip:
                                                          'Transformar/Substituir série',
                                                      onPressed: () async {
                                                        await _mostrarDialogoTransformarSerie(
                                                            serie);
                                                      },
                                                    ),
                                                    if (serie.dataFim == null)
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.stop,
                                                            color: Colors.red),
                                                        tooltip:
                                                            'Encerrar esta série',
                                                        onPressed: () async {
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
                                if (series.isNotEmpty)
                                  Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Exceções',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              // Botão para criar exceções
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.block,
                                                    color: Colors.white,
                                                    size: 16),
                                                label: const Text(
                                                    'Criar Exceção',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                ),
                                                onPressed: () async {
                                                  // Se houver apenas uma série, abrir diretamente
                                                  if (series.length == 1) {
                                                    await showDialog(
                                                      context: context,
                                                      builder: (context) =>
                                                          DialogoExcecaoSerie(
                                                        serie: series.first,
                                                        onConfirmar:
                                                            (dataInicio,
                                                                dataFim) {
                                                          _criarExcecaoPeriodo(
                                                              series.first,
                                                              dataInicio,
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
                                                      builder: (context) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                            'Selecionar Série'),
                                                        content: SizedBox(
                                                          width:
                                                              double.maxFinite,
                                                          child:
                                                              ListView.builder(
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                series.length,
                                                            itemBuilder:
                                                                (context,
                                                                    index) {
                                                              final serie =
                                                                  series[index];
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
                                                                subtitle: Text(
                                                                    'Desde ${DateFormat('dd/MM/yyyy').format(serie.dataInicio)}'),
                                                                onTap: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        serie),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                    if (serieEscolhida !=
                                                        null) {
                                                      await showDialog(
                                                        context: context,
                                                        builder: (context) =>
                                                            DialogoExcecaoSerie(
                                                          serie: serieEscolhida,
                                                          onConfirmar:
                                                              (dataInicio,
                                                                  dataFim) {
                                                            _criarExcecaoPeriodo(
                                                                serieEscolhida,
                                                                dataInicio,
                                                                dataFim);
                                                          },
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          if (excecoes.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ..._agruparExcecoesPorPeriodo()
                                                .map((grupo) {
                                              final excecoesGrupo =
                                                  grupo['excecoes']
                                                      as List<ExcecaoSerie>;
                                              final serie = grupo['serie']
                                                  as SerieRecorrencia;
                                              final dataInicio =
                                                  grupo['dataInicio']
                                                      as DateTime;
                                              final dataFim =
                                                  grupo['dataFim'] as DateTime;
                                              final isPeriodo =
                                                  grupo['isPeriodo'] as bool;

                                              String textoData;
                                              if (isPeriodo) {
                                                textoData =
                                                    '${DateFormat('dd/MM/yyyy').format(dataInicio)} - ${DateFormat('dd/MM/yyyy').format(dataFim)}';
                                              } else {
                                                textoData =
                                                    DateFormat('dd/MM/yyyy')
                                                        .format(dataInicio);
                                              }

                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  '$textoData - ${serie.tipo}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                subtitle: Text(
                                                  excecoesGrupo.first.cancelada
                                                      ? 'Cancelada'
                                                      : 'Modificada',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: excecoesGrupo
                                                            .first.cancelada
                                                        ? Colors.red
                                                        : Colors.orange,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      size: 18),
                                                  color: Colors.red,
                                                  onPressed: () async {
                                                    // Remover todas as exceções do grupo
                                                    for (final excecao
                                                        in excecoesGrupo) {
                                                      await _removerExcecao(
                                                          excecao);
                                                    }
                                                  },
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 300),
                                  child: DisponibilidadesGrid(
                                    disponibilidades: _anoVisualizado != null
                                        ? disponibilidades
                                            .where((d) =>
                                                d.data.year == _anoVisualizado)
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
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Botão de Salvar removido, pois salvamos ao sair
                              ],
                            ),
                          )),
              ),
            ),
            // Overlay de salvamento (semi-transparente como na tela de alocação)
            if (_saving)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.35),
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
                                      Colors.white.withOpacity(0.3),
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
                  color: Colors.black.withOpacity(0.35),
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
                                      Colors.white.withOpacity(0.3),
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
          ],
        ),
      ),
    );
  }

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
