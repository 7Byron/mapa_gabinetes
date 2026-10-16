import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Assinala que o mesmo lote escreveu também a vista diária. A função remota
/// valida a assinatura antes de dispensar a cópia; um update posterior que
/// não atualize a assinatura continua a ser sincronizado normalmente.
class VistaDiariaSync {
  static const campoHash = '_vistaDiariaHash';

  static Object? _ordenar(Object? valor) {
    if (valor is Map) {
      final keys = valor.keys.cast<String>().toList()..sort();
      return {
        for (final k in keys)
          if (k != campoHash) k: _ordenar(valor[k])
      };
    }
    if (valor is List) return valor.map(_ordenar).toList();
    return valor;
  }

  static String assinatura(Map<String, dynamic> dados) =>
      sha256.convert(utf8.encode(jsonEncode(_ordenar(dados)))).toString();

  static Map<String, dynamic> marcar(Map<String, dynamic> dados) =>
      {...dados, campoHash: assinatura(dados)};
}
