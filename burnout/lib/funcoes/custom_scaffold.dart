import 'package:flutter/material.dart';

class CustomScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final PreferredSizeWidget? appBar;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  const CustomScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.drawer,
    this.appBar,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        appBar: appBar,
        drawer: MediaQuery.of(context).size.width >= 1024 ? null : drawer,
        drawerScrimColor: Colors.transparent, // Remove o overlay escuro
        body: Row(
          children: [
            if (MediaQuery.of(context).size.width >= 1024 && drawer != null)
              SizedBox(width: 320, child: drawer),
            Expanded(
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: body,
              ),
            ),
          ],
        ),

        extendBody: extendBody,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        // Garante que o banner não capture toques acima dele
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
