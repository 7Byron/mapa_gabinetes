// lib/services/medico_salvar_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../banco_dados/init_banco_dados.dart';
import '../class/medico.dart';
import '../class/disponibilidade.dart';

/// Salva (ou atualiza) um médico no banco, removendo suas disponibilidades anteriores
/// e inserindo as novas (que estão no atributo `medico.disponibilidades`).
///
/// É parecido com o que faríamos no DatabaseHelper, mas aqui fica isolado.
Future<void> salvarMedicoCompleto(Medico medico) async {
  final db = await initDatabase();
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
