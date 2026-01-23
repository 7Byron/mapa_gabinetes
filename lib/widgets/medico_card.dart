import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../models/medico.dart';

class MedicoCard {
  /// Cartão compacto principal, permitindo personalizar cor e "validez".
  static Widget buildSmallMedicoCard(
      Medico medico, String horarios, Color backgroundColor, bool isValid,
      {Color? corDestaque}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: corDestaque ?? backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: corDestaque != null
            ? Border.all(color: Colors.orange.shade400, width: 2)
            : Border.all(color: Colors.grey.shade300, width: 0.5),
        boxShadow: MyAppTheme.shadowMedicoCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome do Médico
          Text(
            medico.nome,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Horários com ícone
          if (horarios.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 11,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    horarios,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],

          // Especialidade com ícone
          if (medico.especialidade.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  size: 11,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    medico.especialidade,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
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

  /// Cartão de arrasto (feedback) - elegante
  static Widget dragFeedback(Medico medico, String horariosStr) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MyAppTheme.azulEscuro,
              MyAppTheme.azulEscuro.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (horariosStr.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                horariosStr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (medico.especialidade.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                medico.especialidade,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
