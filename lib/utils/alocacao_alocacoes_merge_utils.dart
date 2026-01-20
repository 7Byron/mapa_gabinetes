import '../models/alocacao.dart';

class AlocacaoAlocacoesMergeUtils {
  static List<Alocacao> substituirSeriesNoDia({
    required List<Alocacao> alocacoes,
    required List<Alocacao> alocacoesSeriesRegeneradas,
    required DateTime data,
  }) {
    final chavesSeriesParaRemover = <String>{};
    for (final aloc in alocacoesSeriesRegeneradas) {
      final chaveSemGabinete =
          '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
      chavesSeriesParaRemover.add(chaveSemGabinete);
    }

    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final resultado = <Alocacao>[];
    for (final aloc in alocacoes) {
      final ad = DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
      if (ad != dataNormalizada) {
        resultado.add(aloc);
        continue;
      }
      final chaveSemGabinete =
          '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
      final remover =
          aloc.id.startsWith('serie_') &&
              chavesSeriesParaRemover.contains(chaveSemGabinete);
      if (!remover) {
        resultado.add(aloc);
      }
    }

    resultado.addAll(alocacoesSeriesRegeneradas);
    return resultado;
  }

  static List<Alocacao> substituirSeriesPreservandoOtimistas({
    required List<Alocacao> alocacoesAtuais,
    required List<Alocacao> alocacoesSeriesRegeneradas,
    required DateTime data,
  }) {
    final chavesSeriesParaRemover = <String>{};
    for (final aloc in alocacoesSeriesRegeneradas) {
      final chaveSemGabinete =
          '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
      chavesSeriesParaRemover.add(chaveSemGabinete);
    }

    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final alocacoesAtualizadas = <Alocacao>[];

    for (final aloc in alocacoesAtuais) {
      final alocDateNormalized = DateTime(
        aloc.data.year,
        aloc.data.month,
        aloc.data.day,
      );
      if (alocDateNormalized != dataNormalizada) {
        continue;
      }

      if (aloc.id.startsWith('otimista_serie_')) {
        final temAlocacaoReal = alocacoesSeriesRegeneradas.any((a) {
          return a.medicoId == aloc.medicoId &&
              a.gabineteId == aloc.gabineteId &&
              a.data.year == aloc.data.year &&
              a.data.month == aloc.data.month &&
              a.data.day == aloc.data.day;
        });
        if (!temAlocacaoReal) {
          alocacoesAtualizadas.add(aloc);
        }
        continue;
      }

      if (aloc.id.startsWith('serie_')) {
        final chaveSemGabinete =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}';
        if (chavesSeriesParaRemover.contains(chaveSemGabinete)) {
          continue;
        }
      }
      alocacoesAtualizadas.add(aloc);
    }

    alocacoesAtualizadas.addAll(alocacoesSeriesRegeneradas);
    return alocacoesAtualizadas;
  }

  static List<Alocacao> atualizarAlocacoesGabinetes({
    required List<Alocacao> alocacoesAtuais,
    required List<Alocacao> novasAlocacoes,
    required List<String> gabineteIds,
    required DateTime data,
  }) {
    final dataNormalizada = DateTime(data.year, data.month, data.day);
    final preservadas = <String, Alocacao>{};

    for (final aloc in alocacoesAtuais) {
      final aDate = DateTime(aloc.data.year, aloc.data.month, aloc.data.day);
      if (aDate != dataNormalizada ||
          !gabineteIds.contains(aloc.gabineteId)) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        preservadas[chave] = aloc;
      }
    }

    for (final gabineteId in gabineteIds) {
      final alocacoesDoGabinete = novasAlocacoes.where((a) {
        final aDate = DateTime(a.data.year, a.data.month, a.data.day);
        return a.gabineteId == gabineteId && aDate == dataNormalizada;
      });
      for (final aloc in alocacoesDoGabinete) {
        final chave =
            '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
        preservadas[chave] = aloc;
      }
    }

    return preservadas.values.toList();
  }

  static List<Alocacao> mesclarServidorComOtimistas({
    required List<Alocacao> alocacoesServidor,
    required List<Alocacao> alocacoesLocais,
    required DateTime data,
    void Function(String mensagem)? log,
  }) {
    final alocacoesMap = <String, Alocacao>{};
    for (final aloc in alocacoesServidor) {
      final chave =
          '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';
      alocacoesMap[chave] = aloc;
    }

    final dataNormalizada = DateTime(data.year, data.month, data.day);

    for (final aloc in alocacoesLocais) {
      final alocDateNormalized = DateTime(
        aloc.data.year,
        aloc.data.month,
        aloc.data.day,
      );
      if (alocDateNormalized != dataNormalizada) {
        continue;
      }

      final chave =
          '${aloc.medicoId}_${aloc.data.year}-${aloc.data.month}-${aloc.data.day}_${aloc.gabineteId}';

      if (aloc.id.startsWith('otimista_')) {
        if (alocacoesMap.containsKey(chave)) {
          log?.call(
              '✅ Substituindo alocação otimista pela real durante recarregamento: ${aloc.id} -> ${alocacoesMap[chave]!.id}');
        } else {
          alocacoesMap[chave] = aloc;
          log?.call(
              '✅ Preservando alocação otimista durante recarregamento: ${aloc.id} (médico: ${aloc.medicoId})');
        }
        continue;
      }

      if (aloc.id.startsWith('serie_') && !alocacoesMap.containsKey(chave)) {
        alocacoesMap[chave] = aloc;
      }
    }

    return alocacoesMap.values.toList();
  }
}
