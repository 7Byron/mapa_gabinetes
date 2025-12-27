import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../funcoes/responsive.dart';

class AgravantesStress extends StatefulWidget {
  const AgravantesStress({super.key});

  @override
  State<AgravantesStress> createState() => _AgravantesStressState();
}

class _AgravantesStressState extends State<AgravantesStress> {
  final box = GetStorage();
  bool ads = MyG.to.adsPago;
  // ✅ CORRIGIDO: Valores padrão se não houver argumentos
  double _sumValores = Get.arguments != null ? Get.arguments[0] as double : 0.0;
  final List<int> _grupos = Get.arguments != null
      ? Get.arguments[1] as List<int>
      : [0, 0, 0, 0, 0, 0];

  int _valorIdade = 99;
  int _valorEstCivil = 99;
  int _valorResid = 99;
  int _valorFilhos = 99;
  int _valorVinc = 99;

  String _selectIdade = "0";
  String _selectEstCivil = "0";
  String _selectResid = "0";
  String _selectFilhos = "0";
  String _selectVinculo = "0";
  String _msgErro = "Sem Erro";

  void _onDropdownChanged(String value, String type) {
    switch (type) {
      case 'idade':
        _selectIdade = value;
        _valorIdade = _getValueForDropdown(
            value, {'0': 99, '1': 0, '2': 2, '3': 3, '4': 0});
        break;
      case 'estadoCivil':
        _selectEstCivil = value;
        _valorEstCivil =
            _getValueForDropdown(value, {'0': 99, '1': 0, '2': 0, '3': 3});
        break;
      case 'residencia':
        _selectResid = value;
        _valorResid =
            _getValueForDropdown(value, {'0': 0, '1': 0, '2': 2, '3': 3});
        break;
      case 'filhos':
        _selectFilhos = value;
        _valorFilhos =
            _getValueForDropdown(value, {'0': 99, '1': 0, '2': 2, '3': 3});
        break;
      case 'vinculo':
        _selectVinculo = value;
        _valorVinc = _getValueForDropdown(
            value, {'0': 99, '1': 0, '2': 3, '3': 2, '4': 0});
        break;
    }
  }

  int _getValueForDropdown(String value, Map<String, int> valuesMap) {
    return valuesMap[value] ?? 99;
  }

