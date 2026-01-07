import 'package:flutter/material.dart';

class MyAppTheme {
  // Cores principais - Paleta profissional moderna
  static const Color azulEscuro = Color(0xFF1565C0);
  static const Color azulClaro = Color(0xFF64B5F6);
  static const Color roxo = Color(0xFF7B1FA2);
  static const Color cinzento = Color(0xFF607D8B);

  // Cores adicionais
  static const Color verde = Color(0xFF4CAF50);
  static const Color vermelho = Color(0xFFE53935);
  static const Color laranja = Color(0xFFFF9800);

  // Paleta profissional para estados de gabinetes
  static const Color gabineteLivre = Color(0xFFFEFEFE); // Cinza quase branco
  static const Color gabineteOcupado =
      Color(0xFFE3F2FD); // Azul claro (igual aos cartões de médicos)
  static const Color gabineteConflito =
      Color(0xFFFCE8E8); // Vermelho muito suave e natural

  // Cores para bordas dos gabinetes
  static const Color bordaGabineteLivre = Color(0xFFE8E8E8); // Cinza suave
  static const Color bordaGabineteOcupado =
      Color(0xFFBBDEFB); // Azul claro para borda
  static const Color bordaGabineteConflito =
      Color(0xFFE8B4B4); // Vermelho acinzentado natural

  // Cor para cards de médicos disponíveis
  static const Color medicoDisponivelCard = Color(0xFFE3F2FD); // Azul claro

  // Cores de fundo elegantes
  static const Color backgroundGradientStart = Color(0xFFF5F7FA);
  static const Color backgroundGradientEnd = Color(0xFFE8ECF1);

  // Cores para cards e elevação
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);

  // Tipografia profissional
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: Color(0xFF1A1A1A),
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF424242),
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF616161),
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFF757575),
  );

  // Sombras elegantes e modernas com efeito 3D
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: const Color(0x1A000000),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0x0D000000),
          blurRadius: 4,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowCard3D => [
        // Sombra principal uniforme - visível em todos os lados
        BoxShadow(
          color: const Color(0x20000000),
          blurRadius: 12,
          offset: const Offset(0, 2),
          spreadRadius: 1,
        ),
        // Sombra lateral esquerda
        BoxShadow(
          color: const Color(0x10000000),
          blurRadius: 8,
          offset: const Offset(-2, 0),
          spreadRadius: 0,
        ),
        // Sombra lateral direita
        BoxShadow(
          color: const Color(0x10000000),
          blurRadius: 8,
          offset: const Offset(2, 0),
          spreadRadius: 0,
        ),
        // Sombra superior suave
        BoxShadow(
          color: const Color(0x08000000),
          blurRadius: 6,
          offset: const Offset(0, -1),
          spreadRadius: 0,
        ),
        // Sombra inferior mais pronunciada
        BoxShadow(
          color: const Color(0x15000000),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowCardHover => [
        BoxShadow(
          color: const Color(0x40000000),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0x20000000),
          blurRadius: 10,
          offset: const Offset(0, 3),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowElevated => [
        BoxShadow(
          color: const Color(0x40000000),
          blurRadius: 16,
          offset: const Offset(0, 5),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0x1A000000),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  // Sombra para cards de médicos
  static List<BoxShadow> get shadowMedicoCard => [
        BoxShadow(
          color: const Color(0x1A000000),
          blurRadius: 6,
          offset: const Offset(0, 3),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0x0D000000),
          blurRadius: 3,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
      ];
}
