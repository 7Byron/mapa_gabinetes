import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<Database> initDatabase() async {
  // Obtém o diretório de suporte da aplicação
  Directory appSupportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appSupportDir.path, 'clinica_v2.db');
  if (kDebugMode) {
    print('Database path: ${appSupportDir.path}');
  }
  // Verifica se o banco de dados já existe no diretório
  final dbFile = File(dbPath);
  if (!(await dbFile.exists())) {
    // Copia o banco de dados pré-populado dos assets para o local
    final data = await rootBundle.load('banco_dados/clinica_v2.db');
    final bytes = data.buffer.asUint8List();
    await dbFile.writeAsBytes(bytes, flush: true);
    if (kDebugMode) {
      print('Base de dados copiada para: $dbPath');
    }
  } else {
    if (kDebugMode) {
      print('Base de dados já existente em: $dbPath');
    }
  }
  // Abre ou cria o banco de dados
  return openDatabase(
    dbPath,
    version: 7,
    onCreate: (db, version) async {
      if (kDebugMode) {
        print('Creating database tables...');
      }
      await db.execute('''
        CREATE TABLE especialidades(
          id TEXT PRIMARY KEY,
          nome TEXT UNIQUE
        )
      ''');

      await db.execute('''
        CREATE TABLE disponibilidades(
          id TEXT PRIMARY KEY,
          medicoId TEXT,
          data TEXT,
          horarios TEXT,
          tipo TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE medicos(
          id TEXT PRIMARY KEY,
          nome TEXT,
          especialidade TEXT
        )
      ''');

      // Corrigido: remover o "PRIMARY" duplicado
      await db.execute('''
        CREATE TABLE gabinetes(
          id TEXT PRIMARY KEY,
          setor TEXT,
          nome TEXT,
          especialidades TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE alocacoes(
          id TEXT PRIMARY KEY,
          gabineteId TEXT,
          medicoId TEXT,
          data TEXT,
          horarioInicio TEXT,
          horarioFim TEXT
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (kDebugMode) {
        print('Upgrading database from version $oldVersion to $newVersion...');
      }
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS especialidades(
            id TEXT PRIMARY KEY,
            nome TEXT UNIQUE
          )
        ''');
      }
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS disponibilidades(
            id TEXT PRIMARY KEY,
            medicoId TEXT,
            data TEXT,
            horarios TEXT
          )
        ''');
      }
      if (oldVersion < 4) {
        await db.execute('''
          ALTER TABLE disponibilidades ADD COLUMN tipo TEXT
        ''');
      }
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS gabinetes(
            id TEXT PRIMARY KEY,
            setor TEXT,
            nome TEXT,
            especialidades TEXT
          )
        ''');
      }
      if (oldVersion < 6) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS alocacoes(
            id TEXT PRIMARY KEY,
            gabineteId TEXT,
            medicoId TEXT,
            data TEXT,
            horarioInicio TEXT,
            horarioFim TEXT
          )
        ''');
      }
      if (oldVersion < 7) {
        // Ex: Ajustes da versão 7 em diante
      }
    },
    onOpen: (db) {
      if (kDebugMode) {
        print('Database opened successfully.');
      }
    },
  );
}
