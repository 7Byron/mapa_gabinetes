import 'package:flutter/material.dart';
import '../models/medico.dart';

class MedicoCard {
  /// Cartão compacto principal, permitindo personalizar cor e "validez".
  static Widget buildSmallMedicoCard(
      Medico medico,
      String horariosStr,
      Color corFundo,
      bool valido,
      ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: valido ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            medico.nome,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (medico.especialidade.isNotEmpty)
            Text(
              medico.especialidade,
              style: const TextStyle(fontSize: 12),
            ),
          if (horariosStr.isNotEmpty)
            Text(
              horariosStr,
              style: const TextStyle(fontSize: 12),
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
      Colors.green[100]!,
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
          color: Colors.deepPurple,
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
