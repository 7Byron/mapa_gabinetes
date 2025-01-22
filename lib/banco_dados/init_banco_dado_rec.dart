// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';
// import 'dart:io';
//
// Future<Database> initDatabase() async {
//   final dbPath = await getDatabasesPath();
//   print('Database path: $dbPath'); // Print the database path
//
//   final path = join(dbPath, 'clinica_v2.db');
//   print('Database full path: $path'); // Print the full database path
//
//   final databaseExists = await databaseFactory.databaseExists(path);
//   print('Database exists: $databaseExists'); // Print if the database exists
//
//   return openDatabase(
//       path,
//       version: 7,
//       onCreate: (db, version)
//   async {
//     print('Creating database tables...'); // Print when creating tables
//     await db.execute('''
//         CREATE TABLE especialidades(
//           id TEXT PRIMARY KEY,
//           nome TEXT UNIQUE
//         )
//       ''');
//     await db.execute('''
//         CREATE TABLE disponibilidades(
//           id TEXT PRIMARY KEY,
//           medicoId TEXT,
//           data TEXT,
//           horarios TEXT,
//           tipo TEXT
//         )
//       ''');
//     await db.execute('''
//         CREATE TABLE medicos(
//           id TEXT PRIMARY KEY,
//           nome TEXT,
//           especialidade TEXT
//         )
//       ''');
//     await db.execute('''
//         CREATE TABLE gabinetes(
//           id TEXT PRIMARY PRIMARY KEY,
//           setor TEXT,
//           nome TEXT,
//           especialidades TEXT
//         )
//       ''');
//     await db.execute('''
//         CREATE TABLE alocacoes(
//           id TEXT PRIMARY KEY,
//           gabineteId TEXT,
//           medicoId TEXT,
//           data TEXT,
//           horarioInicio TEXT,
//           horarioFim TEXT
//         )
//       ''');
//   },
//   onUpgrade: (db, oldVersion, newVersion) async {
//   print('Upgrading database from version $oldVersion to $newVersion...');
//   if (oldVersion < 2) {
//   await db.execute('''
//           CREATE TABLE IF NOT EXISTS especialidades(
//             id TEXT PRIMARY KEY,
//             nome TEXT UNIQUE
//           )
//         ''');
//   }
//   if (oldVersion < 3) {
//   await db.execute('''
//           CREATE TABLE IF NOT EXISTS disponibilidades(
//             id TEXT PRIMARY KEY,
//             medicoId TEXT,
//             data TEXT,
//             horarios TEXT
//           )
//         ''');
//   }
//   if (oldVersion < 4) {
//   await db.execute('''
//           ALTER TABLE disponibilidades ADD COLUMN tipo TEXT
//         ''');
//   }
//   if (oldVersion < 5) {
//   await db.execute('''
//           CREATE TABLE IF NOT EXISTS gabinetes(
//             id TEXT PRIMARY KEY,
//             setor TEXT,
//             nome TEXT,
//             especialidades TEXT
//           )
//         ''');
//   }
//   if (oldVersion < 6) {
//   await db.execute('''
//           CREATE TABLE IF NOT EXISTS alocacoes(
//             id TEXT PRIMARY KEY,
//             gabineteId TEXT,
//             medicoId TEXT,
//             data TEXT,
//             horarioInicio TEXT,
//             horarioFim TEXT
//           )
//         ''');
//   }
//   if (oldVersion < 7) {
//     // Não há alterações para a versão 7, mas é bom manter o controle
//   }
//   },
//   );
// }