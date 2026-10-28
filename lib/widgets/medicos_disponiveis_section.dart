import '../utils/app_colors.dart';
import 'package:flutter/material.dart';
import '../models/medico.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';
import '../utils/app_theme.dart';
import '../utils/series_helper.dart';
import 'medico_card.dart';

class MedicosDisponiveisSection extends StatelessWidget {
  final List<Medico> medicosDisponiveis;
  final List<Disponibilidade> disponibilidades;
  final List<Alocacao> alocacoes;
  final Set<String> cartoesEmAlocacao;
  final DateTime selectedDate;
  final Function(Medico)? onEditarMedico; // Callback para editar médico

  const MedicosDisponiveisSection({
    super.key,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.alocacoes,
    required this.cartoesEmAlocacao,
    required this.selectedDate,
    this.onEditarMedico,
  });

  bool _estaAlocada(Disponibilidade disponibilidade) {
    final data = DateTime(disponibilidade.data.year, disponibilidade.data.month,
        disponibilidade.data.day);
    final serieId = disponibilidade.id.startsWith('serie_')
        ? SeriesHelper.extrairSerieIdDeDisponibilidade(disponibilidade.id)
        : null;
    return alocacoes.any((a) {
      final dataAlocacao = DateTime(a.data.year, a.data.month, a.data.day);
      if (a.medicoId != disponibilidade.medicoId || dataAlocacao != data) {
        return false;
      }
      if (serieId != null) return a.id.contains(serieId);
      return a.horarioInicio == disponibilidade.horarios.firstOrNull &&
          a.horarioFim == disponibilidade.horarios.lastOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    final idsDisponiveis = medicosDisponiveis.map((m) => m.id).toSet();
    final dataSelecionada =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final cartoes = disponibilidades.where((d) {
      final data = DateTime(d.data.year, d.data.month, d.data.day);
      return data == dataSelecionada &&
          idsDisponiveis.contains(d.medicoId) &&
          !_estaAlocada(d);
    }).map((d) {
      final medico = medicosDisponiveis.firstWhere((m) => m.id == d.medicoId);
      return (medico: medico, disponibilidade: d);
    }).toList()
      ..sort((a, b) =>
          a.medico.nome.toLowerCase().compareTo(b.medico.nome.toLowerCase()));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: cartoes.isEmpty
          ? const SizedBox.shrink()
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: cartoes.map((cartao) {
                      final medico = cartao.medico;
                      final disponibilidade = cartao.disponibilidade;
                      final horariosList = disponibilidade.horarios;
                      final horariosStr = horariosList.length >= 2
                          ? "${horariosList[0]} - ${horariosList[1]}"
                          : horariosList.join(', ');

                      final estaAAlocar = _estaAAlocar(disponibilidade);

                      return MouseRegion(
                        cursor: estaAAlocar
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.grab,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.bordaAtencao,
                              width: 1,
                            ),
                          ),
                          child: GestureDetector(
                            // Clique único para editar (só aciona se não houver drag)
                            onTap: () {
                              if (!estaAAlocar && onEditarMedico != null) {
                                onEditarMedico!(medico);
                              }
                            },
                            child: estaAAlocar
                                ? _buildMedicoCardContent(
                                    medico,
                                    horariosStr,
                                    estaAAlocar: true,
                                  )
                                : Draggable<String>(
                                    affinity: Axis.vertical,
                                    data:
                                        '${medico.id}|||${disponibilidade.id}',
                                    feedback: MedicoCard.dragFeedback(
                                        medico, horariosStr),
                                    childWhenDragging: Opacity(
                                      opacity: 0.5,
                                      child: _buildMedicoCardContent(
                                          medico, horariosStr),
                                    ),
                                    child: _buildMedicoCardContent(
                                        medico, horariosStr),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }

  bool _estaAAlocar(Disponibilidade disponibilidade) {
    final horarios = disponibilidade.horarios;
    final inicio = horarios.isNotEmpty ? horarios.first : '';
    final fim = horarios.length > 1 ? horarios[1] : '';
    return cartoesEmAlocacao.contains(
      '${disponibilidade.medicoId}|$inicio|$fim',
    );
  }

  Widget _buildMedicoCardContent(
    Medico medico,
    String horarios, {
    bool estaAAlocar = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: estaAAlocar ? 0.65 : 1,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: estaAAlocar ? AppColors.selecao : AppColors.atencao,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: estaAAlocar ? AppColors.bordaLivre : AppColors.bordaAtencao,
            width: 1,
          ),
          boxShadow: MyAppTheme.shadowMedicoCard,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nome do médico
                Padding(
                  padding: EdgeInsets.only(right: estaAAlocar ? 78 : 0),
                  child: Text(
                    medico.nome,
                    style: MyAppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: [
                    if (horarios.isNotEmpty) horarios,
                    if (medico.especialidade.isNotEmpty) medico.especialidade
                  ].join(' · '),
                  child: Text(
                    [
                      if (horarios.isNotEmpty) horarios,
                      if (medico.especialidade.isNotEmpty) medico.especialidade
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.secundario),
                  ),
                ),
              ],
            ),
            if (estaAAlocar)
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A alocar…',
                      style: MyAppTheme.bodySmall.copyWith(
                        color: MyAppTheme.azulEscuro,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
