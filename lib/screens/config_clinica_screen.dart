import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import '../database/database_helper.dart';
import '../main.dart';

class ConfigClinicaScreen extends StatefulWidget {
  const ConfigClinicaScreen({super.key});

  @override
  State<ConfigClinicaScreen> createState() => _ConfigClinicaScreenState();
}

class _ConfigClinicaScreenState extends State<ConfigClinicaScreen> {
  Map<int, List<String>> horarios = {
    1: ["08:00", "20:00"],
    2: ["08:00", "20:00"],
    3: ["08:00", "20:00"],
    4: ["08:00", "20:00"],
    5: ["08:00", "20:00"],
    6: ["08:00", "13:00"],
    7: ["", ""],
  };

  final List<String> diasSemana = [
    "2ª feira",
    "3ª feira",
    "4ª feira",
    "5ª feira",
    "6ª feira",
    "Sábado",
    "Domingo",
  ];

  List<Map<String, dynamic>> feriados = [];

  @override
  void initState() {
    super.initState();
    _carregarDoBD();
  }

  @override
  void dispose() async {
    super.dispose();
  }

  Future<void> _carregarDoBD() async {
    try {
      final db = await DatabaseHelper.database;

      // Verificar existência das tabelas
      final tabelas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('horarios_clinica', 'feriados')",
      );
      if (tabelas.isEmpty) {
        throw Exception('Tabelas obrigatórias não encontradas no banco.');
      }

      // Verificar se as tabelas estão vazias
      final horariosRows = await DatabaseHelper.buscarHorariosClinica();
      if (horariosRows.isEmpty) {
        debugPrint('Tabela horarios_clinica está vazia.');
      }

      final feriadosRows = await DatabaseHelper.buscarFeriados();
      if (feriadosRows.isEmpty) {
        debugPrint('Tabela feriados está vazia.');
      }

      // Carregar horários da clínica
      for (final row in horariosRows) {
        final ds = row['diaSemana'] as int;
        final ab = (row['horaAbertura'] ?? "") as String;
        final fe = (row['horaFecho'] ?? "") as String;
        horarios[ds] = [ab, fe];
      }

      // Carregar feriados
      feriados = feriadosRows.map((row) {
        return {
          'data': row['data'], // Mantém a data como String para trabalhar com o banco
          'descricao': row['descricao'] ?? '', // Substitui por String vazia caso seja nulo
        };
      }).toList();

      // Ordena feriados por data (convertendo para DateTime para comparação)
      feriados.sort((a, b) {
        final dateA = DateTime.tryParse(a['data']) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['data']) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      // Atualiza o estado da tela
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao carregar dados do banco: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados do banco.')),
      );
    }
  }



  Future<void> _gravarAlteracoes() async {
    try {
      for (int ds = 1; ds <= 7; ds++) {
        await DatabaseHelper.salvarHorarioClinica(
          ds,
          horarios[ds]![0],
          horarios[ds]![1],
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações gravadas automaticamente.')),
      );
    } catch (e) {
      debugPrint('Erro ao gravar alterações: $e');
    }
  }

  Future<void> _apagarHorarios(int diaSemana) async {
    setState(() {
      horarios[diaSemana] = ["", ""];
    });
    await DatabaseHelper.deletarHorarioClinica(diaSemana);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Horários do Dia $diaSemana apagados.')),
    );
  }

  Future<void> _adicionarFeriado() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    String descricao = '';

    if (pickedDate != null) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Adicionar Feriado'),
            content: TextField(
              decoration: const InputDecoration(
                labelText: 'Descrição (Opcional)',
                hintText: 'Ex.: Feriado Nacional',
              ),
              onChanged: (value) => descricao = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );

      try {
        await DatabaseHelper.salvarFeriado(pickedDate, descricao);
        setState(() {
          feriados.add({
            'data': pickedDate.toIso8601String(), // Salva a data como String ISO 8601
            'descricao': descricao.isNotEmpty ? descricao : '',
          });

          // Ordena a lista por data
          feriados.sort((a, b) => DateTime.parse(a['data']).compareTo(DateTime.parse(b['data'])));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feriado adicionado com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar feriado: $e')),
        );
      }
    }
  }


  Future<void> _removerFeriado(Map<String, dynamic> feriado) async {
    try {
      // Certifique-se de que 'data' seja convertida para o formato correto
      final data = feriado['data'] is DateTime
          ? (feriado['data'] as DateTime).toIso8601String()
          : feriado['data'].toString();

      await DatabaseHelper.deletarFeriado(data); // Passe como String ao banco
      setState(() {
        feriados.remove(feriado);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feriado removido com sucesso!')),
      );
    } catch (e) {
      debugPrint('Erro ao remover feriado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover feriado.')),
      );
    }
  }




  Future<void> _escolherHora(int ds, bool isAbertura) async {
    final textoAtual = isAbertura ? horarios[ds]![0] : horarios[ds]![1];
    final parts = textoAtual.split(':');
    int h = 8, m = 0;
    if (parts.length == 2) {
      h = int.tryParse(parts[0]) ?? 8;
      m = int.tryParse(parts[1]) ?? 0;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );

    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        if (isAbertura) {
          horarios[ds]![0] = '$hh:$mm';
        } else {
          horarios[ds]![1] = '$hh:$mm';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _gravarAlteracoes(); // Grava alterações antes de sair
        return true; // Permite que o usuário navegue para trás
      },
      child: Scaffold(
        appBar: CustomAppBar(title: 'Configuração Horário da Clínica'),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [

              /// Card para Horários de Início/Fim

              Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horários de Início/Fim (Seg-Dom)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        for (int ds = 1; ds <= 7; ds++) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(diasSemana[ds - 1]),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: InkWell(
                                  onTap: () => _escolherHora(ds, true),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Início',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(horarios[ds]![0]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: InkWell(
                                  onTap: () => _escolherHora(ds, false),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Fim',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(horarios[ds]![1]),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _apagarHorarios(ds),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              /// Card para Feriados


              SizedBox(
                width: 300,
                child: Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Encerrado e/ou Feriados',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: MyAppTheme.darkBlue),
                              onPressed: _adicionarFeriado, // Método para adicionar feriado
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        feriados.isEmpty
                            ? const Text('Sem dias assinalados')
                            : Expanded( // Garante que a lista ocupe o espaço disponível no layout pai
                          child: ListView.builder(
                            shrinkWrap: true, // Evita problemas de expansão excessiva
                            itemCount: feriados.length,
                            itemBuilder: (context, index) {
                              final f = feriados[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(
                                            f['data'] is String ? DateTime.parse(f['data']) : f['data'] as DateTime,
                                          ),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,),
                                        ),
                                        if ((f['descricao'] ?? '').isNotEmpty)
                                          Text(
                                            f['descricao'],
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removerFeriado(f), // Método para remover o feriado
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
