import 'package:flutter/material.dart';
import 'package:mapa_gabinetes/widgets/custom_appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unidade.dart';
import '../widgets/horario_abertura_quadro.dart';
import '../utils/ui_atualizar_dia.dart';

/// Tela para configurar horários de funcionamento da clínica
/// Permite definir horários de abertura e fechamento para cada dia da semana
/// Inclui configurações de encerramento: nunca encerra, dias específicos e feriados
/// Os dados são salvos por unidade para permitir configurações específicas
///
/// Funcionalidades principais:
/// - Configuração de horários por dia da semana
/// - Checkbox "Nunca encerra" para clínicas 24h
/// - Opções de encerramento por dia específico
/// - Configuração de encerramento em feriados
/// - Interface com largura máxima de 720px para melhor responsividade
/// - Caixas uniformes para checkboxes "Encerrado" com estilo consistente

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

  // Configurações de encerramento
  bool nuncaEncerra = false;
  Map<int, bool> encerraDias = {
    1: false, // Segunda-feira
    2: false, // Terça-feira
    3: false, // Quarta-feira
    4: false, // Quinta-feira
    5: false, // Sexta-feira
    6: false, // Sábado
    7: false, // Domingo
  };
  bool encerraFeriados = false;

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

      if (widget.unidade != null) {
        // Carrega dados da unidade específica
        horariosRef = FirebaseFirestore.instance
            .collection('unidades')
            .doc(widget.unidade!.id)
            .collection('horarios_clinica');
        debugPrint('Carregando dados da unidade: ${widget.unidade!.id}');
      } else {
        // Carrega dados globais (fallback para compatibilidade)
        horariosRef = FirebaseFirestore.instance.collection('horarios_clinica');
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

      // Carregar configurações de encerramento
      final configDoc = await horariosRef.doc('config').get();
      if (configDoc.exists) {
        final configData = configDoc.data() as Map<String, dynamic>;
        setState(() {
          nuncaEncerra = configData['nuncaEncerra'] as bool? ?? false;
          encerraFeriados = configData['encerraFeriados'] as bool? ?? false;

          // Carregar configurações por dia
          for (int i = 1; i <= 7; i++) {
            encerraDias[i] = configData['encerraDia$i'] as bool? ?? false;
          }
        });
        debugPrint('Configurações de encerramento carregadas');
      }

      debugPrint('Dados carregados com sucesso. Horários: ${horarios.length}');

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

      // Salvar configurações de encerramento
      final configData = <String, dynamic>{
        'nuncaEncerra': nuncaEncerra,
        'encerraFeriados': encerraFeriados,
      };

      // Adicionar configurações por dia
      for (int i = 1; i <= 7; i++) {
        configData['encerraDia$i'] = encerraDias[i];
      }

      await horariosRef.doc('config').set(configData);
      debugPrint('Configurações de encerramento salvas');

      // Invalidar cache de horários e configurações após salvar
      if (widget.unidade != null) {
        await invalidateCacheEncerramento(widget.unidade!.id);
        debugPrint('🗑️ Cache de horários invalidado após salvar alterações');
      }

      if (!mounted) return;
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

  Future<void> _escolherHora(int ds, bool isAbertura) async {
    final textoAtual = isAbertura ? horarios[ds]![0] : horarios[ds]![1];
    final parts = textoAtual.split(':');
    int h = 8, m = 0;
    if (parts.length == 2) {
      h = int.tryParse(parts[0]) ?? 8;
      m = int.tryParse(parts[1]) ?? 0;
    }
    if (h < 0 || h > 23) h = 8;
    if (m < 0 || m > 59) m = 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

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
    await _gravarAlteracoes();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _gravarAlteracoes();
      },
      child: Scaffold(
        appBar: CustomAppBar(title: 'Horário de Abertura'),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    HorarioAberturaQuadro(
                      horarios: horarios,
                      diasSemana: diasSemana,
                      nuncaEncerra: nuncaEncerra,
                      encerraDias: encerraDias,
                      encerraFeriados: encerraFeriados,
                      onNuncaEncerraChanged: (valor) {
                        setState(() {
                          nuncaEncerra = valor;
                          if (nuncaEncerra) {
                            for (var dia = 1; dia <= 7; dia++) {
                              encerraDias[dia] = false;
                            }
                            encerraFeriados = false;
                          }
                        });
                        _gravarAlteracoes();
                      },
                      onEncerradoChanged: (dia, valor) {
                        setState(() => encerraDias[dia] = valor);
                        _gravarAlteracoes();
                      },
                      onFeriadosChanged: (valor) {
                        setState(() => encerraFeriados = valor);
                        _gravarAlteracoes();
                      },
                      onEscolherHora: _escolherHora,
                      onApagar: _apagarHorarios,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
