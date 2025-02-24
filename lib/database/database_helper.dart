import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'init_banco_dados.dart';
import '../models/alocacao.dart';
import '../models/disponibilidade.dart';
import '../models/gabinete.dart';
import '../models/medico.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  // -------------------------------------------------------
  // GABINETES
  // -------------------------------------------------------
  static Future<List<Gabinete>> buscarGabinetes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('gabinetes');
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return Gabinete(
        id: maps[i]['id'].toString(),
        nome: maps[i]['nome'].toString(),
        setor: maps[i]['setor'].toString(),
        especialidadesPermitidas:
            maps[i]['especialidades'].toString().split(',').toList(),
      );
    });
  }

  static Future<Gabinete> buscarGabinetePorId(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('gabinetes', where: 'id = ?', whereArgs: [id]);
    return Gabinete(
      id: maps.first['id'],
      nome: maps.first['nome'],
      setor: maps.first['setor'],
      especialidadesPermitidas:
          maps.first['especialidades'].toString().split(',').toList(),
    );
  }

  static Future<void> salvarGabinete(Gabinete gabinete) async {
    final db = await database;
    await db.insert(
      'gabinetes',
      gabinete.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> atualizarGabinete(Gabinete gabinete) async {
    final db = await database;
    await db.update(
      'gabinetes',
      gabinete.toMap(),
      where: 'id = ?',
      whereArgs: [gabinete.id],
    );
  }

  static Future<void> deletarGabinete(String id) async {
    final db = await database;
    await db.delete(
      'gabinetes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('medicos');
    await db.delete('gabinetes');
    await db.delete('disponibilidades');
    await db.delete('alocacoes');
    await db.delete('especialidades');
  }

  // -------------------------------------------------------
  // MÉDICOS
  // -------------------------------------------------------
  static Future<List<Medico>> buscarMedicos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('medicos');
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return Medico(
        id: maps[i]['id'].toString(),
        nome: maps[i]['nome'].toString(),
        especialidade: maps[i]['especialidade'].toString(),
        observacoes: maps[i]['observacoes']?.toString(),
        disponibilidades: [],
      );
    });
  }

  static Future<Medico> buscarMedicoPorId(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('medicos', where: 'id = ?', whereArgs: [id]);
    return Medico(
      id: maps.first['id'],
      nome: maps.first['nome'],
      especialidade: maps.first['especialidade'],
      disponibilidades: [],
    );
  }

  static Future<Medico?> buscarMedico(String medicoId) async {
    final db = await database;
    final result = await db.query(
      'medicos',
      where: 'id = ?',
      whereArgs: [medicoId],
    );
    if (result.isNotEmpty) {
      final medico = result.first;
      final disponibilidades = await buscarDisponibilidadesPorMedico(medicoId);
      return Medico(
        id: medico['id'] as String,
        nome: medico['nome'] as String,
        especialidade: medico['especialidade'] as String,
        disponibilidades: disponibilidades,
      );
    }
    return null;
  }

  static Future<void> salvarMedico(Medico medico) async {
    final db = await database;
    try {
      if (kDebugMode) {
        print('Tentando salvar o médico: ${medico.toMap()}');
      }
      // Insere/Atualiza o médico
      await db.insert(
        'medicos',
        medico.toMap(), // Agora usamos o método `toMap` da classe `Medico`
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insere/Atualiza as disponibilidades associadas
      for (var disponibilidade in medico.disponibilidades) {
        await salvarDisponibilidade(medico.id, disponibilidade);
      }

      if (kDebugMode) {
        print('Médico salvo com sucesso: ${medico.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao salvar médico: $e');
      }
      rethrow;
    }
  }

  static Future<void> deletarMedico(String id) async {
    final db = await database;
    // Deleta o médico
    await db.delete(
      'medicos',
      where: 'id = ?',
      whereArgs: [id],
    );
    // Remove as disponibilidades associadas
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------------
  // ESPECIALIDADES
  // -------------------------------------------------------
  static Future<void> salvarEspecialidade(String nome) async {
    final db = await database;
    await db.insert(
      'especialidades',
      {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'nome': nome,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<List<String>> buscarEspecialidades() async {
    final db = await database;
    final result = await db.query('especialidades', columns: ['nome']);
    return result.map((row) => row['nome'] as String).toList();
  }

  // -------------------------------------------------------
  // DISPONIBILIDADES
  // -------------------------------------------------------
  static Future<void> salvarDisponibilidade(
      String medicoId, Disponibilidade disponibilidade) async {
    final db = await database;
    await db.insert(
      'disponibilidades',
      {
        'id': disponibilidade.id,
        'medicoId': medicoId,
        'data': disponibilidade.data.toIso8601String(),
        'horarios': jsonEncode(disponibilidade.horarios),
        'tipo': disponibilidade.tipo,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Disponibilidade>> buscarDisponibilidades(
      String medicoId) async {
    final db = await database;
    final maps = await db.query(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [medicoId],
    );
    return maps.map((map) => Disponibilidade.fromMap(map)).toList();
  }

  static Future<List<Disponibilidade>> buscarDisponibilidadesPorMedico(
      String medicoId) async {
    final db = await database;
    final maps = await db.query(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [medicoId],
    );
    return maps.map((map) => Disponibilidade.fromMap(map)).toList();
  }

  static Future<void> deletarDisponibilidade(String id) async {
    final db = await database;
    await db.delete(
      'disponibilidades',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deletarDisponibilidadesPorTipo(
      String medicoId, String tipo) async {
    final db = await database;
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ? AND tipo = ?',
      whereArgs: [medicoId, tipo],
    );
  }

  static Future<List<Disponibilidade>> buscarTodasDisponibilidades() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('disponibilidades');
    if (maps.isEmpty) {
      return [];
    }
    return maps.map((map) => Disponibilidade.fromMap(map)).toList();
  }

  static Future<void> atualizarDisponibilidade(
      Disponibilidade disponibilidade) async {
    final db = await database;
    await db.update(
      'disponibilidades',
      {
        'id': disponibilidade.id,
        'medicoId': disponibilidade.medicoId,
        'data': disponibilidade.data.toIso8601String(),
        'horarios': jsonEncode(disponibilidade.horarios),
        'tipo': disponibilidade.tipo,
      },
      where: 'id = ?',
      whereArgs: [disponibilidade.id],
    );
  }

  static Future<void> atualizarMedico(Medico medico) async {
    final db = await database;
    await db.update(
      'medicos',
      {
        'id': medico.id,
        'nome': medico.nome,
        'especialidade': medico.especialidade,
        'observacoes': medico.observacoes,
      },
      where: 'id = ?',
      whereArgs: [medico.id],
    );
  }

  // -------------------------------------------------------
  // ALOCAÇÕES
  // -------------------------------------------------------
  static Future<List<Alocacao>> buscarAlocacoes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('alocacoes');
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return Alocacao(
        id: maps[i]['id'].toString(),
        medicoId: maps[i]['medicoId'].toString(),
        gabineteId: maps[i]['gabineteId'].toString(),
        data: DateTime.parse(maps[i]['data'].toString()),
        horarioInicio: maps[i]['horarioInicio'].toString(),
        horarioFim: maps[i]['horarioFim'].toString(),
      );
    });
  }

  static Future<int> salvarAlocacao(Alocacao alocacao) async {
    final db = await database;
    return await db.insert(
      'alocacoes',
      alocacao.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> atualizarAlocacao(Alocacao alocacao) async {
    final db = await database;
    await db.update(
      'alocacoes',
      alocacao.toMap(),
      where: 'id = ?',
      whereArgs: [alocacao.id],
    );
  }

  static Future<void> deletarAlocacao(String alocacaoId) async {
    final db = await database;
    await db.delete(
      'alocacoes',
      where: 'id = ?',
      whereArgs: [alocacaoId],
    );
  }

  // -------------------------------------------------------
// HORARIOS_CLINICA
// -------------------------------------------------------
  static Future<void> salvarHorarioClinica(
      int diaSemana, String abertura, String fecho) async {
    final db = await database;
    await db.insert(
      'horarios_clinica',
      {
        'diaSemana': diaSemana,
        'horaAbertura': abertura,
        'horaFecho': fecho,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> buscarHorariosClinica() async {
    final db = await database;
    final result = await db.query('horarios_clinica');
    return result.isNotEmpty ? result : [];
  }

  static Future<void> deletarHorarioClinica(int diaSemana) async {
    final db = await database;
    await db.delete(
      'horarios_clinica',
      where: 'diaSemana = ?',
      whereArgs: [diaSemana],
    );
  }

// -------------------------------------------------------
// FERIADOS
// -------------------------------------------------------

  static Future<void> salvarFeriado(DateTime data, String descricao) async {
    final db = await database;
    try {
      await db.insert(
        'feriados',
        {
          'data': data
              .toIso8601String(), // Sempre salve como String no formato ISO-8601
          'descricao': descricao.isNotEmpty ? descricao : '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Erro ao salvar feriado: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> buscarFeriados() async {
    final db = await database;
    final result = await db.query('feriados');
    return result.map((row) {
      return {
        'data': row['data'] as String, // Deixa a data como String
        'descricao': row['descricao'] as String? ?? '', // Garante String válida
      };
    }).toList();
  }

  static Future<void> deletarFeriado(String data) async {
    final db = await initDatabase();
    try {
      await db.delete(
        'feriados',
        where: 'data = ?', // Certifique-se de que a consulta use String
        whereArgs: [data],
      );
    } catch (e) {
      throw Exception('Erro ao deletar feriado: $e');
    }
  }

  //Apagar os dados do banco de dados:

  static Future<void> deleteAllFeriados() async {
    final db = await DatabaseHelper.database;
    await db.delete('feriados');
  }

  static Future<void> deleteAllHorariosClinica() async {
    final db = await DatabaseHelper.database;
    await db.delete('horarios_clinica');
  }

  static Future<void> deleteAllAlocacoes() async {
    final db = await DatabaseHelper.database;
    await db.delete('alocacoes');
  }

  static Future<void> deleteAllMedicos() async {
    final db = await DatabaseHelper.database;
    await db.delete('medicos');
  }

  static Future<void> deleteAllGabinetes() async {
    final db = await DatabaseHelper.database;
    await db.delete('gabinetes');
  }

  static Future<void> deleteAllDisponibilidades() async {
    final db = await DatabaseHelper.database;
    await db.delete('disponibilidades');
  }




}
