import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/serie_service.dart';
import '../utils/alocacao_medicos_logic.dart';
import '../utils/series_helper.dart';
import '../models/unidade.dart';

/// Serviço para gerir adição e remoção de datas/disponibilidades
/// Extracted from cadastro_medicos.dart to reduce code size
class DisponibilidadeDataGestaoService {
  /// Adiciona disponibilidades geradas às listas locais
  static void adicionarDisponibilidadesAListas(
    List<Disponibilidade> geradas,
    List<Disponibilidade> disponibilidades,
    List<DateTime> diasSelecionados,
  ) {
    for (final novaDisp in geradas) {
      if (!diasSelecionados.any((d) =>
          d.year == novaDisp.data.year &&
          d.month == novaDisp.data.month &&
          d.day == novaDisp.data.day)) {
        disponibilidades.add(novaDisp);
        diasSelecionados.add(novaDisp.data);
      }
    }
    disponibilidades.sort((a, b) => a.data.compareTo(b.data));
  }

  /// Invalida caches relacionados com uma data/série
  static void invalidarCachesRelacionados(DateTime date, String medicoId) {
    AlocacaoMedicosLogic.invalidateCacheForDay(date);
    final anoSerie = date.year;
    AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(medicoId, anoSerie);
    AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));
  }

  /// Cria uma série recorrente e retorna informações sobre o resultado
  static Future<Map<String, dynamic>> criarSerieRecorrente(
    BuildContext context,
    DateTime date,
    String tipo,
    String medicoId,
    Unidade? unidade,
  ) async {
    try {
      final serie = await DisponibilidadeSerieService.criarSerie(
        medicoId: medicoId,
        dataInicial: date,
        tipo: tipo,
        horarios: [],
        unidade: unidade,
        dataFim: null,
      );

      invalidarCachesRelacionados(date, medicoId);

      final geradas = criarDisponibilidadesSerie(
        date,
        tipo,
        medicoId: medicoId,
        limitarAoAno: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Série $tipo criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return {
        'sucesso': true,
        'serie': serie,
        'disponibilidades': geradas,
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return {'sucesso': false, 'erro': e.toString()};
    }
  }

  /// Cria uma série consecutiva e retorna informações sobre o resultado
  static Future<Map<String, dynamic>> criarSerieConsecutiva(
    BuildContext context,
    DateTime date,
    String tipo,
    String medicoId,
    Unidade? unidade,
  ) async {
    final numeroDiasStr = tipo.split(':')[1];
    final numeroDias = int.tryParse(numeroDiasStr) ?? 5;

    try {
      final serie = await DisponibilidadeSerieService.criarSerie(
        medicoId: medicoId,
        dataInicial: date,
        tipo: 'Consecutivo',
        horarios: [],
        unidade: unidade,
        dataFim: date.add(Duration(days: numeroDias - 1)),
      );

      invalidarCachesRelacionados(date, medicoId);

      final geradas = criarDisponibilidadesSerie(
        date,
        tipo,
        medicoId: medicoId,
        limitarAoAno: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Série Consecutiva criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return {
        'sucesso': true,
        'serie': serie,
        'disponibilidades': geradas,
      };
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return {'sucesso': false, 'erro': e.toString()};
    }
  }

  /// Cria disponibilidades únicas
  static List<Disponibilidade> criarDisponibilidadesUnicas(
    DateTime date,
    String tipo,
    String medicoId,
  ) {
    return criarDisponibilidadesSerie(
      date,
      tipo,
      medicoId: medicoId,
      limitarAoAno: true,
    );
  }

  /// Remove uma série do Firestore e invalida caches
  static Future<bool> removerSerieDoFirestore(
    BuildContext context,
    SerieRecorrencia serie,
    String medicoId,
    Unidade? unidade,
  ) async {
    try {
      await SerieService.removerSerie(
        serie.id,
        medicoId,
        unidade: unidade,
        permanente: true,
      );

      final anoSerie = serie.dataInicio.year;
      AlocacaoMedicosLogic.invalidateSeriesCacheForMedico(medicoId, anoSerie);
      AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover série: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Encontra uma série baseada numa disponibilidade
  static SerieRecorrencia? encontrarSeriePorDisponibilidade(
    Disponibilidade disponibilidade,
    List<SerieRecorrencia> series,
    DateTime date,
  ) {
    // Tentar encontrar pelo ID da série extraído do ID da disponibilidade
    final serieIdFinal =
        SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id);

    final serieEncontrada = series.firstWhere(
      (s) => s.id == serieIdFinal && s.ativo,
      orElse: () => SerieRecorrencia(
        id: '',
        medicoId: '',
        dataInicio: DateTime.now(),
        tipo: '',
        horarios: [],
      ),
    );

    if (serieEncontrada.id.isNotEmpty) {
      return serieEncontrada;
    }

    // Se não encontrou pelo ID, tentar encontrar por tipo e data
    for (final serie in series) {
      if (serie.tipo == disponibilidade.tipo &&
          serie.ativo &&
          (serie.dataFim == null || serie.dataFim!.isAfter(date)) &&
          serie.dataInicio.isBefore(date.add(const Duration(days: 1)))) {
        if (SeriesHelper.verificarDataCorrespondeAoPadraoSerie(date, serie)) {
          return serie;
        }
      }
    }

    return null;
  }
}
