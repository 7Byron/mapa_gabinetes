import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../a_config_app/loja_admob_constants.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';
import '../funcoes/theme_tokens.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final box = GetStorage();
  List<ProductDetails> view = [];
  bool ads = MyG.to.adsPago;
  bool allApps = MyG.to.allApps;
  int itemPurchased = 0;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  // Fluxo simplificado: não usamos flag de sessão de compra

  @override
  void initState() {
    super.initState();

    fetchProducts();
    _subscription = _inAppPurchase.purchaseStream.listen(handlePurchaseUpdates);

    // Agenda a sincronização das variáveis globais para após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGlobalVariables();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Agenda a sincronização para após o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGlobalVariables();
    });
  }

  // Método para sincronizar as variáveis globais com o GetStorage
  void _syncGlobalVariables() {
    final String adsStatus = box.read("ADS") ?? "Não";
    final String allAppsStatus = box.read("ALLAPPS") ?? "Não";

    if (adsStatus == "Sim") {
      MyG.to.atualizarAposCompra(adsRemovidos: true);
      ads = MyG.to.adsPago;
    } else {
      MyG.to.atualizarAposCompra(adsRemovidos: false);
      ads = MyG.to.adsPago;
    }

    if (allAppsStatus == "Sim") {
      MyG.to.atualizarAposCompra(todosApps: true);
      allApps = MyG.to.allApps;
    } else {
      MyG.to.atualizarAposCompra(todosApps: false);
      allApps = MyG.to.allApps;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> fetchProducts() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (available) {
        final Set<String> ids = <String>{
          LojaEAdmobConstants.inAppAdsOff,
          LojaEAdmobConstants.inAppAllAps,
        };
        final ProductDetailsResponse res =
            await _inAppPurchase.queryProductDetails(ids);
        if (res.error == null) {
          view = res.productDetails;
        } else {
          _logError('Failed to fetch products', res.error);
          Get.snackbar(
              'Error', 'Failed to fetch products. Please try again later.');
        }
      } else {
        Get.snackbar('Error', 'In-App Purchase is not available.');
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _logError('Error fetching products', e);
      Get.snackbar(
          'Error', 'Failed to fetch products. Please try again later.');
    }
  }

  void handlePurchaseUpdates(List<PurchaseDetails> event) async {
    for (final PurchaseDetails purchase in event) {
      if (purchase.pendingCompletePurchase) {
        await _completePurchase(purchase);
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          _applyRestoredOrPurchased(purchase.productID, navigate: true);
          break;
        case PurchaseStatus.restored:
          // Em restore não navegamos; apenas aplicamos e informamos
          _applyRestoredOrPurchased(purchase.productID, navigate: false);
          Get.snackbar('Success', 'Purchases restored successfully.');
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchase.error);
          break;
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          break;
      }
    }
    // Eventos processados
  }

  // Aplica a compra/restauração diretamente, atualizando globais e storage,
  // e navega para a página de agradecimento apenas quando for compra nova.
  void _applyRestoredOrPurchased(String productId, {required bool navigate}) {
    if (productId == LojaEAdmobConstants.inAppAdsOff) {
      MyG.to.atualizarAposCompra(adsRemovidos: true);
      ads = MyG.to.adsPago;
      if (navigate) {
        Get.offNamed(RotasPaginas.thanks, arguments: [1]);
      }
    } else if (productId == LojaEAdmobConstants.inAppAllAps) {
      MyG.to.atualizarAposCompra(todosApps: true);
      allApps = MyG.to.allApps;
      if (navigate) {
        Get.offNamed(RotasPaginas.thanks, arguments: [2]);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  //

  Future<void> _completePurchase(PurchaseDetails purchase) async {
    try {
      await _inAppPurchase.completePurchase(purchase);
    } catch (e) {
      _logError('Error completing purchase', e);
      Get.snackbar(
          'Error', 'Failed to complete purchase. Please try again later.');
    }
  }

  void _handlePurchaseError(IAPError? error) {
    if (error != null) {
      _logError('Purchase error', error);

      if (error.code == 'purchase_not_allowed') {
        Get.snackbar(
            'Error', 'Purchase not allowed. Please check your settings.');
      } else {
        Get.snackbar('Purchase Error', 'An error occurred: ${error.message}');
      }
    }
  }

  void _logError(String message, Object? error) {
    String errorMessage = error.toString();

    if (error is PlatformException && error.details != null) {
      errorMessage += " - ${error.details}";
    }

    if (kDebugMode) {
      debugPrint('$message: $errorMessage');
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      // O toast final é mostrado ao processar os eventos RESTORED
    } catch (e) {
      _handleRestoreError(e);
    }
  }

  void _handleRestoreError(Object error) {
    String errorMessage = error.toString();

    if (error is PlatformException && error.details != null) {
      errorMessage += " - ${error.details}";
    }

    _logError('Error restoring purchases', errorMessage);

    Get.snackbar(
      'Error',
      'Failed to restore purchases. Please try again later.',
    );
  }

  void handlePurchase(ProductDetails product) async {
    final String currentAdsStatus = box.read("ADS") ?? "Não";
    final String currentAllAppsStatus = box.read("ALLAPPS") ?? "Não";

    ads = currentAdsStatus == "Sim";
    allApps = currentAllAppsStatus == "Sim";

    if ((product.title == LojaEAdmobConstants.inAppAdsOffTitle && ads) ||
        (product.title == LojaEAdmobConstants.inAppAllApsTitle && allApps)) {
      Get.snackbar('Info', 'You have already purchased this item.');
      return;
    }

    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);

      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _logError('Error during purchase', e);
      Get.snackbar(
          'Error', 'Failed to process purchase. Please try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildStyledAppBar(),
      body: view.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : buildProductList(),
    );
  }

  PreferredSizeWidget _buildStyledAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Padding(
        padding: EdgeInsets.all(Spacing.xs),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 20.0,
                offset: Offset(0.0, 5.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.0),
            child: AppBar(
              elevation: 4.0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          MyG.to.margens['margem05']!,
                          0,
                          MyG.to.margens['margem05']!,
                          MyG.to.margens['margem025']!),
                      child: AutoSizeText(
                        Get.context!.isPhone
                            ? "${"removerAds".tr}\n${"allapps".tr}"
                            : "${"removerAds".tr} | ${"allapps".tr}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: MyG.to.margens['margem085']!,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        maxFontSize: MyG.to.margens['margem1']!,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: restorePurchases,
                  tooltip: 'Restaurar Compras',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildProductList() {
    final String currentAdsStatus = box.read("ADS") ?? "Não";
    final String currentAllAppsStatus = box.read("ALLAPPS") ?? "Não";

    ads = currentAdsStatus == "Sim";
    allApps = currentAllAppsStatus == "Sim";

    final List<ProductDetails> filteredProducts = view.where((product) {
      if (product.id == LojaEAdmobConstants.inAppAdsOff && ads) {
        return false;
      }
      if (product.id == LojaEAdmobConstants.inAppAllAps && allApps) {
        return false;
      }
      return true;
    }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(MyG.to.margens['margem2']!),
          padding: EdgeInsets.all(MyG.to.margens['margem2']!),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: MyG.to.margens['margem3']!,
                color: Colors.green,
              ),
              SizedBox(height: Spacing.m),
              Text(
                'Restored Purchases',
                style: TextStyle(
                  fontSize: MyG.to.margens['margem1']!,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: Spacing.l),
          ...filteredProducts.map((product) => buildProductCard(product)),
          SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }

  Widget buildProductCard(ProductDetails product) {
    final bool isAdsOff = product.title == LojaEAdmobConstants.inAppAdsOffTitle;

    // Gradientes específicos para cada tipo de produto
    final LinearGradient cardGradient =
        isAdsOff ? ThemeTokens.gradAmberLight : ThemeTokens.gradOrangeLight;

    return Center(
      child: Container(
        height: 260,
        width: 250,
        margin: EdgeInsets.fromLTRB(
          MyG.to.margens['margem1']! * 0.8,
          MyG.to.margens['margem1_5']! * 0.8,
          MyG.to.margens['margem1']! * 0.8,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
          gradient: cardGradient,
          border: Border.all(
            color: Colors.amber.shade600,
          ),
          boxShadow: [
            BoxShadow(
              color: cardGradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
            onTap: () => handlePurchase(product),
            child: Padding(
              padding: EdgeInsets.all(
                  MyG.to.margens['margem1_5']! * 0.8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Container(
                    width: MyG.to.margens['margem4']! *
                        1.1,
                    height: MyG.to.margens['margem4']! *
                        1.1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade50,
                          Colors.green.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(
                          MyG.to.margens['margem075']! * 1.1),
                      child: Image.asset(
                        isAdsOff ? RotaImagens.adsOff : RotaImagens.allApps,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  Text(
                    isAdsOff ? "removerAds".tr : "allapps".tr,
                    style: TextStyle(
                      fontSize: MyG.to.margens['margem1_25']! *
                          0.6,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade600,
                          Colors.green.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MyG.to.margens['margem1_5']! *
                            0.8,
                        vertical:
                            MyG.to.margens['margem075']! * 0.8,
                      ),
                      child: Text(
                        product.price,
                        style: TextStyle(
                          fontSize: MyG.to.margens['margem1_25']! *
                              0.6,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
