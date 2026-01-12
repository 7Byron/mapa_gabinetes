// Stub para plataformas que não suportam dart:io (web)
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

void writeLogToFile(String logEntry) {
  if (kIsWeb) {
    try {
      html.HttpRequest.request(
        'http://127.0.0.1:7242/ingest/82a94217-1743-49e6-a685-7fcfb3aa0e20',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: logEntry,
      ).catchError((e) {
        // Silencioso - falha não é crítica
        return Future<html.HttpRequest>.error(e);
      });
    } catch (e) {
      // Silencioso - falha não é crítica
    }
  }
}

