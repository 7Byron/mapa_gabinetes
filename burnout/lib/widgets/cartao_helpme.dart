import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis.dart';
import '../funcoes/variaveis_globais.dart';
import 'botao_icon.dart';
import 'botao_imagem.dart';
import 'internet_site_mail.dart';
import 'itens_reutilizaveis.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/spacing.dart';

class CartaoHelpMe extends StatelessWidget {
  final bool ads = MyG.to.adsPago;

  CartaoHelpMe({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: MyG.to.margens['margem05']!),
      child: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10.0,
            ),
          ],
        ),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
          ),
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.amber.shade100
              : Colors.black87,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.xs),
            child: Column(
              children: [
                Reuse.myHeigthBox050,
                _buildButton(
                  context,
                  onPressed: () {
                    Get.toNamed(RotasPaginas.conselhos);
                  },
                  linhas: 3,
                  icon: Icons.receipt_long_outlined,
                  title: "conselhos2".tr,
                ),
                Reuse.myHeigthBox025,
                _buildButton(
                  context,
                  onPressed: () {
                    Get.toNamed(RotasPaginas.historico);
                  },
                  linhas: 1,
                  icon: Icons.badge_outlined,
                  title: "v_hist".tr,
                ),
                Reuse.myHeigthBox025,
              _buildHelpMeCard(context),
                Reuse.myWidthBox050,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required void Function() onPressed,
    required int linhas,
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
      child: MyBotaoIcon(
        onPressed: onPressed,
        linhas: linhas,
        myIcon: icon,
        titulo: title,
      ),
    );
  }

  Widget _buildHelpMeCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margens['margem05']!),
        child: Column(
          children: [
            Text(
              "help_me".tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.brown,
                fontSize: MyG.to.margens['margem075']!,
                fontWeight: FontWeight.normal,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
              child: MyBotaoImagem(
                onPressed: () {
                  SiteMail().siteEmail(Variaveis.appChat);
                },
                titulo: "appChat".tr,
                imagem: RotaImagens.logoHelpMe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
