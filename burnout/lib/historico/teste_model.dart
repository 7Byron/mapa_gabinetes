  // models/teste_model.dart

  enum TipoTeste {
    dep,
    dep2,
    ans,
    str,
    rai,
    emo,
    ati,
    fel,
    per,
    sor,
    aut,
    rel,
    bur,
  }

  class TesteModel {
    final TipoTeste tipo;
    final String data;
    final String historico;

    TesteModel({required this.tipo, required this.data, required this.historico});
  }
