import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebAdWidget extends StatefulWidget {
  final String adUnitId;
  final double width;
  final double height;
  final String adFormat;

  const WebAdWidget({
    super.key,
    required this.adUnitId,
    this.width = 728,
    this.height = 90,
    this.adFormat = 'banner',
  });

  @override
  State<WebAdWidget> createState() => _WebAdWidgetState();
}

class _WebAdWidgetState extends State<WebAdWidget> {
  String? _viewId;
  final bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _createAdElement();
    }
  }

  void _createAdElement() {
    _viewId = 'ad-${DateTime.now().millisecondsSinceEpoch}';

    // Registrar o elemento HTML usando js interop
    if (kIsWeb) {
      // Usar JavaScript para criar o elemento de anúncio
      _createAdWithJavaScript();
    }
  }

  void _createAdWithJavaScript() {
    // Este método será implementado usando js interop
    // Por enquanto, vamos usar um placeholder
    // Para implementação completa, instale o pacote 'js' e use:
    // @JS('createAdWithFallback')
    // external dynamic createAdWithFallback(String adUnitId, int width, int height, String format);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Em plataformas móveis, mostrar um placeholder
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Anúncio (apenas na versão web)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Na versão web, mostrar um container com instruções
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.ads_click,
              color: Colors.blue[400],
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'Espaço para Anúncio',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'ID: ${widget.adUnitId}',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para banner horizontal (728x90)
class BannerAdWidget extends StatelessWidget {
  final String adUnitId;

  const BannerAdWidget({
    super.key,
    required this.adUnitId,
  });

  @override
  Widget build(BuildContext context) {
    return WebAdWidget(
      adUnitId: adUnitId,
      width: 728,
      height: 90,
      adFormat: 'auto',
    );
  }
}

// Widget para anúncio responsivo
class ResponsiveAdWidget extends StatelessWidget {
  final String adUnitId;

  const ResponsiveAdWidget({
    super.key,
    required this.adUnitId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double height;

        // Definir altura baseada na largura disponível
        if (width >= 728) {
          height = 90; // Banner horizontal
        } else if (width >= 468) {
          height = 60; // Banner médio
        } else {
          height = 50; // Banner pequeno
        }

        return WebAdWidget(
          adUnitId: adUnitId,
          width: width,
          height: height,
          adFormat: 'auto',
        );
      },
    );
  }
}

// Widget para anúncio lateral (300x250)
class SidebarAdWidget extends StatelessWidget {
  final String adUnitId;

  const SidebarAdWidget({
    super.key,
    required this.adUnitId,
  });

  @override
  Widget build(BuildContext context) {
    return WebAdWidget(
      adUnitId: adUnitId,
      width: 300,
      height: 250,
      adFormat: 'auto',
    );
  }
}
