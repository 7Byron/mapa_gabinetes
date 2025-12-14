// lib/services/disponibilidade_serie_service.dart

import '../models/serie_recorrencia.dart';
import '../models/excecao_serie.dart';
import '../models/disponibilidade.dart';
import '../models/unidade.dart';
import 'serie_service.dart';

/// Serviço para criar séries de recorrência em vez de cartões individuais
class DisponibilidadeSerieService {
  /// Cria uma série de recorrência baseada nos parâmetros
  /// Retorna a série criada e uma lista de disponibilidades geradas (para compatibilidade)
  static Future<SerieRecorrencia> criarSerie({
    required String medicoId,
    required DateTime dataInicial,
    required String tipo,
    required List<String> horarios,
    Unidade? unidade,
    DateTime? dataFim,
    String? gabineteId,
    bool usarSerie =
        true, // Se false, cria cartões individuais (compatibilidade)
  }) async {
    // Se não deve usar série, retornar série vazia (será tratado pelo código antigo)
    if (!usarSerie) {
      throw UnimplementedError('Modo de compatibilidade não implementado aqui');
    }

    // Criar ID único para a série
    final serieId = 'serie_${DateTime.now().millisecondsSinceEpoch}';

    // Preparar parâmetros específicos
    Map<String, dynamic> parametros = {};
    if (tipo.startsWith('Consecutivo:')) {
      final numeroDiasStr = tipo.split(':')[1];
      final numeroDias = int.tryParse(numeroDiasStr) ?? 5;
      parametros['numeroDias'] = numeroDias;
      tipo = 'Consecutivo';
    }

    // Criar série
    final serie = SerieRecorrencia(
      id: serieId,
      medicoId: medicoId,
      dataInicio: dataInicial,
      dataFim: dataFim,
      tipo: tipo,
      horarios: horarios,
      gabineteId: gabineteId,
      parametros: parametros,
      ativo: true,
    );

    // Salvar no Firestore
    await SerieService.salvarSerie(serie, unidade: unidade);

    print(
        '✅ Série criada: $tipo para médico $medicoId a partir de ${dataInicial.day}/${dataInicial.month}/${dataInicial.year}');

    return serie;
  }

  /// Converte uma disponibilidade antiga em uma série (migração)
  static Future<SerieRecorrencia?> converterDisponibilidadeParaSerie(
    Disponibilidade disponibilidade, {
    Unidade? unidade,
  }) async {
    // Se já é única, não precisa converter
    if (disponibilidade.tipo == 'Única') {
      return null;
    }

    try {
      final serie = await criarSerie(
        medicoId: disponibilidade.medicoId,
        dataInicial: disponibilidade.data,
        tipo: disponibilidade.tipo,
        horarios: disponibilidade.horarios,
        unidade: unidade,
      );

      return serie;
    } catch (e) {
      print('❌ Erro ao converter disponibilidade para série: $e');
      return null;
    }
  }

