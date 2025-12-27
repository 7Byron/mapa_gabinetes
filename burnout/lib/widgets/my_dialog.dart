import 'package:flutter/material.dart';

import '../funcoes/variaveis_globais.dart';

class MyAlertDialog extends StatelessWidget {
  final String titulo;
  final String texto;

  const MyAlertDialog({
    super.key,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: _buildContent(),
      actions: [_buildActions(context)],
    );
  }

  Widget _buildTitle() {
    return Container(
      height: MyG.to.margens['margem2_5']!,
      color: Colors.amber.shade200,
      child: Center(
        child: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Text(
        texto,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Divider(),
        ),
        Center(
          child: IconButton(
            icon: const Icon(Icons.check_circle),
            iconSize: MyG.to.margens['margem2']!,
            color: Colors.amber.shade200,
            tooltip: 'Close',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
