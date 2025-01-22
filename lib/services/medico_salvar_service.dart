// lib/services/medico_salvar_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../class/medico.dart';
import '../class/disponibilidade.dart';
import '../banco_dados/database_helper.dart';

Future<void> salvarMedicoCompleto(Medico medico) async {
  // Agora vamos usar o DatabaseHelper para obter a base de dados
  final dbHelper =
      DatabaseHelper(); // Passar o caminho da pasta partilhada
  final db = await DatabaseHelper
      .database; // Usar o DatabaseHelper para obter a base de dados
  try {
    if (kDebugMode) {
      print('Tentando salvar o médico: ${medico.toMap()}');
    }

    // 1) Salva/atualiza o médico na tabela "medicos"
    await db.insert(
      'medicos',
      {
        'id': medico.id,
        'nome': medico.nome,
        'especialidade': medico.especialidade,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2) Remove as disponibilidades antigas deste médico
    await db.delete(
      'disponibilidades',
      where: 'medicoId = ?',
      whereArgs: [medico.id],
    );

    // 3) Insere as novas disponibilidades da lista "medico.disponibilidades"
    for (Disponibilidade disp in medico.disponibilidades) {
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
