import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> initDatabase() async {
  // Inicialização para plataformas desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Caminho do banco de dados no diretório de suporte do app
  Directory appSupportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appSupportDir.path, 'mapa_gabinetes.db');
  if (kDebugMode) {
    print('Database path: $dbPath');
  }

  final dbFile = File(dbPath);

  // Verifica se o banco de dados existe
  if (!(await dbFile.exists())) {
    if (kDebugMode) {
      print('Banco de dados não encontrado. Criando novo banco de dados...');
    }
    // Cria o banco de dados vazio e as tabelas
    return _criarNovoBanco(dbPath);
  }

  // Abrir o banco de dados existente
  return _abrirBanco(dbPath);
}

Future<Database> _criarNovoBanco(String dbPath) async {
  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      if (kDebugMode) print('Criando tabelas do banco de dados...');
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
          especialidade TEXT,
          observacoes TEXT
        )
      ''');
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
      await db.execute('''
        CREATE TABLE horarios_clinica(
          diaSemana INTEGER PRIMARY KEY,
          horaAbertura TEXT,
          horaFecho TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE feriados(
          data TEXT PRIMARY KEY,
          descricao TEXT
        )
      ''');
    },
    onOpen: (db) async {
      if (kDebugMode) print('Novo banco de dados criado e aberto com sucesso.');
    },
  );
}

Future<Database> _abrirBanco(String dbPath) async {
  return openDatabase(
    dbPath,
    version: 1,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (kDebugMode) print('Database upgraded from $oldVersion to $newVersion');
    },
    onOpen: (db) async {
      if (kDebugMode) print('Banco de dados aberto com sucesso.');
    },
  );
}
