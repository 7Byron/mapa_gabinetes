import 'dart:async';
import 'package:flutter/material.dart';

class SlideShowUp extends StatefulWidget {
  final Widget child;
  final int delay; // em ms
  final Duration duration;
  final Curve curve;

  const SlideShowUp({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.linearToEaseOut,
  });

  @override
  SlideShowUpState createState() => SlideShowUpState();
}

class SlideShowUpState extends State<SlideShowUp>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _animationController,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(curved);

    // Se o delay for zero, inicia já;
    // caso contrário, aguarda o delay.
    if (widget.delay <= 0) {
      _animationController.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          _animationController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    // Cancelar eventual animação
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
