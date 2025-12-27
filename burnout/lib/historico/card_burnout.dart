import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../historico/teste_model.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/rota_imagens.dart';

class CardBurnout extends StatelessWidget {
  final TesteModel teste;

  const CardBurnout({super.key, required this.teste});

  // ✅ margens seguras (sem null check)
  double _m(String key, double fallback) {
    final v = MyG.to.margens[key];
    if (v == null) return fallback;
    return v.toDouble();
  }

  Color _cardColorForTotal(double points) {
    if (points <= 24) {
      return Colors.amber.shade50;
    }
    if (points <= 48) {
      return Colors.amber.shade100;
    }
    return Colors.amber.shade300;
  }

  String _globalTitleForTotal(double points) {
    if (points <= 24) return "burn_res_low_title".tr;
    if (points <= 48) return "burn_res_mod_title".tr;
    return "burn_res_high_title".tr;
  }

  double _parseNum(String? s) => double.tryParse((s ?? '').trim()) ?? 0.0;

  // lê "t=40;ex=14;dis=7;real=11" (ou variações)
  double? _extractKvpNum(String source, String key) {
    final r = RegExp('$key\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)');
    final m = r.firstMatch(source);
    if (m != null && m.groupCount >= 1) {
      return _parseNum(m.group(1));
    }
    return null;
  }

  // normaliza se vier só "40" (antigo)
  Map<String, double> _readPayload(String raw) {
    final s = raw.trim();

    final double? t = _extractKvpNum(s, 't');
    final double? ex = _extractKvpNum(s, 'ex');
    final double? dis = _extractKvpNum(s, 'dis');
    final double? real = _extractKvpNum(s, 'real');

    // ✅ novo formato
    if (t != null || ex != null || dis != null || real != null) {
      return {
        "t": (t ?? 0.0).clamp(0.0, 72.0),
        "ex": (ex ?? 0.0).clamp(0.0, 24.0),
        "dis": (dis ?? 0.0).clamp(0.0, 24.0),
        "real": (real ?? 0.0).clamp(0.0, 24.0),
      };
    }

    // ✅ formato antigo (só total)
    final double total = _parseNum(s).clamp(0.0, 72.0);
    return {
      "t": total,
      "ex": 0.0,
      "dis": 0.0,
      "real": 0.0,
    };
  }

  int _pct(double value, double max) {
    if (max <= 0) return 0;
    return ((value / max) * 100).round().clamp(0, 100);
  }

  Widget _bar({
    required double value,
    required double max,
    required double radius,
  }) {
    final frac = (max <= 0) ? 0.0 : (value / max).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: LinearProgressIndicator(
        value: frac,
        minHeight: 10,
        backgroundColor: Colors.black.withOpacity(0.06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad05 = _m('margem05', 12);
    final pad03 = _m('margem03', 8);
    final pad02 = _m('margem02', 6);

    final font085 = _m('margem085', 18);
    final font075 = _m('margem075', 14);
    final font065 = _m('margem065', 12);

    final radius = ThemeTokens.radiusLarge;

    final data = teste.data;
    final payload = _readPayload(teste.historico);

    final double t = payload["t"] ?? 0.0;
    final double ex = payload["ex"] ?? 0.0;
    final double dis = payload["dis"] ?? 0.0;
    final double real = payload["real"] ?? 0.0;

    final Color cardColor = _cardColorForTotal(t);
    final String globalTitle = _globalTitleForTotal(t);

    final int pctTotal = _pct(t, 72);
    final int pctEx = _pct(ex, 24);
    final int pctDis = _pct(dis, 24);
    final int pctReal = _pct(real, 24);

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: pad05*3,
          vertical: pad05,
        ),
        child: Column(
          children: [
            // data
            Padding(
              padding: EdgeInsets.only(bottom: pad05),
              child: Text(
                data,
                style: TextStyle(
                  fontSize: font075,
                  color: Colors.brown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      RotaImagens.logoBurnout,
                      height: 34,
                      width: 34,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: pad05),
                    Text(
                      "_tBurnout".tr,
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.w800,
                        fontSize: font085,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$pctTotal%",
                  style: TextStyle(
                    color: Colors.brown,
                    fontWeight: FontWeight.w900,
                    fontSize: font085,
                  ),
                ),
              ],
            ),

            SizedBox(height: pad05),

            // total
            _bar(value: t, max: 72, radius: radius),
            SizedBox(height: pad03),
            Center(
              child: Text(
                globalTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: font075,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${t.toInt()}/72",
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: font065,
                ),
              ),
            ),

            SizedBox(height: pad05),

            // dimensões (compacto)
            _miniRow(
              title: "burn_dim_ex_title".tr,
              pct: pctEx,
              pad02: pad02,
              pad03: pad03,
              font065: font065,
              child: _bar(value: ex, max: 24, radius: radius),
            ),
            _miniRow(
              title: "burn_dim_dis_title".tr,
              pct: pctDis,
              pad02: pad02,
              pad03: pad03,
              font065: font065,
              child: _bar(value: dis, max: 24, radius: radius),
            ),
            _miniRow(
              title: "burn_dim_real_title".tr,
              pct: pctReal,
              pad02: pad02,
              pad03: pad03,
              font065: font065,
              child: _bar(value: real, max: 24, radius: radius),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniRow({
    required String title,
    required int pct,
    required double pad02,
    required double pad03,
    required double font065,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: pad03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.brown,
                    fontWeight: FontWeight.w700,
                    fontSize: font065,
                  ),
                ),
              ),
              Text(
                "$pct%",
                style: TextStyle(
                  color: Colors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: font065,
                ),
              ),
            ],
          ),
          SizedBox(height: pad02),
          child,
        ],
      ),
    );
  }
}
