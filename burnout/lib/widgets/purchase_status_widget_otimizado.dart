import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';

class PurchaseStatusOptimized extends StatelessWidget {
  final Widget? adFreeWidget;

  final Widget? adActiveWidget;

  final Widget? allAppsWidget;

  final Widget? limitedAppsWidget;

  final Widget Function(bool adsPago, bool allApps)? builder;

  const PurchaseStatusOptimized({
    super.key,
    this.adFreeWidget,
    this.adActiveWidget,
    this.allAppsWidget,
    this.limitedAppsWidget,
    this.builder,
  }) : assert(
            builder != null ||
                (adFreeWidget != null && adActiveWidget != null) ||
                (allAppsWidget != null && limitedAppsWidget != null),
            'Deve fornecer ou um builder ou os widgets condicionais');

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyG>(
      builder: (myG) {
        final adsPago = myG.adsPago;
        final allApps = myG.allApps;

        if (builder != null) {
          return builder!(adsPago, allApps);
        }

        if (adFreeWidget != null && adActiveWidget != null) {
          return adsPago ? adFreeWidget! : adActiveWidget!;
        }

        if (allAppsWidget != null && limitedAppsWidget != null) {
          return allApps ? allAppsWidget! : limitedAppsWidget!;
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class AdStatusOptimized extends StatelessWidget {
  final Widget child;
  final bool showWhenAdsPaid;

  const AdStatusOptimized({
    super.key,
    required this.child,
    this.showWhenAdsPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyG>(
      builder: (myG) {
        final adsPago = myG.adsPago;
        final shouldShow = showWhenAdsPaid ? adsPago : !adsPago;

        return Visibility(
          visible: shouldShow,
          child: child,
        );
      },
    );
  }
}

class PremiumFeatureOptimized extends StatelessWidget {
  final Widget premiumWidget;
  final Widget freeWidget;

  const PremiumFeatureOptimized({
    super.key,
    required this.premiumWidget,
    required this.freeWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyG>(
      builder: (myG) {
        final isPremium = myG.isPremiumFeatureEnabled;
        return isPremium ? premiumWidget : freeWidget;
      },
    );
  }
}

extension PurchaseStatusOptimizedExtension on Widget {
  Widget showWhenAdsFreeMELHORADO() {
    return AdStatusOptimized(
      showWhenAdsPaid: true,
      child: this,
    );
  }

  Widget showWhenAdsActiveMELHORADO() {
    return AdStatusOptimized(
      child: this,
    );
  }

  Widget showWhenAllAppsMELHORADO() {
    return GetBuilder<MyG>(
      builder: (myG) => Visibility(
        visible: myG.allApps,
        child: this,
      ),
    );
  }

  Widget showWhenLimitedAppsMELHORADO() {
    return GetBuilder<MyG>(
      builder: (myG) => Visibility(
        visible: !myG.allApps,
        child: this,
      ),
    );
  }
}

class PurchaseChecker {
  static bool get adsRemovidos => MyG.to.adsPago;

  static bool get allAppsDesbloqueados => MyG.to.allApps;

  static bool get isPremium => MyG.to.isPremiumFeatureEnabled;

  static bool shouldShowAds() => !adsRemovidos;
  static bool shouldShowPremiumContent() => isPremium;
}

class SimpleAdVisibility extends StatelessWidget {
  final Widget child;
  final bool showWhenAdsPaid;

  const SimpleAdVisibility({
    super.key,
    required this.child,
    this.showWhenAdsPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShow = showWhenAdsPaid
        ? PurchaseChecker.adsRemovidos
        : PurchaseChecker.shouldShowAds();

    return Visibility(
      visible: shouldShow,
      child: child,
    );
  }
}
