import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../a_config_app/loja_admob_constants.dart';
import '../../funcoes/variaveis_globais.dart';
import '../../funcoes/rota_imagens.dart';
import '../../funcoes/rotas_paginas.dart';
import 'purchase_logger.dart';

/// Enums para melhor tipagem
enum PurchaseType { removeAds, allApps }

enum PurchaseStateStatus {
  idle,
  loading,
  purchasing,
  restoring,
  completed,
  error,
  noInternet
}

/// Modelo para produtos
class PurchaseProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final PurchaseType type;
  final String imageAsset;
  final ProductDetails productDetails;

  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
    required this.imageAsset,
    required this.productDetails,
  });
}

/// Serviço otimizado para In-App Purchases
class InAppPurchaseService extends GetxController {
  static InAppPurchaseService get to => Get.find();

  // Core components
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final GetStorage _storage = GetStorage();
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Estados reativos
  final Rx<PurchaseStateStatus> status = PurchaseStateStatus.idle.obs;
  final RxList<PurchaseProduct> availableProducts = <PurchaseProduct>[].obs;
  final RxString errorMessage = ''.obs;
  final RxBool isConnected = true.obs;

  // Status das compras
  final RxBool hasRemovedAds = false.obs;
  final RxBool hasAllApps = false.obs;

  // IDs dos produtos
  Set<String> get _productIds => {
        LojaEAdmobConstants.inAppAdsOff,
        LojaEAdmobConstants.inAppAllAps,
      };

