import '../funcoes/platform_utils.dart';

enum PlatformType { android, ios }

class LojaEAdmobConstants {
  static final PlatformType _platformType = _getPlatformType();

  static PlatformType _getPlatformType() {
    if (platformIsAndroid()) return PlatformType.android;
    if (platformIsIOS()) return PlatformType.ios;
    throw UnsupportedError('Unsupported platform');
  }

  static String _getPlatformSpecificValue({
    required String androidValue,
    required String iosValue,
  }) {
    switch (_platformType) {
      case PlatformType.android:
        return androidValue;
      case PlatformType.ios:
        return iosValue;
    }
  }

  static String get inAppAdsOffTitle => _getPlatformSpecificValue(
        androidValue: 'ADS OFF (Depression Test)',
        iosValue: 'ADS OFF',
      );

  static String get inAppAllApsTitle => _getPlatformSpecificValue(
        androidValue: 'All Apps (Depression Test)',
        iosValue: 'All Apps',
      );

  static String get inAppAllAps => _getPlatformSpecificValue(
        androidValue: 'allapps',
        iosValue: 'allapps',
      );

  static String get inAppAdsOff => _getPlatformSpecificValue(
        androidValue: 'ads_off',
        iosValue: 'ads_off',
      );

  static String get admobIDdaApp => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016~2605777101',
        iosValue: 'ca-app-pub-5079087452062016~3497005184',
      );

  static String get bannerAdUnitId => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016/3786340293',
        iosValue: 'ca-app-pub-5079087452062016/5851705788',
      );

  static String get interstitialAdUnitId => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016/7366492656',
        iosValue: 'ca-app-pub-5079087452062016/8104859252',
      );

  static String get rewardedAdUnitId => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016/6053410989',
        iosValue: 'ca-app-pub-5079087452062016/4900111410',
      );

  static String get aberturaAdsId => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016/4921767493',
        iosValue: 'ca-app-pub-5079087452062016/9599379108',
      );

  static String get nativeAdsId => _getPlatformSpecificValue(
        androidValue: 'ca-app-pub-5079087452062016/4852009959',
        iosValue: 'ca-app-pub-5079087452062016/8286297436',
      );
}
