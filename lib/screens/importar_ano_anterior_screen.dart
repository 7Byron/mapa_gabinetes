// lib/screens/importar_ano_anterior_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../models/unidade.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../services/disponibilidade_criacao.dart';

/// Ecrã para importar disponibilidades e alocações do ano anterior para o ano atual
/// Permite selecionar médicos e importar suas séries mantendo dia da semana, frequência e gabinete
class ImportarAnoAnteriorScreen extends StatefulWidget {
  final Unidade? unidade;

  const ImportarAnoAnteriorScreen({super.key, this.unidade});

  @override
  State<ImportarAnoAnteriorScreen> createState() => _ImportarAnoAnteriorScreenState();
}

class _ImportarAnoAnteriorScreenState extends State<ImportarAnoAnteriorScreen> {
  bool isLoadingAnos = true; // Carregando anos disponíveis
  bool isLoadingMedicos = false; // Carregando médicos do ano selecionado
  int? anoOrigem; // Ano de onde importar (null até selecionar)
  int anoDestino = DateTime.now().year; // Ano para onde importar
  
  // Anos disponíveis (com dados)
  List<int> anosDisponiveis = [];
  
  // Médicos com disponibilidades/alocações no ano selecionado
  List<MedicoImportacao> medicosParaImportar = [];
  
  // Seleção
  Set<String> medicosSelecionados = {};
  
  // Estatísticas
  int totalDisponibilidades = 0;
  int totalAlocacoes = 0;

  @override
  void initState() {
    super.initState();
    // Primeiro, descobrir quais anos têm dados
    _carregarAnosDisponiveis();
  }
  
