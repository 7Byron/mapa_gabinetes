import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ClinicaFechadaResultado {
  final bool fechada;
  final String mensagem;

  const ClinicaFechadaResultado({
    required this.fechada,
    required this.mensagem,
  });
}

class AlocacaoClinicaStatusService {
  static ClinicaFechadaResultado verificar({
    required DateTime data,
    required bool nuncaEncerra,
    required bool encerraFeriados,
    required Map<int, bool> encerraDias,
    required Map<int, List<String>> horariosClinica,
    required List<Map<String, dynamic>> diasEncerramento,
    required List<Map<String, String>> feriados,
  }) {
    if (nuncaEncerra) {
      return const ClinicaFechadaResultado(fechada: false, mensagem: '');
    }

    final diaSemana = data.weekday;
    final dataFormatada = DateFormat('yyyy-MM-dd').format(data);

    final diaEncerramento = diasEncerramento.firstWhere(
      (d) {
        final dataDia = d['data'] as String? ?? '';
        if (dataDia.isEmpty) return false;
        try {
          final dataDiaParsed = DateTime.parse(dataDia);
          final dataFormatadaParsed = DateTime.parse(dataFormatada);
          return dataDiaParsed.year == dataFormatadaParsed.year &&
              dataDiaParsed.month == dataFormatadaParsed.month &&
              dataDiaParsed.day == dataFormatadaParsed.day;
        } catch (_) {
          return dataDia == dataFormatada;
        }
      },
      orElse: () => <String, dynamic>{},
    );

    if (diaEncerramento.containsKey('id') &&
        diaEncerramento['id']!.toString().isNotEmpty) {
      final descricao = diaEncerramento['descricao'] as String? ?? '';
      final mensagem = descricao.isNotEmpty ? descricao : 'Encerramento';
      _log('🚫 Clínica encerrada: $mensagem');
      return ClinicaFechadaResultado(fechada: true, mensagem: mensagem);
    }

    if (encerraDias[diaSemana] == true) {
      final diasSemana = [
        '',
        'Segunda-feira',
        'Terça-feira',
        'Quarta-feira',
        'Quinta-feira',
        'Sexta-feira',
        'Sábado',
        'Domingo'
      ];
      final mensagem = '${diasSemana[diaSemana]}s';
      _log('🚫 Clínica encerrada: $mensagem');
      return ClinicaFechadaResultado(fechada: true, mensagem: mensagem);
    }

    final feriado = feriados.firstWhere(
      (f) {
        final dataFeriado = f['data']?.toString() ?? '';
        if (dataFeriado.isEmpty) return false;
        try {
          final dataFeriadoParsed = DateTime.parse(dataFeriado);
          final dataFormatadaParsed = DateTime.parse(dataFormatada);
          return dataFeriadoParsed.year == dataFormatadaParsed.year &&
              dataFeriadoParsed.month == dataFormatadaParsed.month &&
              dataFeriadoParsed.day == dataFormatadaParsed.day;
        } catch (_) {
          return dataFeriado == dataFormatada;
        }
      },
      orElse: () => <String, String>{},
    );

    if (feriado.containsKey('id') && feriado['id']!.isNotEmpty) {
      if (encerraFeriados) {
        final mensagem = feriado['descricao'] ?? 'Feriado';
        _log('🚫 Clínica encerrada: $mensagem');
        return ClinicaFechadaResultado(fechada: true, mensagem: mensagem);
      }
    }

    final horariosDoDia = horariosClinica[diaSemana] ?? [];
    if (horariosDoDia.isEmpty) {
      const mensagem = 'Sem horários';
      _log('🚫 Clínica encerrada: $mensagem');
      return const ClinicaFechadaResultado(fechada: true, mensagem: mensagem);
    }

    return const ClinicaFechadaResultado(fechada: false, mensagem: '');
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
