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
          // Linha com Hora e Especialidade
          Row(
            children: [
              Text(
                horarios,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                medico.especialidade,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          // Nome do Médico
          Text(
            medico.nome,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
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