  /// Carrega rapidamente quais anos têm dados disponíveis
  Future<void> _carregarAnosDisponiveis() async {
    setState(() => isLoadingAnos = true);
    
    try {
      final firestore = FirebaseFirestore.instance;
      if (widget.unidade == null) {
        debugPrint('❌ Unidade é null');
        setState(() {
          isLoadingAnos = false;
          anosDisponiveis = [];
        });
        return;
      }
      
      debugPrint('🔍 Procurando anos disponíveis na unidade: ${widget.unidade!.id}');
      final Set<int> anosEncontrados = {};
      
      // Método 1: Buscar diretamente os registos usando collectionGroup
      // Filtrar pelo caminho do documento para garantir que é da unidade correta
      try {
        debugPrint('📊 Buscando alocações usando collectionGroup...');
        final alocacoesCgQuery = firestore
            .collectionGroup('registos')
            .limit(500); // Limitar para performance
        
        final alocacoesCgSnapshot = await alocacoesCgQuery.get();
        debugPrint('📊 Total de registos encontrados (collectionGroup): ${alocacoesCgSnapshot.docs.length}');
        
        final unidadePath = 'unidades/${widget.unidade!.id}/alocacoes';
        for (final doc in alocacoesCgSnapshot.docs) {
          try {
            // Verificar se o documento pertence à unidade correta
            final docPath = doc.reference.path;
            if (docPath.contains(unidadePath)) {
              final data = doc.data();
              if (data.containsKey('data')) {
                final dataStr = data['data'] as String?;
                if (dataStr != null) {
                  final dataObj = DateTime.parse(dataStr);
                  anosEncontrados.add(dataObj.year);
                  debugPrint('  ✅ Ano ${dataObj.year} encontrado em alocação (caminho: $docPath)');
                }
              }
            }
          } catch (e) {
            debugPrint('  ❌ Erro ao processar documento de alocação: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ Erro ao buscar alocações com collectionGroup: $e');
      }
      
      // Método 2: Buscar disponibilidades usando collectionGroup
      try {
        debugPrint('📊 Buscando disponibilidades usando collectionGroup...');
        final disponibilidadesCgQuery = firestore
            .collectionGroup('registos')
            .limit(500); // Limitar para performance
        
        final disponibilidadesCgSnapshot = await disponibilidadesCgQuery.get();
        debugPrint('📊 Total de registos encontrados (collectionGroup): ${disponibilidadesCgSnapshot.docs.length}');
        
        final unidadePath = 'unidades/${widget.unidade!.id}/ocupantes';
        for (final doc in disponibilidadesCgSnapshot.docs) {
          try {
            // Verificar se o documento pertence à unidade correta
            final docPath = doc.reference.path;
            if (docPath.contains(unidadePath) && docPath.contains('/disponibilidades/')) {
              final data = doc.data();
              if (data.containsKey('data')) {
                final dataStr = data['data'] as String?;
                if (dataStr != null) {
                  final dataObj = DateTime.parse(dataStr);
                  anosEncontrados.add(dataObj.year);
                  debugPrint('  ✅ Ano ${dataObj.year} encontrado em disponibilidade (caminho: $docPath)');
                }
              }
            }
          } catch (e) {
            debugPrint('  ❌ Erro ao processar documento de disponibilidade: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ Erro ao buscar disponibilidades com collectionGroup: $e');
      }
      
      final anosOrdenados = anosEncontrados.toList()..sort();
      debugPrint('📅 Anos disponíveis encontrados: $anosOrdenados');
      
      setState(() {
        anosDisponiveis = anosOrdenados;
        isLoadingAnos = false;
      });
    } catch (e) {
      debugPrint('❌ Erro geral ao carregar anos disponíveis: $e');
      setState(() {
        isLoadingAnos = false;
        anosDisponiveis = [];
      });
    }
  }

  /// Carrega médicos apenas do ano selecionado
  Future<void> _carregarMedicosAnoSelecionado() async {
    if (anoOrigem == null) return;
    
    setState(() {
      isLoadingMedicos = true;
      medicosParaImportar = [];
      medicosSelecionados.clear();
      totalDisponibilidades = 0;
      totalAlocacoes = 0;
    });
    
    try {
      final firestore = FirebaseFirestore.instance;
      if (widget.unidade == null) return;
      
      final ocupantesRef = firestore
          .collection('unidades')
          .doc(widget.unidade!.id)
          .collection('ocupantes');
      
      final ocupantesSnapshot = await ocupantesRef.get();
      
      final Map<String, MedicoImportacao> medicosMap = {};
      
      // Carregar médicos e suas disponibilidades/alocações do ano anterior
      for (final ocupanteDoc in ocupantesSnapshot.docs) {
        final dadosMedico = ocupanteDoc.data();
        final medicoId = ocupanteDoc.id;
        
        final medico = Medico(
          id: medicoId,
          nome: dadosMedico['nome'] ?? 'Desconhecido',
          especialidade: dadosMedico['especialidade'] ?? '',
          observacoes: dadosMedico['observacoes'],
          disponibilidades: [],
          ativo: dadosMedico['ativo'] ?? true,
        );
        
        // Carregar disponibilidades do ano de origem
        final disponibilidadesRef = ocupanteDoc.reference
            .collection('disponibilidades')
            .doc(anoOrigem!.toString())
            .collection('registos');
        
        final disponibilidadesSnapshot = await disponibilidadesRef.get();
        final disponibilidadesAnoAnterior = <Disponibilidade>[];
        
        for (final doc in disponibilidadesSnapshot.docs) {
          try {
            final disp = Disponibilidade.fromMap(doc.data());
            disponibilidadesAnoAnterior.add(disp);
          } catch (e) {
            debugPrint('Erro ao carregar disponibilidade: $e');
          }
        }
        
        // Carregar alocações do ano de origem
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('alocacoes')
            .doc(anoOrigem!.toString())
            .collection('registos')
            .where('medicoId', isEqualTo: medicoId);
        
        final alocacoesSnapshot = await alocacoesRef.get();
        final alocacoesAnoAnterior = <Alocacao>[];
        
        for (final doc in alocacoesSnapshot.docs) {
          try {
            final aloc = Alocacao.fromMap(doc.data());
            alocacoesAnoAnterior.add(aloc);
          } catch (e) {
            debugPrint('Erro ao carregar alocação: $e');
          }
        }
        
        // Só adicionar se tiver disponibilidades ou alocações
        if (disponibilidadesAnoAnterior.isNotEmpty || alocacoesAnoAnterior.isNotEmpty) {
          medicosMap[medicoId] = MedicoImportacao(
            medico: medico,
            disponibilidades: disponibilidadesAnoAnterior,
            alocacoes: alocacoesAnoAnterior,
          );
        }
      }
      
      medicosParaImportar = medicosMap.values.toList();
      
      // Calcular estatísticas
      totalDisponibilidades = medicosParaImportar.fold(
        0,
        (total, m) => total + m.disponibilidades.length,
      );
      totalAlocacoes = medicosParaImportar.fold(
        0,
        (total, m) => total + m.alocacoes.length,
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingMedicos = false);
      }
    }
  }

  /// Calcula a data equivalente no ano de destino mantendo o dia da semana
  DateTime _calcularDataAnoSeguinte(DateTime dataOrigem, {String? tipoSerie}) {
    // Para séries mensais, calcular a primeira data equivalente no novo ano (janeiro)
    // mantendo o mesmo dia da semana e ocorrência no mês
    if (tipoSerie == 'Mensal') {
      final weekdayDesejado = dataOrigem.weekday;
      
      // Descobrir qual ocorrência do weekday no mês (ex: 1ª terça-feira)
      final ano = dataOrigem.year;
      final mes = dataOrigem.month;
      final dia = dataOrigem.day;
      final weekdayDia1 = DateTime(ano, mes, 1).weekday;
      final offset = (weekdayDesejado - weekdayDia1 + 7) % 7;
      final primeiroDesteMes = 1 + offset;
      final dif = dia - primeiroDesteMes;
      final n = 1 + (dif ~/ 7); // n-ésima ocorrência
      
      // Calcular a primeira data equivalente em janeiro do ano de destino
      final weekdayDia1Jan = DateTime(anoDestino, 1, 1).weekday;
      final offsetJan = (weekdayDesejado - weekdayDia1Jan + 7) % 7;
      final primeiroNoJan = 1 + offsetJan;
      final diaJan = primeiroNoJan + 7 * (n - 1);
      
      // Verificar se o dia existe em janeiro
      final ultimoDiaJan = DateTime(anoDestino, 2, 0).day;
      if (diaJan <= ultimoDiaJan) {
        return DateTime(anoDestino, 1, diaJan);
      } else {
        // Se não existe (ex: 5ª terça-feira), usar a última terça-feira de janeiro
        return DateTime(anoDestino, 1, ultimoDiaJan - ((ultimoDiaJan - primeiroNoJan) % 7));
      }
    }
    
    // Para séries semanais e quinzenais, encontrar a primeira data equivalente no novo ano
    // mantendo o mesmo dia da semana
    if (tipoSerie == 'Semanal' || tipoSerie == 'Quinzenal') {
      final weekdayDesejado = dataOrigem.weekday;
      
      // Encontrar a primeira ocorrência deste dia da semana em janeiro do ano de destino
      final weekdayDia1Jan = DateTime(anoDestino, 1, 1).weekday;
      final offset = (weekdayDesejado - weekdayDia1Jan + 7) % 7;
      final primeiraDataJan = 1 + offset;
      
      return DateTime(anoDestino, 1, primeiraDataJan);
    }
    
    // Para outros tipos de série (Consecutivo, Única), calcular quantos dias se passaram desde o início do ano
    final inicioAnoOrigem = DateTime(anoOrigem!, 1, 1);
    final diasDesdeInicioAno = dataOrigem.difference(inicioAnoOrigem).inDays;
    
    // Aplica o mesmo número de dias no ano de destino
    final inicioAnoDestino = DateTime(anoDestino, 1, 1);
    return inicioAnoDestino.add(Duration(days: diasDesdeInicioAno));
  }

  /// Importa os médicos selecionados
  Future<void> _importarMedicosSelecionados() async {
    if (medicosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um médico para importar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Importação'),
        content: Text(
          'Tem certeza que deseja importar ${medicosSelecionados.length} médico(s) do ano $anoOrigem para o ano $anoDestino?\n\n'
          'Isso criará novas disponibilidades e alocações mantendo os mesmos dias da semana, frequências e gabinetes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    if (!mounted) return;
    
    final firestore = FirebaseFirestore.instance;
    int disponibilidadesCriadas = 0;
    int alocacoesCriadas = 0;
    int erros = 0;
    
    try {
      // Mostrar progresso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      for (final medicoId in medicosSelecionados) {
        final medicoImport = medicosParaImportar.firstWhere(
          (m) => m.medico.id == medicoId,
        );
        
        try {
          // Agrupar disponibilidades por tipo, horários e dia da semana para criar séries
          // Isso garante que múltiplas séries do mesmo médico sejam tratadas separadamente
          // Ex: Mensal às 5ª quintas + Quinzenal às 4ª feiras = 2 séries diferentes
          final Map<String, List<Disponibilidade>> disponibilidadesPorSerie = {};
          
          for (final disp in medicoImport.disponibilidades) {
            // Criar chave única baseada em tipo, horários e dia da semana
            // Isso garante que séries diferentes sejam agrupadas separadamente
            final diaSemana = disp.data.weekday;
            final horariosStr = disp.horarios.join(",");
            final chave = '${disp.tipo}_$horariosStr _$diaSemana';
            
            if (!disponibilidadesPorSerie.containsKey(chave)) {
              disponibilidadesPorSerie[chave] = [];
            }
            disponibilidadesPorSerie[chave]!.add(disp);
          }
          
          // Criar disponibilidades para cada série (cada série é tratada independentemente)
          for (final serie in disponibilidadesPorSerie.values) {
            if (serie.isEmpty) continue;
            
            try {
              final dispRef = serie.first;
              final tipo = dispRef.tipo;
              
              // IMPORTANTE: Encontrar a primeira data da série no ano anterior
              // Mesmo que alguns dias tenham sido apagados (férias), usamos a primeira data
              // para recriar a série COMPLETA no ano seguinte
              final primeiraDataAnoAnterior = serie.map((d) => d.data).reduce(
                (a, b) => a.isBefore(b) ? a : b,
              );
              
              // Calcular a primeira data equivalente no ano atual
              // Para séries mensais, calcula a primeira data em janeiro do novo ano
              // Para outras séries, mantém o mesmo dia da semana e posição relativa no ano
              final primeiraDataAnoAtual = _calcularDataAnoSeguinte(
                primeiraDataAnoAnterior,
                tipoSerie: tipo,
              );
              
              // IMPORTANTE: Criar série COMPLETA para o ano atual
              // Não importa se alguns dias foram apagados no ano anterior (férias)
              // Criamos a série completa e o usuário apaga manualmente os dias de férias do novo ano
              // Para importação, criar série completa de 12 meses (não limitar ao ano)
              final novasDisponibilidades = criarDisponibilidadesSerie(
                primeiraDataAnoAtual,
                tipo,
                medicoId: medicoId,
                limitarAoAno: false, // false = criar 12 meses completos para o novo ano
              );
              
              // Atualizar horários das novas disponibilidades
              for (final novaDisp in novasDisponibilidades) {
                novaDisp.horarios = dispRef.horarios;
              }
              
              debugPrint(
                '📅 Criando série completa: ${dispRef.tipo} a partir de ${DateFormat('dd/MM/yyyy').format(primeiraDataAnoAtual)} '
                '(${novasDisponibilidades.length} disponibilidades)',
              );
              
              // Salvar disponibilidades no Firebase
              final ocupantesRef = firestore
                  .collection('unidades')
                  .doc(widget.unidade!.id)
                  .collection('ocupantes')
                  .doc(medicoId);
              
              final disponibilidadesRef = ocupantesRef
                  .collection('disponibilidades')
                  .doc(anoDestino.toString())
                  .collection('registos');
              
              final batch = firestore.batch();
              
              for (final novaDisp in novasDisponibilidades) {
                // Verificar se já existe disponibilidade para esta data
                final existing = await disponibilidadesRef
                    .where('data', isEqualTo: novaDisp.data.toIso8601String())
                    .limit(1)
                    .get();
                
                if (existing.docs.isEmpty) {
                  final docRef = disponibilidadesRef.doc();
                  batch.set(docRef, novaDisp.toMap(medicoId));
                  disponibilidadesCriadas++;
                }
              }
              
              await batch.commit();
              
              // Criar alocações correspondentes
              // Criar alocações para o ano de destino
              final alocacoesRef = firestore
                  .collection('unidades')
                  .doc(widget.unidade!.id)
                  .collection('alocacoes')
                  .doc(anoDestino.toString())
                  .collection('registos');
              
              final batchAlocacoes = firestore.batch();
              
              // Para criar alocações, precisamos encontrar o padrão de alocação da série
              // Encontrar o gabinete mais comum para esta série no ano anterior
              // (ignorando dias que podem ter sido apagados por férias)
              final Map<String, int> gabinetesCount = {};
              for (final aloc in medicoImport.alocacoes) {
                // Verificar se esta alocação corresponde a uma data desta série
                final corresponde = serie.any((d) =>
                    d.data.year == aloc.data.year &&
                    d.data.month == aloc.data.month &&
                    d.data.day == aloc.data.day);
                
                if (corresponde) {
                  gabinetesCount[aloc.gabineteId] = (gabinetesCount[aloc.gabineteId] ?? 0) + 1;
                }
              }
              
              // Se encontrou alocações para esta série, usar o gabinete mais comum
              String? gabineteIdSerie;
              if (gabinetesCount.isNotEmpty) {
                gabineteIdSerie = gabinetesCount.entries
                    .reduce((a, b) => a.value > b.value ? a : b)
                    .key;
                
                // Encontrar um exemplo de alocação para pegar os horários
                final exemploAlocacao = medicoImport.alocacoes.firstWhere(
                  (a) => a.gabineteId == gabineteIdSerie &&
                         serie.any((d) =>
                             d.data.year == a.data.year &&
                             d.data.month == a.data.month &&
                             d.data.day == a.data.day),
                  orElse: () => medicoImport.alocacoes.firstWhere(
                    (a) => a.gabineteId == gabineteIdSerie,
                    orElse: () => Alocacao(
                      id: '',
                      medicoId: '',
                      gabineteId: '',
                      data: DateTime.now(),
                      horarioInicio: '',
                      horarioFim: '',
                    ),
                  ),
                );
                
                // Criar alocações para TODAS as datas da série completa
                // (não apenas para as que existiam no ano anterior)
                for (final novaDisp in novasDisponibilidades) {
                  // Verificar se já existe alocação
                  final existing = await alocacoesRef
                      .where('medicoId', isEqualTo: medicoId)
                      .where('data', isEqualTo: novaDisp.data.toIso8601String())
                      .limit(1)
                      .get();
                  
                  if (existing.docs.isEmpty && exemploAlocacao.id.isNotEmpty) {
                    final novaAloc = Alocacao(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      medicoId: medicoId,
                      gabineteId: gabineteIdSerie,
                      data: novaDisp.data,
                      horarioInicio: exemploAlocacao.horarioInicio,
                      horarioFim: exemploAlocacao.horarioFim,
                    );
                    
                    final docRef = alocacoesRef.doc();
                    batchAlocacoes.set(docRef, novaAloc.toMap());
                    alocacoesCriadas++;
                  }
                }
              }
              
              await batchAlocacoes.commit();
            } catch (e) {
              erros++;
              debugPrint('Erro ao importar série do médico $medicoId: $e');
            }
          }
        } catch (e) {
          erros++;
          debugPrint('Erro ao importar médico $medicoId: $e');
        }
      }
      
      if (mounted) {
        Navigator.pop(context); // Fechar diálogo de progresso
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erros > 0
                  ? '$disponibilidadesCriadas disponibilidade(s) e $alocacoesCriadas alocação(ões) criadas. $erros erro(s).'
                  : '$disponibilidadesCriadas disponibilidade(s) e $alocacoesCriadas alocação(ões) importadas com sucesso!',
            ),
            backgroundColor: erros > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Recarregar lista
        medicosSelecionados.clear();
        await _carregarMedicosAnoSelecionado();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fechar diálogo de progresso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Importar Dados',
      ),
      body: isLoadingAnos
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seletores de ano
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ano de Origem:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<int?>(
                                  value: anoOrigem,
                                  isExpanded: true,
                                  hint: anosDisponiveis.isEmpty
                                      ? const Text('Nenhum ano encontrado')
                                      : const Text('Selecione o ano'),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Selecione o ano'),
                                    ),
                                    ...anosDisponiveis.map((ano) => DropdownMenuItem(
                                          value: ano,
                                          child: Text(ano.toString()),
                                        )),
                                  ],
                                  onChanged: anosDisponiveis.isEmpty
                                      ? null
                                      : (value) {
                                          setState(() {
                                            anoOrigem = value;
                                            if (value != null && anoDestino <= value) {
                                              anoDestino = value + 1;
                                            }
                                            // Limpar dados anteriores
                                            medicosParaImportar = [];
                                            medicosSelecionados.clear();
                                            totalDisponibilidades = 0;
                                            totalAlocacoes = 0;
                                          });
                                          // Só carregar médicos se um ano foi selecionado
                                          if (value != null) {
                                            _carregarMedicosAnoSelecionado();
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Recarregar anos disponíveis',
                            onPressed: _carregarAnosDisponiveis,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ano de Destino:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<int>(
                                  value: anoDestino,
                                  isExpanded: true,
                                  items: List.generate(10, (index) {
                                    final ano = DateTime.now().year - 2 + index;
                                    return DropdownMenuItem(
                                      value: ano,
                                      child: Text(ano.toString()),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null && anoOrigem != null && value > anoOrigem!) {
                                      setState(() {
                                        anoDestino = value;
                                      });
                                      // Não precisa recarregar médicos ao mudar apenas o destino
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'O ano de destino deve ser maior que o ano de origem',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (anosDisponiveis.isEmpty && !isLoadingAnos)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Nenhum ano com dados encontrado. Verifique o console (F12) para mais detalhes.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Estatísticas
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEstatistica(
                        'Médicos',
                        medicosParaImportar.length,
                      ),
                      _buildEstatistica(
                        'Disponibilidades',
                        totalDisponibilidades,
                      ),
                      _buildEstatistica(
                        'Alocações',
                        totalAlocacoes,
                      ),
                    ],
                  ),
                ),
                
                // Botão de ação
                if (medicosSelecionados.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.green[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${medicosSelecionados.length} médico(s) selecionado(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _importarMedicosSelecionados,
                          icon: const Icon(Icons.upload),
                          label: const Text('Importar Selecionados'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Lista de médicos
                Expanded(
                  child: anoOrigem == null
                      ? const Center(
                          child: Text('Selecione um ano de origem para ver os médicos'),
                        )
                      : isLoadingMedicos
                          ? const Center(child: CircularProgressIndicator())
                          : medicosParaImportar.isEmpty
                              ? Center(
                                  child: Text(
                                    'Nenhum médico encontrado no ano $anoOrigem',
                                  ),
                                )
                      : ListView.builder(
                          itemCount: medicosParaImportar.length,
                          itemBuilder: (context, index) {
                            final medicoImport = medicosParaImportar[index];
                            final isSelected = medicosSelecionados.contains(
                              medicoImport.medico.id,
                            );
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              color: isSelected ? Colors.blue[100] : null,
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      medicosSelecionados.add(medicoImport.medico.id);
                                    } else {
                                      medicosSelecionados.remove(medicoImport.medico.id);
                                    }
                                  });
                                },
                                title: Text(
                                  medicoImport.medico.nome,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Especialidade: ${medicoImport.medico.especialidade}',
                                    ),
                                    Text(
                                      'Disponibilidades: ${medicoImport.disponibilidades.length}',
                                    ),
                                    Text(
                                      'Alocações: ${medicoImport.alocacoes.length}',
                                    ),
                                    // Mostrar tipos de séries
                                    if (medicoImport.disponibilidades.isNotEmpty)
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          ...medicoImport.disponibilidades
                                              .map((d) => d.tipo)
                                              .toSet()
                                              .map((tipo) => Chip(
                                                    label: Text(tipo),
                                                    labelStyle: const TextStyle(fontSize: 10),
                                                  )),
                                        ],
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
    );
  }

  Widget _buildEstatistica(String label, int valor) {
    return Column(
      children: [
        Text(
          valor.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Classe auxiliar para armazenar dados de importação de um médico
class MedicoImportacao {
  final Medico medico;
  final List<Disponibilidade> disponibilidades;
  final List<Alocacao> alocacoes;

  MedicoImportacao({
    required this.medico,
    required this.disponibilidades,
    required this.alocacoes,
  });
}