  /// Cria uma exceção para cancelar uma data específica de uma série
  static Future<void> cancelarDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    Unidade? unidade,
  }) async {
    final excecaoId = 'excecao_${data.millisecondsSinceEpoch}';

    final excecao = ExcecaoSerie(
      id: excecaoId,
      serieId: serieId,
      data: data,
      cancelada: true,
    );

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
    print(
        '✅ Exceção criada: data ${data.day}/${data.month}/${data.year} cancelada para série $serieId');
  }

  /// Cria uma exceção para modificar horários de uma data específica
  static Future<void> modificarHorariosDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required List<String> horarios,
    Unidade? unidade,
  }) async {
    final excecaoId = 'excecao_${data.millisecondsSinceEpoch}';

    final excecao = ExcecaoSerie(
      id: excecaoId,
      serieId: serieId,
      data: data,
      cancelada: false,
      horarios: horarios,
    );

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
    print(
        '✅ Exceção criada: horários modificados para data ${data.day}/${data.month}/${data.year}');
  }

  /// Cria uma exceção para modificar o gabinete de uma data específica de uma série
  static Future<void> modificarGabineteDataSerie({
    required String serieId,
    required String medicoId,
    required DateTime data,
    required String novoGabineteId,
    Unidade? unidade,
  }) async {
    // Normalizar a data para garantir correspondência exata
    final dataNormalizada = DateTime(data.year, data.month, data.day);

    // Verificar se já existe uma exceção para esta série e data
    final excecoesExistentes = await SerieService.carregarExcecoes(
      medicoId,
      unidade: unidade,
      dataInicio: dataNormalizada,
      dataFim: dataNormalizada,
      serieId: serieId,
    );

    ExcecaoSerie excecao;

    // Se já existe uma exceção para esta data, atualizar ela
    final excecaoExistente = excecoesExistentes.firstWhere(
      (e) =>
          e.serieId == serieId &&
          e.data.year == dataNormalizada.year &&
          e.data.month == dataNormalizada.month &&
          e.data.day == dataNormalizada.day,
      orElse: () => ExcecaoSerie(
        id: '',
        serieId: '',
        data: DateTime(1900, 1, 1),
      ),
    );

    if (excecaoExistente.id.isNotEmpty) {
      // Atualizar exceção existente
      excecao = ExcecaoSerie(
        id: excecaoExistente.id,
        serieId: excecaoExistente.serieId,
        data: excecaoExistente.data,
        cancelada: false, // Garantir que não está cancelada
        horarios:
            excecaoExistente.horarios, // Manter horários existentes se houver
        gabineteId: novoGabineteId, // Atualizar o gabinete
      );
      print('🔄 Atualizando exceção existente: ${excecao.id}');
    } else {
      // Criar nova exceção
      final excecaoId =
          'excecao_${serieId}_${dataNormalizada.millisecondsSinceEpoch}';
      excecao = ExcecaoSerie(
        id: excecaoId,
        serieId: serieId,
        data: dataNormalizada,
        cancelada: false,
        gabineteId: novoGabineteId,
      );
      print('➕ Criando nova exceção: ${excecao.id}');
    }

    await SerieService.salvarExcecao(excecao, medicoId, unidade: unidade);
    print(
        '✅ Exceção salva: ID=${excecao.id}, série=${serieId}, data=${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}, gabinete=$novoGabineteId');
    print(
        '   📋 Detalhes: dataKey=${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}, chaveEsperada=${serieId}_${dataNormalizada.year}-${dataNormalizada.month.toString().padLeft(2, '0')}-${dataNormalizada.day.toString().padLeft(2, '0')}');
  }

  /// Aloca uma série inteira a um gabinete
  static Future<void> alocarSerie({
    required String serieId,
    required String medicoId,
    required String gabineteId,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series =
          await SerieService.carregarSeries(medicoId, unidade: unidade);
      final serie = series.firstWhere((s) => s.id == serieId);

      // Atualizar série com gabinete
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: gabineteId,
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);
      print('✅ Série alocada ao gabinete $gabineteId');
    } catch (e) {
      print('❌ Erro ao alocar série: $e');
      rethrow;
    }
  }

  /// Desaloca uma série (remove o gabineteId)
  static Future<void> desalocarSerie({
    required String serieId,
    required String medicoId,
    Unidade? unidade,
  }) async {
    try {
      // Carregar série
      final series =
          await SerieService.carregarSeries(medicoId, unidade: unidade);
      final serie = series.firstWhere((s) => s.id == serieId);

      // Atualizar série removendo o gabineteId (definindo como null)
      final serieAtualizada = SerieRecorrencia(
        id: serie.id,
        medicoId: serie.medicoId,
        dataInicio: serie.dataInicio,
        dataFim: serie.dataFim,
        tipo: serie.tipo,
        horarios: serie.horarios,
        gabineteId: null, // Remove a alocação
        parametros: serie.parametros,
        ativo: serie.ativo,
      );

      await SerieService.salvarSerie(serieAtualizada, unidade: unidade);
      print('✅ Série desalocada (gabinete removido)');
    } catch (e) {
      print('❌ Erro ao desalocar série: $e');
      rethrow;
    }
  }
}
