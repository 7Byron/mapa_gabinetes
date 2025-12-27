import 'dart:async';

import 'package:flutter/material.dart';

class ShowUp extends StatefulWidget {
  final Widget child;
  final int delay;
  final Duration duration;

  const ShowUp({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  ShowUpState createState() => ShowUpState();
}

class ShowUpState extends State<ShowUp> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _timer = Timer(Duration(milliseconds: widget.delay), _animController.forward);
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animController,
      child: widget.child,
    );
  }
}