  @override
  void onInit() {
    super.onInit();
    _initializePurchases();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  /// Inicialização do serviço
  Future<void> _initializePurchases() async {
    try {
      PurchaseLogger.info('Inicializando serviço de compras...');

      // Carrega status das compras salvas
      _loadPurchaseStatus();

      // Verifica conectividade
      await _checkConnectivity();

      // Configura listener de compras
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          PurchaseLogger.error('Erro no stream de compras', error);
          _setError('Erro no sistema de compras: $error');
        },
      );

      // Carrega produtos disponíveis
      if (isConnected.value) {
        await loadProducts();
      }
    } catch (e) {
      PurchaseLogger.error('Erro na inicialização', e);
      _setError('Falha ao inicializar sistema de compras');
    }
  }

  /// Verifica conectividade com internet
  Future<void> _checkConnectivity() async {
    try {
      // Verifica conectividade usando lookup DNS
      final result = await InternetAddress.lookup('google.com');
      isConnected.value = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      PurchaseLogger.info('Status conectividade: ${isConnected.value}');
    } catch (e) {
      PurchaseLogger.warning('Erro ao verificar conectividade', e);
      isConnected.value = false;
    }
  }

  /// Carrega status das compras do storage
  void _loadPurchaseStatus() {
    hasRemovedAds.value = _storage.read('ADS') == 'Sim';
    hasAllApps.value = _storage.read('ALLAPPS') == 'Sim';

    // ✅ OTIMIZADO: Sincroniza com variáveis globais apenas na inicialização
    MyG.to.atualizarAposCompra(
      adsRemovidos: hasRemovedAds.value,
      todosApps: hasAllApps.value,
    );

    PurchaseLogger.info(
        'Status carregado - Ads: ${hasRemovedAds.value}, AllApps: ${hasAllApps.value}');
  }

  /// Carrega produtos disponíveis da loja
  Future<void> loadProducts() async {
    if (!isConnected.value) {
      status.value = PurchaseStateStatus.noInternet;
      return;
    }

    try {
      status.value = PurchaseStateStatus.loading;
      PurchaseLogger.info('Carregando produtos...');

      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('In-App Purchase não está disponível');
      }

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.error != null) {
        throw Exception(response.error!.message);
      }

      // Converte para modelo interno
      availableProducts.clear();
      for (final productDetails in response.productDetails) {
        final product = _createPurchaseProduct(productDetails);
        if (product != null) {
          availableProducts.add(product);
        }
      }

      status.value = PurchaseStateStatus.idle;
      PurchaseLogger.info('${availableProducts.length} produtos carregados');
    } catch (e) {
      PurchaseLogger.error('Erro ao carregar produtos', e);
      _setError('Erro ao carregar produtos: $e');
    }
  }

  /// Cria modelo de produto interno
  PurchaseProduct? _createPurchaseProduct(ProductDetails productDetails) {
    final PurchaseType? type = _getPurchaseType(productDetails.id);
    if (type == null) return null;

    return PurchaseProduct(
      id: productDetails.id,
      title: _getLocalizedTitle(type),
      description: _getLocalizedDescription(type),
      price: productDetails.price,
      type: type,
      imageAsset: _getImageAsset(type),
      productDetails: productDetails,
    );
  }

  /// Determina tipo de compra pelo ID
  PurchaseType? _getPurchaseType(String productId) {
    if (productId == LojaEAdmobConstants.inAppAdsOff) {
      return PurchaseType.removeAds;
    } else if (productId == LojaEAdmobConstants.inAppAllAps) {
      return PurchaseType.allApps;
    }
    return null;
  }

  /// Obtém título localizado
  String _getLocalizedTitle(PurchaseType type) {
    switch (type) {
      case PurchaseType.removeAds:
        return 'removerAds'.tr;
      case PurchaseType.allApps:
        return 'allapps'.tr;
    }
  }

  /// Obtém descrição localizada
  String _getLocalizedDescription(PurchaseType type) {
    switch (type) {
      case PurchaseType.removeAds:
        return 'removeAdsDesc'.tr;
      case PurchaseType.allApps:
        return 'allAppsDesc'.tr;
    }
  }

  /// Obtém asset da imagem
  String _getImageAsset(PurchaseType type) {
    switch (type) {
      case PurchaseType.removeAds:
        return RotaImagens.adsOff;
      case PurchaseType.allApps:
        return RotaImagens.allApps;
    }
  }

  /// Inicia processo de compra
  Future<void> purchaseProduct(PurchaseProduct product) async {
    if (!isConnected.value) {
      await _checkConnectivity();
      if (!isConnected.value) {
        _showSnackbar('Erro', 'Sem conexão com a internet');
        return;
      }
    }

    // Verifica se já possui o produto
    if (_hasProduct(product.type)) {
      _showSnackbar('Info', 'Você já possui este item');
      return;
    }

    try {
      status.value = PurchaseStateStatus.purchasing;
      PurchaseLogger.info('Iniciando compra: ${product.id}');

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product.productDetails,
      );

      // Usa buyNonConsumable para produtos permanentes
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      PurchaseLogger.error('Erro durante compra', e);
      _setError('Erro ao processar compra: $e');
      _showSnackbar('Erro', 'Falha ao processar compra');
    }
  }

  /// Restaura compras anteriores
  Future<void> restorePurchases() async {
    if (!isConnected.value) {
      await _checkConnectivity();
      if (!isConnected.value) {
        _showSnackbar('Erro', 'Sem conexão com a internet');
        return;
      }
    }

    try {
      status.value = PurchaseStateStatus.restoring;
      PurchaseLogger.info('Restaurando compras...');

      await _inAppPurchase.restorePurchases();
      _showSnackbar('Sucesso', 'Compras restauradas com sucesso');
    } catch (e) {
      PurchaseLogger.error('Erro ao restaurar compras', e);
      _setError('Erro ao restaurar compras: $e');
      _showSnackbar('Erro', 'Falha ao restaurar compras');
    }
  }

  /// Manipula atualizações de compra
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      PurchaseLogger.info(
          'Processando compra: ${purchase.productID} - ${purchase.status}');

      // Completa compras pendentes
      if (purchase.pendingCompletePurchase) {
        await _completePurchase(purchase);
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchase.error);
          break;
        case PurchaseStatus.pending:
          _handlePendingPurchase(purchase);
          break;
        case PurchaseStatus.canceled:
          _handleCanceledPurchase();
          break;
      }
    }
  }

  /// Processa compra bem-sucedida
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    final type = _getPurchaseType(purchase.productID);
    if (type == null) return;

    // Atualiza status
    _updatePurchaseStatus(type, true);

    // Salva no storage
    _savePurchaseStatus(type, true);

    // Atualiza variáveis globais
    _updateGlobalVariables();

    status.value = PurchaseStateStatus.completed;

    // Navega para página de agradecimento
    final itemCode = type == PurchaseType.removeAds ? 1 : 2;
    Get.offNamed(RotasPaginas.thanks, arguments: [itemCode]);

    PurchaseLogger.info('Compra processada com sucesso: ${purchase.productID}');
  }

  /// Manipula erros de compra
  void _handlePurchaseError(IAPError? error) {
    if (error == null) return;

    String message = 'Erro na compra';

    switch (error.code) {
      case 'purchase_not_allowed':
        message = 'Compra não permitida. Verifique suas configurações.';
        break;
      case 'user_cancelled':
        message = 'Compra cancelada pelo usuário';
        break;
      case 'network_error':
        message = 'Erro de rede. Verifique sua conexão.';
        break;
      default:
        message = 'Erro na compra: ${error.message}';
    }

    PurchaseLogger.error('Erro de compra', error);
    _setError(message);
    _showSnackbar('Erro', message);
  }

  /// Manipula compra pendente
  void _handlePendingPurchase(PurchaseDetails purchase) {
    PurchaseLogger.info('Compra pendente: ${purchase.productID}');
    _showSnackbar('Info', 'Compra em processamento...');
  }

  /// Manipula compra cancelada
  void _handleCanceledPurchase() {
    status.value = PurchaseStateStatus.idle;
    PurchaseLogger.info('Compra cancelada pelo usuário');
  }

  /// Completa uma compra
  Future<void> _completePurchase(PurchaseDetails purchase) async {
    try {
      await _inAppPurchase.completePurchase(purchase);
      PurchaseLogger.info('Compra completada: ${purchase.productID}');
    } catch (e) {
      PurchaseLogger.error('Erro ao completar compra', e);
    }
  }

  /// Atualiza status interno da compra
  void _updatePurchaseStatus(PurchaseType type, bool purchased) {
    switch (type) {
      case PurchaseType.removeAds:
        hasRemovedAds.value = purchased;
        break;
      case PurchaseType.allApps:
        hasAllApps.value = purchased;
        break;
    }
  }

  /// Salva status no storage
  void _savePurchaseStatus(PurchaseType type, bool purchased) {
    final key = type == PurchaseType.removeAds ? 'ADS' : 'ALLAPPS';
    _storage.write(key, purchased ? 'Sim' : 'Não');
  }

  /// Atualiza variáveis globais
  void _updateGlobalVariables() {
    MyG.to.atualizarAposCompra(
      adsRemovidos: hasRemovedAds.value,
      todosApps: hasAllApps.value,
    );
  }

  /// Verifica se possui produto
  bool _hasProduct(PurchaseType type) {
    switch (type) {
      case PurchaseType.removeAds:
        return hasRemovedAds.value;
      case PurchaseType.allApps:
        return hasAllApps.value;
    }
  }

  /// Define estado de erro
  void _setError(String message) {
    status.value = PurchaseStateStatus.error;
    errorMessage.value = message;
  }

  /// Mostra snackbar
  void _showSnackbar(String title, String message) {
    Get.snackbar(title, message);
  }

  // Getters de conveniência
  bool get isLoading => status.value == PurchaseStateStatus.loading;
  bool get isPurchasing => status.value == PurchaseStateStatus.purchasing;
  bool get isRestoring => status.value == PurchaseStateStatus.restoring;
  bool get hasError => status.value == PurchaseStateStatus.error;
  bool get isIdle => status.value == PurchaseStateStatus.idle;

  List<PurchaseProduct> get purchasableProducts {
    return availableProducts
        .where((product) => !_hasProduct(product.type))
        .toList();
  }
}
