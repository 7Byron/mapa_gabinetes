import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/dados_relatorio_exportacao.dart';

/// Constrói e formata o livro em blocos, cedendo a interface entre blocos.
class ExcelProgressoService {
  static Future<Uint8List> gerar(Iterable<Excel> etapas,
      {required int totalLinhas, ProgressoExportacao? onProgresso}) async {
    await onProgresso?.call(0.08, 'A preparar o Excel…');
    Excel? livro;
    var feitas = 0;
    final relogio = Stopwatch()..start();
    for (final etapa in etapas) {
      livro = etapa;
      feitas++;
      // O limite por tempo mantém a interface responsiva mesmo com linhas
      // muito maiores; o limite por quantidade evita notificações por célula.
      if (feitas % 12 == 0 || relogio.elapsedMilliseconds >= 24) {
        final parte =
            totalLinhas == 0 ? 1.0 : (feitas / totalLinhas).clamp(0.0, 1.0);
        await onProgresso?.call(0.08 + 0.76 * parte,
            'A preencher e formatar o Excel · ${feitas.clamp(0, totalLinhas)} de $totalLinhas linhas…');
        await Future<void>.delayed(Duration.zero);
        relogio.reset();
      }
    }
    if (livro == null) throw StateError('Não foi possível preparar o Excel.');
    await onProgresso?.call(0.88, 'A finalizar o ficheiro Excel…');
    await Future<void>.delayed(Duration.zero);
    final bytes = livro.encode();
    if (bytes == null) throw StateError('Não foi possível criar o Excel.');
    await onProgresso?.call(0.97, 'Excel preparado. A iniciar o download…');
    return Uint8List.fromList(bytes);
  }
}
