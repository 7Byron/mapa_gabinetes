import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../admob/ad_manager.dart';

/// Classe para variáveis globais
/// - Margens: calculadas UMA VEZ na inicialização
/// - Compras: carregadas UMA VEZ na inicialização + atualizadas após compras
class MyG extends GetxController {
  static MyG get to => Get.find<MyG>();

  // Variáveis de compra
  bool adsPago = false;
  bool allApps = false;

  // Margens calculadas uma vez
  late final double margem;
  late final double margem01;
  late final double margem025;
  late final double margem030;
  late final double margem035;
  late final double margem05;
  late final double margem065;
  late final double margem075;
  late final double margem085;
  late final double margem095;
  late final double margem1;
  late final double margem1_25;
  late final double margem1_5;
  late final double margem2;
  late final double margem2_5;
  late final double margem3;
  late final double margem4;
  late final double margem5;
  late final double margem8;
  late final double margem10;
  late final double margem18;
  late final double margem22;

  // Mapa para código existente
  late final Map<String, double> margens;

  final GetStorage _storage = GetStorage();
  bool _margensCalculadas = false;

  /// Calcula margens uma única vez
  void calcularMargens(double valorInicial) {
    if (_margensCalculadas) return;

    // Define margem base
    margem = valorInicial;

    // Calcula margens com acesso direto
    margem01 = margem * 0.1;
    margem025 = margem * 0.25;
    margem030 = margem * 0.30;
    margem035 = margem * 0.35;
    margem05 = margem * 0.5;
    margem065 = margem * 0.65;
    margem075 = margem * 0.75;
    margem085 = margem * 0.85;
    margem095 = margem * 0.95;
    margem1 = margem * 1.0;
    margem1_25 = margem * 1.25;
    margem1_5 = margem * 1.5;
    margem2 = margem * 2.0;
    margem2_5 = margem * 2.5;
    margem3 = margem * 3.0;
    margem4 = margem * 4.0;
    margem5 = margem * 5.0;
    margem8 = margem * 8.0;
    margem10 = margem * 10.0;
    margem18 = margem * 18.0;
    margem22 = margem * 22.0;

    // Preenche Map para código existente
    margens = {
      "margem01": margem01,
      "margem025": margem025,
      "margem030": margem030,
      "margem035": margem035,
      "margem05": margem05,
      "margem065": margem065,
      "margem075": margem075,
      "margem085": margem085,
      "margem095": margem095,
      "margem1": margem1,
      "margem1_25": margem1_25,
      "margem1_5": margem1_5,
      "margem2": margem2,
      "margem2_5": margem2_5,
      "margem3": margem3,
      "margem4": margem4,
      "margem5": margem5,
      "margem8": margem8,
      "margem10": margem10,
      "margem18": margem18,
      "margem22": margem22,
    };

    _margensCalculadas = true;
  }

  /// Calcula margens usando o contexto atual (fallback seguro)
  void calcularMargensPorContexto(BuildContext context) {
    if (_margensCalculadas) return;

    final Size size = MediaQuery.sizeOf(context);
    final double width = size.width;
    final double height = size.height;
    final double aspectRatio = width / height;

    final double margemBase = width * 0.055; // Baseado na largura

    // Heurística simples para "phone" sem depender de Get.context!.isPhone
    final bool isPhone = width < 600;

    double margemCalculada = isPhone
        ? (aspectRatio > 1.8
            ? margemBase * 0.50
            : (aspectRatio > 1.6 ? margemBase * 0.75 : margemBase))
        : 26; // Tablet mantém fixo

    if (height < 650) {
      margemCalculada *= 0.75; // Redução extra para telas muito baixas
    } else if (height < 750) {
      margemCalculada *= 0.85; // Redução moderada
    }

    calcularMargens(double.parse(margemCalculada.toStringAsFixed(0)));
  }

  /// Garante margens calculadas e retorna a margem base
  double ensureMargem(BuildContext context) {
    if (!_margensCalculadas) {
      calcularMargensPorContexto(context);
    }
    return margem;
  }

  /// Garante margens calculadas e retorna o mapa completo
  Map<String, double> ensureMargens(BuildContext context) {
    if (!_margensCalculadas) {
      calcularMargensPorContexto(context);
    }
    return margens;
  }

