// medico_card.dart
import 'package:flutter/material.dart';
import '../class/medico.dart';

class MedicoCard {
  /// Cartão do médico (compacto)
  static Widget buildSmallMedicoCard(Medico medico, String horariosStr) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medico.nome, style: TextStyle(fontWeight: FontWeight.bold)),
          if (medico.especialidade.isNotEmpty)
            Text(medico.especialidade),
          if (horariosStr.isNotEmpty)
            Text(horariosStr, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Cartão de arrasto (feedback) - roxo
  static Widget dragFeedback(Medico medico, String horariosStr) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        padding: EdgeInsets.all(8),
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (medico.especialidade.isNotEmpty)
              Text(
                medico.especialidade,
                style: TextStyle(color: Colors.white),
              ),
            if (horariosStr.isNotEmpty)
              Text(
                horariosStr,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}