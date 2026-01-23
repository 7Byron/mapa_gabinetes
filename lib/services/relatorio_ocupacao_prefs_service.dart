import 'package:shared_preferences/shared_preferences.dart';

class RelatorioOcupacaoPrefsService {
  static const String _baseKey = 'relatorio_ocupacao_gabinetes';

  static String _buildKey(String? unidadeId) {
    final sufixo = (unidadeId == null || unidadeId.isEmpty)
        ? 'global'
        : unidadeId;
    return '$_baseKey:$sufixo';
  }

  static Future<List<String>?> carregarGabinetesSelecionados({
    String? unidadeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(unidadeId);
    if (!prefs.containsKey(key)) {
      return null;
    }
    return prefs.getStringList(key) ?? <String>[];
  }

  static Future<void> salvarGabinetesSelecionados(
    List<String> gabineteIds, {
    String? unidadeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(unidadeId);
    await prefs.setStringList(key, gabineteIds);
  }
}
