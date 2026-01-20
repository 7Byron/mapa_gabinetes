import 'package:flutter/material.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';
import '../models/unidade.dart';
import '../widgets/gabinetes_section.dart';

class GabinetesContainer extends StatelessWidget {
  final List<Gabinete> gabinetes;
  final List<Alocacao> alocacoes;
  final List<Medico> medicos;
  final List<Disponibilidade> disponibilidades;
  final DateTime selectedDate;
  final bool isAdmin;
  final Set<String> medicosDestacados;
  final Unidade unidade;
  final Future<void> Function(String medicoId, String gabineteId,
      {DateTime? dataEspecifica, List<String>? horarios}) onAlocarMedico;
  final Future<void> Function() onAtualizarEstado;
  final Future<void> Function(String medicoId) onDesalocarMedicoComPergunta;
  final Future<void> Function(String medicoId, String gabineteOrigem,
      String gabineteDestino, DateTime data) onRealocacaoOtimista;
  final VoidCallback onRealocacaoConcluida;
  final void Function(String medicoId, String gabineteId, DateTime data)
      onAlocacaoSerieOtimista;
  final void Function(Medico)? onEditarMedico;

  const GabinetesContainer({
    super.key,
    required this.gabinetes,
    required this.alocacoes,
    required this.medicos,
    required this.disponibilidades,
    required this.selectedDate,
    required this.isAdmin,
    required this.medicosDestacados,
    required this.unidade,
    required this.onAlocarMedico,
    required this.onAtualizarEstado,
    required this.onDesalocarMedicoComPergunta,
    required this.onRealocacaoOtimista,
    required this.onRealocacaoConcluida,
    required this.onAlocacaoSerieOtimista,
    this.onEditarMedico,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: RepaintBoundary(
          child: GabinetesSection(
            gabinetes: gabinetes,
            alocacoes: alocacoes,
            medicos: medicos,
            disponibilidades: disponibilidades,
            selectedDate: selectedDate,
            onAlocarMedico: onAlocarMedico,
            onAtualizarEstado: onAtualizarEstado,
            onDesalocarMedicoComPergunta: onDesalocarMedicoComPergunta,
            isAdmin: isAdmin,
            medicosDestacados: medicosDestacados,
            unidade: unidade,
            onRealocacaoOtimista: onRealocacaoOtimista,
            onRealocacaoConcluida: onRealocacaoConcluida,
            onAlocacaoSerieOtimista: onAlocacaoSerieOtimista,
            onEditarMedico: onEditarMedico,
          ),
        ),
      ),
    );
  }
}
