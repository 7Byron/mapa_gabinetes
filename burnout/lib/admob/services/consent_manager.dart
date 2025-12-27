//...admob/consent_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/ad_logger.dart';

class ConsentManager {
  Future<bool> _computeConsentGiven(ConsentInformation info) async {
    // Usamos canRequestAds como proxy de que o sinal de consentimento é suficiente
    // para pedidos de anúncios (personalizados quando aplicável).
    return await info.canRequestAds();
  }

  // Verifica se o consentimento é necessário (EEA/UK) e atualiza a flag local.
  // Retorna true quando é necessário mostrar formulário; false caso contrário.
  Future<bool> isConsentRequired() async {
    final consentInfo = ConsentInformation.instance;
    final box = GetStorage();

    final completer = Completer<bool>();
    // Em debug, força geografia EEA para testar o formulário no emulador
    final params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
      ),
    );
    consentInfo.requestConsentInfoUpdate(
      kDebugMode ? params : ConsentRequestParameters(),
      () async {
        // Após atualizar, decidimos com base na capacidade de requisitar ads
        // Se já podemos requisitar anúncios, o consentimento não é necessário.
        final needed = !(await consentInfo.canRequestAds());
        if (!needed) {
          box.write('isConsentShown', true);
          box.write('isConsentGiven', await _computeConsentGiven(consentInfo));
          AdLogger.info(
              'Consent', 'Consentimento não é necessário (fora EEA/UK)');
        } else {
          // Em regiões que requerem consentimento, garantir que a UI mostre o formulário
          box.write('isConsentShown', false);
          box.write('isConsentGiven', false);
        }
        if (!completer.isCompleted) completer.complete(needed);
      },
      (error) {
        // Em caso de erro, não bloqueamos a app: consideramos não necessário
        AdLogger.error('Consent', 'Erro ao atualizar: ${error.message}');
        box.write('isConsentShown', true);
        // Conservador: sem decisão explícita, tratamos como não dado (NPA)
        box.write('isConsentGiven', false);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    return completer.future;
  }

  Future<void> showGDPRConsentForm() async {
    final consentInfo = ConsentInformation.instance;
    final box = GetStorage();
    final completer = Completer<void>();

    // Em debug, força geografia EEA para testar o formulário no emulador
    final params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
      ),
    );
    consentInfo.requestConsentInfoUpdate(
      kDebugMode ? params : ConsentRequestParameters(),
      () async {
        try {
          // Só mostra se realmente for necessário
          final needForm = !(await consentInfo.canRequestAds());
          final isAvailable = await consentInfo.isConsentFormAvailable();
          if (needForm && isAvailable) {
            ConsentForm.loadConsentForm(
              (consentForm) => consentForm.show((error) async {
                if (error == null) {
                  AdLogger.success(
                      'Consent', 'Consentimento atualizado com sucesso');
                }
                box.write('isConsentShown', true);
                // Após o form, consultar novamente se já podemos requisitar anúncios
                box.write('isConsentGiven', await _computeConsentGiven(consentInfo));
                if (!completer.isCompleted) completer.complete();
              }),
              (loadError) {
                AdLogger.error(
                    'Consent', 'Erro no formulário: ${loadError.message}');
                box.write('isConsentShown', true);
                // Conservador no erro de load: NPA
                box.write('isConsentGiven', false);
                if (!completer.isCompleted) completer.complete();
              },
            );
          } else {
            // Não necessário: marcar como resolvido
            box.write('isConsentShown', true);
            box.write('isConsentGiven', await _computeConsentGiven(consentInfo));
            if (!completer.isCompleted) completer.complete();
          }
        } catch (e) {
          AdLogger.error('Consent', 'Exceção ao lidar com formulário: $e');
          box.write('isConsentShown', true);
          box.write('isConsentGiven', false);
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        AdLogger.error('Consent', 'Erro no consentimento: ${error.message}');
        box.write('isConsentShown', true);
        box.write('isConsentGiven', false);
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }
}
