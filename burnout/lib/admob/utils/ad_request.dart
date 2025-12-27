import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../funcoes/platform_utils.dart';
import 'ad_logger.dart';

/// Fábrica central para criar AdRequest com NPA (nonPersonalizedAds)
/// com base no estado de consentimento armazenado.
class AdRequestFactory {
  static bool _loggedOnce = false;

  /// Determina se deve solicitar anúncios não personalizados.
  /// Regra simples e robusta ao estado atual do app:
  /// - Se o consentimento não foi concedido (isConsentGiven=false), usamos NPA=true.
  /// - Se foi concedido (isConsentGiven=true), NPA=false.
  static bool _shouldUseNpa() {
    final box = GetStorage();
    final bool isConsentGiven = box.read('isConsentGiven') ?? false;
    // Política: no iOS não usamos tracking → força NPA sempre
    if (platformIsIOS()) return true;
    return !isConsentGiven;
  }

  /// Cria o AdRequest consistente para toda a app.
  /// [collapsible] - Se fornecido ("top" ou "bottom"), cria um banner collapsible
  /// Recomendação AdMob: usar collapsible banners para melhor UX e performance
  static AdRequest build({String? collapsible}) {
    final bool npa = _shouldUseNpa();
    if (!_loggedOnce) {
      _loggedOnce = true;
      final platform = platformIsIOS() ? 'iOS' : 'Android';
      AdLogger.info(
          'AdRequest', 'Primeiro pedido: platform=$platform, NPA=$npa');
    }

    // Se collapsible foi especificado, adiciona aos extras
    if (collapsible != null &&
        (collapsible == 'top' || collapsible == 'bottom')) {
      AdLogger.info(
          'AdRequest', 'Criando AdRequest com collapsible=$collapsible');
      return AdRequest(
        nonPersonalizedAds: npa,
        extras: {
          'collapsible': collapsible,
        },
      );
    }

    return AdRequest(nonPersonalizedAds: npa);
  }
}
