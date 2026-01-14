// Stub para plataformas que não suportam dart:io (web)
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:convert';

void writeLogToFile(String logEntry) {
  if (kIsWeb) {
    try {
      // Tentar enviar via HTTP POST para o servidor de logs
      html.HttpRequest.request(
        'http://127.0.0.1:7242/ingest/82a94217-1743-49e6-a685-7fcfb3aa0e20',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: logEntry,
      ).catchError((e) {
        // Se falhar, tentar usar console.log como fallback
        try {
          final logData = jsonDecode(logEntry);
          print('🔍 [DEBUG] ${logData['location']}: ${logData['message']} | ${logData['data']}');
        } catch (e2) {
          print('🔍 [DEBUG] $logEntry');
        }
        return Future<html.HttpRequest>.error(e);
      });
      
      // Também fazer log no console para debug imediato
      try {
        final logData = jsonDecode(logEntry);
        print('🔍 [DEBUG] ${logData['location']}: ${logData['message']} | ${logData['data']}');
      } catch (e) {
        print('🔍 [DEBUG] $logEntry');
      }
    } catch (e) {
      // Fallback para console se tudo falhar
      try {
        final logData = jsonDecode(logEntry);
        print('🔍 [DEBUG] ${logData['location']}: ${logData['message']} | ${logData['data']}');
      } catch (e2) {
        print('🔍 [DEBUG] $logEntry');
      }
    }
  }
}

