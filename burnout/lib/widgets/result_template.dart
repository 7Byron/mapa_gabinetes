import 'package:flutter/material.dart';
import '../funcoes/custom_scaffold.dart';
import '../widgets/my_drawer.dart';
import 'my_app_bar_secundary.dart';
import '../admob/services/banner_ad_widget.dart';
import '../admob/services/native_ads_widget.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/lista_teste_unificada.dart';

class ResultPageTemplate extends StatelessWidget {
  final String appBarTitle;
  final String appBarImage;
  final Widget Function(BuildContext context) buildResultCard;
  final Widget Function(BuildContext context) buildInfoCard;
  final List<Widget> middleWidgets;
  final bool showNativeAd;

  const ResultPageTemplate({
    super.key,
    required this.appBarTitle,
    required this.appBarImage,
    required this.buildResultCard,
    required this.buildInfoCard,
    this.middleWidgets = const [],
    this.showNativeAd = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool ads = MyG.to.adsPago;
    return CustomScaffold(
      extendBody: true,
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: appBarImage,
        titulo: appBarTitle,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Center(
            child: SizedBox(
              width: MyG.to.margens['margem22']!,
              child: Column(
                children: <Widget>[
                  buildResultCard(context),
                  Reuse.myHeigthBox050,
                  ...middleWidgets,
                  if (!ads && showNativeAd) const NativeAdReuse(),
                  Reuse.myHeigthBox050,
                  buildInfoCard(context),
                  Reuse.myHeigthBox050,
                  const ListaTesteUnificada(isResultMode: true),
                ],
              ),
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
}
