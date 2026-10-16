import 'dart:convert';

import '../models/excecao_serie.dart';
import '../models/serie_recorrencia.dart';

/// Cópias imutáveis do que foi lido/guardado, separadas dos objetos do editor.
/// Uma alteração de outro utilizador não deve ser sobrescrita só por guardar
/// as observações de um médico com séries locais inalteradas.
class CadastroPersistenciaSnapshot {
  final _series = <String, String>{};
  final _excecoes = <String, String>{};

  static Object? _ordenar(Object? valor) {
    if (valor is Map) {
      final keys = valor.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _ordenar(valor[key])};
    }
    if (valor is List) return valor.map(_ordenar).toList();
    return valor;
  }

  static String _assinatura(Map<String, dynamic> dados) =>
      jsonEncode(_ordenar(dados));

  void registarSeries(Iterable<SerieRecorrencia> series) {
    for (final serie in series) {
      _series[serie.id] = _assinatura(serie.toMap());
    }
  }

  void registarExcecoes(Iterable<ExcecaoSerie> excecoes) {
    for (final excecao in excecoes) {
      _excecoes[excecao.id] = _assinatura(excecao.toMap());
    }
  }

  List<SerieRecorrencia> seriesPendentes(Iterable<SerieRecorrencia> series) =>
      series.where((s) => _series[s.id] != _assinatura(s.toMap())).toList();

  List<ExcecaoSerie> excecoesPendentes(Iterable<ExcecaoSerie> excecoes) =>
      excecoes.where((e) => _excecoes[e.id] != _assinatura(e.toMap())).toList();

  Map<String, dynamic> _camposAlterados(
      Map<String, dynamic> atuais, String? assinaturaOriginal) {
    if (assinaturaOriginal == null) return atuais;
    final original = jsonDecode(assinaturaOriginal) as Map<String, dynamic>;
    return {
      for (final entry in atuais.entries)
        if (jsonEncode(_ordenar(entry.value)) !=
            jsonEncode(_ordenar(original[entry.key])))
          entry.key: entry.value
    };
  }

  bool contemSerie(String id) => _series.containsKey(id);
  bool contemExcecao(String id) => _excecoes.containsKey(id);

  Map<String, dynamic> camposSerie(SerieRecorrencia serie) =>
      _camposAlterados(serie.toMap(), _series[serie.id]);

  Map<String, dynamic> camposExcecao(ExcecaoSerie excecao) =>
      _camposAlterados(excecao.toMap(), _excecoes[excecao.id]);

  void clear() {
    _series.clear();
    _excecoes.clear();
  }
}
