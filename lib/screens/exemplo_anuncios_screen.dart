import 'package:flutter/material.dart';
import '../widgets/web_ad_widget.dart';
import '../config/ad_config.dart';

class ExemploAnunciosScreen extends StatelessWidget {
  const ExemploAnunciosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exemplo de Anúncios Web'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner superior
            BannerAdWidget(adUnitId: AdConfig.getAdUnitId('banner_top')),
            SizedBox(height: 20),

            // Conteúdo principal
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conteúdo Principal',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Este é um exemplo de como integrar anúncios na versão web do seu app. '
                      'Os anúncios aparecerão apenas na versão web, enquanto nas versões móveis '
                      'serão exibidos placeholders.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Anúncio responsivo
            ResponsiveAdWidget(adUnitId: AdConfig.getAdUnitId('responsive')),
            SizedBox(height: 20),

            // Mais conteúdo
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mais Informações',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Para implementar anúncios reais, você precisará:',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    _buildBulletPoint('Criar uma conta no Google AdSense'),
                    _buildBulletPoint('Obter seu Publisher ID'),
                    _buildBulletPoint('Criar unidades de anúncio'),
                    _buildBulletPoint('Substituir os IDs nos widgets'),
                    _buildBulletPoint('Implementar o código JavaScript real'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Anúncio lateral (em layout responsivo)
            Center(
              child: SidebarAdWidget(adUnitId: AdConfig.getAdUnitId('sidebar')),
            ),
            SizedBox(height: 20),

            // Banner inferior
            BannerAdWidget(adUnitId: AdConfig.getAdUnitId('banner_bottom')),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
