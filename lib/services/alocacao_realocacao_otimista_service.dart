import 'package:flutter/foundation.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';

class AlocacaoRealocacaoOtimistaResult {
  final List<Alocacao> alocacoesAtualizadas;
  final bool ignorar;

  const AlocacaoRealocacaoOtimistaResult({
    required this.alocacoesAtualizadas,
    required this.ignorar,
  });
}

class AlocacaoRealocacaoOtimistaService {
  static AlocacaoRealocacaoOtimistaResult atualizar({
    required List<Alocacao> alocacoes,
    required List<Disponibilidade> disponibilidades,
    required String medicoId,
    required String gabineteOrigem,
    required String gabineteDestino,
    required DateTime data,
  }) {
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final alocacoesAtuais = List<Alocacao>.from(alocacoes);

    final alocacoesParaMover = alocacoesAtuais.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteOrigem &&
          aDate.year == data.year &&
          aDate.month == data.month &&
          aDate.day == data.day;
    }).toList();

    if (alocacoesParaMover.isEmpty) {
      debugPrint(
          '🟢 [OTIMISTA] Nenhuma alocação encontrada no gabinete origem - cartão está nos desalocados. Verificando se já existe alocação no destino...');

      final jaExisteNoDestino = alocacoesAtuais.any((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.medicoId == medicoId &&
            a.gabineteId == gabineteDestino &&
            aDate.year == data.year &&
            aDate.month == data.month &&
            aDate.day == data.day;
      });

      if (jaExisteNoDestino) {
        debugPrint(
            '⚠️ [OTIMISTA] Alocação já existe no destino - não criar duplicada');
        return const AlocacaoRealocacaoOtimistaResult(
          alocacoesAtualizadas: [],
          ignorar: true,
        );
      }

      debugPrint('🟢 [OTIMISTA] Criando alocação otimista no destino...');

      final dispDoDia = disponibilidades.where((disp) {
        final dd = DateTime(disp.data.year, disp.data.month, disp.data.day);
        return disp.medicoId == medicoId &&
            dd == dataNormalizada &&
            disp.horarios.length >= 2;
      }).toList();
      if (dispDoDia.length != 1) {
        debugPrint(
          '⚠️ [OTIMISTA] Não existe um único cartão válido para alocar; operação ignorada.',
        );
        return const AlocacaoRealocacaoOtimistaResult(
          alocacoesAtualizadas: [],
          ignorar: true,
        );
      }
      final horarioInicio = dispDoDia.first.horarios[0];
      final horarioFim = dispDoDia.first.horarios[1];

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final dataStr =
          '${dataNormalizada.year}${dataNormalizada.month.toString().padLeft(2, '0')}${dataNormalizada.day.toString().padLeft(2, '0')}';
      final alocacaoOtimista = Alocacao(
        id: 'otimista_realoc_${timestamp}_${medicoId}_${gabineteDestino}_$dataStr',
        medicoId: medicoId,
        gabineteId: gabineteDestino,
        data: dataNormalizada,
        horarioInicio: horarioInicio,
        horarioFim: horarioFim,
      );

      alocacoesAtuais.add(alocacaoOtimista);
      debugPrint(
          '   - Alocação otimista criada no destino: id=${alocacaoOtimista.id}, gabinete=${alocacaoOtimista.gabineteId}');
    } else {
      debugPrint(
          '🟢 [OTIMISTA] Movendo ${alocacoesParaMover.length} alocação(ões) de $gabineteOrigem para $gabineteDestino');

      for (final aloc in alocacoesParaMover) {
        debugPrint(
            '   - Movendo alocação: id=${aloc.id}, gabinete atual=${aloc.gabineteId}');
        final removido = alocacoesAtuais.remove(aloc);
        debugPrint('   - Removido da lista: $removido');

        final novaAloc = Alocacao(
          id: aloc.id,
          medicoId: aloc.medicoId,
          gabineteId: gabineteDestino,
          data: aloc.data,
          horarioInicio: aloc.horarioInicio,
          horarioFim: aloc.horarioFim,
        );

        alocacoesAtuais.add(novaAloc);
        debugPrint(
            '   - Adicionado no destino: id=${novaAloc.id}, novo gabinete=${novaAloc.gabineteId}');
      }
    }

    final alocacoesNoDestino = alocacoesAtuais.where((a) {
      final aDate = DateTime(a.data.year, a.data.month, a.data.day);
      return a.medicoId == medicoId &&
          a.gabineteId == gabineteDestino &&
          aDate.year == data.year &&
          aDate.month == data.month &&
          aDate.day == data.day;
    }).toList();
    debugPrint(
        '✅ [OTIMISTA] Verificação: ${alocacoesNoDestino.length} alocação(ões) no destino após atualização');

    return AlocacaoRealocacaoOtimistaResult(
      alocacoesAtualizadas: alocacoesAtuais,
      ignorar: false,
    );
  }
}
