import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import '../models/serie_recorrencia.dart';
import '../services/serie_service.dart';
import '../utils/alocacao_medicos_logic.dart';

/// Helper functions for cadastro_medicos.dart
/// Extracted to improve code organization and reduce file size
class CadastroMedicosHelper {
  /// Compara duas listas de strings para verificar se são iguais
  static bool listasIguais(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Verifica se um ID de disponibilidade é temporário ou inválido
  /// Retorna true se o ID precisa ser regenerado
  static bool isIdTemporarioOuInvalido(String id) {
    return id.isEmpty || id.startsWith('temp_') || id.endsWith('-0');
  }

  /// Gera um ID permanente para uma disponibilidade
  /// Usa timestamp e data formatada para garantir unicidade
  /// Formato: {timestamp}_{medicoId}_{dataStr}
  static String gerarIdPermanenteParaDisponibilidade(
    Disponibilidade disp,
    String medicoId,
  ) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final dataStr =
        '${disp.data.year}${disp.data.month.toString().padLeft(2, '0')}${disp.data.day.toString().padLeft(2, '0')}';
    return '${timestamp}_${medicoId}_$dataStr';
  }

  /// Cria uma cópia profunda de uma lista de disponibilidades
  /// Garante que alterações na lista original não afetem a cópia
  static List<Disponibilidade> criarCopiaProfundaDisponibilidades(
    List<Disponibilidade> disponibilidades,
  ) {
    return disponibilidades
        .map((d) => Disponibilidade(
              id: d.id,
              medicoId: d.medicoId,
              data: d.data,
              horarios: List<String>.from(d.horarios),
              tipo: d.tipo,
            ))
        .toList();
  }

  /// Normaliza uma data removendo horas, minutos, segundos e milissegundos
  /// Retorna uma nova DateTime com apenas ano, mês e dia
  static DateTime normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  /// Filtra disponibilidades únicas de um médico específico
  static List<Disponibilidade> filtrarDisponibilidadesUnicas(
    List<Disponibilidade> disponibilidades,
    String medicoId,
  ) {
    return disponibilidades
        .where((d) => d.tipo == 'Única' && d.medicoId == medicoId)
        .toList();
  }

  /// Remove disponibilidades únicas de um médico específico da lista
  static List<Disponibilidade> removerDisponibilidadesUnicas(
    List<Disponibilidade> disponibilidades,
    String medicoId,
  ) {
    return disponibilidades
        .where((d) => !(d.tipo == 'Única' && d.medicoId == medicoId))
        .toList();
  }

  /// Gera uma chave única para uma disponibilidade
  /// Formato: {medicoId}_{ano-mes-dia}_{tipo}
  static String gerarChaveDisponibilidade(Disponibilidade disp) {
    return '${disp.medicoId}_${disp.data.year}-${disp.data.month}-${disp.data.day}_${disp.tipo}';
  }

  /// Obtém o ID da unidade ou retorna um ID padrão
  static String obterUnidadeId(Unidade? unidade) {
    return unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
  }

