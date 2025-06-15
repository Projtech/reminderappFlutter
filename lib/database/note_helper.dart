import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';

class NoteHelper {
  static final NoteHelper _instance = NoteHelper._internal();
  factory NoteHelper() => _instance;
  NoteHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'notes.db');
    return await openDatabase(
      path,
      version: 2, // ✅ MANTÉM VERSÃO 2
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');
  }

  // ✅ CORRIGIDO: Verifica se coluna existe antes de adicionar
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // ✅ CORRIGIDO: Verifica antes de adicionar colunas da lixeira
      await _addColumnIfNotExists(db, 'notes', 'deleted', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'notes', 'deletedAt', 'INTEGER');
    }
  }

  // ✅ NOVO: Função auxiliar para verificar e adicionar coluna se não existir
  Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnDefinition) async {
    try {
      // Verifica se a coluna já existe
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      final columnExists = result.any((column) => column['name'] == columnName);
      
      if (!columnExists) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
        print('✅ Coluna $columnName adicionada à tabela $tableName');
      } else {
        print('ℹ️ Coluna $columnName já existe na tabela $tableName');
      }
    } catch (e) {
      print('❌ Erro ao verificar/adicionar coluna $columnName: $e');
      // Não relança o erro para evitar crash - continua a execução
    }
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  // ✅ MODIFICADO: Filtrar apenas não deletadas
  Future<List<Note>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes',
        where: 'deleted = 0',
        orderBy: 'isPinned DESC, createdAt DESC'); // Pinned notes first
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // ✅ MODIFICADO: Filtrar apenas não deletadas para backup
  Future<List<Map<String, dynamic>>> getAllNotesAsMaps() async {
    final db = await database;
    return await db.query('notes', where: 'deleted = 0', orderBy: 'createdAt ASC');
  }

  // ✅ NOVO: Obter anotações deletadas (lixeira)
  Future<List<Note>> getDeletedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes',
        where: 'deleted = 1',
        orderBy: 'deletedAt DESC');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // ✅ NOVO: Obter anotações deletadas como Maps (para backup)
  Future<List<Map<String, dynamic>>> getDeletedNotesAsMaps() async {
    final db = await database;
    return await db.query('notes', where: 'deleted = 1');
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // ✅ MODIFICADO: Soft delete ao invés de DELETE físico
  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.update(
      'notes',
      {
        'deleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ NOVO: Restaurar anotação da lixeira
  Future<int> restoreNote(int id) async {
    final db = await database;
    return await db.update(
      'notes',
      {
        'deleted': 0,
        'deletedAt': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ NOVO: Excluir permanentemente
  Future<int> deleteNotePermanently(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ NOVO: Limpar lixeira (excluir todas as deletadas permanentemente)
  Future<int> emptyTrash() async {
    final db = await database;
    return await db.delete('notes', where: 'deleted = 1');
  }

  // ✅ NOVO: Auto-limpeza da lixeira (itens mais antigos que X dias)
  Future<int> cleanOldDeletedNotes(int daysOld) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    return await db.delete(
      'notes',
      where: 'deleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffDate],
    );
  }

  // ✅ MODIFICADO: Deletar todas não deletadas (para backup)
  Future<int> deleteAllNotes() async {
    final db = await database;
    return await db.update(
      'notes',
      {
        'deleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'deleted = 0',
    );
  }
}