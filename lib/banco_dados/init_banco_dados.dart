import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> initDatabase([BuildContext? context]) async {
  // Inicializa o databaseFactory para desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Obtém o diretório de suporte da aplicação
  Directory appSupportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appSupportDir.path, 'mapa_gabinetes.db');
  if (kDebugMode) {
    print('Database path: ${appSupportDir.path}');
  }

  final dbFile = File(dbPath);

  if (!(await dbFile.exists()) && context != null) {
    // Pergunta ao usuário o que fazer somente se o contexto estiver disponível
    final escolha = await _exibirDialogoEscolha(context);

    if (escolha == 'novo') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criando novo banco de dados...')),
      );
      return _criarBancoVazio(dbPath);
    } else if (escolha == 'assets') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiando banco de dados dos assets...')),
      );
      final data = await rootBundle.load('banco_dados/mapa_gabinetes.db');
      final bytes = data.buffer.asUint8List();
      await dbFile.writeAsBytes(bytes, flush: true);
      return _abrirBanco(dbPath);
    } else {
      throw Exception('Nenhuma ação definida para o banco de dados.');
    }
  }

  return _abrirBanco(dbPath);
}


Future<Database> _abrirBanco(String dbPath) async {
  return openDatabase(
    dbPath,
    version: 1, // Começando do zero, definimos a versão inicial como 1
    onCreate: (db, version) async {
      if (kDebugMode) print('Creating database tables...');
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
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (kDebugMode) {
        print('Database upgraded from version $oldVersion to $newVersion...');
      }
      // Aqui você pode adicionar scripts futuros para upgrades
    },
    onOpen: (db) {
      if (kDebugMode) {
        print('Database opened successfully.');
      }
    },
  );
}

Future<Database> _criarBancoVazio(String dbPath) async {
  return openDatabase(
    dbPath,
    version: 1, // Versão inicial como 1
    onCreate: (db, version) async {
      if (kDebugMode) print('Creating database tables...');
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
    },
  );
}

Future<String?> _exibirDialogoEscolha(BuildContext context) async {
  return await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Base de Dados Não Encontrada'),
        content: const Text(
            'O banco de dados não foi encontrado. Deseja criar um banco vazio ou usar o pré-populado dos assets?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('novo'); // Escolha: criar novo
            },
            child: const Text('Criar Novo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('banco_dados'); // Escolha: usar dos assets
            },
            child: const Text('Usar Pré-populado'),
          ),
        ],
      );
    },
  );
}
