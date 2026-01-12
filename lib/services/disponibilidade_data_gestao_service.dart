import 'package:flutter/material.dart';
import '../models/disponibilidade.dart';
import '../models/serie_recorrencia.dart';
import '../services/disponibilidade_serie_service.dart';
import '../services/disponibilidade_criacao.dart';
import '../services/serie_service.dart';
import '../utils/series_helper.dart';
import '../models/unidade.dart';
import '../utils/alocacao_medicos_logic.dart';

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
    // Invalidar cache do ano para garantir que séries sejam recarregadas
    AlocacaoMedicosLogic.invalidateCacheFromDate(DateTime(anoSerie, 1, 1));
  }

  /// Verifica se uma série mensal com ocorrência 5 pode não existir em alguns meses
  /// Retorna true se alguns meses podem não ter a 5ª ocorrência
  static bool _verificarOcorrencia5PodeFaltar(DateTime date) {
    final ocorrencia = SeriesHelper.descobrirOcorrenciaNoMes(date);
    if (ocorrencia != 5) return false;

    // Verificar se alguns meses do ano não têm a 5ª ocorrência
    final weekday = date.weekday;
    final ano = date.year;
    int mesesSemOcorrencia5 = 0;

    for (int mes = 1; mes <= 12; mes++) {
      final ultimoDia = DateTime(ano, mes + 1, 0).day;
      final primeiroDia = DateTime(ano, mes, 1);
      final weekdayDia1 = primeiroDia.weekday;
      final offset = (weekday - weekdayDia1 + 7) % 7;
      final primeiroNoMes = 1 + offset;
      final dia5 = primeiroNoMes + 7 * 4; // 5ª ocorrência (0-indexed, então *4)

      if (dia5 > ultimoDia) {
        mesesSemOcorrencia5++;
      }
    }

    return mesesSemOcorrencia5 > 0;
  }

  /// Verifica se uma série mensal com ocorrência 4 pode ter meses com 5 ocorrências
  /// Retorna true se alguns meses têm 5 ocorrências (ou seja, a 4ª não é a última)
  static bool _verificarOcorrencia4PodeTer5(DateTime date) {
    final ocorrencia = SeriesHelper.descobrirOcorrenciaNoMes(date);
    if (ocorrencia != 4) return false;

    // Verificar se alguns meses do ano têm 5 ocorrências desse dia da semana
    final weekday = date.weekday;
    final ano = date.year;
    int mesesComOcorrencia5 = 0;

    for (int mes = 1; mes <= 12; mes++) {
      final ultimoDia = DateTime(ano, mes + 1, 0).day;
      final primeiroDia = DateTime(ano, mes, 1);
      final weekdayDia1 = primeiroDia.weekday;
      final offset = (weekday - weekdayDia1 + 7) % 7;
      final primeiroNoMes = 1 + offset;
      final dia5 = primeiroNoMes + 7 * 4; // 5ª ocorrência (0-indexed, então *4)

      if (dia5 <= ultimoDia) {
        mesesComOcorrencia5++;
      }
    }

    return mesesComOcorrencia5 > 0;
  }

  /// Pergunta ao utilizador como lidar com meses que não têm a 5ª ocorrência
  static Future<bool?> _perguntarPreferenciaOcorrencia5(
    BuildContext context,
    DateTime date,
  ) async {
    final weekday = date.weekday;
    final nomesDias = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    final nomeDia = nomesDias[weekday - 1];

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Série Mensal - 5ª Ocorrência'),
        content: Text(
          'Escolheu criar uma série mensal para o 5º $nomeDia do mês.\n\n'
          'Alguns meses podem não ter 5 ${nomeDia}s. Como deseja proceder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Apenas quando existe 5º',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Último $nomeDia de todos os meses',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  /// Pergunta ao utilizador como lidar com meses que têm 5 ocorrências quando escolheu a 4ª
  static Future<bool?> _perguntarPreferenciaOcorrencia4(
    BuildContext context,
    DateTime date,
  ) async {
    final weekday = date.weekday;
    final nomesDias = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    final nomeDia = nomesDias[weekday - 1];

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Série Mensal - 4ª Ocorrência'),
        content: Text(
          'Escolheu criar uma série mensal para o 4º $nomeDia do mês.\n\n'
          'Alguns meses têm 5 ${nomeDia}s. Deseja usar sempre a 4ª $nomeDia ou a última $nomeDia de cada mês?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Sempre a 4ª $nomeDia',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Última $nomeDia de cada mês',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
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
      // Verificar se é série mensal que precisa de confirmação do utilizador
      bool usarUltimoQuandoNaoExiste = false;
      bool usarUltimoQuandoExiste5 = false;

      if (tipo == 'Mensal') {
        final ocorrencia = SeriesHelper.descobrirOcorrenciaNoMes(date);

        // Caso 1: Ocorrência 5 que pode faltar em alguns meses
        if (ocorrencia == 5 && _verificarOcorrencia5PodeFaltar(date)) {
          final preferencia =
              await _perguntarPreferenciaOcorrencia5(context, date);
          if (preferencia == null) {
            // Utilizador cancelou
            return {'sucesso': false, 'erro': 'Cancelado pelo utilizador'};
          }
          usarUltimoQuandoNaoExiste = preferencia;
        }

        // Caso 2: Ocorrência 4 que pode ter meses com 5 ocorrências
        if (ocorrencia == 4 && _verificarOcorrencia4PodeTer5(date)) {
          final preferencia =
              await _perguntarPreferenciaOcorrencia4(context, date);
          if (preferencia == null) {
            // Utilizador cancelou
            return {'sucesso': false, 'erro': 'Cancelado pelo utilizador'};
          }
          usarUltimoQuandoExiste5 = preferencia;
        }
      }

      // Preparar parâmetros da série
      Map<String, dynamic> parametros = {};
      if (usarUltimoQuandoNaoExiste) {
        parametros['usarUltimoQuandoNaoExiste5'] = true;
      }
      if (usarUltimoQuandoExiste5) {
        parametros['usarUltimoQuandoExiste5'] = true;
      }

      final serie = await DisponibilidadeSerieService.criarSerie(
        medicoId: medicoId,
        dataInicial: date,
        tipo: tipo,
        horarios: [],
        unidade: unidade,
        dataFim: null,
        parametros: parametros,
      );

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      // Usar a função helper que calcula todos os dias corretamente baseado no tipo da série
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);
      
      // Também invalidar usando o método antigo para compatibilidade
      invalidarCachesRelacionados(date, medicoId);

      final geradas = criarDisponibilidadesSerie(
        date,
        tipo,
        medicoId: medicoId,
        limitarAoAno: true,
        usarUltimoQuandoNaoExiste5: usarUltimoQuandoNaoExiste,
        usarUltimoQuandoExiste5: usarUltimoQuandoExiste5,
      );


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

      // CORREÇÃO CRÍTICA: Invalidar cache para TODOS os dias que a série afeta
      // Usar a função helper que calcula todos os dias corretamente baseado no tipo da série
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);
      
      // Também invalidar usando o método antigo para compatibilidade
      invalidarCachesRelacionados(date, medicoId);

      final geradas = criarDisponibilidadesSerie(
        date,
        tipo,
        medicoId: medicoId,
        limitarAoAno: true,
      );


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

      // CORREÇÃO: Invalidar cache após remover série permanentemente
      // Isso garante que quando criamos uma nova série, não apareçam alocações da série antiga
      final unidadeId = unidade?.id ?? 'fyEj6kOXvCuL65sMfCaR';
      SerieService.invalidateCacheSeries(unidadeId, medicoId);
      AlocacaoMedicosLogic.invalidateCacheParaSerie(serie, unidade: unidade);

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
