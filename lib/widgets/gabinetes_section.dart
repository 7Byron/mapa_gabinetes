import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gabinete.dart';
import '../models/alocacao.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../utils/conflict_utils.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/serie_service.dart';
import '../services/serie_generator.dart';
import '../models/serie_recorrencia.dart';
import 'medico_card.dart';

class GabinetesSection extends StatefulWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final VoidCallback onAtualizarEstado;
  final Future<void> Function(String medicoId) onDesalocarMedicoComPergunta;
  final bool isAdmin; // Novo parâmetro para controlar permissões
  final Set<String>
      medicosDestacados; // IDs dos médicos destacados pela pesquisa
  final Unidade? unidade; // Unidade para buscar disponibilidades do Firebase

  /// Função que aloca UM médico em UM gabinete em UM dia específico
  final Future<void> Function(
    String medicoId,
    String gabineteId, {
    DateTime? dataEspecifica,
    List<String>? horarios,
  }) onAlocarMedico;

  const GabinetesSection({
    super.key,
    required this.gabinetes,
    required this.alocacoes,
    required this.medicos,
    required this.disponibilidades,
    required this.selectedDate,
    required this.onAlocarMedico,
    required this.onAtualizarEstado,
    required this.onDesalocarMedicoComPergunta,
    this.isAdmin = false, // Por defeito é utilizador normal
    this.medicosDestacados = const {}, // Por defeito nenhum médico destacado
    this.unidade, // Unidade opcional
  });

  @override
  State<GabinetesSection> createState() => _GabinetesSectionState();
}

