import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_logger.dart';
import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_request.dart';

class BannerInLineReuse extends StatefulWidget {
  const BannerInLineReuse({super.key});

  @override
  BannerInLineReuseState createState() => BannerInLineReuseState();
}

class BannerInLineReuseState extends State<BannerInLineReuse> {
  BannerAd? _inlineAdaptiveAd;
  bool _isLoaded = false;
  AdSize? _adSize;
  Orientation? _lastOrientation;

  double get _adWidth => MediaQuery.of(context).size.width - (2 * 16.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != currentOrientation) {
      _lastOrientation = currentOrientation;
      _inlineAdaptiveLoadAd();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastOrientation = MediaQuery.of(context).orientation;
      _inlineAdaptiveLoadAd();
    });
  }

  void _inlineAdaptiveLoadAd() async {
    await _inlineAdaptiveAd?.dispose();
    setState(() {
      _inlineAdaptiveAd = null;
      _isLoaded = false;
    });

    final AdSize size = AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
      _adWidth.truncate(),
    );

    _inlineAdaptiveAd = BannerAd(
      adUnitId: LojaEAdmobConstants.bannerAdUnitId,
      size: size,
      request: AdRequestFactory.build(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) async {
          AdLogger.success('InlineBanner', 'Banner inline carregado com sucesso');

          final BannerAd bannerAd = ad as BannerAd;
          final AdSize? size = await bannerAd.getPlatformAdSize();
          if (size == null) {
            AdLogger.error('InlineBanner', 'getPlatformAdSize() retornou null');

            return;
          }

          if (mounted) {
            setState(() {
              _inlineAdaptiveAd = bannerAd;
              _isLoaded = true;
              _adSize = size;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          AdLogger.error('InlineBanner', 'Falha ao carregar banner inline: $error');

          ad.dispose();
        },
      ),
    );
    await _inlineAdaptiveAd!.load();
  }

  @override
  void dispose() {
    _inlineAdaptiveAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _inlineAdaptiveAd != null && _adSize != null) {
      return Align(
        child: SizedBox(
          width: _adWidth,
          height: _adSize!.height.toDouble(),
          child: AdWidget(ad: _inlineAdaptiveAd!),
        ),
      );
    } else {
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }
}
