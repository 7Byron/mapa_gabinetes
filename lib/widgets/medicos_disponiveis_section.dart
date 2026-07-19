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
  final Function(String) onDesalocarMedico;
  final Function(Medico)? onEditarMedico; // Callback para editar médico

  const MedicosDisponiveisSection({
    super.key,
    required this.medicosDisponiveis,
    required this.disponibilidades,
    required this.alocacoes,
    required this.cartoesEmAlocacao,
    required this.selectedDate,
    required this.onDesalocarMedico,
    this.onEditarMedico,
  });

  bool _validarDisponibilidade(Disponibilidade disp) {
    if (disp.horarios.length != 2) return false;
    try {
      final inicioParts = disp.horarios[0].split(':');
      final fimParts = disp.horarios[1].split(':');
      final inicio = TimeOfDay(
        hour: int.parse(inicioParts[0]),
        minute: int.parse(inicioParts[1]),
      );
      final fim = TimeOfDay(
        hour: int.parse(fimParts[0]),
        minute: int.parse(fimParts[1]),
      );
      if (inicio.hour < fim.hour) return true;
      if (inicio.hour == fim.hour && inicio.minute < fim.minute) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: cartoes.isEmpty
          ? const SizedBox.shrink()
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const ClampingScrollPhysics(),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: cartoes.map((cartao) {
                      final medico = cartao.medico;
                      final disponibilidade = cartao.disponibilidade;
                      final horariosList = disponibilidade.horarios;
                      final horariosStr = horariosList.length >= 2
                          ? "${horariosList[0]} - ${horariosList[1]}"
                          : horariosList.join(', ');

                      final isValido = _validarDisponibilidade(disponibilidade);
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
                              color: Colors.grey.shade200,
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
                                    isValido,
                                    estaAAlocar: true,
                                  )
                                : Draggable<String>(
                                    data:
                                        '${medico.id}|||${disponibilidade.id}',
                                    feedback: MedicoCard.dragFeedback(
                                        medico, horariosStr),
                                    childWhenDragging: Opacity(
                                      opacity: 0.5,
                                      child: _buildMedicoCardContent(
                                          medico, horariosStr, isValido),
                                    ),
                                    child: _buildMedicoCardContent(
                                        medico, horariosStr, isValido),
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
    String horarios,
    bool isValid, {
    bool estaAAlocar = false,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: estaAAlocar ? 0.65 : 1,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: estaAAlocar
              ? Colors.blue.shade50
              : isValid
                  ? MyAppTheme.medicoDisponivelCard
                  : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isValid
                ? MyAppTheme.azulClaro.withValues(alpha: 0.4)
                : Colors.red.shade300,
            width: isValid ? 1.5 : 1,
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
                const SizedBox(height: 8),
                // Horários com ícone
                if (horarios.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          horarios,
                          style: MyAppTheme.bodySmall.copyWith(
                            color: Colors.grey[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // Especialidade com ícone
                if (medico.especialidade.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          medico.especialidade,
                          style: MyAppTheme.bodySmall.copyWith(
                            color: Colors.grey[700],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
