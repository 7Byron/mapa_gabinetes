//...funcoes/theme_default.dart
import 'package:flutter/material.dart';
import 'theme_tokens.dart';

ThemeData lightThemeData() => themeData();
ThemeData darkThemeData() => themeData(brightness: Brightness.dark);
// Atenção: o nome da família deve coincidir exatamente com o declarado no pubspec ("Kalam").
ThemeData lightThemeDataKalim() => themeData(fontFamily: 'Kalam');
ThemeData darkThemeDatakalim() =>
    themeData(brightness: Brightness.dark, fontFamily: 'Kalam');

ThemeData themeData(
    {Brightness brightness = Brightness.light, String? fontFamily}) {
  return ThemeData(
    fontFamily: fontFamily,
    brightness: brightness,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
    ),
    scaffoldBackgroundColor: brightness == Brightness.light
        ? Colors.amber.shade50
        : Colors.grey.shade900,
    colorScheme: brightness == Brightness.light
        ? ColorScheme.fromSwatch(
            primarySwatch: Colors.amber,
          ).copyWith(
            primary: Colors.amber.shade500,
            onPrimary: Colors.brown,
            secondary: Colors.amber.shade200,
            onSecondary: Colors.brown,
            surface: Colors.amber.shade300,
            onSurface: Colors.brown,
          )
        : ColorScheme.dark(
            primary: Colors.black,
            onPrimary: Colors.white,
            secondary: Colors.grey.shade700,
            onSecondary: Colors.white,
            surface: Colors.grey.shade800,
          ),
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(
        color: brightness == Brightness.light ? Colors.brown : Colors.white,
      ),
      backgroundColor:
          brightness == Brightness.light ? Colors.amber.shade500 : Colors.black,
      elevation: 8,
      centerTitle: true,
      // Usa a mesma família de fonte do tema atual
      titleTextStyle: ThemeData(brightness: brightness)
          .textTheme
          .titleLarge
          ?.copyWith(
            color: brightness == Brightness.light ? Colors.brown : Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
          ),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: fontFamily,
      ),
    ).apply(
      bodyColor: brightness == Brightness.light ? Colors.brown : Colors.white,
      displayColor:
          brightness == Brightness.light ? Colors.brown : Colors.white,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor:
          brightness == Brightness.light ? Colors.amber : Colors.grey.shade700,
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor:
            brightness == Brightness.light ? Colors.brown : Colors.white,
        backgroundColor: brightness == Brightness.light
            ? Colors.amber
            : Colors.grey.shade800,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor:
            brightness == Brightness.light ? Colors.brown : Colors.white,
        side: BorderSide(
          color: brightness == Brightness.light
              ? Colors.amber.shade700
              : Colors.white70,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor:
            brightness == Brightness.light ? Colors.brown : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
    ),
    dividerTheme: const DividerThemeData(thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.amber.shade50
          : Colors.grey.shade800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
        borderSide: BorderSide(
          color: brightness == Brightness.light
              ? Colors.amber.shade500
              : Colors.white,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
        borderSide: BorderSide(
          color: brightness == Brightness.light
              ? Colors.amber.shade700
              : Colors.white,
          width: 2.0,
        ),
      ),
      hintStyle: TextStyle(
        color: brightness == Brightness.light ? Colors.brown : Colors.white70,
      ),
    ),
  );
}
