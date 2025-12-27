import 'package:flutter/material.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/margens_constantes.dart';

class Reuse {
  static double get margem => MyG.to.margem;

  static SizedBox myHeightBox(double height) => SizedBox(height: height);
  static TextStyle myFontSize(double fontSize) => TextStyle(fontSize: fontSize);
  static SizedBox myWidthBox(double width) => SizedBox(width: width);

  static SizedBox get myHeigthBox025 => MargensConstantes.heightBox5;
  static SizedBox get myHeigthBox050 => MargensConstantes.heightBox10;
  static SizedBox get myHeigthBox1 => MargensConstantes.heightBox10;
  static SizedBox get myHeigthBox1_5 => MargensConstantes.heightBox15;
  static SizedBox get myHeigthBox2 => MargensConstantes.heightBox20;
  static SizedBox get myHeigthBox3 => MargensConstantes.heightBox30;

  static SizedBox get myWidthBox025 => MargensConstantes.widthBox5;
  static SizedBox get myWidthBox050 => MargensConstantes.widthBox10;
  static SizedBox get myWidthBox1 => MargensConstantes.widthBox10;
  static SizedBox get myWidthBox1_5 => MargensConstantes.widthBox15;

  static TextStyle get myFontSize050 => myFontSize(MyG.to.margens['margem05']!);
  static TextStyle get myFontSize075 =>
      myFontSize(MyG.to.margens['margem075']!);
  static TextStyle get myFontSize085 =>
      myFontSize(MyG.to.margens['margem085']!);
  static TextStyle get myFontSize095 =>
      myFontSize(MyG.to.margens['margem095']!);
  static TextStyle get myFontSize1 => myFontSize(MyG.to.margens['margem1']!);

  static const mySombraContainer = BoxDecoration(
    boxShadow: MargensConstantes.sombraMedia,
  );

  static TextStyle get myTitulo => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: MyG.to.margens['margem085']!,
      );

  static Icon get myIconUndo =>
      Icon(Icons.undo, color: Colors.orange, size: MyG.to.margens['margem1']!);

  static Image get myImagemAdsOn =>
      Image.asset(RotaImagens.adsOn, height: MyG.to.margens['margem1_5']!);

  static Image get myAdsOffIcon =>
      Image.asset(RotaImagens.adsOff, height: MyG.to.margens['margem1_5']!);

  static Icon get myHelpIcon => Icon(
        Icons.help_outlined,
        color: Colors.orange,
        size: MyG.to.margens['margem1_25']!,
      );

  static const Widget myDivider = MargensConstantes.divisor;

  static TextStyle get myTextIntro => TextStyle(
        fontSize: MyG.to.margens['margem085']!,
        fontWeight: FontWeight.bold,
      );
}
