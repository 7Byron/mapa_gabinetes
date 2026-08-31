import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'searchable_selection_field.dart';

class PesquisaSection extends StatefulWidget {
  final String? pesquisaNome;
  final String? pesquisaEspecialidade;
  final List<String> opcoesNome;
  final List<String> opcoesEspecialidade;
  final int cartoesDestacados;
  final Function(String?) onPesquisaNomeChanged;
  final Function(String?) onPesquisaEspecialidadeChanged;
  final VoidCallback onLimparPesquisa;

  const PesquisaSection({
    super.key,
    required this.pesquisaNome,
    required this.pesquisaEspecialidade,
    required this.opcoesNome,
    required this.opcoesEspecialidade,
    required this.cartoesDestacados,
    required this.onPesquisaNomeChanged,
    required this.onPesquisaEspecialidadeChanged,
    required this.onLimparPesquisa,
  });

  @override
  State<PesquisaSection> createState() => _PesquisaSectionState();
}

class _PesquisaSectionState extends State<PesquisaSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MyAppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: MyAppTheme.shadowCard3D,
      ),
      clipBehavior: Clip.none,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título da seção
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.highlight_alt,
                color: Colors.blue.shade900,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Destacar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pesquisa por Nome do Médico
          SearchableSelectionField<String>(
            key: const ValueKey('destacar-medico'),
            value: widget.pesquisaNome,
            label: 'Destacar Médico',
            hint: 'Selecionar médico...',
            dialogTitle: 'Médico',
            searchHint: 'Pesquisar médico',
            suffixIcon: Icons.person_pin_circle_outlined,
            options: widget.opcoesNome
                .map((nome) => SearchableSelectionOption(
                      value: nome,
                      label: nome,
                    ))
                .toList(),
            onChanged: widget.onPesquisaNomeChanged,
          ),
          const SizedBox(height: 12),

          // Pesquisa por Especialidade
          SearchableSelectionField<String>(
            key: const ValueKey('destacar-especialidade'),
            value: widget.pesquisaEspecialidade,
            label: 'Destacar Especialidade',
            hint: 'Selecionar especialidade...',
            dialogTitle: 'Especialidade',
            searchHint: 'Pesquisar especialidade',
            suffixIcon: Icons.local_hospital_outlined,
            options: widget.opcoesEspecialidade
                .map((especialidade) => SearchableSelectionOption(
                      value: especialidade,
                      label: especialidade,
                    ))
                .toList(),
            onChanged: widget.onPesquisaEspecialidadeChanged,
          ),

          // Botão para limpar pesquisa
          if (widget.pesquisaNome != null ||
              widget.pesquisaEspecialidade != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onLimparPesquisa,
                icon: const Icon(Icons.clear),
                label: const Text('Limpar Destaque'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ],

          // Informação sobre a pesquisa
          if (widget.pesquisaNome != null ||
              widget.pesquisaEspecialidade != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pesquisaNome != null
                              ? 'Médico destacado: ${widget.pesquisaNome}'
                              : 'Especialidade destacada: ${widget.pesquisaEspecialidade}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cartões destacados: ${widget.cartoesDestacados}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
