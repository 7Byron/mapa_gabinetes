// lib/config_app/test_info.dart
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';

/// Mapa com informações de cada teste, para evitar o uso de switch.
final Map<String, Map<String, String>> testesMap = {
  "aut": {
    "titulo": "_tAutoConfianca",
    "imagem": RotaImagens.logoAutoConfianca,
    "rota": RotasPaginas.testeAutoConfianca,
    "intro": "aut_intro",
  },
  "sor": {
    "titulo": "_tSorriso",
    "imagem": RotaImagens.logoSorriso,
    "rota": RotasPaginas.testeSorisso,
    "intro": "sor.intro",
  },
  "dep": {
    "titulo": "_tDepressao",
    "imagem": RotaImagens.logoDepressao,
    "rota": RotasPaginas.testeDepressao,
    "intro": "_introTesteDepressao",
  },
  "ans": {
    "titulo": "_tAnsiedade",
    "imagem": RotaImagens.logoAnsiedade,
    "rota": RotasPaginas.testeAnsiedade,
    "intro": "_introTesteAnsiedade",
  },
  "str": {
    "titulo": "_tStress",
    "imagem": RotaImagens.logoStress,
    "rota": RotasPaginas.testeStress,
    "intro": "_introTesteStress",
  },
  "rai": {
    "titulo": "_tRaiva",
    "imagem": RotaImagens.logoRaiva,
    "rota": RotasPaginas.testeRaiva,
    "intro": "_introTesteRaiva",
  },
  "emo": {
    "titulo": "_tDependencia",
    "imagem": RotaImagens.logoDependencia,
    "rota": RotasPaginas.testeDependencia,
    "intro": "_introTesteDependencia",
  },
  "ati": {
    "titulo": "_tAtitude",
    "imagem": RotaImagens.logoAtitude,
    "rota": RotasPaginas.testeAtitude,
    "intro": "_introTesteAtitude",
  },
  "fel": {
    "titulo": "_tFelicidade",
    "imagem": RotaImagens.logoFelicidade,
    "rota": RotasPaginas.testeFelicidade,
    "intro": "_introTesteFelicidade",
  },
  "per": {
    "titulo": "_tPersonalidade",
    "imagem": RotaImagens.logoPersonalidade,
    "rota": RotasPaginas.introPersonalidade,
    "intro": "_introTestePersonalidade",
  },
  "rel": {
    "titulo": "_tRelacionamentos",
    "imagem": RotaImagens.logoRelacionamentos,
    "rota": RotasPaginas.testeRelacionamentos,
    "intro": "rel.intro",
  },
  "bur": {
    "titulo": "_tBurnout",
    "imagem": RotaImagens.logoBurnout,
    "rota": RotasPaginas.testeBurnout,
    "intro": "burn_intro",
  },
};

/// Se quiser lidar com um teste inválido, pode criar uma função utilitária:
Map<String, String> getTestInfo(String key) {
  return testesMap[key] ?? {
    "titulo": "",
    "imagem": "",
    "rota": "",
    "intro": "",
  };
}
