import 'package:flutter/material.dart';

ThemeData _baseLightThemeData({String? fontFamily}) {
  return ThemeData(
    fontFamily: fontFamily,
    scaffoldBackgroundColor: Colors.amber.shade50,
    primaryColorDark: Colors.amber.shade200,
    primaryColor: Colors.amber.shade500,
    primaryColorLight: Colors.brown,
    brightness: Brightness.light,
    appBarTheme: AppBarTheme(
      iconTheme: const IconThemeData(color: Colors.brown),
      backgroundColor: Colors.amber.shade500,
      elevation: 4.0,
      centerTitle: true,
      titleTextStyle: const TextStyle(color: Colors.brown),
    ),
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.amber)
        .copyWith(surface: Colors.amber.shade300),
  );
}

ThemeData _baseDarkThemeData({String? fontFamily}) {
  return ThemeData(
    fontFamily: fontFamily,
    colorScheme: const ColorScheme.dark(),
  );
}

ThemeData lightThemeData() {
  return _baseLightThemeData();
}

ThemeData darkThemeData() {
  return _baseDarkThemeData();
}

ThemeData lightThemeDataKalam() {
  return _baseLightThemeData(fontFamily: 'kalam');
}

ThemeData darkThemeDataKalam() {
  return _baseDarkThemeData(fontFamily: 'kalam');
}
