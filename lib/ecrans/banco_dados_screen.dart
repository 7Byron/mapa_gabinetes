// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../banco_dados/database_helper.dart';
import '../class/medico.dart';
import '../class/gabinete.dart';
import '../class/alocacao.dart';
import '../class/disponibilidade.dart';

class BancoDadosScreen extends StatefulWidget {
  @override
  _BancoDadosScreenState createState() => _BancoDadosScreenState();
}

class _BancoDadosScreenState extends State<BancoDadosScreen> {
  List<Medico> medicos = [];
  List<Gabinete> gabinetes = [];
  List<Disponibilidade> disponibilidades = [];
  List<Alocacao> alocacoes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _deleteAllData() async {
    await DatabaseHelper.deleteAllData();
    setState(() {
      medicos.clear();
      gabinetes.clear();
      disponibilidades.clear();
      alocacoes.clear();
    });
  }

  void _showDeleteAllConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmação'),
          content: Text('Tem certeza que deseja apagar todos os dados?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Excluir'),
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

  Future<void> _loadData() async {
    medicos = await DatabaseHelper.buscarMedicos();
    gabinetes = await DatabaseHelper.buscarGabinetes();
    disponibilidades = await DatabaseHelper.buscarTodasDisponibilidades();
    alocacoes = await DatabaseHelper.buscarAlocacoes();
    setState(() {});
  }

  Future<void> _deleteMedico(String medicoId) async {
    await DatabaseHelper.deletarMedico(medicoId);
    setState(() {
      medicos.removeWhere((m) => m.id == medicoId);
    });
  }

  Future<void> _deleteGabinete(String gabineteId) async {
    await DatabaseHelper.deletarGabinete(gabineteId);
    setState(() {
      gabinetes.removeWhere((g) => g.id == gabineteId);
    });
  }

  Future<void> _deleteDisponibilidade(String disponibilidadeId) async {
    await DatabaseHelper.deletarDisponibilidade(disponibilidadeId);
    setState(() {
      disponibilidades.removeWhere((d) => d.id == disponibilidadeId);
    });
  }

  Future<void> _deleteAlocacao(String alocacaoId) async {
    await DatabaseHelper.deletarAlocacao(alocacaoId);
    setState(() {
      alocacoes.removeWhere((a) => a.id == alocacaoId);
    });
  }

  Future<void> _editMedico(Medico medico) async {
    // Implementar a lógica de edição aqui
    // ...
    await DatabaseHelper.atualizarMedico(medico);
    setState(() {
      // Atualizar a lista de médicos
      final index = medicos.indexWhere((element) => element.id == medico.id);
      if (index != -1) {
        medicos[index] = medico;
      }
    });
  }

  Future<void> _editGabinete(Gabinete gabinete) async {
    // Implementar a lógica de edição aqui
    // ...
    await DatabaseHelper.atualizarGabinete(gabinete);
    setState(() {
      // Atualizar a lista de gabinetes
      final index = gabinetes.indexWhere((element) =>
      element.id == gabinete.id);
      if (index != -1) {
        gabinetes[index] = gabinete;
      }
    });
  }

  Future<void> _editDisponibilidade(Disponibilidade disponibilidade) async {
    // Implementar a lógica de edição aqui
    // ...
    await DatabaseHelper.atualizarDisponibilidade(disponibilidade);
    setState(() {
      // Atualizar a lista de disponibilidades
      final index = disponibilidades.indexWhere((element) =>
      element.id == disponibilidade.id);
      if (index != -1) {
        disponibilidades[index] = disponibilidade;
      }
    });
  }

  Future<void> _editAlocacao(Alocacao alocacao) async {
    // Implementar a lógica de edição aqui
    // ...
    await DatabaseHelper.atualizarAlocacao(alocacao);
    setState(() {
      // Atualizar a lista de alocações
      final index = alocacoes.indexWhere((element) =>
      element.id == alocacao.id);
      if (index != -1) {
        alocacoes[index] = alocacao;
      }
    });
  }

