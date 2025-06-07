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
      version: 4, // ✅ VERSÃO 4 para novo campo
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
        isCompleted INTEGER NOT NULL DEFAULT 0,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurringType TEXT,
        recurrenceInterval INTEGER NOT NULL DEFAULT 1,
        notificationsEnabled INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE reminders ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE reminders ADD COLUMN recurringType TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE reminders ADD COLUMN notificationsEnabled INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 4) {
      // ✅ NOVA MIGRAÇÃO: Adicionar campo de intervalo
      await db.execute('ALTER TABLE reminders ADD COLUMN recurrenceInterval INTEGER NOT NULL DEFAULT 1');
    }
  }

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reminders',
        orderBy: 'dateTime ASC');
    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getAllRemindersAsMaps() async {
    final db = await database;
    return await db.query('reminders');
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
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllReminders() async {
    final db = await database;
    return await db.delete('reminders');
  }

  // ✅ REMOVIDO: método createNextOccurrence não é mais necessário
  // O agendamento múltiplo é feito pelo NotificationService

  Future<int> getReminderCountByCategory(String categoryName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM reminders WHERE category = ?',
      [categoryName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ✅ NOVO: Buscar lembretes recorrentes que precisam reagendar
  Future<List<Reminder>> getRecurringRemindersNeedingReschedule() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'isRecurring = 1 AND isCompleted = 0 AND notificationsEnabled = 1 AND dateTime < ?',
      whereArgs: [now],
    );
    
    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }
}