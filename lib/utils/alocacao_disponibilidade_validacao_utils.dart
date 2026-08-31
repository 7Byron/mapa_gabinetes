import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import 'time_utils.dart';

class AtualizacaoHorarioAlocacao {
  final Alocacao original;
  final Alocacao atualizada;

  const AtualizacaoHorarioAlocacao({
    required this.original,
    required this.atualizada,
  });
}

/// Valida alocações persistidas contra os cartões de disponibilidade atuais.
class AlocacaoDisponibilidadeValidacaoUtils {
  AlocacaoDisponibilidadeValidacaoUtils._();

  static String _chaveMedicoDia(String medicoId, DateTime data) =>
      '${medicoId}_${data.year}-${data.month}-${data.day}';

  static String? _chaveIntervalo(String inicio, String fim) {
    try {
      return '${TimeUtils.parseTimeToMinutes(inicio)}_'
          '${TimeUtils.parseTimeToMinutes(fim)}';
    } on FormatException {
      return null;
    }
  }

  /// Remove apenas alocações cujo médico tem disponibilidades carregadas no
  /// dia, mas nenhuma delas corresponde ao intervalo da alocação.
  ///
  /// Se um médico não tiver qualquer disponibilidade carregada, a alocação é
  /// preservada. Este comportamento conservador evita ocultar cartões quando
  /// uma leitura parcial do Firestore falha.
  static List<Alocacao> filtrarOrfasConfirmadas({
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    void Function(Alocacao alocacao)? onOrfaEncontrada,
  }) {
    final intervalosPorMedicoDia = <String, Set<String>>{};

    for (final disponibilidade in disponibilidades) {
      if (disponibilidade.horarios.length < 2) continue;
      final intervalo = _chaveIntervalo(
        disponibilidade.horarios[0],
        disponibilidade.horarios[1],
      );
      if (intervalo == null) continue;

      final chave = _chaveMedicoDia(
        disponibilidade.medicoId,
        disponibilidade.data,
      );
      intervalosPorMedicoDia
          .putIfAbsent(chave, () => <String>{})
          .add(intervalo);
    }

    return alocacoes.where((alocacao) {
      final chave = _chaveMedicoDia(alocacao.medicoId, alocacao.data);
      final intervalosValidos = intervalosPorMedicoDia[chave];
      if (intervalosValidos == null) return true;

      final intervaloAlocacao = _chaveIntervalo(
        alocacao.horarioInicio,
        alocacao.horarioFim,
      );
      final valida = intervaloAlocacao != null &&
          intervalosValidos.contains(intervaloAlocacao);
      if (!valida) onOrfaEncontrada?.call(alocacao);
      return valida;
    }).toList();
  }

  static bool disponibilidadeCorresponde({
    required Disponibilidade disponibilidade,
    required String medicoId,
    required DateTime data,
    required String horarioInicio,
    required String horarioFim,
  }) {
    if (disponibilidade.medicoId != medicoId ||
        disponibilidade.data.year != data.year ||
        disponibilidade.data.month != data.month ||
        disponibilidade.data.day != data.day ||
        disponibilidade.horarios.length < 2) {
      return false;
    }

    final esperado = _chaveIntervalo(horarioInicio, horarioFim);
    final atual = _chaveIntervalo(
      disponibilidade.horarios[0],
      disponibilidade.horarios[1],
    );
    return esperado != null && esperado == atual;
  }

  static bool alocacaoCorrespondeAoCartao({
    required Alocacao alocacao,
    required String medicoId,
    required DateTime data,
    required List<String> horarios,
  }) {
    if (horarios.length < 2 ||
        alocacao.medicoId != medicoId ||
        alocacao.data.year != data.year ||
        alocacao.data.month != data.month ||
        alocacao.data.day != data.day) {
      return false;
    }

    final esperado = _chaveIntervalo(horarios[0], horarios[1]);
    final atual = _chaveIntervalo(
      alocacao.horarioInicio,
      alocacao.horarioFim,
    );
    return esperado != null && esperado == atual;
  }

  /// Deteta reparações seguras para dados antigos em que o horário de uma
  /// disponibilidade única foi alterado sem atualizar a respetiva alocação.
  /// Só propõe uma alteração quando existe exatamente um cartão e uma única
  /// alocação para o médico nesse dia; perante qualquer ambiguidade não tenta
  /// adivinhar a correspondência.
  static List<AtualizacaoHorarioAlocacao>
      encontrarCorrecoesInequivocasDeCartoesUnicos({
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
  }) {
    final dispsPorMedicoDia = <String, List<Disponibilidade>>{};
    final alocsPorMedicoDia = <String, List<Alocacao>>{};

    for (final disponibilidade in disponibilidades) {
      final chave = _chaveMedicoDia(
        disponibilidade.medicoId,
        disponibilidade.data,
      );
      dispsPorMedicoDia
          .putIfAbsent(chave, () => <Disponibilidade>[])
          .add(disponibilidade);
    }
    for (final alocacao in alocacoes) {
      final chave = _chaveMedicoDia(alocacao.medicoId, alocacao.data);
      alocsPorMedicoDia.putIfAbsent(chave, () => <Alocacao>[]).add(alocacao);
    }

    final correcoes = <AtualizacaoHorarioAlocacao>[];
    for (final entry in dispsPorMedicoDia.entries) {
      final disps = entry.value;
      final alocs = alocsPorMedicoDia[entry.key] ?? const <Alocacao>[];
      if (disps.length != 1 || alocs.length != 1) continue;

      final disp = disps.single;
      final aloc = alocs.single;
      if (disp.tipo != 'Única' ||
          disp.horarios.length < 2 ||
          disponibilidadeCorresponde(
            disponibilidade: disp,
            medicoId: aloc.medicoId,
            data: aloc.data,
            horarioInicio: aloc.horarioInicio,
            horarioFim: aloc.horarioFim,
          )) {
        continue;
      }

      correcoes.add(
        AtualizacaoHorarioAlocacao(
          original: aloc,
          atualizada: Alocacao(
            id: aloc.id,
            medicoId: aloc.medicoId,
            gabineteId: aloc.gabineteId,
            data: aloc.data,
            horarioInicio: disp.horarios[0],
            horarioFim: disp.horarios[1],
          ),
        ),
      );
    }
    return correcoes;
  }
}
