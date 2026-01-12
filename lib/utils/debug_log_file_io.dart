// Implementação para mobile/desktop usando dart:io
import 'dart:io';

void writeLogToFile(String logEntry) {
  try {
    final logFile = File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log');
    logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);
  } catch (e) {
    // Silencioso
  }
}

