import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Suaviza as etapas e mantém movimento durante esperas de duração desconhecida.
/// Só permite chegar a 100% após a conclusão efetiva do trabalho.
class MatrizProgressoController extends ValueNotifier<double> {
  MatrizProgressoController() : super(0);
  Timer? _timer;
  double _alvo = 0;
  double _limite = 0;
  Completer<void>? _conclusao;
  double _passoConclusao = 0;

  void iniciar() {
    parar();
    value = 0;
    _alvo = 0.04;
    _limite = 0.14;
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  void etapa(double alvo, {required double limiteEspera}) {
    _alvo = math.max(_alvo, alvo.clamp(0, 0.98));
    _limite = math.max(_alvo, limiteEspera.clamp(0, 0.99));
  }

  void _tick() {
    if (_conclusao != null) {
      value = math.min(1, value + _passoConclusao);
      if (value == 1) {
        _timer?.cancel();
        _conclusao!.complete();
        _conclusao = null;
      }
      return;
    }
    if (value < _alvo) {
      value = math.min(_alvo, value + math.max(0.004, (_alvo - value) * 0.2));
    } else if (value < _limite) {
      value = math.min(
          _limite, value + math.max(0.0002, (_limite - value) * 0.012));
    }
  }

  Future<void> concluir() {
    if (value == 1) return Future<void>.value();
    if (_conclusao == null) {
      _passoConclusao = math.max(0.001, (1 - value) / 8);
      _conclusao = Completer<void>();
    }
    return _conclusao!.future;
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
    if (_conclusao != null) {
      _conclusao!.complete();
      _conclusao = null;
    }
  }

  @override
  void dispose() {
    parar();
    super.dispose();
  }
}
