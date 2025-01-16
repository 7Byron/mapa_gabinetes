import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> initDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    join(dbPath, 'clinica_v2.db'),
    version: 5,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE especialidades(
          id TEXT PRIMARY KEY,
          nome TEXT UNIQUE
        )
      ''');
      await db.execute('''
        CREATE TABLE reservas(
          id TEXT PRIMARY KEY,
          gabineteId TEXT,
          medicoId TEXT,
          data TEXT,
          horario TEXT
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
      await db.execute('''
  CREATE TABLE gabinetes(
    id TEXT PRIMARY KEY,
    setor TEXT,
    nome TEXT,
    especialidades TEXT
  )
''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
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
      // Certifique-se de que a tabela `gabinetes` seja criada
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
    },
  );
}
