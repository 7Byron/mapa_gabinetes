import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dados nacionais e municipais: https://github.com/luismelo4/feriados.
class FeriadosService {
  Future<List<Map<String, dynamic>>> _obter(
      String caminho, Map<String, String> parametros) async {
    final resposta = await http
        .get(Uri.https('feriados-red.vercel.app', caminho, parametros))
        .timeout(const Duration(seconds: 25));
    if (resposta.statusCode != 200) {
      throw Exception(
          'Não foi possível obter os feriados. O município pode não ter dados para este ano.');
    }
    return (jsonDecode(utf8.decode(resposta.bodyBytes)) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> municipios() =>
      _obter('/municipalities', {});

  Future<List<Map<String, dynamic>>> feriados(
          String ano, Map<String, dynamic>? municipio) =>
      _obter('/holidays', {
        'year': ano,
        if (municipio != null)
          'municipality': municipio['municipality'] as String,
        if (municipio != null) 'district': municipio['district'] as String,
      });
}
