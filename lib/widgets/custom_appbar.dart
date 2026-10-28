import '../utils/matriz_colors.dart';
import '../utils/app_colors.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final double? currentZoom;
  final VoidCallback? onRefresh;
  final Color? backgroundColor;
  final Color refreshColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.onZoomIn,
    this.onZoomOut,
    this.currentZoom,
    this.onRefresh,
    this.backgroundColor = MatrizColors.barra,
    this.refreshColor = MatrizColors.iconeClaro,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.borda)),
      backgroundColor: backgroundColor,
      foregroundColor: AppColors.texto,
      title: titleWidget ??
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
      actions: [
        // Botão de atualizar
        if (onRefresh != null)
          IconButton(
            icon: Icon(Icons.refresh, color: refreshColor),
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
