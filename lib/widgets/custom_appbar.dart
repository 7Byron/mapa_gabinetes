import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final double? currentZoom;
  final VoidCallback? onRefresh;

  const CustomAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.onZoomIn,
    this.onZoomOut,
    this.currentZoom,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: titleWidget ??
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
      actions: [
        // Botão de refresh (laranja)
        if (onRefresh != null)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: onRefresh,
            tooltip: 'Atualizar dados (limpar cache e recarregar)',
          ),
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
