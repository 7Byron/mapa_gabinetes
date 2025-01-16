import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../banco_dados/init_banco_dados.dart';
import '../class/disponibilidade.dart';
import '../class/gabinete.dart';
import '../class/medico.dart';
import '../class/reservas.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Salvar uma reserva no banco de dados
  static Future<void> salvarReserva(Reserva reserva) async {
    final db = await initDatabase();
    await db.insert(
      'reservas',
      reserva.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Buscar todas as reservas no banco de dados
  static Future<List<Reserva>> buscarReservas() async {
    final db = await initDatabase();
    final result = await db.query('reservas');
    return result.map((reserva) {
      return Reserva(
        id: reserva['id'] as String,
        gabineteId: reserva['gabineteId'] as String,
        medicoId: reserva['medicoId'] as String,
        data: DateTime.parse(reserva['data'] as String),
        horario: reserva['horario'] as String,
      );
    }).toList();
  }

  // Deletar uma reserva pelo ID
  static Future<void> deletarReserva(String id) async {
    final db = await initDatabase();
    await db.delete(
      'reservas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Salvar uma disponibilidade no banco de dados
  static Future<void> salvarDisponibilidade(
      String medicoId, Disponibilidade disponibilidade) async {
    final db = await initDatabase();
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

  // Buscar disponibilidades associadas a um médico
  static Future<List<Disponibilidade>> buscarDisponibilidades(
      String medicoId) async {
    final db = await initDatabase();
    final maps = await db.query(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [medicoId],
    );
    return maps.map((map) => Disponibilidade.fromMap(map)).toList();
  }

  // Deletar uma disponibilidade pelo ID
  static Future<void> deletarDisponibilidade(String id) async {
    final db = await initDatabase();
    await db.delete(
      'disponibilidades',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Salvar um médico no banco de dados
  static Future<void> salvarMedico(Medico medico) async {
    final db = await initDatabase();
    try {
      if (kDebugMode) {
        print('Tentando salvar o médico: ${medico.toMap()}');
      }
      // Insere/Atualiza o médico
      await db.insert(
        'medicos',
        {
          'id': medico.id,
          'nome': medico.nome,
          'especialidade': medico.especialidade,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insere/Atualiza as disponibilidades
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

  // Buscar um médico pelo ID
  static Future<Medico?> buscarMedico(String medicoId) async {
    final db = await initDatabase();
    final result = await db.query(
      'medicos',
      where: 'id = ?',
      whereArgs: [medicoId],
    );
    if (result.isNotEmpty) {
      final medico = result.first;
      final disponibilidades = await buscarDisponibilidades(medicoId);
      return Medico(
        id: medico['id'] as String,
        nome: medico['nome'] as String,
        especialidade: medico['especialidade'] as String,
        disponibilidades: disponibilidades,
        ferias: [],
      );
    }
    return null;
  }

  // Método para buscar todos os médicos
  static Future<List<Medico>> buscarMedicos() async {
    final db = await initDatabase();
    final result = await db.query('medicos');
    List<Medico> medicos = [];
    for (var row in result) {
      final disponibilidades = await buscarDisponibilidades(row['id'] as String);
      medicos.add(
        Medico(
          id: row['id'] as String,
          nome: row['nome'] as String,
          especialidade: row['especialidade'] as String,
          disponibilidades: disponibilidades,
          ferias: [],
        ),
      );
    }
    return medicos;
  }

  // Salvar uma nova especialidade
  static Future<void> salvarEspecialidade(String nome) async {
    final db = await initDatabase();
    await db.insert(
      'especialidades',
      {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'nome': nome},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Buscar todas as especialidades
  static Future<List<String>> buscarEspecialidades() async {
    final db = await initDatabase();
    final result = await db.query('especialidades', columns: ['nome']);
    return result.map((row) => row['nome'] as String).toList();
  }

  // Método para deletar um médico pelo ID
  static Future<void> deletarMedico(String id) async {
    final db = await initDatabase();
    // Deleta o médico
    await db.delete(
      'medicos',
      where: 'id = ?',
      whereArgs: [id],
    );

    // E remove as disponibilidades associadas
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [id],
    );
  }

  // Exemplo de deletar disponibilidades de um tipo específico
  static Future<void> deletarDisponibilidadesPorTipo(String medicoId, String tipo) async {
    final db = await initDatabase();
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ? AND tipo = ?',
      whereArgs: [medicoId, tipo],
    );
  }

  // Salvar um gabinete
  static Future<void> salvarGabinete(Gabinete gabinete) async {
    final db = await initDatabase();
    await db.insert(
      'gabinetes',
      gabinete.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Buscar todos os gabinetes
  static Future<List<Gabinete>> buscarGabinetes() async {
    final db = await initDatabase();
    final result = await db.query('gabinetes');
    return result.map((map) => Gabinete.fromMap(map)).toList();
  }

  // Atualizar um gabinete
  static Future<void> atualizarGabinete(Gabinete gabinete) async {
    final db = await initDatabase();
    await db.update(
      'gabinetes',
      gabinete.toMap(),
      where: 'id = ?',
      whereArgs: [gabinete.id],
    );
  }

  // Deletar um gabinete
  static Future<void> deletarGabinete(String id) async {
    final db = await initDatabase();
    await db.delete(
      'gabinetes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

}