  Padding _buildDropdownWithPadding(
      String currentValue, List<Map<String, dynamic>> items, String type) {
    final r = ResponsiveConfig.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          MyG.to.margens['margem2']!,
          MyG.to.margens['margem030']!,
          MyG.to.margens['margem2']!,
          MyG.to.margens['margem030']!),
      child: DropdownButton<String>(
        style: TextStyle(
          fontSize: r.clampFont(r.font(16)),
          color: Theme.of(context).textTheme.bodyMedium!.color,
        ),
        items: items
            .map((item) => _buildDropdownMenuItem(item['value'], item['title']))
            .toList(),
        isExpanded: true,
        hint: Text(
          items[0]['title'],
          style: TextStyle(
            fontSize: r.clampFont(r.font(16)),
            color: Theme.of(context)
                .textTheme
                .bodyMedium!
                .color
                ?.withValues(alpha: 0.8),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _onDropdownChanged(value!, type);
          });
        },
        value: currentValue,
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownMenuItem(String value, String title) {
    final r = ResponsiveConfig.of(context);
    return DropdownMenuItem<String>(
      value: value,
      child: AutoSizeText(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge!.color,
          fontSize: r.clampFont(r.font(16)),
        ),
        maxLines: 1,
      ),
    );
  }

  final List<Map<String, dynamic>> _idadeItems = [
    {'value': "0", 'title': "* ${"Ag_id1".tr}"},
    {'value': "1", 'title': "Ag_id2".tr},
    {'value': "2", 'title': "Ag_id3".tr},
    {'value': "3", 'title': "Ag_id4".tr},
    {'value': "4", 'title': "Ag_id5".tr},
  ];

  final List<Map<String, dynamic>> _estadoCivilItems = [
    {'value': "0", 'title': "* ${"Ag_ec1".tr}"},
    {'value': "1", 'title': "Ag_ec2".tr},
    {'value': "2", 'title': "Ag_ec3".tr},
    {'value': "3", 'title': "Ag_ec4".tr},
  ];

  final List<Map<String, dynamic>> _residenciaItems = [
    {'value': "0", 'title': "* ${"Ag_red1".tr}"},
    {'value': "1", 'title': "Ag_red2".tr},
    {'value': "2", 'title': "Ag_red3".tr},
    {'value': "3", 'title': "Ag_red4".tr},
  ];

  final List<Map<String, dynamic>> _filhosCasaItems = [
    {'value': "0", 'title': "* ${"Ag_fc1".tr}"},
    {'value': "1", 'title': "Ag_fc2".tr},
    {'value': "2", 'title': "Ag_fc3".tr},
    {'value': "3", 'title': "Ag_fc4".tr},
  ];

  final List<Map<String, dynamic>> _vinculoItems = [
    {'value': "0", 'title': "* ${"Ag_trb1".tr}"},
    {'value': "1", 'title': "Ag_trb2".tr},
    {'value': "2", 'title': "Ag_trb3".tr},
    {'value': "3", 'title': "Ag_trb4".tr},
    {'value': "4", 'title': "Ag_trb5".tr},
  ];

  Future<void> _validarDados() async {
    if (Platform.isAndroid) {
      _msgErro = _validarDadosComum();
    } else if (Platform.isIOS) {
      _valorVinc = _valorVinc == 99 ? 2 : _valorVinc;
      _valorFilhos = _valorFilhos == 99 ? 2 : _valorFilhos;
      _valorResid = _valorResid == 99 ? 2 : _valorResid;
      _valorEstCivil = _valorEstCivil == 99 ? 2 : _valorEstCivil;
      _valorIdade = _valorIdade == 99 ? 2 : _valorIdade;
    } else {
      _msgErro = _validarDadosComum();
    }

    if (_msgErro == "Sem Erro") {
      _sumValores += _valorIdade +
          _valorVinc +
          _valorFilhos +
          _valorResid +
          _valorEstCivil;
      await _gravarHistorico();
    } else {
      _mostrarErro();
    }
  }

  String _validarDadosComum() {
    if (_valorVinc == 99) return "Err_vinlab".tr;
    if (_valorFilhos == 99) return "Err_fil".tr;
    if (_valorResid == 99) return "Err_res".tr;
    if (_valorEstCivil == 99) return "Err_estciv".tr;
    if (_valorIdade == 99) return "Err_ida".tr;
    return "Sem Erro";
  }

  Future<void> _gravarHistorico() async {
    HistoricOperator().gravarHistorico(
      "str",
      "${_sumValores.toInt()}#a${_grupos[0]}b${_grupos[1]}c${_grupos[2]}d${_grupos[3]}e${_grupos[4]}f${_grupos[5]}g",
    );

    if (ads) {
      Get.offNamed(
        RotasPaginas.resultadoTesteStress,
        arguments: [_sumValores.toInt(), _grupos],
      );
    } else {
      // Se o anúncio não estiver carregado, tenta carregar e aguarda um pouco
      if (!AdManager.to.hasRewardedAd) {
        await AdManager.to.loadRewardedAd();
        // Aguarda até 2 segundos para o anúncio carregar
        int attempts = 0;
        while (!AdManager.to.hasRewardedAd && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      showVideoResultadoDialog(
        () {
          Get.back();
          final List<int> teste = [0, 0, 0, 0, 0, 0];
          Get.offNamed(RotasPaginas.resultadoTesteStress,
              arguments: [0, teste]);
        },
        () async {
          Get.back();
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          Get.offNamed(RotasPaginas.resultadoTesteStress,
              arguments: [_sumValores.toInt(), _grupos]);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _mostrarErro() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              Text(
                "Ag_faldad".tr,
                style: TextStyle(
                  fontSize: MyG.to.margens['margem1_25']!,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: MyG.to.margem),
            child: Text(
              "${"Ag_faldad_des".tr}\n\n$_msgErro",
              maxLines: 5,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize:
                      ResponsiveConfig.of(context).clampFont(MyG.to.margem),
                  color: Colors.black38),
            ),
          ),
          actions: <Widget>[
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Divider(),
                ),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.check_circle),
                    iconSize: MyG.to.margens['margem2']!,
                    color: Colors.amber,
                    tooltip: 'fechar',
                    onPressed: () {
                      Get.back();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    await (AdManager.to.rewardedService?.loadRewardedAd() ?? Future.value());
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoStress,
        titulo: "_tStress".tr,
      ),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          height: double.maxFinite,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                    MyG.to.margens['margem2']!,
                    MyG.to.margens['margem2']!,
                    MyG.to.margens['margem2']!,
                    MyG.to.margens['margem030']!),
                child: AutoSizeText(
                  "Ag_tit".tr,
                  style: TextStyle(
                    fontSize: r.clampFont(r.font(14)),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
              if (Platform.isIOS)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      MyG.to.margens['margem2']!,
                      MyG.to.margens['margem030']!,
                      MyG.to.margens['margem2']!,
                      MyG.to.margens['margem030']!),
                  child: Text(
                    "* Optional",
                    style: TextStyle(
                      fontSize: r.clampFont(r.font(12)),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDropdownWithPadding(
                        _selectIdade, _idadeItems, 'idade'),
                    _buildDropdownWithPadding(
                        _selectEstCivil, _estadoCivilItems, 'estadoCivil'),
                    _buildDropdownWithPadding(
                        _selectResid, _residenciaItems, 'residencia'),
                    _buildDropdownWithPadding(
                        _selectFilhos, _filhosCasaItems, 'filhos'),
                    _buildDropdownWithPadding(
                        _selectVinculo, _vinculoItems, 'vinculo'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(MyG.to.margens['margem2']!),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    minimumSize:
                        Size(double.infinity, r.buttonHeight.clamp(40.0, 64.0)),
                    padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _validarDados,
                  child: AutoSizeText(
                    "Ag_CalStre".tr,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.brown,
                      fontSize: r.clampFont(r.font(18)),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }
}
