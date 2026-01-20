import 'dart:async';

class AlocacaoProgressaoController {
  Timer? _timer;
  bool _ativo = false;
  void Function()? _onCancel;

  void iniciar({
    required bool Function() deveCancelar,
    required void Function() onCancel,
    required void Function() onTick,
  }) {
    parar();
    _onCancel = onCancel;
    _ativo = true;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (deveCancelar()) {
        timer.cancel();
        _timer = null;
        _ativo = false;
        onCancel();
        return;
      }
      onTick();
    });
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
    if (_ativo) {
      _ativo = false;
      _onCancel?.call();
    }
  }

  bool get ativo => _ativo;
}
