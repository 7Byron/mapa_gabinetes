import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:mapa_gabinetes/widgets/time_picker_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';

class ConfigClinicaScreen extends StatefulWidget {
  final Unidade? unidade;

  const ConfigClinicaScreen({super.key, this.unidade});

  @override
  State<ConfigClinicaScreen> createState() => _ConfigClinicaScreenState();
}

class _ConfigClinicaScreenState extends State<ConfigClinicaScreen> {
  Map<int, List<String>> horarios = {
    1: ["", ""], // Segunda-feira - vazio por padrão
    2: ["", ""], // Terça-feira - vazio por padrão
    3: ["", ""], // Quarta-feira - vazio por padrão
    4: ["", ""], // Quinta-feira - vazio por padrão
    5: ["", ""], // Sexta-feira - vazio por padrão
    6: ["", ""], // Sábado - vazio por padrão
    7: ["", ""], // Domingo - vazio por padrão
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
    debugPrint(
        'ConfigClinicaScreen inicializada. Unidade: ${widget.unidade?.id ?? 'null'}');
    _carregarDoBD();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega dados quando a tela volta a ser exibida
    _carregarDoBD();
  }

  @override
  void dispose() async {
    super.dispose();
  }

  Future<void> _carregarDoBD() async {
    try {
      debugPrint('Carregando dados da clínica do Firestore...');

      CollectionReference horariosRef;
      CollectionReference feriadosRef;

      if (widget.unidade != null) {
        // Carrega dados da unidade específica
        horariosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('horarios_clinica');
        feriadosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('feriados');
        debugPrint('Carregando dados da unidade: ${widget.unidade!.id}');
      } else {
        // Carrega dados globais (fallback para compatibilidade)
        horariosRef = FirebaseFirestore.instance.collection('horarios_clinica');
        feriadosRef = FirebaseFirestore.instance.collection('feriados');
        debugPrint('Carregando dados globais');
      }

      // Carregar horários da clínica
      final horariosSnapshot = await horariosRef.get();
      debugPrint('Horários encontrados: ${horariosSnapshot.docs.length}');

      for (final doc in horariosSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final diaSemana = data['diaSemana'] as int?;
        final horaAbertura = data['horaAbertura'] as String? ?? '';
        final horaFecho = data['horaFecho'] as String? ?? '';

        if (diaSemana != null && diaSemana >= 1 && diaSemana <= 7) {
          horarios[diaSemana] = [horaAbertura, horaFecho];
          debugPrint(
              'Horário carregado para dia $diaSemana: $horaAbertura - $horaFecho');
        }
      }

      // Carregar feriados da nova estrutura por ano
      final feriados = <Map<String, dynamic>>[];

      // Carrega apenas o ano atual por padrão (otimização)
      final anoAtual = DateTime.now().year.toString();
      final anoRef = feriadosRef.doc(anoAtual);
      final registosRef = anoRef.collection('registos');

      try {
        final registosSnapshot = await registosRef.get();
        debugPrint(
            'Feriados encontrados no ano $anoAtual: ${registosSnapshot.docs.length}');

        for (final doc in registosSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          feriados.add({
            'id': doc.id,
            'data': data['data'] as String? ?? '',
            'descricao': data['descricao'] as String? ?? '',
          });
        }
      } catch (e) {
        debugPrint('Erro ao carregar feriados do ano $anoAtual: $e');
        // Fallback: tenta carregar de todos os anos
        final anosSnapshot = await feriadosRef.get();
        for (final anoDoc in anosSnapshot.docs) {
          final registosRef = anoDoc.reference.collection('registos');
          final registosSnapshot = await registosRef.get();
          for (final doc in registosSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            feriados.add({
              'id': doc.id,
              'data': data['data'] as String? ?? '',
              'descricao': data['descricao'] as String? ?? '',
            });
          }
        }
        debugPrint('Feriados carregados (fallback): ${feriados.length}');
      }

      this.feriados = feriados;

      // Ordena feriados por data
      feriados.sort((a, b) {
        final dateA = DateTime.tryParse(a['data']) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['data']) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      debugPrint(
          'Dados carregados com sucesso. Horários: ${horarios.length}, Feriados: ${feriados.length}');

      // Atualiza o estado da tela
      setState(() {});
    } catch (e) {
      debugPrint('Erro ao carregar dados do Firestore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  Future<void> _gravarAlteracoes() async {
    try {
      debugPrint('Gravando alterações no Firestore...');

      CollectionReference horariosRef;
      if (widget.unidade != null) {
        horariosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('horarios_clinica');
        debugPrint('Salvando horários na unidade: ${widget.unidade!.id}');
      } else {
        horariosRef = FirebaseFirestore.instance.collection('horarios_clinica');
        debugPrint('Salvando horários globais');
      }

      // Salvar horários da clínica
      for (int ds = 1; ds <= 7; ds++) {
        final horaAbertura = horarios[ds]![0];
        final horaFecho = horarios[ds]![1];

        await horariosRef.doc(ds.toString()).set({
          'diaSemana': ds,
          'horaAbertura': horaAbertura,
          'horaFecho': horaFecho,
        });

        debugPrint('Horário salvo para dia $ds: $horaAbertura - $horaFecho');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alterações gravadas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao gravar alterações: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gravar alterações: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _apagarHorarios(int diaSemana) async {
    try {
      setState(() {
        horarios[diaSemana] = ["", ""];
      });

      CollectionReference horariosRef;
      if (widget.unidade != null) {
        horariosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('horarios_clinica');
      } else {
        horariosRef = FirebaseFirestore.instance.collection('horarios_clinica');
      }

      // Salva no Firestore com horários vazios
      await horariosRef.doc(diaSemana.toString()).set({
        'diaSemana': diaSemana,
        'horaAbertura': '',
        'horaFecho': '',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Horários do dia ${diasSemana[diaSemana - 1]} apagados.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao apagar horários: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao apagar horários: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _adicionarFeriado() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    // Se o usuário cancelou a seleção de data, não faz nada
    if (pickedDate == null) return;

    String descricao = '';

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
      CollectionReference feriadosRef;
      if (widget.unidade != null) {
        feriadosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('feriados');
        debugPrint('Salvando feriado na unidade: ${widget.unidade!.id}');
      } else {
        feriadosRef = FirebaseFirestore.instance.collection('feriados');
        debugPrint('Salvando feriado global');
      }

      // Salva no Firestore na nova estrutura por ano
      final ano = pickedDate.year.toString();
      final anoRef = feriadosRef.doc(ano);
      final registosRef = anoRef.collection('registos');

      final feriadoId = DateTime.now().millisecondsSinceEpoch.toString();
      await registosRef.doc(feriadoId).set({
        'data': pickedDate.toIso8601String(),
        'descricao': descricao.isNotEmpty ? descricao : '',
      });

      // Cria um Map<String, dynamic> explícito para evitar problemas de tipo
      final novoFeriado = <String, dynamic>{
        'id': feriadoId,
        'data': pickedDate.toIso8601String(),
        'descricao': descricao.isNotEmpty ? descricao : '',
      };

      debugPrint('Feriado salvo no ano $ano com ID: $feriadoId');

      debugPrint('Feriado criado: ${novoFeriado.toString()}');

      setState(() {
        debugPrint(
            'Adicionando feriado à lista. Total antes: ${feriados.length}');
        feriados.add(novoFeriado);
        debugPrint('Feriado adicionado. Total depois: ${feriados.length}');

        feriados.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['data'] as String) ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['data'] as String) ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        debugPrint('Feriados ordenados. Total final: ${feriados.length}');
      });

      debugPrint('Feriado salvo no Firestore com ID: $feriadoId');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feriado adicionado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar feriado: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar feriado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removerFeriado(Map<String, dynamic> feriado) async {
    try {
      final feriadoId = feriado['id'] as String?;

      if (feriadoId != null) {
        CollectionReference feriadosRef;
        if (widget.unidade != null) {
          feriadosRef = FirebaseFirestore.instance
              .collection('unidades')
              .doc(widget.unidade!.id)
              .collection('feriados');
        } else {
          feriadosRef = FirebaseFirestore.instance.collection('feriados');
        }

        // Remove do Firestore na nova estrutura por ano
        final dataFeriado = DateTime.tryParse(feriado['data'] as String);
        if (dataFeriado != null) {
          final ano = dataFeriado.year.toString();
          final anoRef = feriadosRef.doc(ano);
          final registosRef = anoRef.collection('registos');

          await registosRef.doc(feriadoId).delete();
          debugPrint('Feriado removido do ano $ano: $feriadoId');
        } else {
          // Fallback: tenta remover da estrutura antiga
          await feriadosRef.doc(feriadoId).delete();
          debugPrint('Feriado removido (fallback): $feriadoId');
        }
      }

      setState(() {
        feriados.remove(feriado);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feriado removido com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao remover feriado: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover feriado: $e'),
          backgroundColor: Colors.red,
        ),
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

    final result = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => CustomTimePickerDialog(
        initialTime: TimeOfDay(hour: h, minute: m),
        onTimeSelected: (picked) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          setState(() {
            if (isAbertura) {
              horarios[ds]![0] = '$hh:$mm';
            } else {
              horarios[ds]![1] = '$hh:$mm';
            }
          });

          // Salva automaticamente após selecionar
          _gravarAlteracoes();
        },
      ),
    );

    // Se o usuário cancelou, não faz nada
    if (result == null) return;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) async {
        await _gravarAlteracoes();
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
                        const SizedBox(height: 26),
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
                                tooltip: "Eliminar",
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
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
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              tooltip: "Novo",
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed:
                                  _adicionarFeriado, // Método para adicionar feriado
                            ),
                          ],
                        ),
                        const Divider(
                          color: Colors.black26,
                          thickness: 2,
                        ),
                        feriados.isEmpty
                            ? const Text('Sem dias assinalados')
                            : Expanded(
                                // Garante que a lista ocupe o espaço disponível no layout pai
                                child: ListView.builder(
                                  shrinkWrap:
                                      true, // Evita problemas de expansão excessiva
                                  itemCount: feriados.length,
                                  itemBuilder: (context, index) {
                                    final f = feriados[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('dd/MM/yyyy').format(
                                                  DateTime.tryParse(f['data']
                                                          as String) ??
                                                      DateTime.now(),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if ((f['descricao'] ?? '')
                                                  .isNotEmpty)
                                                Text(
                                                  f['descricao'],
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                          IconButton(
                                            tooltip: "Eliminar",
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _removerFeriado(
                                                f), // Método para remover o feriado
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