class _GabinetesSectionState extends State<GabinetesSection> {
  int _horarioParaMinutos(String horario) {
    final partes = horario.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Realoca um médico de um gabinete para outro
  /// Se for série, pergunta se quer realocar toda a série ou apenas o dia
  Future<void> _realocarMedicoEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataAlvo,
  }) async {
    try {
      // Buscar todas as alocações do médico do Firebase para verificar se é série
      debugPrint('🔍 Verificando se é série para realocação...');
      final todasAlocacoesMedico = await AlocacaoMedicosLogic.buscarAlocacoesMedico(
        widget.unidade,
        medicoId,
        anoEspecifico: dataAlvo.year,
      );
      
      final dataAlvoNormalizada = DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
      
      // Verificar se há outras alocações do mesmo médico em datas futuras
      final alocacoesFuturas = todasAlocacoesMedico.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return aDateNormalizada.isAfter(dataAlvoNormalizada) &&
            a.gabineteId == gabineteOrigem; // Apenas do gabinete de origem
      }).toList();
      
      // Verificar se há outras alocações passadas do mesmo gabinete
      final alocacoesPassadas = todasAlocacoesMedico.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return aDateNormalizada.isBefore(dataAlvoNormalizada) &&
            a.gabineteId == gabineteOrigem; // Apenas do gabinete de origem
      }).toList();
      
      bool podeSerSerie = alocacoesFuturas.isNotEmpty || alocacoesPassadas.isNotEmpty;
      
      // Tentar inferir o tipo da série
      String tipoSerie = 'Única';
      if (podeSerSerie) {
        // Buscar disponibilidade para verificar o tipo
        final disponibilidade = widget.disponibilidades.firstWhere(
          (d) =>
              d.medicoId == medicoId &&
              d.data.year == dataAlvo.year &&
              d.data.month == dataAlvo.month &&
              d.data.day == dataAlvo.day,
          orElse: () => Disponibilidade(
            id: '',
            medicoId: '',
            data: DateTime(1900, 1, 1),
            horarios: [],
            tipo: 'Única',
          ),
        );
        
        tipoSerie = disponibilidade.tipo;
        
        // Se não encontrou disponibilidade ou é "Única", tentar inferir
        if (tipoSerie == 'Única' && alocacoesFuturas.isNotEmpty) {
          final primeiraFutura = alocacoesFuturas.first;
          final primeiraFuturaDate = DateTime(
            primeiraFutura.data.year,
            primeiraFutura.data.month,
            primeiraFutura.data.day,
          );
          final diasDiferenca = primeiraFuturaDate.difference(dataAlvoNormalizada).inDays;
          
          if (diasDiferenca == 7 || diasDiferenca % 7 == 0) {
            tipoSerie = 'Semanal';
          } else if (diasDiferenca == 14 || diasDiferenca % 14 == 0) {
            tipoSerie = 'Quinzenal';
          } else if (primeiraFuturaDate.day == dataAlvoNormalizada.day) {
            tipoSerie = 'Mensal';
          }
        }
      }
      
      // Se é série, perguntar se quer realocar toda a série ou apenas o dia
      if (podeSerSerie && tipoSerie != 'Única') {
        final escolha = await showDialog<String>(
          context: context,
          builder: (ctxDialog) {
            return AlertDialog(
              title: const Text('Realocar série?'),
              content: Text(
                'Esta alocação faz parte de uma série "$tipoSerie".\n\n'
                'Deseja realocar apenas este dia (${dataAlvo.day}/${dataAlvo.month}) '
                'ou toda a série a partir deste dia para o novo gabinete?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctxDialog).pop('1dia'),
                  child: const Text('Apenas este dia'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctxDialog).pop('serie'),
                  child: const Text('Toda a série'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctxDialog).pop(null),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
        
        if (escolha == null) {
          return; // Usuário cancelou
        }
        
        if (escolha == 'serie') {
          // Realocar toda a série
          await _realocarSerieEntreGabinetes(
            medicoId: medicoId,
            gabineteOrigem: gabineteOrigem,
            gabineteDestino: gabineteDestino,
            dataRef: dataAlvo,
            tipoSerie: tipoSerie,
          );
          return;
        }
      }
      
      // Realocar apenas o dia (ou se não for série)
      await _realocarDiaUnicoEntreGabinetes(
        medicoId: medicoId,
        gabineteOrigem: gabineteOrigem,
        gabineteDestino: gabineteDestino,
        dataAlvo: dataAlvo,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao realocar médico entre gabinetes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao realocar médico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Realoca apenas um dia entre gabinetes
  Future<void> _realocarDiaUnicoEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataAlvo,
  }) async {
    try {
      // Desalocar do gabinete de origem usando a função estática
      // Mas como não temos acesso direto a onAlocacoesChanged, vamos fazer manualmente
      final firestore = FirebaseFirestore.instance;
      final ano = dataAlvo.year.toString();
      final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      
      // Encontrar a alocação no gabinete de origem
      final alocacaoParaRemover = widget.alocacoes.firstWhere(
        (a) {
          final aDate = DateTime(a.data.year, a.data.month, a.data.day);
          return a.medicoId == medicoId &&
              a.gabineteId == gabineteOrigem &&
              aDate == dataAlvo;
        },
      );
      
      // Remover do Firebase
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');
      
      await alocacoesRef.doc(alocacaoParaRemover.id).delete();
      
      // Alocar no novo gabinete
      await widget.onAlocarMedico(
        medicoId,
        gabineteDestino,
        dataEspecifica: dataAlvo,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Médico realocado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao realocar dia único: $e');
      rethrow;
    }
  }

  /// Realoca toda a série entre gabinetes
  Future<void> _realocarSerieEntreGabinetes({
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime dataRef,
    required String tipoSerie,
  }) async {
    try {
      debugPrint('🔄 Realocando série "$tipoSerie" do gabinete $gabineteOrigem para $gabineteDestino');
      
      // Buscar todas as alocações da série do gabinete de origem
      final todasAlocacoesMedico = await AlocacaoMedicosLogic.buscarAlocacoesMedico(
        widget.unidade,
        medicoId,
        anoEspecifico: dataRef.year,
      );
      
      final dataRefNormalizada = DateTime(dataRef.year, dataRef.month, dataRef.day);
      
      // Filtrar alocações da série a partir da data de referência no gabinete de origem
      final alocacoesDaSerie = todasAlocacoesMedico.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        final aDateNormalizada = DateTime(aDate.year, aDate.month, aDate.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteOrigem &&
            !aDateNormalizada.isBefore(dataRefNormalizada);
      }).toList();
      
      debugPrint('📊 Alocações da série encontradas: ${alocacoesDaSerie.length}');
      
      if (alocacoesDaSerie.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma alocação da série encontrada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Desalocar todas as alocações da série do gabinete de origem
      for (final aloc in alocacoesDaSerie) {
        try {
          final firestore = FirebaseFirestore.instance;
          final ano = aloc.data.year.toString();
          final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
          final alocacoesRef = firestore
              .collection('unidades')
              .doc(unidadeId)
              .collection('alocacoes')
              .doc(ano)
              .collection('registos');
          
          await alocacoesRef.doc(aloc.id).delete();
          debugPrint('  ✅ Alocação removida: ${aloc.id}');
        } catch (e) {
          debugPrint('  ❌ Erro ao remover alocação: $e');
        }
      }
      
      // Alocar todas as alocações da série no novo gabinete
      int alocadas = 0;
      for (final aloc in alocacoesDaSerie) {
        try {
          await widget.onAlocarMedico(
            medicoId,
            gabineteDestino,
            dataEspecifica: aloc.data,
          );
          alocadas++;
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('  ❌ Erro ao alocar dia ${aloc.data.day}/${aloc.data.month}: $e');
        }
      }
      
      debugPrint('✅ Série realocada: $alocadas de ${alocacoesDaSerie.length} dias');
      
      // Atualizar estado
      widget.onAtualizarEstado();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Série realocada: $alocadas de ${alocacoesDaSerie.length} dia(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao realocar série: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool _validarDisponibilidade(Disponibilidade disponibilidade) {
    if (disponibilidade.horarios.isEmpty) return false;

    for (final horario in disponibilidade.horarios) {
      if (horario.isEmpty || !horario.contains(':')) return false;

      final partes = horario.split(':');
      if (partes.length != 2) return false;

      try {
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);

        if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) return false;
      } catch (e) {
        return false;
      }
    }

    return true;
  }

  /// Extrai o número do nome do gabinete para ordenação
  /// Exemplos: "Gabinete 101" -> 101, "103" -> 103, "Sala A" -> null
  int? _extrairNumeroGabinete(String nome) {
    // Procura por sequências de dígitos no nome
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(nome);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '');
    }
    return null;
  }

  /// Ordena gabinetes por número (se disponível) ou alfabeticamente
  void _ordenarGabinetesPorNumero(List<Gabinete> gabinetes) {
    gabinetes.sort((a, b) {
      final numA = _extrairNumeroGabinete(a.nome);
      final numB = _extrairNumeroGabinete(b.nome);
      
      // Se ambos têm números, ordena numericamente
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }
      
      // Se apenas um tem número, ele vem primeiro
      if (numA != null) return -1;
      if (numB != null) return 1;
      
      // Se nenhum tem número, ordena alfabeticamente
      return a.nome.compareTo(b.nome);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa gabinetes por setor
    final gabinetesPorSetor = <String, List<Gabinete>>{};
    for (var g in widget.gabinetes) {
      gabinetesPorSetor[g.setor] ??= [];
      gabinetesPorSetor[g.setor]!.add(g);
    }
    
    // Ordena gabinetes dentro de cada setor por número
    gabinetesPorSetor.forEach((setor, lista) {
      _ordenarGabinetesPorNumero(lista);
    });

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      physics: const ClampingScrollPhysics(),
      itemCount: gabinetesPorSetor.keys.length,
      itemBuilder: (context, index) {
        final setor = gabinetesPorSetor.keys.elementAt(index);
        final listaGabinetes = gabinetesPorSetor[setor]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título do setor
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                setor,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Grid de Gabinetes
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: listaGabinetes.length,
              itemBuilder: (ctx, idx) {
                final gabinete = listaGabinetes[idx];

                // Alocações deste gabinete no dia selecionado
                final alocacoesDoGab = widget.alocacoes.where((a) {
                  // Filtrar apenas alocações do dia selecionado
                  if (a.gabineteId != gabinete.id ||
                      a.data.year != widget.selectedDate.year ||
                      a.data.month != widget.selectedDate.month ||
                      a.data.day != widget.selectedDate.day) {
                    return false;
                  }
                  
                  // FILTRAR: Não mostrar alocações de médicos inativos
                  final medico = widget.medicos.firstWhere(
                    (m) => m.id == a.medicoId,
                    orElse: () => Medico(
                      id: a.medicoId,
                      nome: 'Desconhecido',
                      especialidade: '',
                      disponibilidades: [],
                      ativo: false,
                    ),
                  );
                  
                  // Só mostrar se o médico estiver ativo
                  return medico.ativo;
                }).toList();

                final temConflito =
                    ConflictUtils.temConflitoGabinete(alocacoesDoGab);

                Color corFundo;
                if (alocacoesDoGab.isEmpty) {
                  corFundo = const Color(0xFFE4EAF2); // Azul clarinho
                } else if (temConflito) {
                  corFundo = const Color(0xFFFFCDD2); // Vermelho clarinho
                } else {
                  corFundo = const Color(0xFFC8E6C9); // Verde clarinho
                }

                return DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    // Verificar se o usuário é administrador
                    if (!widget.isAdmin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Apenas administradores podem fazer alterações nas alocações.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return false;
                    }

                    final medicoId = details.data;
                    // 1) Ache o médico
                    final medico = widget.medicos.firstWhere(
                      (m) => m.id == medicoId,
                      orElse: () => Medico(
                        id: '',
                        nome: '',
                        especialidade: '',
                        disponibilidades: [],
                        ativo: false,
                      ),
                    );
                    if (medico.id.isEmpty) return false;

                    // 2) Verificar se o médico já está alocado em outro gabinete
                    final dataAlvo = DateTime(
                      widget.selectedDate.year,
                      widget.selectedDate.month,
                      widget.selectedDate.day,
                    );
                    final estaAlocadoEmOutroGabinete = widget.alocacoes.any((a) {
                      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                      return a.medicoId == medicoId &&
                          a.gabineteId != gabinete.id &&
                          aDate == dataAlvo;
                    });

                    // Se já está alocado em outro gabinete, não precisa validar disponibilidade
                    // (o cartão já está funcionando, apenas está sendo movido)
                    if (estaAlocadoEmOutroGabinete) {
                      debugPrint('Médico $medicoId está alocado em outro gabinete, aceitando para realocar.');
                      return true;
                    }

                    // 3) Se não está alocado, verificar disponibilidade (vem da área de não alocados)
                    final disponibilidade = widget.disponibilidades.firstWhere(
                      (d) =>
                          d.medicoId == medico.id &&
                          d.data.year == widget.selectedDate.year &&
                          d.data.month == widget.selectedDate.month &&
                          d.data.day == widget.selectedDate.day,
                      orElse: () => Disponibilidade(
                        id: '',
                        medicoId: '',
                        data: DateTime(1900, 1, 1),
                        horarios: [],
                        tipo: 'Única',
                      ),
                    );
                    if (disponibilidade.medicoId.isEmpty) return false;

                    // 4) Verifica se horários são válidos (apenas para novos cartões)
                    if (!_validarDisponibilidade(disponibilidade)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cartão de disponibilidade mal configurado. Configure corretamente.',
                          ),
                        ),
                      );
                      return false;
                    }
                    debugPrint('Médico $medicoId não está alocado, aceitando para alocar.');
                    return true;
                  },
                  onAcceptWithDetails: (details) async {
                    final medicoId = details.data;
                    
                    // Verificar se o médico já está alocado neste gabinete no dia selecionado
                    final dataAlvo = DateTime(
                      widget.selectedDate.year,
                      widget.selectedDate.month,
                      widget.selectedDate.day,
                    );
                    final jaEstaAlocadoNoMesmoGabinete = widget.alocacoes.any((a) {
                      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                      return a.medicoId == medicoId &&
                          a.gabineteId == gabinete.id &&
                          aDate == dataAlvo;
                    });
                    
                    // Se já está alocado no mesmo gabinete, desalocar (com pergunta)
                    if (jaEstaAlocadoNoMesmoGabinete) {
                      await widget.onDesalocarMedicoComPergunta(medicoId);
                      return;
                    }
                    
                    // Verificar se o médico está alocado em OUTRO gabinete no dia selecionado
                    final alocacaoEmOutroGabinete = widget.alocacoes.firstWhere(
                      (a) {
                        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
                        return a.medicoId == medicoId &&
                            a.gabineteId != gabinete.id &&
                            aDate == dataAlvo;
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
                    
                    // Se está alocado em outro gabinete, perguntar se quer realocar
                    if (alocacaoEmOutroGabinete.id.isNotEmpty) {
                      await _realocarMedicoEntreGabinetes(
                        medicoId: medicoId,
                        gabineteOrigem: alocacaoEmOutroGabinete.gabineteId,
                        gabineteDestino: gabinete.id,
                        dataAlvo: dataAlvo,
                      );
                      return;
                    }
                    
                    // 1) Localiza disponibilidade
                    final disponibilidade = widget.disponibilidades.firstWhere(
                      (d) =>
                          d.medicoId == medicoId &&
                          d.data.year == widget.selectedDate.year &&
                          d.data.month == widget.selectedDate.month &&
                          d.data.day == widget.selectedDate.day,
                      orElse: () => Disponibilidade(
                        id: '',
                        medicoId: '',
                        data: DateTime(1900, 1, 1),
                        horarios: [],
                        tipo: '',
                      ),
                    );

                    if (disponibilidade.medicoId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Disponibilidade inválida para o médico.')),
                      );
                      return;
                    }

                    final tipoDisponibilidade = disponibilidade.tipo;

                    if (tipoDisponibilidade == 'Única') {
                      await widget.onAlocarMedico(
                        medicoId,
                        gabinete.id,
                        dataEspecifica: widget.selectedDate,
                      );
                      // Não precisa chamar onAtualizarEstado() aqui porque
                      // onAlocarMedico já chama onAlocacoesChanged() internamente
                    } else {
                      // Pergunta se alocar série
                      final escolha = await showDialog<String>(
                        context: context,
                        builder: (ctxDialog) {
                          return AlertDialog(
                            title: const Text('Alocar série?'),
                            content: Text(
                              'Esta disponibilidade é do tipo "$tipoDisponibilidade".\n'
                              'Deseja alocar apenas este dia (${widget.selectedDate.day}/${widget.selectedDate.month}) '
                              'ou todos os dias da série a partir deste?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctxDialog).pop('1dia'),
                                child: const Text('Apenas este dia'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctxDialog).pop('serie'),
                                child: const Text('Toda a série'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctxDialog).pop(null),
                                child: const Text('Cancelar'),
                              ),
                            ],
                          );
                        },
                      );

                      if (escolha == '1dia') {
                        await widget.onAlocarMedico(
                          medicoId,
                          gabinete.id,
                          dataEspecifica: widget.selectedDate,
                        );
                        // Não precisa chamar onAtualizarEstado() aqui porque
                        // onAlocarMedico já chama onAlocacoesChanged() internamente
                      } else if (escolha == 'serie') {
                        try {
                        final dataRef = widget.selectedDate;
                          
                          debugPrint('🔄 Alocando série do tipo: $tipoDisponibilidade');
                          debugPrint('📅 Data de referência: ${dataRef.day}/${dataRef.month}/${dataRef.year}');
                          debugPrint('👨‍⚕️ Médico ID: $medicoId');
                          debugPrint('🏢 Gabinete ID: ${gabinete.id}');
                          
                          if (widget.unidade == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Erro: Unidade não definida'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          
                          // Normalizar o tipo da série
                          final tipoNormalizado = tipoDisponibilidade.startsWith('Consecutivo')
                              ? 'Consecutivo'
                              : tipoDisponibilidade;
                          
                          // Extrair número de dias para séries consecutivas
                          int? numeroDiasConsecutivo;
                          if (tipoNormalizado == 'Consecutivo') {
                            final match = RegExp(r'Consecutivo:(\d+)').firstMatch(tipoDisponibilidade);
                            numeroDiasConsecutivo = match != null ? int.tryParse(match.group(1) ?? '') ?? 5 : 5;
                          }
                          
                          // Usar horários da disponibilidade
                          final horariosRef = disponibilidade.horarios.isNotEmpty 
                              ? disponibilidade.horarios 
                              : ['08:00', '15:00']; // Fallback
                          
                          // Buscar séries existentes do médico
                          final seriesExistentes = await SerieService.carregarSeries(
                            medicoId,
                            unidade: widget.unidade,
                          );
                          
                          // Tentar encontrar uma série correspondente
                          final dataRefNormalizada = DateTime(dataRef.year, dataRef.month, dataRef.day);
                          
                          SerieRecorrencia? serieEncontrada;
                          
                          for (final serie in seriesExistentes) {
                            if (serie.tipo != tipoNormalizado) continue;
                            
                            // Verificar se a data de referência está dentro do período da série
                            if (dataRefNormalizada.isBefore(serie.dataInicio)) continue;
                            if (serie.dataFim != null && dataRefNormalizada.isAfter(serie.dataFim!)) continue;
                            
                            // Para séries mensais, verificar se a data de referência corresponde à mesma ocorrência
                            if (tipoNormalizado == 'Mensal') {
                              final weekdayRef = dataRefNormalizada.weekday;
                              final weekdaySerie = serie.dataInicio.weekday;
                              
                              if (weekdayRef != weekdaySerie) continue;
                              
                              final ocorrenciaRef = _descobrirOcorrenciaNoMes(dataRefNormalizada);
                              final ocorrenciaSerie = _descobrirOcorrenciaNoMes(serie.dataInicio);
                              
                              if (ocorrenciaRef != ocorrenciaSerie) continue;
                            }
                            
                            // Para séries consecutivas, verificar se o número de dias corresponde
                            if (tipoNormalizado == 'Consecutivo' && numeroDiasConsecutivo != null) {
                              final numeroDiasSerie = serie.parametros['numeroDias'] as int? ?? 5;
                              
                              if (numeroDiasSerie != numeroDiasConsecutivo) continue;
                            }
                            
                            // Série encontrada!
                            serieEncontrada = serie;
                            break;
                          }
                          
                          // Se não encontrou série, criar uma nova
                          if (serieEncontrada == null) {
                            debugPrint('📝 Criando nova série do tipo: $tipoDisponibilidade');
                            
                            serieEncontrada = await DisponibilidadeSerieService.criarSerie(
                              medicoId: medicoId,
                              dataInicial: dataRefNormalizada,
                              tipo: tipoDisponibilidade,
                              horarios: horariosRef,
                              unidade: widget.unidade,
                            );
                            
                            debugPrint('✅ Nova série criada: ${serieEncontrada.id}');
                          } else {
                            debugPrint('✅ Série existente encontrada: ${serieEncontrada.id}');
                          }
                          
                          // Verificar se a série já está alocada neste gabinete
                          if (serieEncontrada.gabineteId == gabinete.id) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('A série já está alocada neste gabinete.'),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                            debugPrint('ℹ️ Série já está alocada no gabinete selecionado');
                            widget.onAtualizarEstado();
                            return;
                          }
                          
                          // Verificar se a série está alocada em outro gabinete
                          if (serieEncontrada.gabineteId != null && serieEncontrada.gabineteId != gabinete.id) {
                            if (mounted) {
                              final confirmacao = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Série já alocada'),
                                  content: Text(
                                    'Esta série já está alocada em outro gabinete.\n\n'
                                    'Deseja realocar a série para este gabinete?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Realocar'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirmacao != true) {
                                debugPrint('❌ Usuário cancelou a realocação da série');
                                return;
                              }
                            }
                          }
                          
                          // Atualizar o gabineteId da série
                          debugPrint('🔄 Atualizando gabineteId da série ${serieEncontrada.id} para ${gabinete.id}');
                          
                          await DisponibilidadeSerieService.alocarSerie(
                            serieId: serieEncontrada.id,
                            medicoId: medicoId,
                            gabineteId: gabinete.id,
                            unidade: widget.unidade,
                          );
                          
                          debugPrint('✅ Série alocada ao gabinete ${gabinete.id}');
                          
                          // Gerar e salvar alocações no Firestore para o dia atual e próximos 90 dias
                          // Isso garante que as alocações apareçam imediatamente
                          debugPrint('🔄 Gerando alocações para o dia atual e próximos 90 dias...');
                          
                          final serieAtualizada = SerieRecorrencia(
                            id: serieEncontrada.id,
                            medicoId: serieEncontrada.medicoId,
                            dataInicio: serieEncontrada.dataInicio,
                            dataFim: serieEncontrada.dataFim,
                            tipo: serieEncontrada.tipo,
                            horarios: serieEncontrada.horarios,
                            gabineteId: gabinete.id,
                            parametros: serieEncontrada.parametros,
                            ativo: serieEncontrada.ativo,
                          );
                          
                          // Carregar exceções para o período
                          final excecoes = await SerieService.carregarExcecoes(
                              medicoId,
                            unidade: widget.unidade,
                            dataInicio: dataRefNormalizada,
                            dataFim: dataRefNormalizada.add(const Duration(days: 90)),
                          );
                          
                          // Gerar alocações para os próximos 90 dias
                          final alocacoesGeradas = SerieGenerator.gerarAlocacoes(
                            series: [serieAtualizada],
                            excecoes: excecoes,
                            dataInicio: dataRefNormalizada,
                            dataFim: dataRefNormalizada.add(const Duration(days: 90)),
                          );
                          
                          debugPrint('📊 Alocações geradas: ${alocacoesGeradas.length}');
                          
                          // Salvar todas as alocações geradas no Firestore usando batch write
                          // Isso garante que todas as alocações da série apareçam imediatamente
                          final firestore = FirebaseFirestore.instance;
                          final unidadeId = widget.unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
                          final batch = firestore.batch();
                          
                          // Agrupar alocações por ano para criar as referências corretas
                          final alocacoesPorAno = <String, List<Alocacao>>{};
                          for (final aloc in alocacoesGeradas) {
                            final ano = aloc.data.year.toString();
                            if (!alocacoesPorAno.containsKey(ano)) {
                              alocacoesPorAno[ano] = [];
                            }
                            alocacoesPorAno[ano]!.add(aloc);
                          }
                          
                          // Adicionar todas as alocações ao batch
                          for (final entry in alocacoesPorAno.entries) {
                            final ano = entry.key;
                            final alocacoesRef = firestore
                                .collection('unidades')
                                .doc(unidadeId)
                                .collection('alocacoes')
                                .doc(ano)
                                .collection('registos');
                            
                            for (final aloc in entry.value) {
                              final alocRef = alocacoesRef.doc(aloc.id);
                              batch.set(alocRef, {
                                'id': aloc.id,
                                'medicoId': aloc.medicoId,
                                'gabineteId': aloc.gabineteId,
                                'data': aloc.data.toIso8601String(),
                                'horarioInicio': aloc.horarioInicio,
                                'horarioFim': aloc.horarioFim,
                              });
                            }
                          }
                          
                          // Executar batch write
                          await batch.commit();
                          debugPrint('✅ ${alocacoesGeradas.length} alocações da série salvas no Firestore');
                          
                          // Invalidar cache para todas as datas afetadas
                          for (final aloc in alocacoesGeradas) {
                            AlocacaoMedicosLogic.invalidateCacheFromDate(aloc.data);
                          }
                          
                          // Invalidar cache apenas para o dia atual
                          AlocacaoMedicosLogic.invalidateCacheFromDate(dataRefNormalizada);
                          
                          // NÃO chamar onAtualizarEstado() aqui - o listener do Firestore vai atualizar automaticamente
                          // Isso evita atualizações duplicadas que causam o comportamento de "piscar"
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Série alocada com sucesso! As alocações serão geradas automaticamente.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e, stackTrace) {
                          debugPrint('❌ Erro ao alocar série: $e');
                          debugPrint('Stack trace: $stackTrace');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao alocar série: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    final alocacoesDoGabinete = widget.alocacoes.where((a) {
                      return a.gabineteId == gabinete.id &&
                          a.data.year == widget.selectedDate.year &&
                          a.data.month == widget.selectedDate.month &&
                          a.data.day == widget.selectedDate.day;
                    }).toList()
                      ..sort((a, b) => _horarioParaMinutos(a.horarioInicio)
                          .compareTo(_horarioParaMinutos(b.horarioInicio)));

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: corFundo,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nome do gabinete
                              Text(
                                gabinete.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                gabinete.especialidadesPermitidas.join(", "),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Lista de médicos alocados
                              if (alocacoesDoGabinete.isNotEmpty)
                                ...alocacoesDoGabinete.map((a) {
                                  final medico = widget.medicos.firstWhere(
                                    (m) => m.id == a.medicoId,
                                    orElse: () => Medico(
                                      id: '',
                                      nome: 'Desconhecido',
                                      especialidade: '',
                                      disponibilidades: [],
                                      ativo: false,
                                    ),
                                  );

                                  final horariosAlocacao = a
                                          .horarioFim.isNotEmpty
                                      ? '${a.horarioInicio} - ${a.horarioFim}'
                                      : a.horarioInicio;

                                  // Verificar se o médico está destacado pela pesquisa
                                  final isDestacado = widget.medicosDestacados
                                      .contains(medico.id);
                                  final corDestaque = isDestacado
                                      ? Colors.orange.shade200
                                      : null;

                                  return widget.isAdmin
                                      ? Draggable<String>(
                                          data: medico.id,
                                          feedback: MedicoCard.dragFeedback(
                                            medico,
                                            horariosAlocacao,
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.5,
                                            child:
                                                MedicoCard.buildSmallMedicoCard(
                                              medico,
                                              horariosAlocacao,
                                              Colors.white,
                                              true,
                                              corDestaque: corDestaque,
                                            ),
                                          ),
                                          child:
                                              MedicoCard.buildSmallMedicoCard(
                                            medico,
                                            horariosAlocacao,
                                            Colors.white,
                                            true,
                                            corDestaque: corDestaque,
                                          ),
                                          onDragEnd: (details) {
                                            if (details.wasAccepted == false) {
                                              debugPrint(
                                                  'Cartão foi solto fora de qualquer DragTarget. Nenhuma ação será disparada.');
                                            }
                                          },
                                        )
                                      : MedicoCard.buildSmallMedicoCard(
                                          medico,
                                          horariosAlocacao,
                                          Colors.white,
                                          true,
                                          corDestaque: corDestaque,
                                        );
                                }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
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
}
