import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/gabinete.dart';
import '../models/unidade.dart';
import '../models/disponibilidade.dart';
import '../services/medico_salvar_service.dart';
import '../services/gabinete_service.dart';
import '../widgets/date_picker_customizado.dart';
import '../utils/alocacao_medicos_logic.dart' as logic;
import '../services/disponibilidade_unica_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';

/// Tela para listar e gerir todas as alocações da base de dados
/// Permite filtrar por nome de médico e data, e ordenar por gabinete, médico ou data
class ListaAlocacoesScreen extends StatefulWidget {
  final Unidade? unidade;

  const ListaAlocacoesScreen({super.key, this.unidade});

  @override
  State<ListaAlocacoesScreen> createState() => _ListaAlocacoesScreenState();
}

class _ListaAlocacoesScreenState extends State<ListaAlocacoesScreen> {
  List<Alocacao> todasAlocacoes = [];
  List<Alocacao> alocacoesFiltradas = [];
  List<Alocacao> todasAlocacoesCarregadas =
      []; // Todas as alocações sem filtro de ano
  List<Disponibilidade> todasDisponibilidadesCarregadas =
      []; // Todas as disponibilidades sem filtro de ano
  List<Medico> medicos = [];
  List<Gabinete> gabinetes = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  DateTime? _dataFiltro;
  String? _medicoFiltroId;
  String? _gabineteFiltroId;
  late int _anoFiltro; // Ano selecionado para filtro

  // Feriados e dias de encerramento
  List<Map<String, String>> feriados = [];
  List<Map<String, dynamic>> diasEncerramento = [];
  bool encerraFeriados = false; // Configuração se a clínica encerra em feriados

  // Estrutura para cartões combinados (disponibilidade + alocação)
  List<Map<String, dynamic>> cartoesCombinados = [];

  // Ordenação
  String _ordenacaoAtual = 'data'; // 'gabinete', 'medico', 'data'

  @override
  void initState() {
    super.initState();
    _anoFiltro = DateTime.now().year; // Ano corrente por default
    _carregarDados();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);

