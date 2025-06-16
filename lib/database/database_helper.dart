// lib/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reminder.dart';

class DatabaseHelper {
static final DatabaseHelper _instance = DatabaseHelper._internal();
factory DatabaseHelper() => _instance;
DatabaseHelper._internal();

static Database? _database;

Future<Database> get database async {
  if (_database != null) return _database!;
  _database = await _initDatabase();
  return _database!;
}

Future<Database> _initDatabase() async {
  String path = join(await getDatabasesPath(), 'reminders.db');
  return await openDatabase(
    path,
    version: 7,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE reminders(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      dateTime INTEGER NOT NULL,
      createdAt INTEGER NOT NULL,
      isCompleted INTEGER NOT NULL DEFAULT 0,
      isRecurring INTEGER NOT NULL DEFAULT 0,
      recurringType TEXT,
      recurrenceInterval INTEGER NOT NULL DEFAULT 1,
      notificationsEnabled INTEGER NOT NULL DEFAULT 1,
      deleted INTEGER NOT NULL DEFAULT 0,
      deletedAt INTEGER,
      isChecklist INTEGER NOT NULL DEFAULT 0,
      checklistItems TEXT
    )
  ''');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await _addColumnIfNotExists(db, 'reminders', 'isRecurring', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'reminders', 'recurringType', 'TEXT');
  }
  if (oldVersion < 3) {
    await _addColumnIfNotExists(db, 'reminders', 'notificationsEnabled', 'INTEGER NOT NULL DEFAULT 1');
  }
  if (oldVersion < 4) {
    await _addColumnIfNotExists(db, 'reminders', 'recurrenceInterval', 'INTEGER NOT NULL DEFAULT 1');
  }
  if (oldVersion < 5) {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _addColumnIfNotExists(db, 'reminders', 'createdAt', 'INTEGER NOT NULL DEFAULT $now');
  }
  if (oldVersion < 6) {
    await _addColumnIfNotExists(db, 'reminders', 'deleted', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'reminders', 'deletedAt', 'INTEGER');
  }
  if (oldVersion < 7) {
    await _addColumnIfNotExists(db, 'reminders', 'isChecklist', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'reminders', 'checklistItems', 'TEXT');
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

Future<int> insertReminder(Reminder reminder) async {
  final db = await database;
  return await db.insert('reminders', reminder.toMap());
}

// ✅ NOVO: Método para inserir dados raw preservando estado deleted
Future<int> insertReminderRaw(Map<String, dynamic> reminderMap) async {
  final db = await database;
  // Remove o ID para evitar conflitos de UNIQUE constraint
  final mapWithoutId = Map<String, dynamic>.from(reminderMap);
  mapWithoutId.remove('id');
  return await db.insert('reminders', mapWithoutId);
}

Future<List<Reminder>> getAllReminders() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('reminders',
      where: 'deleted = 0',
      orderBy: 'dateTime ASC');
  return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
}

Future<List<Map<String, dynamic>>> getAllRemindersAsMaps() async {
  final db = await database;
  return await db.query('reminders', where: 'deleted = 0');
}

Future<List<Reminder>> getDeletedReminders() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('reminders',
      where: 'deleted = 1',
      orderBy: 'deletedAt DESC');
  return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
}

Future<List<Map<String, dynamic>>> getDeletedRemindersAsMaps() async {
  final db = await database;
  return await db.query('reminders', where: 'deleted = 1');
}

Future<int> updateReminder(Reminder reminder) async {
  final db = await database;
  return await db.update(
    'reminders',
    reminder.toMap(),
    where: 'id = ?',
    whereArgs: [reminder.id],
  );
}

Future<int> deleteReminder(int id) async {
  final db = await database;
  return await db.update(
    'reminders',
    {
      'deleted': 1,
      'deletedAt': DateTime.now().millisecondsSinceEpoch,
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> restoreReminder(int id) async {
  final db = await database;
  return await db.update(
    'reminders',
    {
      'deleted': 0,
      'deletedAt': null,
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<int> deleteReminderPermanently(int id) async {
  final db = await database;
  return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
}

Future<int> emptyTrash() async {
  final db = await database;
  return await db.delete('reminders', where: 'deleted = 1');
}

Future<int> cleanOldDeletedReminders(int daysOld) async {
  final db = await database;
  final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
  return await db.delete(
    'reminders',
    where: 'deleted = 1 AND deletedAt < ?',
    whereArgs: [cutoffDate],
  );
}

Future<int> deleteAllReminders() async {
  final db = await database;
  return await db.update(
    'reminders',
    {
      'deleted': 1,
      'deletedAt': DateTime.now().millisecondsSinceEpoch,
    },
    where: 'deleted = 0',
  );
}

Future<int> getReminderCountByCategory(String categoryName) async {
  final db = await database;
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM reminders WHERE category = ? AND deleted = 0',
    [categoryName],
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<List<Reminder>> getRecurringRemindersNeedingReschedule() async {
  final db = await database;
  final now = DateTime.now().millisecondsSinceEpoch;
  
  final List<Map<String, dynamic>> maps = await db.query(
    'reminders',
    where: 'isRecurring = 1 AND isCompleted = 0 AND notificationsEnabled = 1 AND dateTime < ? AND deleted = 0',
    whereArgs: [now],
  );
  
  return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
}
}