import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Drop and recreate all tables on any schema change
    await db.execute('DROP TABLE IF EXISTS sessions');
    await db.execute('DROP TABLE IF EXISTS user_profile');
    await _createDB(db, newVersion);
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
        total_sessions INTEGER DEFAULT 0,
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
        feedback TEXT,
        synced INTEGER DEFAULT 0,
        last_synced_at INTEGER
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_sessions_user_id ON sessions(user_id)');
    await db.execute('CREATE INDEX idx_sessions_status ON sessions(status)');
    await db.execute('CREATE INDEX idx_sessions_created_at ON sessions(created_at DESC)');
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
    await db.insert(
      'sessions',
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'sessions',
      updates,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
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

  Future<List<Map<String, dynamic>>> getPendingSessions(String userId) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: 'user_id = ? AND synced = ? AND status = ?',
      whereArgs: [userId, 0, 'pending_upload'],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
