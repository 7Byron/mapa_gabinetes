//...funcoes/rotas_paginas.dart
import 'package:get/get.dart';

import '../outras_paginas/conselhos.dart';
import '../historico/historico.dart';
import '../outras_paginas/intro.dart';
import '../outras_paginas/pay_screen.dart';
import '../outras_paginas/thanks_page.dart';

import '../paginas_resultados/auto_confianca_resultado.dart';
import '../paginas_resultados/personalidade_resultado.dart';
import '../paginas_resultados/ansiedade_resultado.dart';
import '../paginas_resultados/depressao_resultado.dart';
import '../paginas_resultados/relacionamento_resultado.dart';
import '../paginas_resultados/atitude_resultado.dart';
import '../paginas_resultados/dependencia_resultados.dart';
import '../paginas_resultados/felicidades_resultados.dart';
import '../paginas_resultados/raiva_resultado.dart';
import '../paginas_resultados/sorriso_resultados.dart';
import '../paginas_resultados/stress_resultado.dart';
import '../paginas_resultados/burnout_resultado.dart';

import '../paginas_testes/intro_teste_personalidade.dart';
import '../paginas_testes/teste_ansiedade.dart';
import '../paginas_testes/teste_atitude.dart';
import '../paginas_testes/teste_auto_confianca.dart';
import '../paginas_testes/teste_dependencia_emocional.dart';
import '../paginas_testes/teste_depressao.dart';
import '../paginas_testes/teste_felicidade.dart';
import '../paginas_testes/teste_personalidade.dart';
import '../paginas_testes/teste_raiva.dart';
import '../paginas_testes/teste_relacionamentos.dart';
import '../paginas_testes/teste_sorriso.dart';
import '../paginas_testes/teste_stress.dart';
import '../paginas_testes/teste_stress_agravantes.dart';
import '../paginas_testes/teste_burnout.dart';

abstract class PaginasApp {
  static final List<GetPage> paginas = [
    // Outras Páginas
    GetPage(name: RotasPaginas.intro, page: () => const Intro()),
    GetPage(name: RotasPaginas.pay, page: () => const PayScreen()),
    GetPage(name: RotasPaginas.thanks, page: () => const ThankPage()),
    GetPage(name: RotasPaginas.historico, page: () => const Historico()),
    GetPage(name: RotasPaginas.conselhos, page: () => const Conselhos()),

    // Páginas de Resultados
    GetPage(
        name: RotasPaginas.resultadoDepressao,
        page: () => const ResultadoDepressao()),
    GetPage(
        name: RotasPaginas.resultadoAnsiedade,
        page: () => const ResultadoAnsiedade()),
    GetPage(
        name: RotasPaginas.resultadoTesteStress,
        page: () => const ResultadoTesteStress()),
    GetPage(
        name: RotasPaginas.resultadoTesteRaiva,
        page: () => const TesteRaivaResultado()),
    GetPage(
        name: RotasPaginas.resultadoTesteDependencia,
        page: () => const TesteDependenciaResultado()),
    GetPage(
        name: RotasPaginas.resultadoTesteAtitude,
        page: () => const ResultadoTesteAtitude()),
    GetPage(
        name: RotasPaginas.resultadoTesteFelicidade,
        page: () => const ResultadoFelicidade()),
    GetPage(
        name: RotasPaginas.resultadoTestePersonalidade,
        page: () => const ResultadoPersonalidade()),
    GetPage(
        name: RotasPaginas.resultadoRelacionamento,
        page: () => const ResultadoRelacionamento()),
    GetPage(
        name: RotasPaginas.resultadoSorriso,
        page: () => const TesteSorrisoResultado()),
    GetPage(
        name: RotasPaginas.resultadoAutoConfianca,
        page: () => const ResultadoAutoConfianca()),
    GetPage(
        name: RotasPaginas.resultadoBournt,
        page: () => const ResultadoBournt()),

    // Páginas de Testes
    GetPage(
        name: RotasPaginas.testeAnsiedade,
        page: () => const PaginaTesteAnsiedade(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeStress,
        page: () => const PaginaTesteStress(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeStressAgravantes,
        page: () => const AgravantesStress(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeRaiva,
        page: () => const TesteRaiva(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeDependencia,
        page: () => const TesteDependenciaEmocional(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeAtitude,
        page: () => const PaginaTesteAtitude(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeFelicidade,
        page: () => const PaginaTesteFelicidade(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.introPersonalidade,
        page: () => const IntroTestePersonalidade(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testePersonalidade,
        page: () => const PaginaTestePersonalidade(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeSorisso,
        page: () => const TesteSorriso(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeAutoConfianca,
        page: () => const TesteAutoConfianca(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeDepressao,
        page: () => const PaginaTesteDepressao(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeRelacionamentos,
        page: () => const TesteRelacionamentos(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
    GetPage(
        name: RotasPaginas.testeBurnout,
        page: () => const TesteBurnout(),
        transition: Transition.rightToLeft,
        transitionDuration: const Duration(milliseconds: 300)),
  ];
}

abstract class RotasPaginas {
  static const String intro = '/intro';
  static const String pay = '/pay';
  static const String testeDepressao = '/testeDepressao';
  static const String testeDepressao2 = '/testeDepressao2';
  static const String testeAnsiedade = '/testeAnsiedade';
  static const String testeStress = '/testeStress';
  static const String testeDependencia = '/testeDependencia';
  static const String testeAtitude = '/testeAtitude';
  static const String testeFelicidade = '/testeFelicidade';
  static const String testeRelacionamentos = '/teste_relacionamentos';
  static const String testeBurnout = '/teste_burnout';
  static const String introPersonalidade = '/introPersonalidade';
  static const String testePersonalidade = '/testePersonalidade';
  static const String testeStressAgravantes = '/agravantes';
  static const String resultadoTesteStress = '/stress_resultado';
  static const String resultadoTesteRaiva = '/raiva_resultado';
  static const String resultadoTesteDependencia = '/dependencia_resultado';
  static const String resultadoTesteAtitude = '/atitude_resultado';
  static const String resultadoTesteFelicidade = '/felicidade_resultado';
  static const String resultadoTestePersonalidade = '/personalidade_resultado';
  static const String resultadoRelacionamento = '/resultado_relacionamentos';
  static const String resultadoBournt = '/resultado_burnout';
  static const String testeRaiva = '/testeRaiva';
  static const String resultadoDepressao = '/resultadoDepressao';
  static const String resultadoAnsiedade = '/resultadoAnsiedade';
  static const String historico = '/historico';
  static const String conselhos = '/conselhos';
  static const String thanks = '/thanks';
  static const String testeSorisso = '/testeSorriso';
  static const String resultadoSorriso = '/sorriso_resultado';
  static const String testeAutoConfianca = '/testeAutoConfianca';
  static const String resultadoAutoConfianca = '/auto_confianca_resultado';

}
