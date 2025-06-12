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
      version: 6, // ✅ VERSÃO 6 para lixeira
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
        deletedAt INTEGER
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
      await db.execute('ALTER TABLE reminders ADD COLUMN recurrenceInterval INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 5) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.execute('ALTER TABLE reminders ADD COLUMN createdAt INTEGER NOT NULL DEFAULT $now');
    }
    if (oldVersion < 6) {
      // ✅ MIGRAÇÃO V6: Adicionar campos da lixeira
      await db.execute('ALTER TABLE reminders ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE reminders ADD COLUMN deletedAt INTEGER');
    }
  }

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder.toMap());
  }

  // ✅ MODIFICADO: Filtrar apenas não deletados
  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reminders',
        where: 'deleted = 0',
        orderBy: 'dateTime ASC');
    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  // ✅ MODIFICADO: Filtrar apenas não deletados para backup
  Future<List<Map<String, dynamic>>> getAllRemindersAsMaps() async {
    final db = await database;
    return await db.query('reminders', where: 'deleted = 0');
  }

  // ✅ NOVO: Obter lembretes deletados (lixeira)
  Future<List<Reminder>> getDeletedReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reminders',
        where: 'deleted = 1',
        orderBy: 'deletedAt DESC');
    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  // ✅ NOVO: Obter lembretes deletados como Maps (para backup)
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

  // ✅ MODIFICADO: Soft delete ao invés de DELETE físico
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

  // ✅ NOVO: Restaurar lembrete da lixeira
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

  // ✅ NOVO: Excluir permanentemente
  Future<int> deleteReminderPermanently(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ NOVO: Limpar lixeira (excluir todos os deletados permanentemente)
  Future<int> emptyTrash() async {
    final db = await database;
    return await db.delete('reminders', where: 'deleted = 1');
  }

  // ✅ NOVO: Auto-limpeza da lixeira (itens mais antigos que X dias)
  Future<int> cleanOldDeletedReminders(int daysOld) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    return await db.delete(
      'reminders',
      where: 'deleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffDate],
    );
  }

  // ✅ MODIFICADO: Deletar todos não deletados (para backup)
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

  // ✅ MODIFICADO: Contar apenas não deletados
  Future<int> getReminderCountByCategory(String categoryName) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM reminders WHERE category = ? AND deleted = 0',
      [categoryName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ✅ MODIFICADO: Filtrar apenas não deletados
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