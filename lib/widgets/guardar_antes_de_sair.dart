import 'package:flutter/material.dart';

/// Aguarda a gravação antes de permitir a saída, sem pedir confirmação.
class GuardarAntesDeSair extends StatefulWidget {
  const GuardarAntesDeSair({
    super.key,
    required this.onGuardar,
    required this.child,
  });

  final Future<bool> Function() onGuardar;
  final Widget child;

  @override
  State<GuardarAntesDeSair> createState() => _GuardarAntesDeSairState();
}

class _GuardarAntesDeSairState extends State<GuardarAntesDeSair> {
  bool _aGuardar = false;
  bool _podeSair = false;

  Future<void> _sair(Object? result) async {
    if (_aGuardar) return;
    _aGuardar = true;
    try {
      if (!await widget.onGuardar() || !mounted) return;
      setState(() => _podeSair = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(result);
    } finally {
      _aGuardar = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _podeSair,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _sair(result);
      },
      child: widget.child,
    );
  }
}
