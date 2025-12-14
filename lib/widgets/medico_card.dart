import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:mapa_gabinetes/main.dart';
import '../models/medico.dart';

class MedicoCard {
  /// Cartão compacto principal, permitindo personalizar cor e "validez".
  static Widget buildSmallMedicoCard(
      Medico medico, String horarios, Color backgroundColor, bool isValid,
      {Color? corDestaque}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.all(6),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: corDestaque ?? backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: corDestaque != null
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nome do Médico (centralizado)
          SizedBox(
            width: double.infinity,
            child: Text(
              medico.nome,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),

          // Horários e especialidade centralizados
          SizedBox(
            width: double.infinity,
            child: Text(
              "$horarios ${medico.especialidade}",
              style: const TextStyle(
                fontSize: 11,
                color: Colors.purple,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão simples, se quiser usar sem se preocupar com cores/validez
  static Widget buildSmallMedicoCardSimple(Medico medico, String horariosStr) {
    return buildSmallMedicoCard(
      medico,
      horariosStr,
      Colors.blue[100]!,
      true,
    );
  }

  /// Cartão de arrasto (feedback) - roxo
  static Widget dragFeedback(Medico medico, String horariosStr) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: MyAppTheme.azulClaro,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              medico.nome,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (horariosStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                horariosStr,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            if (medico.especialidade.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                medico.especialidade,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
