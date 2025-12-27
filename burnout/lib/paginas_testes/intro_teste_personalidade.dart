import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/internet_site_mail.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../funcoes/theme_tokens.dart';

class IntroTestePersonalidade extends StatefulWidget {
  const IntroTestePersonalidade({super.key});

  @override
  State<IntroTestePersonalidade> createState() =>
      _IntroTestePersonalidadeState();
}

class _IntroTestePersonalidadeState extends State<IntroTestePersonalidade> {
  bool ads = MyG.to.adsPago;

  @override
  void initState() {
    super.initState();
    if (!ads) {
      Future.microtask(() => AdManager.to.loadInterstitialAd());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
          image: RotaImagens.logoPersonalidade, titulo: "_tPersonalidade".tr),
      drawer: const MyDrawer(),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: MyG.to.margens['margem22']!,
            padding: EdgeInsets.all(MyG.to.margens['margem025']!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Reuse.myHeigthBox050,
                _buildIntroCard(),
                _buildOceanPresentations(),
                _buildCreditsCard(),
                _buildEscolhaCard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Widget _buildIntroCard() {
    return _buildCard(
      children: [
        AutoSizeText(
          "int_tracos_t".tr,
          style: _textStyleTitulo(),
          maxLines: 1,
        ),
        Divider(
          height: MyG.to.margem,
          thickness: 2,
          //color: Colors.brown,
        ),
        Text(
          "int_tracos".tr,
          textAlign: TextAlign.center,
          style: _textStyleExplicacao(),
        ),
      ],
    );
  }

  Widget _buildOceanPresentations() {
    return Column(
      children: [
        _buildOceanCard(
            "h-intro_tit".tr, "", "h-intro".tr, RotaImagens.perIntro),
        _buildOceanCard(
            "5_o".tr, RotaImagens.per1A, "h-o".tr, RotaImagens.per5Aberto),
        _buildOceanCard("5_c".tr, RotaImagens.per2C, "h-c".tr,
            RotaImagens.per2Consciencioso),
        _buildOceanCard("5_e".tr, RotaImagens.per3E, "h-e".tr,
            RotaImagens.per3Extrovertido),
        _buildOceanCard(
            "5_a".tr, RotaImagens.per4N, "h-a".tr, RotaImagens.per1Amavel),
        _buildOceanCard(
            "5_n".tr, RotaImagens.per5A, "h-n".tr, RotaImagens.per4Neurotica),
      ],
    );
  }

  Widget _buildCreditsCard() {
    return _buildCard(
      children: [
        SizedBox(
          height: MyG.to.margens['margem2']!,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCreditsLink(
                  "Credits Sprouts Schools", Variaveis.sproutsschoolsSite),
              const Text(" "),
              _buildCreditsLink("(video)", Variaveis.ilustVideo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEscolhaCard() {
    return _buildCard(
      children: [
        Text(
          "h_esc".tr,
          textAlign: TextAlign.center,
          style: _textStyleTitulo(),
        ),
        const Divider(),
        _buildEscolhaButton("5_o".tr, Colors.cyan.shade100),
        _buildEscolhaButton("5_c".tr, Colors.green.shade100),
        _buildEscolhaButton("5_e".tr, Colors.yellow.shade100),
        _buildEscolhaButton("5_a".tr, Colors.orange.shade100),
        _buildEscolhaButton("5_n".tr, Colors.brown.shade100),
        Text(
          "escolha".tr,
          style: TextStyle(
            fontSize: MyG.to.margens['margem065']!,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0), // Bordas arredondadas
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Mesmo borderRadius
        ),
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildOceanCard(
      String titulo, String icon, String texto, String imagem) {
    return _buildCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: _textStyleTitulo(),
            ),
            if (icon.isNotEmpty)
              Image.asset(icon, height: MyG.to.margens['margem3']!),
          ],
        ),
        const Divider(),
        Text(
          texto,
          style: _textStyleExplicacao(),
        ),
        Reuse.myHeigthBox050,
        Image.asset(imagem),
      ],
    );
  }

  Future<void> _onEscolhaPressed(String titulo) async {
    if (!ads) {
      // Verifica se há anúncio disponível antes de tentar mostrar
      if (AdManager.to.hasInterstitialAd) {
        AdManager.to.showInterstitialAd();
      } else {
        // Se não há anúncio disponível, tenta carregar e aguardar
        await AdManager.to.loadInterstitialAd();
        // Aguarda até 2 segundos para o anúncio carregar
        int attempts = 0;
        while (!AdManager.to.hasInterstitialAd && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        if (AdManager.to.hasInterstitialAd) {
          AdManager.to.showInterstitialAd();
        }
      }
    }
    Get.offNamed(RotasPaginas.testePersonalidade, arguments: titulo);
  }

  Widget _buildEscolhaButton(String titulobotao, Color corbotao) {
    return Column(
      children: [
        SizedBox(
          width: Get.width * .8,
          height: MyG.to.margens['margem2']!,
          child: ElevatedButton(
            onPressed: () => _onEscolhaPressed(titulobotao),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: EdgeInsets.all(MyG.to.margens['margem01']!),
              backgroundColor: corbotao,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall)),
            ),
            child: AutoSizeText(
              titulobotao,
              style: TextStyle(
                color: Colors.brown,
                fontSize: MyG.to.margens['margem085']!,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
            ),
          ),
        ),
        Reuse.myHeigthBox050,
      ],
    );
  }

  InkWell _buildCreditsLink(String text, String url) {
    return InkWell(
      onTap: () => SiteMail().siteEmail(url),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue,
          fontSize: MyG.to.margens['margem065']!,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  TextStyle _textStyleTitulo() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.brown
          : Colors.white,
      fontSize: MyG.to.margens['margem095']!.clamp(8.0, 18.0),
      fontWeight: FontWeight.bold,
    );
  }

  TextStyle _textStyleExplicacao() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.brown
          : Colors.white,
      fontSize: MyG.to.margens['margem085']!.clamp(8.0, 18.0),
    );
  }
}