    try {
      // Carregar médicos
      final medicosData = await buscarMedicos(
        unidade: widget.unidade,
      );

      // Carregar gabinetes
      final gabinetesData = await buscarGabinetes(
        unidade: widget.unidade,
      );

      // Carregar todas as alocações de TODOS os anos disponíveis
      final alocacoesCarregadas = await _carregarTodasAlocacoesTodosAnos();

      // Carregar todas as disponibilidades de TODOS os anos disponíveis
      final disponibilidadesCarregadas =
          await _carregarTodasDisponibilidadesTodosAnos();

      // Carregar feriados e dias de encerramento
      await _carregarFeriadosEDiasEncerramento();

      setState(() {
        medicos = medicosData;
        gabinetes = gabinetesData;
        todasAlocacoesCarregadas = alocacoesCarregadas;
        todasDisponibilidadesCarregadas = disponibilidadesCarregadas;
        _aplicarFiltros();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  /// Carrega todas as alocações de todos os anos disponíveis
  Future<List<Alocacao>> _carregarTodasAlocacoesTodosAnos() async {
    final firestore = FirebaseFirestore.instance;
    final todasAlocacoes = <Alocacao>[];

    if (widget.unidade == null) {
      return todasAlocacoes;
    }

    try {
      // CORREÇÃO: Tentar carregar de anos específicos diretamente
      // A coleção 'alocacoes' pode não ter documentos de ano até que uma alocação seja salva
      // Primeiro, tentar buscar anos da coleção de alocações
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('alocacoes');

      final anoAtual = DateTime.now().year;
      final anosParaVerificar = <int>[];

      // Tentar buscar anos da coleção de alocações
      try {
        final anosSnapshot = await alocacoesRef.get();
        if (anosSnapshot.docs.isNotEmpty) {
          for (final anoDoc in anosSnapshot.docs) {
            final ano = int.tryParse(anoDoc.id);
            if (ano != null) {
              anosParaVerificar.add(ano);
            }
          }
        }
      } catch (e) {
        // Se falhar, continuar com anos padrão
        debugPrint('Erro ao buscar anos da coleção alocacoes: $e');
      }

      // Adicionar ano atual, anterior e próximo como fallback (sempre verificar estes)
      anosParaVerificar.addAll([anoAtual - 1, anoAtual, anoAtual + 1]);

      // Remover duplicatas e ordenar
      final anosUnicos = anosParaVerificar.toSet().toList()..sort();

      // CORREÇÃO: Também carregar da coleção "dias" (vista materializada usada pelo mapa de gabinetes)
      // A coleção "dias" pode ter alocações que ainda não foram sincronizadas para "alocacoes"
      final alocacoesDaVistaDiaria = <Alocacao>[];
      try {
        final diasRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('dias');

        // Buscar todos os documentos de dias (limitado para performance)
        final diasSnapshot = await diasRef.limit(500).get();

        for (final diaDoc in diasSnapshot.docs) {
          try {
            final alocacoesRef = diaDoc.reference.collection('alocacoes');
            final alocacoesSnapshot = await alocacoesRef.get();

            for (final doc in alocacoesSnapshot.docs) {
              try {
                final data = doc.data();
                final alocacao = Alocacao.fromMap(data);
                alocacoesDaVistaDiaria.add(alocacao);
              } catch (e) {
                debugPrint('Erro ao parsear alocação da vista diária: $e');
              }
            }
          } catch (e) {
            debugPrint('Erro ao carregar alocações do dia ${diaDoc.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar da vista diária: $e');
      }

      // Carregar alocações de cada ano em paralelo
      final futures = <Future<void>>[];

      for (final ano in anosUnicos) {
        final anoStr = ano.toString();
        final registosRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('alocacoes')
            .doc(anoStr)
            .collection('registos');

        futures.add(
          registosRef.get().then((registosSnapshot) {
            for (final doc in registosSnapshot.docs) {
              try {
                final data = doc.data();
                final alocacao = Alocacao.fromMap(data);
                todasAlocacoes.add(alocacao);
              } catch (e) {
                debugPrint('Erro ao carregar alocação do ano $anoStr: $e');
              }
            }
          }).catchError((e) {
            debugPrint('Erro ao carregar alocações do ano $anoStr: $e');
          }),
        );
      }

      // Aguardar todas as cargas em paralelo
      await Future.wait(futures);

      // CORREÇÃO: Mesclar alocações da vista diária com as da coleção alocacoes
      // Usar um Map para evitar duplicatas (chave: medicoId_data_gabineteId)
      final alocacoesMap = <String, Alocacao>{};

      // Primeiro, adicionar alocações da coleção alocacoes
      for (final aloc in todasAlocacoes) {
        final key =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month.toString().padLeft(2, '0')}-${aloc.data.day.toString().padLeft(2, '0')}_${aloc.gabineteId}';
        alocacoesMap[key] = aloc;
      }

      // Depois, adicionar alocações da vista diária (sobrescrever se houver duplicata)
      for (final aloc in alocacoesDaVistaDiaria) {
        final key =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month.toString().padLeft(2, '0')}-${aloc.data.day.toString().padLeft(2, '0')}_${aloc.gabineteId}';
        alocacoesMap[key] =
            aloc; // Vista diária tem prioridade (mais atualizada)
      }

      // CORREÇÃO CRÍTICA: Gerar alocações dinamicamente a partir de séries (como o mapa de gabinetes faz)
      // Isso é necessário porque alocações de séries podem não estar salvas no Firestore
      final alocacoesDeSeries = <Alocacao>[];
      try {
        // Carregar todos os médicos ativos
        final medicosRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('ocupantes');
        final medicosSnapshot =
            await medicosRef.where('ativo', isEqualTo: true).get();
        final medicoIds = medicosSnapshot.docs.map((d) => d.id).toList();

        // Gerar alocações para cada ano
        for (final ano in anosUnicos) {
          final dataInicioAno = DateTime(ano, 1, 1);
          final dataFimAno = DateTime(ano + 1, 1, 1);

          // Processar médicos em paralelo
          final futures = medicoIds.map((medicoId) async {
            try {
              // Carregar séries do médico
              final series = await SerieService.carregarSeries(
                medicoId,
                unidade: widget.unidade,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
              );

              // Filtrar apenas séries com gabineteId (alocadas)
              final seriesComGabinete = series
                  .where((s) =>
                      s.ativo &&
                      s.gabineteId != null &&
                      s.gabineteId!.isNotEmpty)
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

              // Gerar alocações de séries para o ano
              final alocsGeradas = SerieGenerator.gerarAlocacoes(
                series: seriesComGabinete,
                dataInicio: dataInicioAno,
                dataFim: dataFimAno,
                excecoes: excecoes,
              );

              return alocsGeradas;
            } catch (e) {
              debugPrint(
                  'Erro ao gerar alocações de séries para médico $medicoId: $e');
              return <Alocacao>[];
            }
          }).toList();

          final resultados = await Future.wait(futures);
          for (final resultado in resultados) {
            alocacoesDeSeries.addAll(resultado);
          }
        }
      } catch (e) {
        debugPrint('Erro ao gerar alocações de séries: $e');
      }

      // Adicionar alocações geradas de séries (sobrescrever se houver duplicata)
      for (final aloc in alocacoesDeSeries) {
        final key =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month.toString().padLeft(2, '0')}-${aloc.data.day.toString().padLeft(2, '0')}_${aloc.gabineteId}';
        alocacoesMap[key] = aloc; // Séries têm prioridade (mais atualizadas)
      }

      final todasAlocacoesMescladas = alocacoesMap.values.toList();

      debugPrint(
          '✅ Carregadas ${todasAlocacoesMescladas.length} alocações (${todasAlocacoes.length} da coleção + ${alocacoesDaVistaDiaria.length} da vista diária + ${alocacoesDeSeries.length} de séries) de ${anosUnicos.length} anos');

      return todasAlocacoesMescladas;
    } catch (e) {
      debugPrint('❌ Erro ao carregar todas as alocações: $e');
    }

    return todasAlocacoes;
  }

  /// Carrega todas as disponibilidades de todos os anos disponíveis
  /// As disponibilidades são geradas dinamicamente a partir de séries de recorrência
  Future<List<Disponibilidade>>
      _carregarTodasDisponibilidadesTodosAnos() async {
    final todasDisponibilidades = <Disponibilidade>[];

    if (widget.unidade == null) {
      return todasDisponibilidades;
    }

    try {
      // Primeiro, descobrir quais anos temos dados (alocações ou séries)
      final firestore = FirebaseFirestore.instance;
      final anosComAlocacoes = <int>{};

      // Buscar anos das alocações
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('alocacoes');
      final anosSnapshot = await alocacoesRef.get();

      for (final anoDoc in anosSnapshot.docs) {
        final ano = int.tryParse(anoDoc.id);
        if (ano != null) {
          anosComAlocacoes.add(ano);
        }
      }

      // Adicionar anos comuns (ano atual, anterior e próximo)
      final anoAtual = DateTime.now().year;
      anosComAlocacoes.add(anoAtual - 1);
      anosComAlocacoes.add(anoAtual);
      anosComAlocacoes.add(anoAtual + 1);

      // Carregar disponibilidades para cada ano usando o método que gera a partir de séries
      final futures = <Future<List<Disponibilidade>>>[];

      for (final ano in anosComAlocacoes) {
        futures.add(
          logic.AlocacaoMedicosLogic.carregarDisponibilidadesDeSeries(
            unidade: widget.unidade,
            anoEspecifico: ano.toString(),
          ).then((disps) {
            return disps;
          }).catchError((e) {
            debugPrint('Erro ao carregar disponibilidades do ano $ano: $e');
            return <Disponibilidade>[];
          }),
        );
      }

      // Aguardar todas as cargas em paralelo
      final resultados = await Future.wait(futures);

      // Combinar todas as disponibilidades geradas de séries
      for (final disps in resultados) {
        todasDisponibilidades.addAll(disps);
      }

      // Também carregar disponibilidades "Única" do Firestore para cada ano
      final ocupantesRef = FirebaseFirestore.instance
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('ocupantes');
      final ocupantesSnapshot = await ocupantesRef.get();

      final futuresUnicas = <Future<void>>[];
      for (final ocupanteDoc in ocupantesSnapshot.docs) {
        for (final ano in anosComAlocacoes) {
          futuresUnicas.add(
            DisponibilidadeUnicaService.carregarDisponibilidadesUnicas(
              ocupanteDoc.id,
              ano,
              widget.unidade,
            ).then((dispsUnicas) {
              todasDisponibilidades.addAll(dispsUnicas);
            }).catchError((e) {
              debugPrint(
                  'Erro ao carregar disponibilidades únicas do médico ${ocupanteDoc.id} ano $ano: $e');
            }),
          );
        }
      }

      await Future.wait(futuresUnicas);

      debugPrint(
          '✅ Carregadas ${todasDisponibilidades.length} disponibilidades de ${anosComAlocacoes.length} anos');
    } catch (e) {
      debugPrint('❌ Erro ao carregar todas as disponibilidades: $e');
    }

    return todasDisponibilidades;
  }

  /// Carrega feriados e dias de encerramento da unidade
  Future<void> _carregarFeriadosEDiasEncerramento() async {
    if (widget.unidade == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Carregar feriados
      // CORREÇÃO: Carregar de anos específicos (como nas alocações)
      // A coleção pode não ter documentos de ano até que um feriado seja salvo
      final feriadosRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('feriados');

      final feriadosTemp = <Map<String, String>>[];

      // Tentar buscar anos da coleção de feriados
      try {
        final anosFeriadosSnapshot = await feriadosRef.get();
        if (anosFeriadosSnapshot.docs.isNotEmpty) {
          for (final anoDoc in anosFeriadosSnapshot.docs) {
            final registosRef = anoDoc.reference.collection('registos');
            final registosSnapshot = await registosRef.get();
            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              feriadosTemp.add({
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar anos da coleção feriados: $e');
      }

      // Sempre verificar anos padrão (ano atual, anterior, próximo e ano do filtro)
      final anoAtual = DateTime.now().year;
      final anosParaVerificar = <int>{
        anoAtual - 1,
        anoAtual,
        anoAtual + 1,
        _anoFiltro,
      }.toList();

      for (final ano in anosParaVerificar) {
        try {
          final anoRef = feriadosRef.doc(ano.toString());
          final registosRef = anoRef.collection('registos');
          final registosSnapshot = await registosRef.get();

          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            // Evitar duplicatas
            final jaExiste = feriadosTemp.any((f) => f['id'] == doc.id);
            if (!jaExiste) {
              feriadosTemp.add({
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
              });
            }
          }
        } catch (e) {
          // Ignorar erros ao carregar de um ano específico
        }
      }

      // Carregar dias de encerramento
      // CORREÇÃO: Carregar de anos específicos (como nas alocações)
      final encerramentosRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('encerramentos');

      final diasEncerramentoTemp = <Map<String, dynamic>>[];

      // Tentar buscar anos da coleção de encerramentos
      try {
        final anosEncerramentosSnapshot = await encerramentosRef.get();
        if (anosEncerramentosSnapshot.docs.isNotEmpty) {
          for (final anoDoc in anosEncerramentosSnapshot.docs) {
            final registosRef = anoDoc.reference.collection('registos');
            final registosSnapshot = await registosRef.get();
            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              diasEncerramentoTemp.add({
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
                'motivo': data['motivo'] as String? ?? 'Encerramento',
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar anos da coleção encerramentos: $e');
      }

      // Sempre verificar anos padrão (ano atual, anterior, próximo e ano do filtro)
      for (final ano in anosParaVerificar) {
        try {
          final anoRef = encerramentosRef.doc(ano.toString());
          final registosRef = anoRef.collection('registos');
          final registosSnapshot = await registosRef.get();
          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            // Evitar duplicatas
            final jaExiste = diasEncerramentoTemp.any((d) => d['id'] == doc.id);
            if (!jaExiste) {
              diasEncerramentoTemp.add({
                'id': doc.id,
                'data': data['data'] as String? ?? '',
                'descricao': data['descricao'] as String? ?? '',
                'motivo': data['motivo'] as String? ?? 'Encerramento',
              });
            }
          }
        } catch (e) {
          // Ignorar erros ao carregar de um ano específico
        }
      }

      // Carregar configuração se encerra em feriados
      final configRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('config_clinica')
          .doc('horarios');

      final configDoc = await configRef.get();
      final encerraFeriadosTemp =
          configDoc.data()?['encerraFeriados'] as bool? ?? false;

      setState(() {
        feriados = feriadosTemp;
        diasEncerramento = diasEncerramentoTemp;
        encerraFeriados = encerraFeriadosTemp;
      });
    } catch (e) {
      debugPrint('Erro ao carregar feriados e dias de encerramento: $e');
    }
  }

  /// Verifica se uma data é feriado ou dia de encerramento
  bool _ehFeriadoOuEncerramento(DateTime data) {
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);

    // Verificar dias de encerramento
    for (final dia in diasEncerramento) {
      final dataDia = dia['data']?.toString() ?? '';
      if (dataDia.isEmpty) continue;
      try {
        String dataDiaNormalizada = dataDia;
        if (dataDia.contains('T')) {
          dataDiaNormalizada = dataDia.split('T')[0];
        }
        if (dataDiaNormalizada == dataFormatada) {
          return true;
        }
      } catch (e) {
        if (dataDia.contains(dataFormatada) ||
            dataFormatada.contains(dataDia.split('T')[0])) {
          return true;
        }
      }
    }

    // Verificar feriados (se a clínica encerra em feriados)
    if (encerraFeriados) {
      for (final feriado in feriados) {
        final dataFeriado = feriado['data']?.toString() ?? '';
        if (dataFeriado.isEmpty) continue;
        try {
          final dataFeriadoParsed = DateTime.parse(dataFeriado);
          if (dataFeriadoParsed.year == data.year &&
              dataFeriadoParsed.month == data.month &&
              dataFeriadoParsed.day == data.day) {
            return true;
          }
        } catch (e) {
          String dataFeriadoNormalizada = dataFeriado;
          if (dataFeriado.contains('T')) {
            dataFeriadoNormalizada = dataFeriado.split('T')[0];
          }
          if (dataFeriadoNormalizada == dataFormatada) {
            return true;
          }
        }
      }
    }

    return false;
  }

  void _aplicarFiltros() {
    setState(() {
      // Primeiro, filtrar por ano
      todasAlocacoes = todasAlocacoesCarregadas
          .where((a) => a.data.year == _anoFiltro)
          .toList();

      final disponibilidadesAno = todasDisponibilidadesCarregadas
          .where((d) => d.data.year == _anoFiltro)
          .toList();

      // Se um médico foi selecionado, resetar o filtro de gabinete se não for válido
      if (_medicoFiltroId != null && _gabineteFiltroId != null) {
        final gabinetesDisponiveis = _getGabinetesFiltrados();
        final gabineteValido =
            gabinetesDisponiveis.any((g) => g.id == _gabineteFiltroId);
        if (!gabineteValido) {
          _gabineteFiltroId = null;
        }
      }

      // Criar mapa de alocações por disponibilidade (medicoId + data)
      // IMPORTANTE: Um médico pode ter múltiplas alocações no mesmo dia
      // Usar uma lista de alocações por chave
      final alocacoesMap = <String, List<Alocacao>>{};
      for (final aloc in todasAlocacoes) {
        final key =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month.toString().padLeft(2, '0')}-${aloc.data.day.toString().padLeft(2, '0')}';
        if (!alocacoesMap.containsKey(key)) {
          alocacoesMap[key] = [];
        }
        alocacoesMap[key]!.add(aloc);
      }

      // Combinar disponibilidades com alocações
      cartoesCombinados = [];

      for (final disp in disponibilidadesAno) {
        // Aplicar filtros
        if (_medicoFiltroId != null && disp.medicoId != _medicoFiltroId) {
          continue;
        }

        if (_dataFiltro != null) {
          final dataFiltro =
              DateTime(_dataFiltro!.year, _dataFiltro!.month, _dataFiltro!.day);
          final dataDisp =
              DateTime(disp.data.year, disp.data.month, disp.data.day);
          if (dataDisp != dataFiltro) continue;
        }

        // Filtrar feriados e dias de encerramento
        final dataDisp =
            DateTime(disp.data.year, disp.data.month, disp.data.day);
        final ehFeriadoOuEncerramento = _ehFeriadoOuEncerramento(dataDisp);
        if (ehFeriadoOuEncerramento) {
          continue; // Não mostrar disponibilidades em feriados ou dias de encerramento
        }

        // Verificar se há alocação para esta disponibilidade
        final key =
            '${disp.medicoId}_${disp.data.year}-${disp.data.month.toString().padLeft(2, '0')}-${disp.data.day.toString().padLeft(2, '0')}';
        final alocacoesDoDia = alocacoesMap[key] ?? [];

        // CORREÇÃO: Se há alocações do dia para o médico, usar a primeira
        // Não depender de correspondência exata de horários, pois pode haver diferenças de formato
        Alocacao? alocacaoCorrespondente;
        if (alocacoesDoDia.isNotEmpty) {
          // Se há alocações, sempre usar pelo menos a primeira
          // Tentar encontrar correspondência exata de horários primeiro (melhor match)
          if (disp.horarios.isNotEmpty && disp.horarios.length >= 2) {
            final horarioInicioDisp = disp.horarios[0].trim();
            final horarioFimDisp = disp.horarios.length > 1
                ? disp.horarios[1].trim()
                : disp.horarios[0].trim();

            // Tentar encontrar correspondência exata
            alocacaoCorrespondente = alocacoesDoDia.firstWhere(
              (a) =>
                  a.horarioInicio.trim() == horarioInicioDisp &&
                  a.horarioFim.trim() == horarioFimDisp,
              orElse: () => alocacoesDoDia
                  .first, // FALLBACK: usar primeira se não encontrar match exato
            );
          } else {
            // Se não há horários na disponibilidade, usar a primeira alocação
            alocacaoCorrespondente = alocacoesDoDia.first;
          }
        }

        // Se há filtro de gabinete, só incluir se a alocação corresponder
        if (_gabineteFiltroId != null) {
          if (alocacaoCorrespondente == null ||
              alocacaoCorrespondente.gabineteId != _gabineteFiltroId) {
            continue;
          }
        }

        cartoesCombinados.add({
          'tipo': alocacaoCorrespondente != null ? 'alocado' : 'nao_alocado',
          'disponibilidade': disp,
          'alocacao': alocacaoCorrespondente,
          'medicoId': disp.medicoId,
          'data': disp.data,
        });
      }

      // Aplicar ordenação
      _aplicarOrdenacao();
    });
  }

  void _aplicarOrdenacao() {
    switch (_ordenacaoAtual) {
      case 'gabinete':
        cartoesCombinados.sort((a, b) {
          final alocA = a['alocacao'] as Alocacao?;
          final alocB = b['alocacao'] as Alocacao?;
          final nomeA = alocA != null
              ? _getNomeGabinete(alocA.gabineteId)
              : 'Sem gabinete';
          final nomeB = alocB != null
              ? _getNomeGabinete(alocB.gabineteId)
              : 'Sem gabinete';
          return nomeA.compareTo(nomeB);
        });
        break;
      case 'medico':
        cartoesCombinados.sort((a, b) {
          final nomeA = _getNomeMedico(a['medicoId'] as String);
          final nomeB = _getNomeMedico(b['medicoId'] as String);
          return nomeA.compareTo(nomeB);
        });
        break;
      case 'data':
      default:
        // Ordenar por data (crescente - mais antigas primeiro)
        cartoesCombinados.sort((a, b) {
          final dataA = a['data'] as DateTime;
          final dataB = b['data'] as DateTime;
          return dataA.compareTo(dataB);
        });
        break;
    }
  }

  Future<void> _apagarAlocacao(Alocacao alocacao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja apagar esta alocação?\n\n'
          'Gabinete: ${_getNomeGabinete(alocacao.gabineteId)}\n'
          'Data: ${DateFormat('dd/MM/yyyy').format(alocacao.data)}\n'
          'Horário: ${alocacao.horarioInicio} - ${alocacao.horarioFim}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      final ano = alocacao.data.year.toString();

      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');

      await alocacoesRef.doc(alocacao.id).delete();

      // Remover da lista local
      setState(() {
        todasAlocacoes.removeWhere((a) => a.id == alocacao.id);
        todasAlocacoesCarregadas.removeWhere((a) => a.id == alocacao.id);
        _aplicarFiltros();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alocação apagada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar alocação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getNomeMedico(String medicoId) {
    final medico = medicos.firstWhere(
      (m) => m.id == medicoId,
      orElse: () => Medico(
        id: medicoId,
        nome: 'Desconhecido',
        especialidade: '',
        disponibilidades: [],
        ativo: false,
      ),
    );
    return medico.nome;
  }

  String _getNomeGabinete(String gabineteId) {
    final gabinete = gabinetes.firstWhere(
      (g) => g.id == gabineteId,
      orElse: () => Gabinete(
        id: gabineteId,
        setor: '',
        nome: gabineteId,
        especialidadesPermitidas: [],
      ),
    );
    return gabinete.nome;
  }

  // Obter gabinetes filtrados baseado no médico selecionado
  List<Gabinete> _getGabinetesFiltrados() {
    if (_medicoFiltroId == null) {
      return gabinetes;
    }

    // Obter todos os gabinetes únicos das alocações do médico selecionado
    final gabinetesIds = todasAlocacoes
        .where((aloc) => aloc.medicoId == _medicoFiltroId)
        .map((aloc) => aloc.gabineteId)
        .toSet();

    return gabinetes.where((g) => gabinetesIds.contains(g.id)).toList();
  }

  // Obter lista de anos disponíveis nas alocações e disponibilidades
  List<int> _getAnosDisponiveis() {
    final anosAlocacoes =
        todasAlocacoesCarregadas.map((a) => a.data.year).toSet();
    final anosDisponibilidades =
        todasDisponibilidadesCarregadas.map((d) => d.data.year).toSet();

    final todosAnos = {...anosAlocacoes, ...anosDisponibilidades};

    if (todosAnos.isEmpty) {
      return [DateTime.now().year]; // Retornar pelo menos o ano atual
    }

    final anosLista = todosAnos.toList();
    anosLista.sort((a, b) => b.compareTo(a)); // Ordenar decrescente
    return anosLista;
  }

  // Widget para opção de ordenação
  Widget _buildOpcaoOrdenacao(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    final isSelected = _ordenacaoAtual == value;
    return InkWell(
      onTap: () {
        setState(() {
          _ordenacaoAtual = value;
          _aplicarOrdenacao();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            ),
            Icon(
              Icons.sort_by_alpha,
              size: 16,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anosDisponiveis = _getAnosDisponiveis();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Cartões de disponibilidade',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            // Dropdown de ano
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: DropdownButton<int>(
                value: anosDisponiveis.contains(_anoFiltro)
                    ? _anoFiltro
                    : (anosDisponiveis.isNotEmpty
                        ? anosDisponiveis.first
                        : DateTime.now().year),
                underline: const SizedBox(),
                dropdownColor: Theme.of(context).primaryColor,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.white, size: 20),
                items: anosDisponiveis.map((ano) {
                  return DropdownMenuItem<int>(
                    value: ano,
                    child: Text(ano.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _anoFiltro = value;
                      _aplicarFiltros();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              height: 32,
              width: 32,
              child: Image.asset(
                'images/am_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna Esquerda: Filtros e Ordenação
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filtro de Médico
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: DropdownButton<String?>(
                        value: _medicoFiltroId,
                        isExpanded: true,
                        hint: const Text('Todos os médicos'),
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade700),
                        items: () {
                          final medicosOrdenados = List<Medico>.from(medicos)
                            ..sort((a, b) => a.nome
                                .toLowerCase()
                                .compareTo(b.nome.toLowerCase()));
                          return [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos os médicos'),
                            ),
                            ...medicosOrdenados
                                .map((m) => DropdownMenuItem<String?>(
                                      value: m.id,
                                      child: Text(
                                          '${m.nome}${!m.ativo ? ' (Inativo)' : ''}'),
                                    )),
                          ];
                        }(),
                        onChanged: (value) {
                          setState(() {
                            _medicoFiltroId = value;
                            if (value != null) {
                              _gabineteFiltroId = null;
                            }
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filtro de Gabinete
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: DropdownButton<String?>(
                        value: _gabineteFiltroId,
                        isExpanded: true,
                        hint: const Text('Todos os gabinetes'),
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade700),
                        items: () {
                          final gabinetesParaMostrar = _getGabinetesFiltrados();
                          final gabinetesOrdenados =
                              List<Gabinete>.from(gabinetesParaMostrar)
                                ..sort((a, b) => a.nome.compareTo(b.nome));
                          return [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos os gabinetes'),
                            ),
                            ...gabinetesOrdenados
                                .map((g) => DropdownMenuItem<String?>(
                                      value: g.id,
                                      child: Text(g.nome),
                                    )),
                          ];
                        }(),
                        onChanged: (value) {
                          setState(() {
                            _gabineteFiltroId = value;
                            _aplicarFiltros();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filtro de Data
                    InkWell(
                      onTap: () async {
                        final data = await showDatePickerCustomizado(
                          context: context,
                          initialDate: _dataFiltro ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (data != null) {
                          setState(() {
                            _dataFiltro = data;
                            _aplicarFiltros();
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dataFiltro != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(_dataFiltro!)
                                    : 'Filtrar por data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _dataFiltro != null
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Botão para limpar filtros
                    if (_dataFiltro != null ||
                        _medicoFiltroId != null ||
                        _gabineteFiltroId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _dataFiltro = null;
                              _medicoFiltroId = null;
                              _gabineteFiltroId = null;
                              _aplicarFiltros();
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Limpar filtros'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Ordenação
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ordenar por',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              _buildOpcaoOrdenacao(
                                context,
                                'gabinete',
                                Icons.business,
                                'Gabinete',
                              ),
                              const SizedBox(height: 8),
                              _buildOpcaoOrdenacao(
                                context,
                                'medico',
                                Icons.person,
                                'Médico',
                              ),
                              const SizedBox(height: 8),
                              _buildOpcaoOrdenacao(
                                context,
                                'data',
                                Icons.calendar_today,
                                'Data',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Coluna Direita: Lista de Alocações
          Expanded(
            child: Column(
              children: [
                // Cards de Métricas
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${cartoesCombinados.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dataFiltro != null ||
                          _medicoFiltroId != null ||
                          _gabineteFiltroId != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade300,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filtrados',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${cartoesCombinados.length}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Lista
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : cartoesCombinados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Não há cartões de disponibilidade',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: cartoesCombinados.length,
                              itemBuilder: (context, index) {
                                final cartao = cartoesCombinados[index];
                                final disponibilidade =
                                    cartao['disponibilidade']
                                        as Disponibilidade;
                                final alocacao =
                                    cartao['alocacao'] as Alocacao?;
                                final medicoNome =
                                    _getNomeMedico(disponibilidade.medicoId);
                                final gabineteNome = alocacao != null
                                    ? _getNomeGabinete(alocacao.gabineteId)
                                    : 'Sem gabinete';
                                final isAlocado = alocacao != null;
                                final alocacaoNotNull =
                                    alocacao; // Para evitar warnings do linter

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  color: isAlocado ? null : Colors.grey.shade50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        // Ícone
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isAlocado
                                                ? Colors.blue.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isAlocado
                                                ? Icons.check_circle
                                                : Icons.pending,
                                            color: isAlocado
                                                ? Colors.blue.shade700
                                                : Colors.orange.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Informações em Row
                                        Expanded(
                                          child: Row(
                                            children: [
                                              // Gabinete
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  gabineteNome,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: isAlocado
                                                        ? Colors.black
                                                        : Colors.grey.shade600,
                                                    fontStyle: isAlocado
                                                        ? FontStyle.normal
                                                        : FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                              // Médico
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  medicoNome,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Data e Horário
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  isAlocado &&
                                                          alocacaoNotNull !=
                                                              null
                                                      ? '${DateFormat('dd/MM/yyyy').format(disponibilidade.data)} • ${alocacaoNotNull.horarioInicio} - ${alocacaoNotNull.horarioFim}'
                                                      : '${DateFormat('dd/MM/yyyy').format(disponibilidade.data)} • ${disponibilidade.horarios.isNotEmpty ? disponibilidade.horarios.join(', ') : 'Sem horário'}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Botão de deletar (só para alocações)
                                        if (isAlocado &&
                                            alocacaoNotNull != null)
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 20),
                                            onPressed: () => _apagarAlocacao(
                                                alocacaoNotNull),
                                            tooltip: 'Apagar alocação',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