  /// Carrega status das compras na inicialização
  void carregarStatusComprasInicial() {
    try {
      final dynamic adsValueRaw = _storage.read('ADS');
      final dynamic allAppsValueRaw = _storage.read('ALLAPPS');
      final String adsValue =
          adsValueRaw is bool ? (adsValueRaw ? 'Sim' : 'Não') : (adsValueRaw ?? 'Não');
      final String allAppsValue =
          allAppsValueRaw is bool ? (allAppsValueRaw ? 'Sim' : 'Não') : (allAppsValueRaw ?? 'Não');

      if (kDebugMode) {
        debugPrint('VARIAVEIS_GLOBAIS - Carregando status inicial...');
        debugPrint('VARIAVEIS_GLOBAIS - ADS GetStorage: $adsValue');
        debugPrint('VARIAVEIS_GLOBAIS - ALLAPPS GetStorage: $allAppsValue');
      }

      adsPago = adsValue == 'Sim';
      allApps = allAppsValue == 'Sim';

      if (kDebugMode) {
        debugPrint('VARIAVEIS_GLOBAIS - adsPago atribuído: $adsPago');
        debugPrint('VARIAVEIS_GLOBAIS - allApps atribuído: $allApps');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao carregar status inicial das compras: $e');
      }
      // Valores padrão em caso de erro
      adsPago = false;
      allApps = false;
    }

    // Sem overrides em debug: respeita somente o que está no storage/servidor
  }

  /// Atualiza após compra bem-sucedida
  void atualizarAposCompra({bool? adsRemovidos, bool? todosApps}) {
    bool mudou = false;
    final bool antesAdsPago = adsPago;

    if (kDebugMode) {
      debugPrint('VARIAVEIS_GLOBAIS - atualizarAposCompra chamado');
      debugPrint(
          'VARIAVEIS_GLOBAIS - adsRemovidos: $adsRemovidos, todosApps: $todosApps');
      debugPrint(
          'VARIAVEIS_GLOBAIS - Valores antes: adsPago=$adsPago, allApps=$allApps');
    }

    if (adsRemovidos != null && adsPago != adsRemovidos) {
      adsPago = adsRemovidos;
      _storage.write('ADS', adsRemovidos ? 'Sim' : 'Não');
      mudou = true;
      if (kDebugMode) {
        debugPrint('VARIAVEIS_GLOBAIS - ADS atualizado para: $adsPago');
      }
    }

    if (todosApps != null && allApps != todosApps) {
      allApps = todosApps;
      _storage.write('ALLAPPS', todosApps ? 'Sim' : 'Não');
      mudou = true;
      if (kDebugMode) {
        debugPrint('VARIAVEIS_GLOBAIS - ALLAPPS atualizado para: $allApps');
      }
    }

    // Força rebuild apenas se houve mudança
    if (mudou) {
      if (kDebugMode) {
        debugPrint(
            'VARIAVEIS_GLOBAIS - Chamando update() para notificar GetBuilders');
      }
      update(['compras']); // Notifica apenas os GetBuilder interessados no estado de compras
    }

    // Se os anúncios foram reativados (antes true -> agora false), inicializa AdManager
    try {
      if (antesAdsPago && adsPago == false) {
        if (Get.isRegistered<AdManager>()) {
          // Inicializa serviços de anúncios agora que voltaram a estar ativos
          // ignore: discarded_futures
          AdManager.to.initializeAndConfigure();
        }
      }
    } catch (_) {}

    if (kDebugMode) {
      debugPrint(
          'VARIAVEIS_GLOBAIS - Valores finais: adsPago=$adsPago, allApps=$allApps');
      debugPrint('VARIAVEIS_GLOBAIS - Storage ADS: ${_storage.read('ADS')}');
      debugPrint(
          'VARIAVEIS_GLOBAIS - Storage ALLAPPS: ${_storage.read('ALLAPPS')}');
    }
  }

  /// Verifica se uma funcionalidade premium está desbloqueada
  bool get isPremiumFeatureEnabled => adsPago || allApps;

  /// Status detalhado para debug
  Map<String, dynamic> get statusCompras => {
        'adsPago': adsPago,
        'allApps': allApps,
        'storageADS': _storage.read('ADS'),
        'storageALLAPPS': _storage.read('ALLAPPS'),
        'margensCalculadas': _margensCalculadas,
        'margemBase': _margensCalculadas ? margem : null,
        'timestamp': DateTime.now().toIso8601String(),
      };
}

/// Acesso direto às margens
extension MargemAccess on MyG {
  // Getters para migração gradual do código existente
  double get margin01 => margem01;
  double get margin025 => margem025;
  double get margin05 => margem05;
  double get margin1 => margem1;
  double get margin2 => margem2;
  double get margin3 => margem3;
  double get margin5 => margem5;

  // Métodos de conveniência
  double get smallSpacing => margem025;
  double get mediumSpacing => margem05;
  double get largeSpacing => margem1;
  double get extraLargeSpacing => margem2;
}
