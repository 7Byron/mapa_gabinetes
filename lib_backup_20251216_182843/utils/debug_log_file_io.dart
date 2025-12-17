// Implementação para mobile/desktop usando dart:io
import 'dart:io';

void writeLogToFile(String logEntry) {
  final logFile = File('/Users/byronrodrigues/Documents/Flutter Projects/mapa_gabinetes/.cursor/debug.log');
  logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);
}

