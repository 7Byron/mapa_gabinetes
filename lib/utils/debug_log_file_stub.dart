// Stub para plataformas que não suportam dart:io (web)
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void writeLogToFile(String logEntry) {
  if (kIsWeb) {
    // No web, enviar via HTTP POST para o servidor de logs
    try {
      // Enviar para o endpoint de ingest de logs usando HttpRequest
      html.HttpRequest.request(
        'http://127.0.0.1:7242/ingest/82a94217-1743-49e6-a685-7fcfb3aa0e20',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: logEntry,
      ).catchError((e) {
        // Silencioso - não é crítico se falhar
        // Retornar um Future que completa com erro para evitar problemas
        return Future<html.HttpRequest>.error(e);
      });
      // Também imprimir no console para debug
      debugPrint('[DEBUG LOG] $logEntry');
    } catch (e) {
      // Se não conseguir enviar, pelo menos imprimir
      debugPrint('[DEBUG LOG RAW] $logEntry');
    }
  } else {
    // Para plataformas não-web, usar debugPrint como fallback
    debugPrint('[DEBUG LOG] $logEntry');
  }
}

