import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final double? currentZoom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onZoomIn,
    this.onZoomOut,
    this.currentZoom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      actions: [
        // Botões de zoom se fornecidos
        if (onZoomIn != null || onZoomOut != null) ...[
          if (currentZoom != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  '${(currentZoom! * 100).toInt()}%',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          if (onZoomOut != null)
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: onZoomOut,
              tooltip: 'Diminuir zoom',
            ),
          if (onZoomIn != null)
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: onZoomIn,
              tooltip: 'Aumentar zoom',
            ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Image.asset(
            'images/am_icon.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
