import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// True if [name] exists in sqlite_master.
  Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      ['table', name],
    );
    return rows.isNotEmpty;
  }

  /// Post-open guard: recover from partial installs / restores (missing auxiliary tables).
  Future<void> _onOpenRepairIfNeeded(Database db) async {
    try {
      if (!await _tableExists(db, 'lesson_progress')) {
        debugPrint('DatabaseHelper: onOpen — provisioning lesson_progress');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lesson_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            lesson_id TEXT NOT NULL,
            completed_at INTEGER,
            score REAL,
            UNIQUE(user_id, lesson_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_lesson_progress_user ON lesson_progress(user_id)',
        );
      }
    } catch (e, st) {
      debugPrint('DatabaseHelper: onOpen repair: $e\n$st');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('voicebridge.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: _onOpenRepairIfNeeded,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      // Legacy drop logic preserved
      await db.execute('DROP TABLE IF EXISTS sessions');
      await db.execute('DROP TABLE IF EXISTS user_profile');
      await _createDB(db, newVersion);
      return; // Return early since tables recreated completely
    }
    
    if (oldVersion < 8) {
      // 1. Incremental migration for pronunciation
      try {
        await db.execute('ALTER TABLE sessions ADD COLUMN pronunciation_tips TEXT');
      } catch (_) {}

      // 2. Ensure lesson progress exists for existing users who jumped schema
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lesson_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          lesson_id TEXT NOT NULL,
          completed_at INTEGER,
          score REAL,
          UNIQUE(user_id, lesson_id)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lesson_progress_user ON lesson_progress(user_id)');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL';

    // User profile table
    await db.execute('''
      CREATE TABLE user_profile (
        user_id $idType,
        email $textType,
        display_name $textType,
        baseline_completed INTEGER DEFAULT 0,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        total_sessions INTEGER DEFAULT 0,
        xp INTEGER DEFAULT 0,
        daily_goal INTEGER DEFAULT 3,
        daily_sessions_today INTEGER DEFAULT 0,
        last_session_date TEXT,
        achievements_json TEXT,
        last_synced_at INTEGER,
        data_json TEXT
      )
    ''');

    // Sessions table
    await db.execute('''
      CREATE TABLE sessions (
        session_id $idType,
        user_id $textType,
        type $textType,
        created_at $intType,
        completed_at INTEGER,
        status $textType,
        prompt_id TEXT,
        prompt_text TEXT,
        audio_local_path TEXT,
        audio_remote_url TEXT,
        audio_duration $realType,
        transcript TEXT,
        fluency_score $realType,
        grammar_score $realType,
        pronunciation_score $realType,
        composite_score $realType,
        estimated_band $realType,
        cefr_level TEXT,
        feedback TEXT,
        word_results TEXT,
        synced INTEGER DEFAULT 0,
        last_synced_at INTEGER,
        grammar_corrections TEXT,
        improvement_tips TEXT,
        advanced_vocabulary TEXT,
        pronunciation_tips TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_sessions_user_id ON sessions(user_id)');
    await db.execute('CREATE INDEX idx_sessions_status ON sessions(status)');
    await db.execute('CREATE INDEX idx_sessions_created_at ON sessions(created_at DESC)');

    // Lesson progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        completed_at INTEGER,
        score REAL,
        UNIQUE(user_id, lesson_id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lesson_progress_user ON lesson_progress(user_id)');
  }

  // User Profile Operations
  Future<void> insertUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final db = await database;
    final results = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Session Operations
  Future<void> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    try {
      await db.insert(
        'sessions',
        session,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Robust Self-Healing: If DB cache didn't refresh schema, manually patch column and retry.
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('no column named pronunciation_tips') || errorStr.contains('has no column')) {
        debugPrint('DatabaseHelper: Detected stale session schema. Executing emergency hot-patch...');
        try {
          await db.execute('ALTER TABLE sessions ADD COLUMN pronunciation_tips TEXT');
          debugPrint('DatabaseHelper: Hot-patch succeeded. Retrying operation...');
          // Re-attempt original insertion now that schema satisfies dependencies
          await db.insert(
            'sessions',
            session,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          return; // Retried insert succeeded
        } catch (innerError) {
          debugPrint('DatabaseHelper: Hot-patch failure: $innerError');
        }
      }
      // Re-throw if healing failed or it was a different kind of error
      rethrow;
    }
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    final db = await database;
    try {
      await db.update(
        'sessions',
        updates,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('no column named pronunciation_tips') || errorStr.contains('has no column')) {
        debugPrint('DatabaseHelper: Emergency hot-patch triggered during update...');
        try {
          await db.execute('ALTER TABLE sessions ADD COLUMN pronunciation_tips TEXT');
          await db.update(
            'sessions',
            updates,
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
          return;
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUserSessions(String userId, {int limit = 20}) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSessions(String userId) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'user_id = ? AND synced = ? AND status = ?',
      whereArgs: [userId, 0, 'completed'],
    );
  }

  // Lesson Operations
  Future<List<Map<String, dynamic>>> getLessonProgress(String userId) async {
    final db = await database;
    try {
      return await db.query(
        'lesson_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('no such table') || errorStr.contains('doesn\'t exist')) {
        debugPrint('DatabaseHelper: Emergency provision of lesson_progress table...');
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS lesson_progress (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              lesson_id TEXT NOT NULL,
              completed_at INTEGER,
              score REAL,
              UNIQUE(user_id, lesson_id)
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lesson_progress_user ON lesson_progress(user_id)');
          debugPrint('DatabaseHelper: Provision complete. Retrying query...');
          return await db.query('lesson_progress', where: 'user_id = ?', whereArgs: [userId]);
        } catch (_) {}
      }
      return []; // Final graceful failure fallback
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
