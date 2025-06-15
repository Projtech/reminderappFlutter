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
     version: 2,
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

 Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
   if (oldVersion < 2) {
     await _addColumnIfNotExists(db, 'notes', 'deleted', 'INTEGER NOT NULL DEFAULT 0');
     await _addColumnIfNotExists(db, 'notes', 'deletedAt', 'INTEGER');
   }
 }

 Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnDefinition) async {
   try {
     final result = await db.rawQuery('PRAGMA table_info($tableName)');
     final columnExists = result.any((column) => column['name'] == columnName);
     
     if (!columnExists) {
       await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition');
     }
   } catch (e) {
     // Continua a execução sem relançar o erro
   }
 }

 Future<int> insertNote(Note note) async {
   final db = await database;
   return await db.insert('notes', note.toMap());
 }

 Future<List<Note>> getAllNotes() async {
   final db = await database;
   final List<Map<String, dynamic>> maps = await db.query('notes',
       where: 'deleted = 0',
       orderBy: 'isPinned DESC, createdAt DESC');
   return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
 }

 Future<List<Map<String, dynamic>>> getAllNotesAsMaps() async {
   final db = await database;
   return await db.query('notes', where: 'deleted = 0', orderBy: 'createdAt ASC');
 }

 Future<List<Note>> getDeletedNotes() async {
   final db = await database;
   final List<Map<String, dynamic>> maps = await db.query('notes',
       where: 'deleted = 1',
       orderBy: 'deletedAt DESC');
   return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
 }

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

 Future<int> deleteNotePermanently(int id) async {
   final db = await database;
   return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
 }

 Future<int> emptyTrash() async {
   final db = await database;
   return await db.delete('notes', where: 'deleted = 1');
 }

 Future<int> cleanOldDeletedNotes(int daysOld) async {
   final db = await database;
   final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
   return await db.delete(
     'notes',
     where: 'deleted = 1 AND deletedAt < ?',
     whereArgs: [cutoffDate],
   );
 }

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