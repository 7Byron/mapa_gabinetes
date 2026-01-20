import 'package:flutter/material.dart';

class CarregamentoOverlay extends StatelessWidget {
  final bool isRefreshing;
  final String mensagem;
  final double progresso;

  const CarregamentoOverlay({
    super.key,
    required this.isRefreshing,
    required this.mensagem,
    required this.progresso,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isRefreshing ? 'A atualizar dados...' : mensagem,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progresso * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
