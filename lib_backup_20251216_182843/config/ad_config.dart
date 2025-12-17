class AdConfig {
  // Publisher ID do Google AdSense
  static const String publisherId = 'ca-pub-5079087452062016';
  
  // IDs das unidades de anúncio (substitua pelos seus IDs reais)
  static const String bannerTopAdUnitId = '1234567890'; // Banner superior
  static const String bannerBottomAdUnitId = '0987654321'; // Banner inferior
  static const String sidebarAdUnitId = '1122334455'; // Anúncio lateral
  static const String responsiveAdUnitId = '5566778899'; // Anúncio responsivo
  static const String contentAdUnitId = '9988776655'; // Anúncio no conteúdo
  
  // Configurações de anúncios
  static const Map<String, Map<String, dynamic>> adUnits = {
    'banner_top': {
      'id': bannerTopAdUnitId,
      'width': 728,
      'height': 90,
      'format': 'auto',
    },
    'banner_bottom': {
      'id': bannerBottomAdUnitId,
      'width': 728,
      'height': 90,
      'format': 'auto',
    },
    'sidebar': {
      'id': sidebarAdUnitId,
      'width': 300,
      'height': 250,
      'format': 'auto',
    },
    'responsive': {
      'id': responsiveAdUnitId,
      'width': 'auto',
      'height': 'auto',
      'format': 'auto',
    },
    'content': {
      'id': contentAdUnitId,
      'width': 468,
      'height': 60,
      'format': 'auto',
    },
  };
  
  // Verificar se os anúncios estão habilitados
  static bool get adsEnabled => true;
  
  // Verificar se está em modo de teste
  static bool get isTestMode => false;
  
  // Obter configuração de uma unidade de anúncio
  static Map<String, dynamic>? getAdUnitConfig(String unitName) {
    return adUnits[unitName];
  }
  
  // Obter ID de uma unidade de anúncio
  static String getAdUnitId(String unitName) {
    return adUnits[unitName]?['id'] ?? '';
  }
} 