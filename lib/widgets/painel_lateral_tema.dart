import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

ThemeData temaPainelLateral(BuildContext context) {
  final tema = Theme.of(context);
  final esquema = ColorScheme.fromSeed(
          seedColor: AppColors.acao, brightness: Brightness.dark)
      .copyWith(
    primary: AppColors.menta,
    onPrimary: AppColors.navegacao,
    surface: AppColors.navegacao,
    onSurface: AppColors.textoNavegacao,
    onSurfaceVariant: AppColors.secundarioNavegacao,
    outline: AppColors.bordaNavegacao,
    secondary: AppColors.menta,
    secondaryContainer: AppColors.navegacaoElevada,
  );
  return tema.copyWith(
    brightness: Brightness.dark,
    colorScheme: esquema,
    canvasColor: AppColors.navegacao,
    cardColor: AppColors.navegacao,
    textTheme: tema.textTheme.apply(
        bodyColor: AppColors.textoNavegacao,
        displayColor: AppColors.textoNavegacao),
    iconTheme: const IconThemeData(color: AppColors.secundarioNavegacao),
    dividerTheme:
        const DividerThemeData(color: AppColors.bordaNavegacao, thickness: 1),
    cardTheme: tema.cardTheme
        .copyWith(color: AppColors.navegacao, shadowColor: Colors.transparent),
    listTileTheme: tema.listTileTheme.copyWith(
        minTileHeight: 40,
        horizontalTitleGap: 8,
        minVerticalPadding: 2,
        visualDensity: const VisualDensity(vertical: -2),
        textColor: AppColors.textoNavegacao,
        iconColor: AppColors.secundarioNavegacao,
        selectedColor: AppColors.menta,
        selectedTileColor: AppColors.navegacaoElevada),
    checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.secundarioNavegacao),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.menta
                : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.navegacao)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textoNavegacao,
            side: const BorderSide(color: AppColors.bordaNavegacao))),
    inputDecorationTheme: tema.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.navegacaoElevada,
        labelStyle: const TextStyle(color: AppColors.secundarioNavegacao),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.bordaNavegacao)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.menta))),
  );
}
