import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class LayoutResponsivoToggle extends StatelessWidget {
  final bool mostrarColunaEsquerda;
  final VoidCallback onMostrarFiltros;
  final VoidCallback onMostrarMapa;

  const LayoutResponsivoToggle({
    super.key,
    required this.mostrarColunaEsquerda,
    required this.onMostrarFiltros,
    required this.onMostrarMapa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        boxShadow: MyAppTheme.shadowCard,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: onMostrarFiltros,
                icon: Icon(
                  Icons.settings,
                  size: 16,
                  color:
                      mostrarColunaEsquerda ? Colors.white : Colors.blue.shade600,
                ),
                label: Text(
                  'Ver Filtros',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mostrarColunaEsquerda
                        ? Colors.white
                        : Colors.blue.shade600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      mostrarColunaEsquerda ? Colors.blue.shade600 : Colors.white,
                  foregroundColor:
                      mostrarColunaEsquerda ? Colors.white : Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.blue.shade600,
                      width: 1,
                    ),
                  ),
                  elevation: mostrarColunaEsquerda ? 2 : 0,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              child: ElevatedButton.icon(
                onPressed: onMostrarMapa,
                icon: Icon(
                  Icons.map,
                  size: 16,
                  color: !mostrarColunaEsquerda
                      ? Colors.white
                      : Colors.blue.shade600,
                ),
                label: Text(
                  'Ver Mapa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !mostrarColunaEsquerda
                        ? Colors.white
                        : Colors.blue.shade600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      !mostrarColunaEsquerda ? Colors.blue.shade600 : Colors.white,
                  foregroundColor:
                      !mostrarColunaEsquerda ? Colors.white : Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.blue.shade600,
                      width: 1,
                    ),
                  ),
                  elevation: !mostrarColunaEsquerda ? 2 : 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
