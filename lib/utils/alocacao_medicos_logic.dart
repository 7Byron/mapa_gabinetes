// import '../database/database_helper.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../services/gabinete_service.dart';
import '../services/medico_salvar_service.dart';
import '../utils/conflict_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlocacaoMedicosLogic {
  static Future<void> carregarDadosIniciais({
    required List<Gabinete> gabinetes,
    required List<Medico> medicos,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required Function(List<Gabinete>) onGabinetes,
    required Function(List<Medico>) onMedicos,
    required Function(List<Disponibilidade>) onDisponibilidades,
    required Function(List<Alocacao>) onAlocacoes,
    Unidade? unidade,
  }) async {
    try {
      print('🔄 Carregando dados iniciais do Firebase...');

      // Carrega gabinetes da unidade
      final gabs = await buscarGabinetes(unidade: unidade);

      // Carrega médicos da unidade
      final meds = await buscarMedicos(unidade: unidade);

      // Carrega disponibilidades da unidade
      final disps = await _carregarDisponibilidadesUnidade(unidade);

      // Carrega alocações da unidade
      final alocs = await _carregarAlocacoesUnidade(unidade);

      print('✅ Dados iniciais carregados');
      print('📊 Gabinetes: ${gabs.length}');
      print('📊 Médicos: ${meds.length}');
      print('📊 Disponibilidades: ${disps.length}');
      print('📊 Alocações: ${alocs.length}');
      
      // Debug específico para o Dr. Francisco
      final drFrancisco = meds.where((m) => m.nome.toLowerCase().contains('francisco')).toList();
      if (drFrancisco.isNotEmpty) {
        print('👨‍⚕️ Dr. Francisco encontrado: ${drFrancisco.first.nome} (ID: ${drFrancisco.first.id})');
        final dispDrFrancisco = disps.where((d) => d.medicoId == drFrancisco.first.id).toList();
        print('  📅 Disponibilidades do Dr. Francisco: ${dispDrFrancisco.length}');
        for (final disp in dispDrFrancisco) {
          print('    - ${disp.data.day}/${disp.data.month}/${disp.data.year} - Horários: ${disp.horarios.join(', ')}');
        }
      } else {
        print('❌ Dr. Francisco não encontrado na lista de médicos');
      }

      // Atualizar as listas
      onGabinetes(List<Gabinete>.from(gabs));
      onMedicos(List<Medico>.from(meds));
      onDisponibilidades(List<Disponibilidade>.from(disps));
      onAlocacoes(List<Alocacao>.from(alocs));
    } catch (e) {
      print('❌ Erro ao carregar dados iniciais: $e');
      // Em caso de erro, inicializar com listas vazias
      onGabinetes(<Gabinete>[]);
      onMedicos(<Medico>[]);
      onDisponibilidades(<Disponibilidade>[]);
      onAlocacoes(<Alocacao>[]);
    }
  }

  static List<Medico> filtrarMedicosPorData({
    required DateTime dataSelecionada,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
  }) {
    final dataAlvo = DateTime(
        dataSelecionada.year, dataSelecionada.month, dataSelecionada.day);

    final dispNoDia = disponibilidades.where((disp) {
      final d = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return d == dataAlvo;
    }).toList();

    final idsMedicosNoDia = dispNoDia.map((d) => d.medicoId).toSet();
    final alocadosNoDia = alocacoes
        .where((a) {
          final aData = DateTime(a.data.year, a.data.month, a.data.day);
          return aData == dataAlvo;
        })
        .map((a) => a.medicoId)
        .toSet();

    return medicos
        .where((m) =>
            idsMedicosNoDia.contains(m.id) && !alocadosNoDia.contains(m.id))
        .toList();
  }

  static List<Gabinete> filtrarGabinetesPorUI({
    required List<Gabinete> gabinetes,
    required List<Alocacao> alocacoes,
    required DateTime selectedDate,
    required List<String> pisosSelecionados,
    required String filtroOcupacao,
    required bool mostrarConflitos,
  }) {
    final filtrados =
        gabinetes.where((g) => pisosSelecionados.contains(g.setor)).toList();

    List<Gabinete> filtradosOcupacao = [];
    for (final gab in filtrados) {
      final alocacoesDoGab = alocacoes.where((a) {
        return a.gabineteId == gab.id &&
            a.data.year == selectedDate.year &&
            a.data.month == selectedDate.month &&
            a.data.day == selectedDate.day;
      }).toList();

      final estaOcupado = alocacoesDoGab.isNotEmpty;

      if (filtroOcupacao == 'Todos') {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Livres' && !estaOcupado) {
        filtradosOcupacao.add(gab);
      } else if (filtroOcupacao == 'Ocupados' && estaOcupado) {
        filtradosOcupacao.add(gab);
      }
    }

    if (mostrarConflitos) {
      return filtradosOcupacao.where((gab) {
        final alocacoesDoGab = alocacoes.where((a) {
          return a.gabineteId == gab.id &&
              a.data.year == selectedDate.year &&
              a.data.month == selectedDate.month &&
              a.data.day == selectedDate.day;
        }).toList();
        return ConflictUtils.temConflitoGabinete(alocacoesDoGab);
      }).toList();
    } else {
      return filtradosOcupacao;
    }
  }

  static Future<void> alocarMedico({
    required DateTime selectedDate,
    required String medicoId,
    required String gabineteId,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required Function() onAlocacoesChanged,
    Unidade? unidade,
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final indexAloc = alocacoes.indexWhere((a) {
      final alocDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && alocDate == dataAlvo;
    });
    if (indexAloc != -1) {
      alocacoes.removeAt(indexAloc);
      // TODO: Refatorar lógica para usar Firestore diretamente.
      // Toda referência a DatabaseHelper removida. Adapte para usar serviços Firebase.
    }

    final dispDoDia = disponibilidades.where((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataAlvo;
    }).toList();

    final horarioInicio =
        dispDoDia.isNotEmpty ? dispDoDia.first.horarios[0] : '00:00';
    final horarioFim =
        dispDoDia.isNotEmpty ? dispDoDia.first.horarios[1] : '00:00';

    final novaAloc = Alocacao(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicoId: medicoId,
      gabineteId: gabineteId,
      data: dataAlvo,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );

    // Salvar no Firebase
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Salvar na coleção de alocações da unidade por ano
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
      final ano = dataAlvo.year.toString();
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');
      
      await alocacoesRef.doc(novaAloc.id).set({
        'id': novaAloc.id,
        'medicoId': novaAloc.medicoId,
        'gabineteId': novaAloc.gabineteId,
        'data': novaAloc.data.toIso8601String(),
        'horarioInicio': novaAloc.horarioInicio,
        'horarioFim': novaAloc.horarioFim,
      });
      
      print('✅ Alocação salva no Firebase: ${novaAloc.id}');
    } catch (e) {
      print('❌ Erro ao salvar alocação no Firebase: $e');
    }

    alocacoes.add(novaAloc);
    onAlocacoesChanged();
  }

  static Future<void> desalocarMedicoDiaUnico({
    required DateTime selectedDate,
    required String medicoId,
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Function() onAlocacoesChanged,
    Unidade? unidade,
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final indexAloc = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });
    if (indexAloc == -1) return;

    final alocacaoRemovida = alocacoes[indexAloc];
    alocacoes.removeAt(indexAloc);
    
    // Remover do Firebase
    try {
      final firestore = FirebaseFirestore.instance;
      final ano = alocacaoRemovida.data.year.toString();
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR'; // Fallback para compatibilidade
      final alocacoesRef = firestore
          .collection('unidades')
          .doc(unidadeId)
          .collection('alocacoes')
          .doc(ano)
          .collection('registos');
      
      await alocacoesRef.doc(alocacaoRemovida.id).delete();
      print('✅ Alocação removida do Firebase: ${alocacaoRemovida.id} (ano: $ano, unidade: $unidadeId)');
    } catch (e) {
      print('❌ Erro ao remover alocação do Firebase: $e');
    }

    final temDisp = disponibilidades.any((disp) {
      final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
      return disp.medicoId == medicoId && dd == dataAlvo;
    });
    if (temDisp) {
      final medico = medicos.firstWhere(
        (m) => m.id == medicoId,
        orElse: () => Medico(
          id: medicoId,
          nome: 'Médico não identificado',
          especialidade: '',
          disponibilidades: [],
        ),
      );
      if (!medicosDisponiveis.contains(medico)) {
        medicosDisponiveis.add(medico);
      }
    }

    onAlocacoesChanged();
  }

  static Future<void> desalocarMedicoSerie({
    required String medicoId,
    required DateTime dataRef,
    required String tipo,
    required List<Disponibilidade> disponibilidades,
    required List<Alocacao> alocacoes,
    required List<Medico> medicos,
    required List<Medico> medicosDisponiveis,
    required Function() onAlocacoesChanged,
  }) async {
    final listaMesmaSerie = disponibilidades.where((d2) {
      if (d2.medicoId != medicoId) return false;
      if (d2.tipo != tipo) return false;
      return !d2.data.isBefore(dataRef);
    }).toList();

    for (final disp in listaMesmaSerie) {
      final dataAlvo = DateTime(disp.data.year, disp.data.month, disp.data.day);
      final indexAloc = alocacoes.indexWhere((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId && aDate == dataAlvo;
      });

      if (indexAloc != -1) {
        alocacoes.removeAt(indexAloc);
        // TODO: Refatorar lógica para usar Firestore diretamente.
        // Toda referência a DatabaseHelper removida. Adapte para usar serviços Firebase.
      }

      final temDisp = disponibilidades.any((disp2) {
        final dd = DateTime(disp2.data.year, disp2.data.month, disp2.data.day);
        return disp2.medicoId == medicoId && dd == dataAlvo;
      });
      if (temDisp) {
        final medico = medicos.firstWhere(
          (m) => m.id == medicoId,
          orElse: () => Medico(
            id: medicoId,
            nome: 'Médico não identificado',
            especialidade: '',
            disponibilidades: [],
          ),
        );
        if (!medicosDisponiveis.contains(medico)) {
          medicosDisponiveis.add(medico);
        }
      }
    }

    onAlocacoesChanged();
  }

  /// Carrega todas as disponibilidades de todos os médicos de uma unidade (otimizado para ano atual)
  static Future<List<Disponibilidade>> _carregarDisponibilidadesUnidade(
      Unidade? unidade) async {
    final anoAtual = DateTime.now().year.toString();
    return _carregarDisponibilidadesUnidadePorAno(unidade, anoAtual);
  }

  /// Carrega disponibilidades de todos os médicos de uma unidade por ano específico
  static Future<List<Disponibilidade>> _carregarDisponibilidadesUnidadePorAno(
      Unidade? unidade, String? anoEspecifico) async {
    final firestore = FirebaseFirestore.instance;
    final disponibilidades = <Disponibilidade>[];

    try {
      if (unidade != null) {
        // Carrega disponibilidades da unidade específica por ano
        final medicosRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('ocupantes');

        final medicosSnapshot = await medicosRef.get();

        print(
            '📊 Carregando disponibilidades para ${medicosSnapshot.docs.length} médicos da unidade ${unidade.id}');
        print('🔍 ID da unidade: ${unidade.id}');
        print('🏥 Nome da unidade: ${unidade.nome}');
        
        // Debug específico para verificar se há médicos
        if (medicosSnapshot.docs.isEmpty) {
          print('⚠️ NENHUM MÉDICO ENCONTRADO NA UNIDADE!');
        } else {
          print('✅ Médicos encontrados:');
          for (final doc in medicosSnapshot.docs) {
            final data = doc.data();
            print('  - ${data['nome']} (${doc.id})');
          }
        }

        for (final medicoDoc in medicosSnapshot.docs) {
          final medicoData = medicoDoc.data();
          final medicoNome = medicoData['nome'] ?? 'Desconhecido';
          print(
              '👨‍⚕️ Verificando disponibilidades do médico: $medicoNome (${medicoDoc.id})');

          final disponibilidadesRef =
              medicoDoc.reference.collection('disponibilidades');

          if (anoEspecifico != null) {
            // Carrega apenas o ano específico (mais eficiente)
            print('  📅 Carregando disponibilidades do ano específico: $anoEspecifico');
            
            final registosRef = disponibilidadesRef.doc(anoEspecifico).collection('registos');
            final registosSnapshot = await registosRef.get();
            
            print('    📊 Registos encontrados no ano $anoEspecifico: ${registosSnapshot.docs.length}');

            for (final dispDoc in registosSnapshot.docs) {
              final data = dispDoc.data();
              final disponibilidade = Disponibilidade.fromMap(data);
              disponibilidades.add(disponibilidade);
              print(
                  '      - ${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year} - Horários: ${disponibilidade.horarios.join(', ')}');
            }
          } else {
            // Carrega todos os anos (para relatórios ou histórico)
            final anosSnapshot = await disponibilidadesRef.get();
            print('  📊 Anos encontrados para disponibilidades: ${anosSnapshot.docs.length}');

            for (final anoDoc in anosSnapshot.docs) {
              final ano = anoDoc.id;
              print('  📅 Carregando disponibilidades do ano: $ano');
              
              final registosRef = anoDoc.reference.collection('registos');
              final registosSnapshot = await registosRef.get();
              
              print('    📊 Registos encontrados no ano $ano: ${registosSnapshot.docs.length}');

              for (final dispDoc in registosSnapshot.docs) {
                final data = dispDoc.data();
                final disponibilidade = Disponibilidade.fromMap(data);
                disponibilidades.add(disponibilidade);
                print(
                    '      - ${disponibilidade.data.day}/${disponibilidade.data.month}/${disponibilidade.data.year} - Horários: ${disponibilidade.horarios.join(', ')}');
              }
            }
          }
        }

        print(
            '📊 Disponibilidades carregadas da unidade ${unidade.id}: ${disponibilidades.length}');
        
        // Debug específico para verificar disponibilidades
        if (disponibilidades.isEmpty) {
          print('⚠️ NENHUMA DISPONIBILIDADE ENCONTRADA!');
        } else {
          print('✅ Disponibilidades encontradas:');
          for (final disp in disponibilidades) {
            print('  - ${disp.medicoId}: ${disp.data.day}/${disp.data.month}/${disp.data.year} - Horários: ${disp.horarios.join(', ')}');
          }
        }
      } else {
        // Carrega disponibilidades globais (fallback)
        final medicosRef = firestore.collection('medicos');
        final medicosSnapshot = await medicosRef.get();

        for (final medicoDoc in medicosSnapshot.docs) {
          final disponibilidadesRef =
              medicoDoc.reference.collection('disponibilidades');
          final dispSnapshot = await disponibilidadesRef.get();

          for (final dispDoc in dispSnapshot.docs) {
            final data = dispDoc.data();
            disponibilidades.add(Disponibilidade.fromMap(data));
          }
        }

        print(
            '📊 Disponibilidades carregadas globalmente: ${disponibilidades.length}');
        
        // Debug específico para verificar disponibilidades globais
        if (disponibilidades.isEmpty) {
          print('⚠️ NENHUMA DISPONIBILIDADE GLOBAL ENCONTRADA!');
        } else {
          print('✅ Disponibilidades globais encontradas:');
          for (final disp in disponibilidades) {
            print('  - ${disp.medicoId}: ${disp.data.day}/${disp.data.month}/${disp.data.year} - Horários: ${disp.horarios.join(', ')}');
          }
        }
      }
    } catch (e) {
      print('❌ Erro ao carregar disponibilidades: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }

    print('🎯 Total final de disponibilidades retornadas: ${disponibilidades.length}');
    return disponibilidades;
  }

  /// Carrega todas as alocações de uma unidade (otimizado para ano atual)
  static Future<List<Alocacao>> _carregarAlocacoesUnidade(Unidade? unidade) async {
    final anoAtual = DateTime.now().year.toString();
    return _carregarAlocacoesUnidadePorAno(unidade, anoAtual); // Carrega apenas o ano atual
  }

  /// Carrega alocações de uma unidade por ano específico
  static Future<List<Alocacao>> _carregarAlocacoesUnidadePorAno(Unidade? unidade, String? anoEspecifico) async {
    final firestore = FirebaseFirestore.instance;
    final alocacoes = <Alocacao>[];

    try {
      if (unidade != null) {
        // Carrega alocações da unidade específica por ano
        final alocacoesRef = firestore
            .collection('unidades')
            .doc(unidade.id)
            .collection('alocacoes');

        if (anoEspecifico != null) {
          // Carrega apenas o ano específico (mais eficiente)
          print('📅 Carregando alocações do ano específico: $anoEspecifico');
          
          final registosRef = alocacoesRef.doc(anoEspecifico).collection('registos');
          final registosSnapshot = await registosRef.get();
          
          print('  📊 Registos encontrados no ano $anoEspecifico: ${registosSnapshot.docs.length}');

          for (final doc in registosSnapshot.docs) {
            final data = doc.data();
            final alocacao = Alocacao.fromMap(data);
            alocacoes.add(alocacao);
            print('    - ${alocacao.medicoId} -> ${alocacao.gabineteId} (${alocacao.data.day}/${alocacao.data.month}/${alocacao.data.year})');
          }
        } else {
          // Carrega todos os anos (para relatórios ou histórico)
          final anosSnapshot = await alocacoesRef.get();
          print('📊 Anos encontrados para alocações: ${anosSnapshot.docs.length}');

          for (final anoDoc in anosSnapshot.docs) {
            final ano = anoDoc.id;
            print('📅 Carregando alocações do ano: $ano');
            
            final registosRef = anoDoc.reference.collection('registos');
            final registosSnapshot = await registosRef.get();
            
            print('  📊 Registos encontrados no ano $ano: ${registosSnapshot.docs.length}');

            for (final doc in registosSnapshot.docs) {
              final data = doc.data();
              final alocacao = Alocacao.fromMap(data);
              alocacoes.add(alocacao);
              print('    - ${alocacao.medicoId} -> ${alocacao.gabineteId} (${alocacao.data.day}/${alocacao.data.month}/${alocacao.data.year})');
            }
          }
        }

        print('📊 Alocações carregadas da unidade ${unidade.id}: ${alocacoes.length}');
      } else {
        // Carrega alocações globais (fallback)
        final alocacoesRef = firestore.collection('alocacoes');
        final alocacoesSnapshot = await alocacoesRef.get();

        for (final doc in alocacoesSnapshot.docs) {
          final data = doc.data();
          alocacoes.add(Alocacao.fromMap(data));
        }

        print('📊 Alocações carregadas globalmente: ${alocacoes.length}');
      }
    } catch (e) {
      print('❌ Erro ao carregar alocações: $e');
    }

    print('🎯 Total final de alocações retornadas: ${alocacoes.length}');
    return alocacoes;
  }
}
