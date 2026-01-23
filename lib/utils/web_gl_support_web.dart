// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool hasWebGL() {
  try {
    final canvas = html.CanvasElement();
    return canvas.getContext('webgl2') != null ||
        canvas.getContext('webgl') != null ||
        canvas.getContext('experimental-webgl') != null;
  } catch (e) {
    // Se houver erro, assumir que WebGL não está disponível
    return false;
  }
}
