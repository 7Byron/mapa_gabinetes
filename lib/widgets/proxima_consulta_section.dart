import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/proxima_consulta_utils.dart';
import 'searchable_selection_field.dart';

class ProximaConsultaSection extends StatelessWidget {
  final String? medicoId;
  final String? especialidade;
  final Map<String, String> opcoesMedicos;
  final List<String> opcoesEspecialidades;
  final List<ProximaConsultaItem> resultados;
  final bool carregando;
  final String? erro;
  final ValueChanged<String?> onMedicoChanged;
  final ValueChanged<String?> onEspecialidadeChanged;
  final ValueChanged<ProximaConsultaItem> onConsultaTap;

  const ProximaConsultaSection({
    super.key,
    required this.medicoId,
    required this.especialidade,
    required this.opcoesMedicos,
    required this.opcoesEspecialidades,
    required this.resultados,
    required this.carregando,
    required this.erro,
    required this.onMedicoChanged,
    required this.onEspecialidadeChanged,
    required this.onConsultaTap,
  });

  String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final temPesquisa = medicoId != null || especialidade != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: MyAppTheme.shadowCard3D,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available, color: MyAppTheme.azulEscuro),
              const SizedBox(width: 8),
              Text(
                'Próxima consulta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MyAppTheme.azulEscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchableSelectionField<String>(
            key: ValueKey('proxima-medico-$medicoId'),
            value: medicoId,
            label: 'Médico',
            hint: 'Selecionar médico...',
            dialogTitle: 'Médico',
            searchHint: 'Pesquisar médico',
            suffixIcon: Icons.person_outline,
            options: opcoesMedicos.entries
                .map((item) => SearchableSelectionOption(
                      value: item.key,
                      label: item.value,
                    ))
                .toList(),
            onChanged: onMedicoChanged,
          ),
          const SizedBox(height: 12),
          SearchableSelectionField<String>(
            key: ValueKey('proxima-especialidade-$especialidade'),
            value: especialidade,
            label: 'Especialidade',
            hint: 'Selecionar especialidade...',
            dialogTitle: 'Especialidade',
            searchHint: 'Pesquisar especialidade',
            suffixIcon: Icons.local_hospital_outlined,
            options: opcoesEspecialidades
                .map((item) => SearchableSelectionOption(
                      value: item,
                      label: item,
                    ))
                .toList(),
            onChanged: onEspecialidadeChanged,
          ),
          if (carregando) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (erro != null) ...[
            const SizedBox(height: 16),
            Text(erro!, style: TextStyle(color: Colors.red.shade700)),
          ] else if (temPesquisa) ...[
            const SizedBox(height: 16),
            if (resultados.isEmpty)
              const Text('Não foram encontradas consultas futuras.')
            else
              ...resultados.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onConsultaTap(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 17, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.medico.nome} — ${_data(item.alocacao.data)}, '
                                '${item.alocacao.horarioInicio} - ${item.alocacao.horarioFim}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 17,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
