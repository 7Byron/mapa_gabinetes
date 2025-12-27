import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/spacing.dart';

class YesNoDiscordoConcordo extends StatefulWidget {
  final Color gradientStart;
  final Color gradientEnd;
  final String imagePath;
  final String label;
  final int responseValue;
  final void Function() onPressed;

  const YesNoDiscordoConcordo({
    super.key,
    required this.gradientStart,
    required this.gradientEnd,
    required this.imagePath,
    required this.label,
    required this.responseValue,
    required this.onPressed,
  });

  @override
  YesNoDiscordoConcordoState createState() => YesNoDiscordoConcordoState();
}

class YesNoDiscordoConcordoState extends State<YesNoDiscordoConcordo> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 500)); 
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),  
              height: _pressed ? MyG.to.margem * 3.5 : MyG.to.margens['margem4']!,
              width: _pressed ? MyG.to.margem * 7 : MyG.to.margens['margem8']!,  
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.0),
                boxShadow: _pressed
                    ? []
                    : const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20.0,
                    offset: Offset(0.0, 5.0),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.gradientStart, widget.gradientEnd],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        MyG.to.margens['margem05']!,
                        MyG.to.margens['margem1']!,
                        MyG.to.margens['margem025']!,
                        MyG.to.margens['margem1']!,
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(MyG.to.margens['margem025']!),
                          child: Image.asset(widget.imagePath),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AutoSizeText(
                          widget.label.tr,
                          style: TextStyle(
                            fontSize: _pressed
                                ? MyG.to.margens['margem085']! 
                                : MyG.to.margens['margem1']!, 
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: Spacing.s),
                  ],
                ),
              ),
            ),
            SizedBox(height: Spacing.s),
          ],
        ),
      ),
    );
  }
}
