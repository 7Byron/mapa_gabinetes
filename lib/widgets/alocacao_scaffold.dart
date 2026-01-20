import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/unidade.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/custom_drawer.dart';

class AlocacaoScaffold extends StatelessWidget {
  final Unidade unidade;
  final bool isAdmin;
  final DateTime selectedDate;
  final double zoomLevel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRefresh;
  final Widget body;

  const AlocacaoScaffold({
    super.key,
    required this.unidade,
    required this.isAdmin,
    required this.selectedDate,
    required this.zoomLevel,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRefresh,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title:
            'Mapa de ${unidade.nomeAlocacao} - ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
        onZoomIn: onZoomIn,
        onZoomOut: onZoomOut,
        currentZoom: zoomLevel,
        onRefresh: onRefresh,
      ),
      drawer: CustomDrawer(
        onRefresh: onRefresh,
        unidade: unidade,
        isAdmin: isAdmin,
      ),
      body: body,
    );
  }
}
