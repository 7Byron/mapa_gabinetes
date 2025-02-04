import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/main.dart';
import '../models/medico.dart';

class MedicoCard {
  /// Cartão compacto principal, permitindo personalizar cor e "validez".
  static Widget buildSmallMedicoCard(
      Medico medico, String horarios, Color backgroundColor, bool isValid) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.all(6),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome do Médico (centralizado e ajustável)
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                medico.nome,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Linha para horários e especialidade
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Horários
                Text(
                  horarios,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 4),

                // Especialidade (ajustável)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      medico.especialidade,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              medico.nome,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (medico.especialidade.isNotEmpty)
              Text(
                medico.especialidade,
                style: const TextStyle(color: Colors.white),
              ),
            if (horariosStr.isNotEmpty)
              Text(
                horariosStr,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
