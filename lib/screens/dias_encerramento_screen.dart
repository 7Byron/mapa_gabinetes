import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';

/// Tela para gerenciar dias de encerramento da clínica
/// Permite configurar feriados, manutenções e outros dias de encerramento
/// Os dados são organizados por unidade e ano para melhor organização

class DiasEncerramentoScreen extends StatefulWidget {
  final Unidade? unidade;

  const DiasEncerramentoScreen({super.key, this.unidade});

  @override
  State<DiasEncerramentoScreen> createState() => _DiasEncerramentoScreenState();
}

class _DiasEncerramentoScreenState extends State<DiasEncerramentoScreen> {
  List<Map<String, dynamic>> diasEncerramento = [];
  String anoSelecionado = DateTime.now().year.toString();
  List<String> anosDisponiveis = [];

  @override
  void initState() {
    super.initState();
    debugPrint(
        'DiasEncerramentoScreen inicializada. Unidade: ${widget.unidade?.id ?? 'null'}');
    _carregarAnosDisponiveis();
    _carregarDiasEncerramento();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carregarDiasEncerramento();
  }

  Future<void> _carregarAnosDisponiveis() async {
    try {
      CollectionReference encerramentosRef;
      if (widget.unidade != null) {
        encerramentosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('encerramentos');
      } else {
        encerramentosRef = FirebaseFirestore.instance.collection('encerramentos');
      }

      final anosSnapshot = await encerramentosRef.get();
      final anos = <String>[];
      
      for (final doc in anosSnapshot.docs) {
        anos.add(doc.id);
      }
      
      // Adiciona o ano atual se não existir
      if (!anos.contains(anoSelecionado)) {
        anos.add(anoSelecionado);
      }
      
      // Ordena os anos
      anos.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
      
      setState(() {
        anosDisponiveis = anos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar anos disponíveis: $e');
    }
  }

  Future<void> _carregarDiasEncerramento() async {
    try {
      debugPrint('Carregando dias de encerramento do ano $anoSelecionado...');

      CollectionReference encerramentosRef;
      if (widget.unidade != null) {
        encerramentosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('encerramentos');
        debugPrint('Carregando dados da unidade: ${widget.unidade!.id}');
      } else {
        encerramentosRef = FirebaseFirestore.instance.collection('encerramentos');
        debugPrint('Carregando dados globais');
      }

      final anoRef = encerramentosRef.doc(anoSelecionado);
      final registosRef = anoRef.collection('registos');

      final registosSnapshot = await registosRef.get();
      debugPrint('Dias de encerramento encontrados: ${registosSnapshot.docs.length}');

      final dias = <Map<String, dynamic>>[];
      for (final doc in registosSnapshot.docs) {
        final data = doc.data();
        dias.add({
          'id': doc.id,
          'data': data['data'] as String? ?? '',
          'descricao': data['descricao'] as String? ?? '',
          'motivo': data['motivo'] as String? ?? 'Encerramento',
        });
      }

      // Ordena por data
      dias.sort((a, b) {
        final dateA = DateTime.tryParse(a['data']) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['data']) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      setState(() {
        diasEncerramento = dias;
      });

      debugPrint('Dias de encerramento carregados: ${dias.length}');
    } catch (e) {
      debugPrint('Erro ao carregar dias de encerramento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  Future<void> _adicionarDiaEncerramento() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    String descricao = '';
    String motivo = 'Encerramento';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Adicionar Dia de Encerramento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Descrição (Opcional)',
                  hintText: 'Ex.: Feriado Nacional',
                ),
                onChanged: (value) => descricao = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                ),
                value: motivo,
                items: const [
                  DropdownMenuItem(value: 'Encerramento', child: Text('Encerramento')),
                  DropdownMenuItem(value: 'Feriado', child: Text('Feriado')),
                  DropdownMenuItem(value: 'Manutenção', child: Text('Manutenção')),
                  DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                ],
                onChanged: (value) => motivo = value ?? 'Encerramento',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    try {
      CollectionReference encerramentosRef;
      if (widget.unidade != null) {
        encerramentosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('encerramentos');
        debugPrint('Salvando dia de encerramento na unidade: ${widget.unidade!.id}');
      } else {
        encerramentosRef = FirebaseFirestore.instance.collection('encerramentos');
        debugPrint('Salvando dia de encerramento global');
      }

      final ano = pickedDate.year.toString();
      final anoRef = encerramentosRef.doc(ano);
      final registosRef = anoRef.collection('registos');

      final diaId = DateTime.now().millisecondsSinceEpoch.toString();
      await registosRef.doc(diaId).set({
        'data': pickedDate.toIso8601String(),
        'descricao': descricao.isNotEmpty ? descricao : '',
        'motivo': motivo,
      });

      final novoDia = <String, dynamic>{
        'id': diaId,
        'data': pickedDate.toIso8601String(),
        'descricao': descricao.isNotEmpty ? descricao : '',
        'motivo': motivo,
      };

      debugPrint('Dia de encerramento salvo no ano $ano com ID: $diaId');

      setState(() {
        diasEncerramento.add(novoDia);
        diasEncerramento.sort((a, b) {
          final dateA = DateTime.tryParse(a['data'] as String) ?? DateTime.now();
          final dateB = DateTime.tryParse(b['data'] as String) ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dia de encerramento adicionado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao salvar dia de encerramento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar dia de encerramento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removerDiaEncerramento(Map<String, dynamic> dia) async {
    try {
      final diaId = dia['id'] as String?;

      if (diaId != null) {
        CollectionReference encerramentosRef;
        if (widget.unidade != null) {
          encerramentosRef = FirebaseFirestore.instance
              .collection('unidades')
              .doc(widget.unidade!.id)
              .collection('encerramentos');
        } else {
          encerramentosRef = FirebaseFirestore.instance.collection('encerramentos');
        }

        final dataDia = DateTime.tryParse(dia['data'] as String);
        if (dataDia != null) {
          final ano = dataDia.year.toString();
          final anoRef = encerramentosRef.doc(ano);
          final registosRef = anoRef.collection('registos');

          await registosRef.doc(diaId).delete();
          debugPrint('Dia de encerramento removido do ano $ano: $diaId');
        }
      }

      setState(() {
        diasEncerramento.remove(dia);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dia de encerramento removido com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao remover dia de encerramento: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover dia de encerramento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getMotivoColor(String motivo) {
    switch (motivo) {
      case 'Feriado':
        return Colors.red;
      case 'Manutenção':
        return Colors.orange;
      case 'Encerramento':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Dias de Encerramento'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Seletor de ano
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Ano: ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: anoSelecionado,
                      items: anosDisponiveis.map((ano) {
                        return DropdownMenuItem(
                          value: ano,
                          child: Text(ano),
                        );
                      }).toList(),
                      onChanged: (String? novoAno) {
                        if (novoAno != null) {
                          setState(() {
                            anoSelecionado = novoAno;
                          });
                          _carregarDiasEncerramento();
                        }
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _adicionarDiaEncerramento,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Lista de dias de encerramento
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: diasEncerramento.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum dia de encerramento configurado para este ano',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: diasEncerramento.length,
                          itemBuilder: (context, index) {
                            final dia = diasEncerramento[index];
                            final data = DateTime.tryParse(dia['data'] as String) ?? DateTime.now();
                            final motivo = dia['motivo'] as String? ?? 'Encerramento';
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getMotivoColor(motivo),
                                  child: Icon(
                                    _getMotivoIcon(motivo),
                                    color: Colors.white,
                                  ),
                                ),
                                                                 title: Text(
                                   DateFormat('dd/MM/yyyy (EEEE)').format(data),
                                   style: const TextStyle(fontWeight: FontWeight.bold),
                                 ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      motivo,
                                      style: TextStyle(
                                        color: _getMotivoColor(motivo),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if ((dia['descricao'] ?? '').isNotEmpty)
                                      Text(
                                        dia['descricao'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removerDiaEncerramento(dia),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMotivoIcon(String motivo) {
    switch (motivo) {
      case 'Feriado':
        return Icons.celebration;
      case 'Manutenção':
        return Icons.build;
      case 'Encerramento':
        return Icons.block;
      default:
        return Icons.event_busy;
    }
  }
} 