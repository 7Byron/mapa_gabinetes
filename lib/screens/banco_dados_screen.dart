// settings_screen.dart (ou banco_dados_screen.dart)

import 'package:flutter/material.dart';
// IMPORT CORRETO: sem "path_pr", e sim "path_provider" oficial
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/medico.dart';
import '../models/gabinete.dart';
import '../models/disponibilidade.dart';
import '../models/alocacao.dart';

class BancoDadosScreen extends StatefulWidget {
  const BancoDadosScreen({super.key});

  @override
  BancoDadosScreenState createState() => BancoDadosScreenState();
}

class BancoDadosScreenState extends State<BancoDadosScreen> {
  List<Medico> medicos = [];
  List<Gabinete> gabinetes = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];
  List<Map<String, dynamic>> horariosClinica = [];
  List<Map<String, dynamic>> feriados = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Carrega todos os dados do banco (médicos, gabinetes, disponibilidades, alocações)
  Future<void> _loadData() async {
    medicos = await DatabaseHelper.buscarMedicos();
    gabinetes = await DatabaseHelper.buscarGabinetes();
    disponibilidades = await DatabaseHelper.buscarTodasDisponibilidades();
    alocacoes = await DatabaseHelper.buscarAlocacoes();
    horariosClinica = await DatabaseHelper.buscarHorariosClinica();
    feriados = await DatabaseHelper.buscarFeriados();
    setState(() {});
  }

  Widget _buildHorariosClinicaList() {
    if (horariosClinica.isEmpty) {
      return const Center(child: Text('Nenhum horário encontrado.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: horariosClinica.length,
      itemBuilder: (context, index) {
        final horario = horariosClinica[index];
        return ListTile(
          title: Text('Dia ${horario['diaSemana']}'),
          subtitle: Text(
            'Início: ${horario['horaAbertura']}, Fim: ${horario['horaFecho']}',
          ),
        );
      },
    );
  }

  Widget _buildFeriadosList() {
    if (feriados.isEmpty) {
      return const Center(child: Text('Nenhum feriado encontrado.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: feriados.length,
      itemBuilder: (context, index) {
        final feriado = feriados[index];
        return ListTile(
          title: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(feriado['data']))),
          subtitle: Text(feriado['descricao']),
        );
      },
    );
  }


  /// Apaga todos os dados (médicos, gabinetes, disponibilidades, alocações)
  Future<void> _deleteAllData() async {
    await DatabaseHelper.deleteAllData();
    setState(() {
      medicos.clear();
      gabinetes.clear();
      disponibilidades.clear();
      alocacoes.clear();
    });
  }

  /// Mostra um diálogo de confirmação para apagar tudo
  void _showDeleteAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmação'),
          content: const Text('Tem certeza que deseja apagar todos os dados?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Excluir'),
              onPressed: () {
                _deleteAllData();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Mostra a localização do banco de dados no sistema
  Future<void> _showDatabaseLocation() async {
    final dbDirectory = await getApplicationSupportDirectory();
    final dbPath = "${dbDirectory.path}/mapa_gabinetes.db";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Localização da Base de Dados'),
          content: Text(dbPath),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  /// Deleta um médico específico
  Future<void> _deleteMedico(String medicoId) async {
    await DatabaseHelper.deletarMedico(medicoId);
    setState(() {
      medicos.removeWhere((m) => m.id == medicoId);
    });
  }

  /// Deleta um gabinete específico
  Future<void> _deleteGabinete(String gabineteId) async {
    await DatabaseHelper.deletarGabinete(gabineteId);
    setState(() {
      gabinetes.removeWhere((g) => g.id == gabineteId);
    });
  }

  /// Deleta uma disponibilidade específica
  Future<void> _deleteDisponibilidade(String disponibilidadeId) async {
    await DatabaseHelper.deletarDisponibilidade(disponibilidadeId);
    setState(() {
      disponibilidades.removeWhere((d) => d.id == disponibilidadeId);
    });
  }

  /// Deleta uma alocação específica
  Future<void> _deleteAlocacao(String alocacaoId) async {
    await DatabaseHelper.deletarAlocacao(alocacaoId);
    setState(() {
      alocacoes.removeWhere((a) => a.id == alocacaoId);
    });
  }

  /// Edita (atualiza) o médico no banco
  Future<void> _editMedico(Medico medico) async {
    await DatabaseHelper.atualizarMedico(medico);
    setState(() {
      final index = medicos.indexWhere((m) => m.id == medico.id);
      if (index != -1) {
        medicos[index] = medico;
      }
    });
  }

  /// Edita (atualiza) o gabinete
  Future<void> _editGabinete(Gabinete gabinete) async {
    await DatabaseHelper.atualizarGabinete(gabinete);
    setState(() {
      final index = gabinetes.indexWhere((g) => g.id == gabinete.id);
      if (index != -1) {
        gabinetes[index] = gabinete;
      }
    });
  }

  /// Edita (atualiza) a disponibilidade
  Future<void> _editDisponibilidade(Disponibilidade disp) async {
    await DatabaseHelper.atualizarDisponibilidade(disp);
    setState(() {
      final index = disponibilidades.indexWhere((d) => d.id == disp.id);
      if (index != -1) {
        disponibilidades[index] = disp;
      }
    });
  }

  /// Edita (atualiza) a alocação
  Future<void> _editAlocacao(Alocacao aloc) async {
    await DatabaseHelper.atualizarAlocacao(aloc);
    setState(() {
      final index = alocacoes.indexWhere((a) => a.id == aloc.id);
      if (index != -1) {
        alocacoes[index] = aloc;
      }
    });
  }

  /// Diálogo genérico de confirmação de exclusão
  void _showDeleteConfirmationDialog(
      String message,
      String id,
      Function(String) deleteFunction,
      ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirmação'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Excluir'),
              onPressed: () {
                deleteFunction(id);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Editar médico: mostra um diálogo com textfields
  void _showEditMedicoDialog(Medico medico) {
    showDialog(
      context: context,
      builder: (context) {
        String newName = medico.nome;
        String newEspecialidade = medico.especialidade;
        return AlertDialog(
          title: const Text('Editar Médico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: medico.nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (value) {
                  newName = value;
                },
              ),
              TextFormField(
                initialValue: medico.especialidade,
                decoration: const InputDecoration(labelText: 'Especialidade'),
                onChanged: (value) {
                  newEspecialidade = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () {
                medico.nome = newName;
                medico.especialidade = newEspecialidade;
                _editMedico(medico);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Editar gabinete: mostra um diálogo
  void _showEditGabineteDialog(Gabinete gabinete) {
    showDialog(
      context: context,
      builder: (context) {
        String newName = gabinete.nome;
        return AlertDialog(
          title: const Text('Editar Gabinete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: gabinete.nome,
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (value) {
                  newName = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () {
                gabinete.nome = newName;
                _editGabinete(gabinete);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Editar disponibilidade
  void _showEditDisponibilidadeDialog(Disponibilidade disp) {
    showDialog(
      context: context,
      builder: (context) {
        // Precisamos de variáveis locais para não sobrescrever imediatamente
        String newId = disp.id;
        String newMedicoId = disp.medicoId;
        List<String> newHorarios = [...disp.horarios];

        return AlertDialog(
          title: const Text('Editar Disponibilidade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: disp.id,
                decoration: const InputDecoration(labelText: 'Id'),
                onChanged: (value) {
                  newId = value;
                },
              ),
              TextFormField(
                initialValue: disp.medicoId,
                decoration: const InputDecoration(labelText: 'MedicoId'),
                onChanged: (value) {
                  newMedicoId = value;
                },
              ),
              TextFormField(
                initialValue: newHorarios.join(', '),
                decoration: const InputDecoration(labelText: 'Horarios'),
                onChanged: (value) {
                  newHorarios = value.split(', ');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () {
                // Atualiza os campos
                disp.id = newId;
                disp.medicoId = newMedicoId;
                disp.horarios = newHorarios;

                _editDisponibilidade(disp);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Editar alocação
  void _showEditAlocacaoDialog(Alocacao aloc) {
    showDialog(
      context: context,
      builder: (context) {
        String newId = aloc.id;
        String newMedicoId = aloc.medicoId;
        String newGabineteId = aloc.gabineteId;
        String newHorarioInicio = aloc.horarioInicio;

        return AlertDialog(
          title: const Text('Editar Alocacao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: aloc.id,
                decoration: const InputDecoration(labelText: 'Id'),
                onChanged: (value) {
                  newId = value;
                },
              ),
              TextFormField(
                initialValue: aloc.medicoId,
                decoration: const InputDecoration(labelText: 'MedicoId'),
                onChanged: (value) {
                  newMedicoId = value;
                },
              ),
              TextFormField(
                initialValue: aloc.gabineteId,
                decoration: const InputDecoration(labelText: 'GabineteId'),
                onChanged: (value) {
                  newGabineteId = value;
                },
              ),
              TextFormField(
                initialValue: aloc.horarioInicio,
                decoration: const InputDecoration(labelText: 'HorarioInicio'),
                onChanged: (value) {
                  newHorarioInicio = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () {
                // Atualiza
                aloc.id = newId;
                aloc.medicoId = newMedicoId;
                aloc.gabineteId = newGabineteId;
                aloc.horarioInicio = newHorarioInicio;

                _editAlocacao(aloc);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // AQUI ESTÃO OS MÉTODOS _buildSectionTitle, _buildMedicoList, etc.
  // ------------------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMedicoList() {
    if (medicos.isEmpty) {
      return const Center(child: Text('Nenhum médico encontrado.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: medicos.length,
      itemBuilder: (context, index) {
        final medico = medicos[index];
        return ListTile(
          title: Text("${medico.nome} - ${medico.especialidade}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditMedicoDialog(medico);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                    'Tem certeza que deseja excluir o médico ${medico.nome}?',
                    medico.id,
                    _deleteMedico,
                  );
                },
                tooltip: 'Excluir',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGabineteList() {
    if (gabinetes.isEmpty) {
      return const Center(child: Text('Nenhum gabinete encontrado.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: gabinetes.length,
      itemBuilder: (context, index) {
        final gabinete = gabinetes[index];
        return ListTile(
          title: Text(gabinete.nome),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditGabineteDialog(gabinete);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                    'Tem certeza que deseja excluir o gabinete ${gabinete.nome}?',
                    gabinete.id,
                    _deleteGabinete,
                  );
                },
                tooltip: 'Excluir',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisponibilidadeList() {
    if (disponibilidades.isEmpty) {
      return const Center(child: Text('Nenhuma disponibilidade encontrada.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: disponibilidades.length,
      itemBuilder: (context, index) {
        final disp = disponibilidades[index];
        return ListTile(
          title: Text(disp.id),
          subtitle: Text('Médico: ${disp.medicoId} | Tipo: ${disp.tipo}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditDisponibilidadeDialog(disp);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                    'Tem certeza que deseja excluir a disponibilidade ${disp.id}?',
                    disp.id,
                    _deleteDisponibilidade,
                  );
                },
                tooltip: 'Excluir',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlocacaoList() {
    if (alocacoes.isEmpty) {
      return const Center(child: Text('Nenhuma alocação encontrada.'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: alocacoes.length,
      itemBuilder: (context, index) {
        final aloc = alocacoes[index];
        return ListTile(
          title: Text(aloc.id),
          subtitle: Text(
            'Médico: ${aloc.medicoId}, Gabinete: ${aloc.gabineteId}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditAlocacaoDialog(aloc),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                    'Tem certeza que deseja excluir a alocação ${aloc.id}?',
                    aloc.id,
                    _deleteAlocacao,
                  );
                },
                tooltip: 'Excluir',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de Dados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _showDeleteAllConfirmationDialog,
            tooltip: 'Apagar todos os dados',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDatabaseLocation,
            tooltip: 'Ver localização do banco de dados',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Médicos'),
            _buildMedicoList(),
            _buildSectionTitle('Gabinetes'),
            _buildGabineteList(),
            _buildSectionTitle('Disponibilidades'),
            _buildDisponibilidadeList(),
            _buildSectionTitle('Alocações'),
            _buildAlocacaoList(),
            _buildSectionTitle('Horários da Clínica'),
            _buildHorariosClinicaList(),
            _buildSectionTitle('Feriados'),
            _buildFeriadosList(),
          ],
        ),
      ),
    );
  }
}
