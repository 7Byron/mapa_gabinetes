import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../admob/ad_manager.dart';
import '../admob/utils/ad_logger.dart';
import '../funcoes/variaveis_globais.dart';

class MyTitleExpanded extends StatefulWidget {
  const MyTitleExpanded({
    super.key,
    required this.titulo,
    required this.texto,
  });

  final String titulo;
  final String texto;

  @override
  MyTitleExpandedState createState() => MyTitleExpandedState();
}

class MyTitleExpandedState extends State<MyTitleExpanded> {
  final bool _ads = MyG.to.adsPago;
  int _tapCount = 0;

  Future<void> _handleTap() async {
    if (_ads) return;

    try {
      if (_tapCount == 0) {
        await AdManager.to.loadInterstitialAd();
      }

      if (++_tapCount >= 3) {
        AdManager.to.showInterstitialAd();
        _tapCount = 0;
      }
    } catch (e) {
      AdLogger.error('ExpansionTile', 'Error showing ad: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData noDividerTheme = Theme.of(context).copyWith(
      dividerColor: Colors.transparent,
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
    );

    return Column(children: <Widget>[
      Padding(
        padding: EdgeInsets.only(top: MyG.to.margens['margem05']!),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0), // Bordas arredondadas
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior:
              Clip.antiAlias, // Garante que a sombra siga o borderRadius
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0), // Mesmo borderRadius
            ),
            child: Theme(
              data: noDividerTheme,
              child: ExpansionTile(
                onExpansionChanged: (_) {
                  if (!_ads) _handleTap();
                },
                title: AutoSizeText(
                  widget.titulo,
                  maxLines: 1,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.brown
                        : Colors.white,
                    fontSize: MyG.to.margens['margem085']!,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                    child: Text(
                      widget.texto,
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.brown
                            : Colors.white,
                        fontSize: MyG.to.margens['margem075']!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
