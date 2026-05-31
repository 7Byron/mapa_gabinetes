class TextSearchUtils {
  static String normalize(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> tokens(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }

  static bool matchesAllTerms(String query, Iterable<String> fields) {
    final queryTerms = tokens(query);
    if (queryTerms.isEmpty) return true;

    final fieldTokens = fields.expand(tokens).toList();
    if (fieldTokens.isEmpty) return false;

    return queryTerms.every(
      (term) => fieldTokens.any((token) => token.startsWith(term)),
    );
  }
}
