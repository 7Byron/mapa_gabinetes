import 'package:flutter/material.dart';

/// Constantes globais do aplicativo organizadas por categoria
class ConstantesApp {
  // Durations constantes
  static const Duration animacaoRapida = Duration(milliseconds: 300);
  static const Duration animacaoMedia = Duration(milliseconds: 500);
  static const Duration animacaoLenta = Duration(milliseconds: 750);
  static const Duration animacaoMuitoLenta = Duration(seconds: 2);

  // Cores específicas do app
  static const Color corPrimaria = Colors.amber;
  static const Color corSecundaria = Colors.orangeAccent;
  static const Color corTexto = Colors.brown;
  static const Color corErro = Colors.redAccent;
  static const Color corSucesso = Colors.green;

  // Configurações de grid
  static const int gridColunas = 3;
  static const double gridAspectRatio = 0.8;
  static const double gridSpacing = 8.0;

  // Configurações de tema
  static const double elevacaoPadrao = 6.0;
  static const double elevacaoAppBar = 8.0;

  // Tamanhos de ícone
  static const double iconeSmall = 16.0;
  static const double iconeMedio = 24.0;
  static const double iconeGrande = 32.0;

  // Configurações de Internet Checker
  static const Duration internetCheckInterval = Duration(seconds: 5);
  static const Duration internetCheckTimeout = Duration(seconds: 2);

  // Configurações de Ad
  static const int tapCountParaAd = 3;

  // Strings de configuração
  static const String fonteFamilia = 'Kalam';
  static const String packageName = 'teste_depressao';

  // Configurações de layout responsivo
  static const double breakpointTablet = 600;
  static const double porcentagemDrawerMobile = 0.8;
  static const double porcentagemDrawerTablet = 0.5;
}

/// Extension para facilitar verificação de dispositivo
extension DeviceType on BuildContext {
  bool get isTablet =>
      MediaQuery.of(this).size.width > ConstantesApp.breakpointTablet;
  bool get isMobile => !isTablet;
}

/// Classe para configurações específicas de teste
class ConfiguracoesTeste {
  static const int maxLinhasTitulo = 2;
  static const int maxLinhasPergunta = 3;
  static const double alturaMinimaBotao = 50.0;
  static const double larguraMaximaCard = 600.0;
}

/// Configurações de animação específicas
class AnimacoesConfig {
  static const Curve curvaDefault = Curves.easeInOut;
  static const Curve curvaRapida = Curves.fastOutSlowIn;
  static const Curve curvaElastica = Curves.elasticOut;
}

/// Padrões de texto comumente usados
class PadroesTexto {
  static const TextStyle titulo = TextStyle(
    fontWeight: FontWeight.bold,
    color: ConstantesApp.corTexto,
  );

  static const TextStyle subtitulo = TextStyle(
    fontWeight: FontWeight.w600,
    color: ConstantesApp.corTexto,
  );

  static const TextStyle corpo = TextStyle(
    fontWeight: FontWeight.normal,
    color: ConstantesApp.corTexto,
  );

  static const TextStyle botao = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}
