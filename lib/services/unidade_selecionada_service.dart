import 'package:shared_preferences/shared_preferences.dart';

class UnidadeSelecionadaService {
  static const String _selectedUnidadeIdKey = 'selected_unidade_id';

  static Future<void> salvarUnidadeSelecionada(String unidadeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedUnidadeIdKey, unidadeId);
  }

  static Future<String?> carregarUnidadeSelecionada() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedUnidadeIdKey);
    return (id != null && id.isNotEmpty) ? id : null;
  }

  static Future<void> limparUnidadeSelecionada() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedUnidadeIdKey);
  }
}