  /// **Mostrar a localização do banco de dados**
  Future<void> _showDatabaseLocation() async {
    final dbDirectory = await getApplicationSupportDirectory();
    final dbPath = "${dbDirectory.path}/clinica_v2.db";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Localização da Base de Dados'),
          content: Text(dbPath),
          actions: <Widget>[
            TextButton(
              child: Text('Fechar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Banco de Dados'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () {
              _showDeleteAllConfirmationDialog();
            },
            tooltip: 'Apagar todos os dados',
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              _showDatabaseLocation(); // Mostra o caminho da base de dados
            },
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMedicoList() {
    return medicos.isEmpty
        ? Center(child: Text('Nenhum médico encontrado.'))
        : ListView.builder(
      shrinkWrap: true,
      itemCount: medicos.length,
      itemBuilder: (context, index) {
        final medico = medicos[index];
        return ListTile(
          title: Text("${medico.nome}-${medico.especialidade}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _showEditMedicoDialog(medico);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                      'Tem certeza que deseja excluir o médico ${medico.nome}?',
                      medico.id,
                      _deleteMedico);
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
    return gabinetes.isEmpty
        ? Center(child: Text('Nenhum gabinete encontrado.'))
        : ListView.builder(
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
                icon: Icon(Icons.edit),
                onPressed: () {
                  _showEditGabineteDialog(gabinete);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                      'Tem certeza que deseja excluir o gabinete ${gabinete
                          .nome}?',
                      gabinete.id,
                      _deleteGabinete);
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
    return disponibilidades.isEmpty
        ? Center(child: Text('Nenhuma disponibilidade encontrada.'))
        : ListView.builder(
      shrinkWrap: true,
      itemCount: disponibilidades.length,
      itemBuilder: (context, index) {
        final disponibilidade = disponibilidades[index];
        return ListTile(
          title: Text(disponibilidade.id),
          subtitle: Text(disponibilidade.medicoId),
          trailing: Row(
            mainAxisSize: MainAxisSize.min, //
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _showEditDisponibilidadeDialog(disponibilidade);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                      'Tem certeza que deseja excluir a disponibilidade ${disponibilidade.id}?',
                      disponibilidade.id,
                      _deleteDisponibilidade);
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
    return alocacoes.isEmpty
        ? Center(child: Text('Nenhuma alocação encontrada.'))
        : ListView.builder(
      shrinkWrap: true,
      itemCount: alocacoes.length,
      itemBuilder: (context, index) {
        final alocacao = alocacoes[index];
        return ListTile(
          title: Text(alocacao.id),
          subtitle: Text('Médico: ${alocacao.medicoId}, Gabinete: ${alocacao.gabineteId}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min, // sSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  _showEditAlocacaoDialog(alocacao);
                },
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(
                      'Tem certeza que deseja excluir a alocação ${alocacao.id}?',
                      alocacao.id,
                      _deleteAlocacao);
                },
                tooltip: 'Excluir',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String message, String id, Function deleteFunction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmação'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Excluir'),
              onPressed: () {
                deleteFunction(id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditMedicoDialog(Medico medico) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newName = medico.nome;
        String newEspecialidade = medico.especialidade;
        return AlertDialog(
          title: Text('Editar Médico'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: medico.nome,
                decoration: InputDecoration(labelText: 'Nome'),
                onChanged: (value) {
                  newName = value;
                },
              ),
              TextFormField(
                initialValue: medico.especialidade,
                decoration: InputDecoration(labelText: 'Especialidade'),
                onChanged: (value) {
                  newEspecialidade = value;
                  medico.especialidade = newEspecialidade;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
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

  void _showEditGabineteDialog(Gabinete gabinete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newName = gabinete.nome;
        return AlertDialog(
          title: Text('Editar Gabinete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: gabinete.nome,
                decoration: InputDecoration(labelText: 'Nome'),
                onChanged: (value) {
                  newName = value;
                  gabinete.nome = newName;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
              onPressed: () {
                _editGabinete(gabinete);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditDisponibilidadeDialog(Disponibilidade disponibilidade) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newId = disponibilidade.id;
        String newMedicoId = disponibilidade.medicoId;
        List<String> newHorarios = disponibilidade.horarios;
        return AlertDialog(
          title: Text('Editar Disponibilidade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: disponibilidade.id,
                decoration: InputDecoration(labelText: 'Id'),
                onChanged: (value) {
                  newId = value;
                  disponibilidade.id = newId;
                },
              ),
              TextFormField(
                initialValue: disponibilidade.medicoId,
                decoration: InputDecoration(labelText: 'MedicoId'),
                onChanged: (value) {
                  newMedicoId = value;
                  disponibilidade.medicoId = newMedicoId;
                },
              ),
              TextFormField(
                initialValue: disponibilidade.horarios.join(', '),
                decoration: InputDecoration(labelText: 'Horarios'),
                onChanged: (value) {
                  newHorarios = value.split(', ');
                  disponibilidade.horarios = newHorarios;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
              onPressed: () {
                disponibilidade.id = newId;
                disponibilidade.medicoId = newMedicoId;
                disponibilidade.horarios = newHorarios;
                _editDisponibilidade(disponibilidade);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditAlocacaoDialog(Alocacao alocacao) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newId = alocacao.id;
        String newMedicoId = alocacao.medicoId;
        String newGabineteId = alocacao.gabineteId;
        String newHorarioInicio = alocacao.horarioInicio;
        return AlertDialog(
          title: Text('Editar Alocacao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: alocacao.id,
                decoration: InputDecoration(labelText: 'Id'),
                onChanged: (value) {
                  newId = value;
                  alocacao.id = newId;
                },
              ),
              TextFormField(
                initialValue: alocacao.medicoId,
                decoration: InputDecoration(labelText: 'MedicoId'),
                onChanged: (value) {
                  newMedicoId = value;
                  alocacao.medicoId = newMedicoId;
                },
              ),
              TextFormField(
                initialValue: alocacao.gabineteId,
                decoration: InputDecoration(labelText: 'GabineteId'),
                onChanged: (value) {
                  newGabineteId = value;
                  alocacao.gabineteId = newGabineteId;
                },
              ),
              TextFormField(
                initialValue: alocacao.horarioInicio,
                decoration: InputDecoration(labelText: 'HorarioInicio'),
                onChanged: (value) {
                  newHorarioInicio = value;
                  alocacao.horarioInicio = newHorarioInicio;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
              onPressed: () {
                alocacao.id = newId;
                alocacao.medicoId = newMedicoId;
                alocacao.gabineteId = newGabineteId;
                alocacao.horarioInicio = newHorarioInicio;
                _editAlocacao(alocacao);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}