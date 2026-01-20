import 'package:flutter/material.dart';

class ZoomableContainer extends StatelessWidget {
  final double zoomLevel;
  final Widget child;

  const ZoomableContainer({
    super.key,
    required this.zoomLevel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth / zoomLevel;
        final containerHeight = constraints.maxHeight / zoomLevel;

        return OverflowBox(
          minWidth: containerWidth,
          maxWidth: containerWidth,
          minHeight: containerHeight,
          maxHeight: containerHeight,
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: zoomLevel,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: containerWidth,
              height: containerHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
