// import '../database/database_helper.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../utils/conflict_utils.dart';

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
  }) async {
    try {
      print('🔄 Carregando dados iniciais do Firebase...');

      // Por enquanto, vamos inicializar com listas vazias
      // TODO: Implementar carregamento real do Firebase por unidade
      final gabs = <Gabinete>[];
      final meds = <Medico>[];
      final disps = <Disponibilidade>[];
      final alocs = <Alocacao>[];

      print('✅ Dados iniciais carregados (listas vazias)');
      print('📊 Gabinetes: ${gabs.length}');
      print('📊 Médicos: ${meds.length}');
      print('📊 Disponibilidades: ${disps.length}');
      print('📊 Alocações: ${alocs.length}');

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

    // TODO: Refatorar lógica para usar Firestore diretamente.
    // Toda referência a DatabaseHelper removida. Adapte para usar serviços Firebase.
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
  }) async {
    final dataAlvo =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final indexAloc = alocacoes.indexWhere((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId && aDate == dataAlvo;
    });
    if (indexAloc == -1) return;

    alocacoes.removeAt(indexAloc);
    // TODO: Refatorar lógica para usar Firestore diretamente.
    // Toda referência a DatabaseHelper removida. Adapte para usar serviços Firebase.

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
}