  /// Invalida o cache para todas as disponibilidades fornecidas
  /// Invalida cache por dia e por ano para garantir atualização completa
  static void invalidarCacheDisponibilidades(
    List<Disponibilidade> disponibilidades,
  ) {
    final anosInvalidar = <int>{};
    for (final disp in disponibilidades) {
      final d = normalizarData(disp.data);
      AlocacaoMedicosLogic.invalidateCacheForDay(d);
      anosInvalidar.add(disp.data.year);
    }

    // Invalidar cache para TODOS os anos das disponibilidades
    for (final ano in anosInvalidar) {
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(ano, 1, 1));
      // Invalidar também próximo ano (caso haja séries que se estendam)
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(ano + 1, 1, 1));
    }

    // Invalidar também cache de médicos ativos para garantir recarregamento
    final anoAtual = DateTime.now().year;
    if (!anosInvalidar.contains(anoAtual)) {
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoAtual, 1, 1));
    }
  }

  /// Prepara disponibilidades únicas para salvar
  /// Cria uma cópia profunda, filtra únicas, e gera IDs permanentes se necessário
  /// Retorna a lista de disponibilidades únicas prontas para salvar
  static List<Disponibilidade> prepararDisponibilidadesUnicasParaSalvar(
    List<Disponibilidade> disponibilidades,
    String medicoId,
  ) {
    // Fazer cópia PROFUNDA da lista para garantir que não seja afetada por modificações
    final todasDisponibilidades =
        criarCopiaProfundaDisponibilidades(disponibilidades);

    // Filtrar e preparar disponibilidades únicas
    return filtrarDisponibilidadesUnicas(todasDisponibilidades, medicoId)
        .map((d) {
      // Se ID estiver vazio ou for temporário, gerar um novo permanente antes de salvar
      String idFinal = d.id;
      if (isIdTemporarioOuInvalido(idFinal)) {
        idFinal = gerarIdPermanenteParaDisponibilidade(d, medicoId);
      }

      return Disponibilidade(
        id: idFinal, // Garantir que ID não está vazio
        medicoId: d.medicoId,
        data: d.data,
        horarios: List<String>.from(d.horarios), // Cópia da lista de horários
        tipo: d.tipo,
      );
    }).toList();
  }

  /// Salva todas as séries de recorrência fornecidas
  /// Retorna o número de séries salvas
  /// CORREÇÃO CRÍTICA: Invalida cache para todas as séries após salvar
  static Future<int> salvarSeries(
    List<SerieRecorrencia> series,
    Unidade? unidade,
  ) async {
    int salvas = 0;
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
      await SerieService.salvarSerie(serieComHorarios, unidade: unidade);
      
      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que esta série afeta
      // Isso garante que quando o utilizador navega para qualquer dia da série,
      // os dados serão recarregados do servidor e estarão atualizados
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serieComHorarios, unidade: unidade);
      
      salvas++;
    }
    return salvas;
  }

  /// Mescla disponibilidades preservando as únicas não salvas
  /// Retorna um mapa de chaves para disponibilidades
  static Map<String, Disponibilidade> mesclarDisponibilidadesPreservandoUnicas(
    List<Disponibilidade> disponibilidadesExistentes,
    List<Disponibilidade> disponibilidadesNovas,
    String medicoId,
  ) {
    final resultado = <String, Disponibilidade>{};

    // PRIMEIRO: Adicionar TODAS as disponibilidades únicas existentes (não salvas ainda)
    // Isso preserva disponibilidades únicas que foram adicionadas mas ainda não salvas
    for (final disp in disponibilidadesExistentes) {
      if (disp.tipo == 'Única' && disp.medicoId == medicoId) {
        final chave = gerarChaveDisponibilidade(disp);
        resultado[chave] = disp;
      }
    }

    // SEGUNDO: Adicionar outras disponibilidades existentes que não são únicas
    for (final disp in disponibilidadesExistentes) {
      if (disp.tipo != 'Única') {
        final chave = gerarChaveDisponibilidade(disp);
        if (!resultado.containsKey(chave)) {
          resultado[chave] = disp;
        }
      }
    }

    // TERCEIRO: Adicionar novas disponibilidades, preservando únicas existentes
    for (final disp in disponibilidadesNovas) {
      final chave = gerarChaveDisponibilidade(disp);
      // Se for disponibilidade única e já existe, preservar a existente (não salva ainda)
      // Se for série ou não existe, adicionar/substituir
      if (disp.tipo == 'Única' && resultado.containsKey(chave)) {
        // Preservar a existente (pode não estar salva ainda)
        continue;
      }
      resultado[chave] = disp;
    }

    return resultado;
  }

  /// Mescla disponibilidades preservando únicas não salvas e filtrando por ano
  /// Usado quando há séries e precisa preservar disponibilidades de outros anos
  static Map<String, Disponibilidade> mesclarDisponibilidadesComAno(
    List<Disponibilidade> disponibilidadesExistentes,
    List<Disponibilidade> disponibilidadesNovas,
    String medicoId,
    int anoParaCarregar,
  ) {
    final resultado = <String, Disponibilidade>{};

    // PRIMEIRO: Adicionar TODAS as disponibilidades únicas existentes (independente do ano)
    for (final disp in disponibilidadesExistentes) {
      if (disp.tipo == 'Única' && disp.medicoId == medicoId) {
        final chave = gerarChaveDisponibilidade(disp);
        resultado[chave] = disp;
      }
    }

    // SEGUNDO: Adicionar disponibilidades existentes que não são do ano atual e não são únicas
    for (final disp in disponibilidadesExistentes) {
      if (disp.data.year != anoParaCarregar && disp.tipo != 'Única') {
        final chave = gerarChaveDisponibilidade(disp);
        if (!resultado.containsKey(chave)) {
          resultado[chave] = disp;
        }
      }
    }

    // TERCEIRO: Adicionar novas disponibilidades, preservando únicas existentes
    for (final disp in disponibilidadesNovas) {
      final chave = gerarChaveDisponibilidade(disp);
      if (disp.tipo == 'Única' && resultado.containsKey(chave)) {
        // Preservar a existente (não salva ainda)
        continue;
      }
      resultado[chave] = disp;
    }

    return resultado;
  }

  /// Mescla apenas disponibilidades únicas preservando as não salvas
  /// Usado quando não há séries
  static List<Disponibilidade> mesclarApenasUnicas(
    List<Disponibilidade> disponibilidadesExistentes,
    List<Disponibilidade> disponibilidadesUnicasFirestore,
    String medicoId,
  ) {
    final disponibilidadesUnicas = <String, Disponibilidade>{};

    // PRIMEIRO: Adicionar TODAS as disponibilidades únicas existentes (não salvas ainda)
    for (final disp in disponibilidadesExistentes) {
      if (disp.tipo == 'Única' && disp.medicoId == medicoId) {
        final chave = gerarChaveDisponibilidade(disp);
        disponibilidadesUnicas[chave] = disp;
      }
    }

    // SEGUNDO: Adicionar/sobrescrever com as do Firestore (já salvas)
    for (final dispUnica in disponibilidadesUnicasFirestore) {
      final chave = gerarChaveDisponibilidade(dispUnica);
      disponibilidadesUnicas[chave] = dispUnica;
    }

    // Manter séries existentes
    final resultado = disponibilidadesExistentes
        .where((d) => d.id.startsWith('serie_'))
        .toList();

    // Adicionar todas as disponibilidades únicas (mescladas)
    resultado
        .addAll(disponibilidadesUnicas.values.where((d) => d.tipo == 'Única'));

    resultado.sort((a, b) => a.data.compareTo(b.data));
    return resultado;
  }
}
