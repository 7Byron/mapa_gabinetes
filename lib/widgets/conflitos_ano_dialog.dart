import 'package:flutter/material.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';

class ConflitosAnoDialog extends StatelessWidget {
  final int ano;
  final List<Map<String, dynamic>> conflitos;
  final ValueChanged<DateTime> onSelecionarData;

  const ConflitosAnoDialog({
    super.key,
    required this.ano,
    required this.conflitos,
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
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Conflitos de Gabinete ($ano)'),
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
        child: conflitos.isEmpty
            ? const Text('Não há conflitos no ano.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: conflitos.length,
                itemBuilder: (context, index) {
                  final conflito = conflitos[index];
                  final gabinete = conflito['gabinete'] as Gabinete;
                  final data = conflito['data'] as DateTime;
                  final medico1 = conflito['medico1'] as Medico;
                  final horario1 = conflito['horario1'] as String;
                  final medico2 = conflito['medico2'] as Medico;
                  final horario2 = conflito['horario2'] as String;
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      final dataNormalizada =
                          DateTime(data.year, data.month, data.day);
                      debugPrint(
                          '🔍 [DEBUG] Clicou em conflito - navegando para data: ${dataNormalizada.day}/${dataNormalizada.month}/${dataNormalizada.year}');
                      onSelecionarData(dataNormalizada);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.error, color: Colors.red),
                        title: Text(
                          '${gabinete.nome} - ${data.day}/${data.month}/${data.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${medico1.nome}: $horario1'),
                            Text('${medico2.nome}: $horario2'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
