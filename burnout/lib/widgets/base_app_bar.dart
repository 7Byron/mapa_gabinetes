import 'package:flutter/material.dart';
import '../funcoes/responsive.dart';
import '../funcoes/spacing.dart';

class BaseRoundedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool alignWithDrawer;
  final double? toolbarHeightOverride;

  const BaseRoundedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.alignWithDrawer = true,
    this.toolbarHeightOverride,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);

    return Padding(
      padding: EdgeInsets.all(Spacing.xs),
      child: Padding(
        padding: EdgeInsets.only(
          left: (MediaQuery.of(context).size.width >= 1024 && alignWithDrawer)
              ? 320.0
              : 0.0,
        ),
        child: Center(
          child: SizedBox(
            width: r.contentMaxWidth,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20.0,
                    offset: Offset(0.0, 5.0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: AppBar(
                  elevation: 4.0,
                  centerTitle: centerTitle,
                  toolbarHeight:
                      toolbarHeightOverride ?? r.buttonHeight.clamp(40.0, 64.0),
                  title: title,
                  actions: actions,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(56); // altura base; toolbarHeight define o real
}

