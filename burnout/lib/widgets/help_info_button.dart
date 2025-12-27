import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/itens_reutilizaveis.dart';
import 'my_dialog.dart';

class HelpInfoButton extends StatelessWidget {
  final String title;
  final String text;

  const HelpInfoButton({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.dialog(MyAlertDialog(titulo: title, texto: text));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 10.0,
              offset: Offset(0.0, 5.0),
            ),
          ],
        ),
        child: Reuse.myHelpIcon,
      ),
    );
  }
}

