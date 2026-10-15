import 'package:flutter/material.dart';

import '../models/medico.dart';
import 'medico_card.dart';

/// O arrasto de um cartão alocado exige uma escolha explícita no menu.
class CartaoMapaInterativo extends StatefulWidget {
  final Medico medico;
  final String horarios;
  final String dragData;
  final bool ausente;
  final Color? corDestaque;
  final VoidCallback? onEditar;
  final Future<void> Function() onAlternarAusencia;

  const CartaoMapaInterativo({
    super.key,
    required this.medico,
    required this.horarios,
    required this.dragData,
    required this.ausente,
    this.corDestaque,
    this.onEditar,
    required this.onAlternarAusencia,
  });

  @override
  State<CartaoMapaInterativo> createState() => _CartaoMapaInterativoState();
}

class _CartaoMapaInterativoState extends State<CartaoMapaInterativo> {
  bool _movimento = false;
  bool _aGuardar = false;

  @override
  void didUpdateWidget(covariant CartaoMapaInterativo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragData != widget.dragData ||
        oldWidget.ausente != widget.ausente) {
      _movimento = false;
    }
  }

  Future<void> _abrirMenu() async {
    if (_aGuardar) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final cartao = context.findRenderObject()! as RenderBox;
    final retangulo = MatrixUtils.transformRect(
        cartao.getTransformTo(overlay), Offset.zero & cartao.size);
    final acao = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(retangulo.left, retangulo.bottom, retangulo.width, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (widget.onEditar != null)
          const PopupMenuItem(
            value: 'editar',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Editar disponibilidade'),
            ),
          ),
        PopupMenuItem(
          value: 'ausencia',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                Icon(widget.ausente ? Icons.event_available : Icons.event_busy),
            title: Text(
                widget.ausente ? 'Ativar este cartão' : 'Inativar este cartão'),
          ),
        ),
        if (!widget.ausente)
          PopupMenuItem(
            value: 'mover',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_with),
              title: Text(_movimento ? 'Bloquear movimento' : 'Mover cartão'),
            ),
          ),
      ],
    );
    if (!mounted) return;
    if (acao == 'editar') {
      setState(() => _movimento = false);
      widget.onEditar?.call();
    } else if (acao == 'mover') {
      setState(() => _movimento = !_movimento);
    } else if (acao == 'ausencia') {
      setState(() {
        _movimento = false;
        _aGuardar = true;
      });
      try {
        await widget.onAlternarAusencia();
      } finally {
        if (mounted) setState(() => _aGuardar = false);
      }
    }
  }

  Widget _cartao() => MedicoCard.buildSmallMedicoCard(
        widget.medico,
        widget.horarios,
        widget.ausente ? Colors.grey.shade200 : Colors.white,
        true,
        ausente: widget.ausente,
        corDestaque: widget.corDestaque,
      );

  @override
  Widget build(BuildContext context) {
    Widget cartao = _cartao();
    if (_movimento && !widget.ausente && !_aGuardar) {
      cartao = Draggable<String>(
        data: widget.dragData,
        feedback: MedicoCard.dragFeedback(widget.medico, widget.horarios),
        childWhenDragging: Opacity(opacity: 0.5, child: _cartao()),
        onDragEnd: (_) {
          if (mounted) setState(() => _movimento = false);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: cartao,
        ),
      );
    }
    return GestureDetector(
      onTap: _abrirMenu,
      child: AbsorbPointer(absorbing: _aGuardar, child: cartao),
    );
  }
}
