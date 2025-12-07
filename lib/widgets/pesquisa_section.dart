import 'package:flutter/material.dart';

class PesquisaSection extends StatefulWidget {
  final String? pesquisaNome;
  final String? pesquisaEspecialidade;
  final List<String> opcoesNome;
  final List<String> opcoesEspecialidade;
  final Function(String?) onPesquisaNomeChanged;
  final Function(String?) onPesquisaEspecialidadeChanged;
  final VoidCallback onLimparPesquisa;

  const PesquisaSection({
    super.key,
    required this.pesquisaNome,
    required this.pesquisaEspecialidade,
    required this.opcoesNome,
    required this.opcoesEspecialidade,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
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
                Icons.search,
                color: Colors.blue.shade900,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pesquisa',
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
          DropdownButtonFormField<String>(
            initialValue: widget.pesquisaNome,
            decoration: const InputDecoration(
              labelText: 'Pesquisar por Nome',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.person_search),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Selecionar médico...'),
              ),
              ...widget.opcoesNome.map((nome) => DropdownMenuItem(
                    value: nome,
                    child: Text(
                      nome,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: widget.onPesquisaNomeChanged,
          ),
          const SizedBox(height: 12),

          // Pesquisa por Especialidade
          DropdownButtonFormField<String>(
            initialValue: widget.pesquisaEspecialidade,
            decoration: const InputDecoration(
              labelText: 'Pesquisar por Especialidade',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: Icon(Icons.medical_services),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Selecionar especialidade...'),
              ),
              ...widget.opcoesEspecialidade
                  .map((especialidade) => DropdownMenuItem(
                        value: especialidade,
                        child: Text(
                          especialidade,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
            ],
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
                label: const Text('Limpar Pesquisa'),
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
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.pesquisaNome != null
                          ? 'Médico destacado: ${widget.pesquisaNome}'
                          : 'Especialidade destacada: ${widget.pesquisaEspecialidade}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
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
