import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../a_config_app/lista_testes.dart';
import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';
import '../admob/services/native_ads_widget.dart';

import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/botao_imagem.dart';
import '../widgets/expanded_title.dart';
import '../widgets/internet_site_mail.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../funcoes/custom_scaffold.dart';
import '../widgets/my_drawer.dart';

class Conselhos extends StatefulWidget {
  const Conselhos({super.key});

  @override
  State<Conselhos> createState() => _ConselhosState();
}

class _ConselhosState extends State<Conselhos> {
  late final bool ads = MyG.to.adsPago;
  // static const String newStart = "https://newstart.com/newstart-now/";
  // static const String byronSdHealty = "https://www.byronsd.com/2021/08/healthy-lifestyle.html";

  @override
  void dispose() {
    super.dispose();
    if (!ads) {
      try {
        // Verifica se há anúncio disponível antes de tentar mostrar
        if (AdManager.to.hasInterstitialAd) {
          AdManager.to.showInterstitialAd();
        }
        // Não aguardamos carregamento no dispose, pois a página está sendo fechada
      } catch (e) {
        // Ignorado: ambiente web pode não ter plugin
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoApp,
        titulo: "conselhos".tr,
      ),
      drawer: const MyDrawer(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(MyG.to.margens['margem05']!),
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            child: Column(
              children: [
                _buildCard(context),
                Reuse.myHeigthBox050,
                _buildAutoSizeText(),
                Reuse.myHeigthBox050,
                const Divider(
                  height: 8,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey,
                ),

                ///Links abaixo servem para ser aprovado pelo IOS o teste de depressao.
                if (ListaTeste.nomeApp == "_tDepressao".tr)
                  _buildCitationsSection(),
                // Anúncio nativo após o título "Tips for a Healthy Lifestyle" e antes da primeira caixa "Good Sleep"
                if (!ads) const NativeAdReuse(),
                Reuse.myHeigthBox050,
                _buildTitles(),
                Reuse.myHeigthBox050,
                _buildRemainingTitles(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads
          ? Reuse.myHeigthBox1_5
          : const BannerAdWidget(
              collapsible: true, // Banner collapsible (recomendação AdMob)
            ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      decoration: Reuse.mySombraContainer,
      child: Card(
        color: Theme.of(context).canvasColor,
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(
            children: [
              Text(
                "help_me".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: MyG.to.margens['margem075']!,
                  fontWeight: FontWeight.normal,
                ),
              ),
              _buildHelpButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem1']!),
      child: MyBotaoImagem(
        onPressed: () => SiteMail().siteEmail(Variaveis.appChat),
        titulo: "appChat".tr,
        imagem: RotaImagens.logoHelpMe,
      ),
    );
  }

  Widget _buildAutoSizeText() {
    return AutoSizeText(
      "conselhos2".tr,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: MyG.to.margens['margem085']!,
        fontWeight: FontWeight.bold,
      ),
      maxLines: MyG.to.margem < 30 ? 2 : 1,
      maxFontSize: (MyG.to.margem * 1.2).toInt().toDouble(),
    );
  }

  Widget _buildTitles() {
    return Column(
      children: [
        _buildTitle("C1t",
            ["C1", "C1a", "C1b", "C1c", "C1d", "C1e", "C1f", "C1g", "C1h"]),
        _buildTitle("C2t", ["C2", "C2a", "C2b"]),
      ],
    );
  }

  Widget _buildRemainingTitles() {
    return Column(
      children: [
        _buildTitle(
            "C3t", ["C3", "C3a", "C3b", "C3c", "C3d", "C3e", "C3f", "C3g"]),
        _buildTitle("C4t", ["C4"]),
        _buildTitle("C5t", ["C5"]),
        _buildTitle("C6t", ["C6"]),
        _buildTitle("C7t", ["C7"]),
        _buildTitle("C8t", ["C8", "C8a"]),
        _buildTitle("C9t", ["C9"]),
        _buildTitle("C10t", ["C10", "C10a", "C10b", "C10c", "C10d"]),
        _buildTitle("C11t", ["C11", "C11a", "C11b", "C11c", "C11d", "C11e"]),
      ],
    );
  }

  Widget _buildTitle(String tituloKey, List<String> contentKeys) {
    final content = contentKeys.map((key) => key.tr).join("\n");
    return MyTitleExpanded(
      titulo: tituloKey.tr,
      texto: content,
    );
  }

  Widget _buildCitationsSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: MyG.to.margens['margem1']!),
      child: Column(
        children: [
          AutoSizeText(
            "citacoes_titulo".tr,
            style: TextStyle(
              fontSize: MyG.to.margens['margem075']!,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          Reuse.myHeigthBox050,
          _buildCitationLink(
            Variaveis.healthyLifestyleTips,
            "citacao_byronsd".tr,
          ),
          _buildCitationLink(
            Variaveis.whoMentalHealth,
            "citacao_who".tr,
          ),
          _buildCitationLink(
            Variaveis.mayoClinicDepression,
            "citacao_mayo".tr,
          ),
        ],
      ),
    );
  }

  Widget _buildCitationLink(String url, String title) {
    return Padding(
      padding: EdgeInsets.only(top: MyG.to.margens['margem025']!),
      child: GestureDetector(
        onTap: () => SiteMail().siteEmail(url),
        child: AutoSizeText(
          title,
          style: TextStyle(
            color: Colors.blue,
            fontSize: MyG.to.margens['margem065']!,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue,
            decorationThickness: 1,
          ),
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
