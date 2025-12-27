import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_logger.dart';
import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_request.dart';

class NativeAdReuse extends StatefulWidget {
  const NativeAdReuse({super.key});

  @override
  NativeAdReuseState createState() => NativeAdReuseState();
}

class NativeAdReuseState extends State<NativeAdReuse> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (_nativeAdIsLoaded) return;

    _nativeAd = NativeAd(
      adUnitId: LojaEAdmobConstants.nativeAdsId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          AdLogger.success('NativeAd', 'Anúncio nativo carregado com sucesso');
          setState(() => _nativeAdIsLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          AdLogger.error(
              'NativeAd', 'Falha ao carregar anúncio nativo: $error');
          ad.dispose();
          setState(() => _nativeAdIsLoaded = false);
        },
      ),
      request: AdRequestFactory.build(),
      nativeTemplateStyle: _nativeTemplateStyle(),
    )..load();
  }

  NativeTemplateStyle _nativeTemplateStyle() {
    return NativeTemplateStyle(
      templateType: TemplateType.medium,
      mainBackgroundColor: const Color(0xFFFFF8E1),
      cornerRadius: 10.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Colors.white,
        backgroundColor: Colors.orange.shade600,
        style: NativeTemplateFontStyle.bold,
        size: 16.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.brown.shade800,
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.bold,
        size: 16.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.brown.shade700,
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.normal,
        size: 14.0,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: Colors.brown.shade600,
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.normal,
        size: 12.0,
      ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    AdLogger.info('NativeAd', 'Anúncio nativo descartado');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Só mostra o espaço quando o anúncio estiver realmente carregado
    if (_nativeAdIsLoaded && _nativeAd != null) {
      return SizedBox(
        height: 300,
        width: MediaQuery.of(context).size.width,
        child: AdWidget(ad: _nativeAd!),
      );
    }
    // Se não estiver carregado, não mostra nada (sem espaço, sem progress bar)
    return const SizedBox.shrink();
  }
}
