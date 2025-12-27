// utils/tipo_teste_utils.dart


import '../historico/teste_model.dart';

TipoTeste stringToTipoTeste(String tipoTesteStr) {
  switch (tipoTesteStr) {
    case 'dep':
      return TipoTeste.dep;
    case 'ans':
      return TipoTeste.ans;
    case 'str':
      return TipoTeste.str;
    case 'rai':
      return TipoTeste.rai;
    case 'emo':
      return TipoTeste.emo;
    case 'ati':
      return TipoTeste.ati;
    case 'fel':
      return TipoTeste.fel;
    case 'per':
      return TipoTeste.per;
    case 'sor':
      return TipoTeste.sor;
    case 'aut':
      return TipoTeste.aut;
    case 'rel':
      return TipoTeste.rel;
    case 'bur':
      return TipoTeste.bur;
    default:
      throw Exception('TipoTeste desconhecido: $tipoTesteStr');
  }
}
