// lib/services/medico_salvar_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/medico.dart';
import '../database/database_helper.dart';

Future<void> salvarMedicoCompleto(Medico medico) async {
  final db = await DatabaseHelper.database;
  try {
    if (kDebugMode) print('Tentando salvar médico: ${medico.toMap()}');

    // 1) Salva/atualiza o médico
    await db.insert(
      'medicos',
      {
        'id': medico.id,
        'nome': medico.nome,
        'especialidade': medico.especialidade,
        'observacoes': medico.observacoes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2) Remove disponibilidades antigas
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [medico.id],
    );

    // 3) Insere as novas
    for (final disp in medico.disponibilidades) {
      await db.insert(
        'disponibilidades',
        {
          'id': disp.id,
          'medicoId': medico.id,
          'data': disp.data.toIso8601String(),
          'horarios': jsonEncode(disp.horarios),
          'tipo': disp.tipo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (kDebugMode) print('Médico salvo com sucesso: ${medico.id}');
  } catch (e) {
    if (kDebugMode) print('Erro ao salvar médico: $e');
    rethrow;
  }
}
