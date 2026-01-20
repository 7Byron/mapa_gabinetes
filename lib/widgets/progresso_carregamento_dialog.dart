import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ProgressoCarregamentoDialog extends StatelessWidget {
  final double progresso;
  final String mensagem;

  const ProgressoCarregamentoDialog({
    super.key,
    required this.progresso,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progresso,
                  backgroundColor: Colors.grey.shade300,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(MyAppTheme.azulEscuro),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(progresso * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(mensagem),
            ],
          ),
        ),
      ),
    );
  }
}
