import 'package:flutter/widgets.dart';
import 'variaveis_globais.dart';

class Spacing {
  static double get xs => MyG.to.margens['margem025']!;
  static double get s => MyG.to.margens['margem05']!;
  static double get m => MyG.to.margens['margem075']!;
  static double get l => MyG.to.margens['margem1']!;
  static double get xl => MyG.to.margens['margem1_25']!;
  static double get xxl => MyG.to.margens['margem2']!;

  static SizedBox get vxs => SizedBox(height: xs);
  static SizedBox get vs => SizedBox(height: s);
  static SizedBox get vm => SizedBox(height: m);
  static SizedBox get vl => SizedBox(height: l);
  static SizedBox get vxl => SizedBox(height: xl);
  static SizedBox get vxxl => SizedBox(height: xxl);

  static SizedBox get hxs => SizedBox(width: xs);
  static SizedBox get hs => SizedBox(width: s);
  static SizedBox get hm => SizedBox(width: m);
  static SizedBox get hl => SizedBox(width: l);
  static SizedBox get hxl => SizedBox(width: xl);
  static SizedBox get hxxl => SizedBox(width: xxl);
}

