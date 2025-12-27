import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../funcoes/rota_imagens.dart';
import '../funcoes/responsive.dart';

class RealNetworkController extends GetxController {
  static RealNetworkController get to => Get.find<RealNetworkController>();

  late final StreamSubscription _connectivitySub;
  final RxBool isDialogOpen = false.obs;
  final RxBool isConnected = true.obs;

  @override
  void onInit() {
    super.onInit();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((_) => _probeAndUpdate());

    _checkConnectionOnStart();
  }

  Future<void> _checkConnectionOnStart() async {
    await _probeAndUpdate();
  }

  Future<void> _probeAndUpdate() async {
    final ok = await _hasInternet();
    isConnected.value = ok;
    if (!ok) {
      _showNoConnectionDialog();
    } else {
      _closeDialogIfOpen();
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final resp = await http
          .head(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  void _showNoConnectionDialog() {
    if (!isDialogOpen.value) {
      isDialogOpen.value = true;

      Get.dialog(
        Center(
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: SizedBox(
              width: 250,
              height: 400,
              child: Card(
                color: Colors.amber.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80.0,
                      child: Image.asset(RotaImagens.logoApp),
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    const Text(
                      "Byron System Developer",
                      style: TextStyle(
                        color: Colors.brown,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    const Divider(),
                    Text(
                      "Internet: OFF",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: ResponsiveConfig.of(Get.context!)
                            .clampFont(ResponsiveConfig.of(Get.context!).font(18)),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(
                      height: 25,
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Icon(
                          Icons.signal_cellular_off,
                          color: Colors.orangeAccent,
                          size: 50.0,
                        ),
                        Icon(
                          Icons.wifi_off,
                          color: Colors.orangeAccent,
                          size: 50.0,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "  Reconnect  ",
                          style: TextStyle(
                            color: Colors.brown,
                            fontSize: ResponsiveConfig.of(Get.context!)
                                .clampFont(ResponsiveConfig.of(Get.context!).font(18)),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(
                          Icons.electrical_services,
                          color: Colors.brown,
                          size: 30.0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      ).then((_) {
        isDialogOpen.value = false;
      });
    }
  }

  void _closeDialogIfOpen() {
    if (isDialogOpen.value && Get.isDialogOpen == true) {
      Get.back();
      isDialogOpen.value = false;
    }
  }

  @override
  void onClose() {
    _connectivitySub.cancel();
    super.onClose();
  }
}
