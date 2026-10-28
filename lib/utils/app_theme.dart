import 'package:flutter/material.dart';
import 'app_colors.dart';

class MyAppTheme {
  static Color corOcupacao(double percentagem) {
    final proporcao = percentagem.clamp(0.0, 100.0) / 100.0;
    return Color.lerp(AppColors.textoOcupado, AppColors.acao, proporcao) ??
        AppColors.acao;
  }

  // Cores principais - Paleta profissional moderna
  static const Color azulEscuro = AppColors.acao;
  static const Color roxo = AppColors.acao;
  static const Color cinzento = AppColors.secundario;

  // Cores adicionais
  static const Color vermelho = AppColors.textoConflito;

  // Paleta profissional para estados de gabinetes
  static const Color gabineteLivre = AppColors.superficie; // Cinza quase branco
  static const Color gabineteOcupado =
      AppColors.ocupado; // Azul claro (igual aos cartões de médicos)
  static const Color gabineteConflito =
      AppColors.conflito; // Vermelho muito suave e natural

  // Cores para bordas dos gabinetes
  static const Color bordaGabineteLivre = AppColors.borda; // Cinza suave
  static const Color bordaGabineteOcupado =
      AppColors.bordaOcupado; // Azul claro para borda
  static const Color bordaGabineteConflito =
      AppColors.bordaConflito; // Vermelho acinzentado natural

  // Cores de fundo elegantes
  static const Color backgroundGradientStart = AppColors.fundo;
  static const Color backgroundGradientEnd = AppColors.fundo;

  // Cores para cards e elevação
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Tipografia profissional
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.texto,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.texto,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secundario,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secundario,
  );

  static List<BoxShadow> get shadowCard => const [
        BoxShadow(
            color: Color(0x0D142E36), blurRadius: 7, offset: Offset(0, 2)),
      ];
  static List<BoxShadow> get shadowCard3D => shadowCard;
  static List<BoxShadow> get shadowMedicoCard => const [
        BoxShadow(
            color: Color(0x08142E36), blurRadius: 4, offset: Offset(0, 1)),
      ];
  static List<BoxShadow> get shadowCardHover => const [
        BoxShadow(
            color: Color(0x17142E36), blurRadius: 10, offset: Offset(0, 3)),
      ];

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(seedColor: AppColors.acao).copyWith(
      primary: AppColors.acao,
      onPrimary: Colors.white,
      secondary: AppColors.acao,
      onSecondary: Colors.white,
      surface: AppColors.superficie,
      onSurface: AppColors.texto,
      onSurfaceVariant: AppColors.secundario,
      outline: AppColors.borda,
      error: AppColors.textoConflito,
      errorContainer: AppColors.conflito,
      primaryContainer: AppColors.selecao,
      onPrimaryContainer: AppColors.acaoHover,
      secondaryContainer: AppColors.selecao,
      onSecondaryContainer: AppColors.acaoHover,
      tertiary: AppColors.textoOcupado,
    );
    final base = ThemeData(
        useMaterial3: true, colorScheme: esquema, fontFamily: 'Montserrat');
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fundo,
      textTheme: base.textTheme
          .apply(bodyColor: AppColors.texto, displayColor: AppColors.texto),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.texto,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              fontFamily: 'Montserrat',
              color: AppColors.texto,
              fontSize: 18,
              fontWeight: FontWeight.w600)),
      cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borda))),
      dividerTheme:
          const DividerThemeData(color: AppColors.linha, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.acao,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acao,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.acao,
              side: const BorderSide(color: AppColors.borda),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borda)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borda)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.acao)),
          labelStyle: const TextStyle(color: AppColors.secundario)),
      chipTheme: base.chipTheme.copyWith(
          selectedColor: AppColors.selecao,
          secondarySelectedColor: AppColors.selecao,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.borda),
          labelStyle:
              base.textTheme.labelLarge?.copyWith(color: AppColors.texto),
          secondaryLabelStyle:
              base.textTheme.labelLarge?.copyWith(color: AppColors.acaoHover),
          checkmarkColor: AppColors.acao),
      datePickerTheme: const DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: AppColors.selecao,
          headerForegroundColor: AppColors.texto),
    );
  }
}
