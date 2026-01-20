import 'package:flutter/material.dart';
import '../models/medico.dart';

class MedicosNaoAlocadosDialog extends StatelessWidget {
  final int ano;
  final List<Medico> medicos;
  final Map<String, int> medicosComDias;
  final Map<String, List<DateTime>> medicosComDatas;
  final ValueChanged<Medico> onAbrirCadastro;
  final ValueChanged<DateTime> onSelecionarData;

  const MedicosNaoAlocadosDialog({
    super.key,
    required this.ano,
    required this.medicos,
    required this.medicosComDias,
    required this.medicosComDatas,
    required this.onAbrirCadastro,
    required this.onSelecionarData,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Stack(
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Médicos Não Alocados ($ano)'),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 20,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: medicos.isEmpty
            ? const Text('Não há médicos não alocados no ano.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: medicos.length,
                itemBuilder: (context, index) {
                  final medico = medicos[index];
                  final numDias = medicosComDias[medico.id] ?? 0;
                  final datas = medicosComDatas[medico.id] ?? [];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                onAbrirCadastro(medico);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        radius: 20,
                                        child: Text(
                                          medico.nome[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              medico.nome,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              medico.especialidade.isNotEmpty
                                                  ? medico.especialidade
                                                  : 'Sem especialidade',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              '$numDias ${numDias == 1 ? "dia" : "dias"} não alocados',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.end,
                                children: datas.take(10).map((data) {
                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      final dataNormalizada =
                                          DateTime(data.year, data.month, data.day);
                                      onSelecionarData(dataNormalizada);
                                    },
                                    child: Chip(
                                      label: Text(
                                        '${data.day}/${data.month}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      backgroundColor: Colors.blue.shade50,
                                      side: BorderSide(
                                          color: Colors.blue.shade200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
