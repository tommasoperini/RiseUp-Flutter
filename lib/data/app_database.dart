import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/alarm.dart';
import '../models/sleep_record.dart';
import '../models/study_session.dart';
import '../models/weekly_goal.dart';

/// Accesso al database SQLite del dispositivo, realizzato secondo il pattern
/// singleton: costruttore privato e istanza statica, in modo da garantire
/// l'esistenza di una sola connessione per l'intero ciclo di vita
/// dell'applicazione (sezione 6.1 della relazione).
///
/// I ViewModel accedono direttamente a questa classe, senza un livello
/// Repository o DAO intermedio: semplificazione motivata dalla sezione 5.2
/// della relazione, dato che qui non sono richiesti i meccanismi di
/// testabilità che giustificano quel livello nella versione Android.
///
/// A differenza di Room, sqflite non offre un meccanismo di TypeConverter
/// automatico: la conversione degli attributi di tipo enumerativo e
/// temporale è realizzata esplicitamente nei metodi `toMap`/`fromMap` di
/// ciascuna classe del Model, non qui.
///
/// Le operazioni di scrittura seguono lo stile mostrato a lezione: `insert`
/// specifica `conflictAlgorithm: ConflictAlgorithm.replace`, così che un
/// eventuale conflitto sulla chiave primaria sostituisca la riga esistente
/// anziché sollevare un'eccezione; `update` e `delete` individuano la riga
/// tramite una clausola `where` parametrica, evitando la concatenazione
/// diretta di stringhe nella query.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _nomeFile = 'study_sleep_tracker.db';
  static const int _versioneSchema = 1;

  Database? _database;

  Future<Database> get _db async {
    final esistente = _database;
    if (esistente != null) return esistente;
    final aperto = await _apri();
    _database = aperto;
    return aperto;
  }

  Future<Database> _apri() async {
    final percorso = join(await getDatabasesPath(), _nomeFile);
    return openDatabase(
      percorso,
      version: _versioneSchema,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE alarm (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            orario INTEGER NOT NULL,
            giorniRipetizione INTEGER NOT NULL DEFAULT 0,
            attiva INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sleep_record (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inizioSonno INTEGER NOT NULL,
            fineSonno INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE study_session (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            istanteInizio INTEGER NOT NULL,
            istanteFine INTEGER,
            durataStudio INTEGER NOT NULL,
            durataPausa INTEGER NOT NULL DEFAULT 5,
            cicliPrevisti INTEGER NOT NULL DEFAULT 1,
            cicliCompletati INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE weekly_goal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            categoria TEXT NOT NULL UNIQUE,
            valoreObiettivo INTEGER NOT NULL,
            dataCreazione INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // -----------------------------------------------------------------------
  // Alarm
  // -----------------------------------------------------------------------

  Future<int> insertAlarm(Alarm alarm) async {
    final db = await _db;
    return db.insert(
      'alarm',
      alarm.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final db = await _db;
    await db.update('alarm', alarm.toMap(),
        where: 'id = ?', whereArgs: [alarm.id]);
  }

  Future<void> deleteAlarm(int id) async {
    final db = await _db;
    await db.delete('alarm', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Alarm>> getAllAlarms() async {
    final db = await _db;
    final righe = await db.query('alarm', orderBy: 'orario ASC');
    return righe.map(Alarm.fromMap).toList();
  }

  // -----------------------------------------------------------------------
  // SleepRecord
  // -----------------------------------------------------------------------

  Future<int> insertSleepRecord(SleepRecord record) async {
    final db = await _db;
    return db.insert(
      'sleep_record',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSleepRecord(SleepRecord record) async {
    final db = await _db;
    await db.update('sleep_record', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> deleteSleepRecord(int id) async {
    final db = await _db;
    await db.delete('sleep_record', where: 'id = ?', whereArgs: [id]);
  }

  /// La sessione di sonno ancora aperta, se esiste: quella con `fineSonno`
  /// nullo. Il vincolo di esisterne al più una è imposto dalla logica
  /// applicativa (SleepViewModel), non dallo schema.
  Future<SleepRecord?> getSleepRecordInCorso() async {
    final db = await _db;
    final righe = await db.query(
      'sleep_record',
      where: 'fineSonno IS NULL',
      orderBy: 'inizioSonno DESC',
      limit: 1,
    );
    if (righe.isEmpty) return null;
    return SleepRecord.fromMap(righe.first);
  }

  Future<List<SleepRecord>> getSleepRecordsConclusi() async {
    final db = await _db;
    final righe = await db.query(
      'sleep_record',
      where: 'fineSonno IS NOT NULL',
      orderBy: 'inizioSonno DESC',
    );
    return righe.map(SleepRecord.fromMap).toList();
  }

  // -----------------------------------------------------------------------
  // StudySession
  // -----------------------------------------------------------------------

  Future<int> insertStudySession(StudySession sessione) async {
    final db = await _db;
    return db.insert(
      'study_session',
      sessione.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStudySession(StudySession sessione) async {
    final db = await _db;
    await db.update('study_session', sessione.toMap(),
        where: 'id = ?', whereArgs: [sessione.id]);
  }

  Future<List<StudySession>> getAllStudySessions() async {
    final db = await _db;
    final righe = await db.query('study_session', orderBy: 'istanteInizio DESC');
    return righe.map(StudySession.fromMap).toList();
  }

  // -----------------------------------------------------------------------
  // WeeklyGoal
  // -----------------------------------------------------------------------

  Future<int> insertWeeklyGoal(WeeklyGoal obiettivo) async {
    final db = await _db;
    return db.insert(
      'weekly_goal',
      obiettivo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWeeklyGoal(WeeklyGoal obiettivo) async {
    final db = await _db;
    await db.update('weekly_goal', obiettivo.toMap(),
        where: 'id = ?', whereArgs: [obiettivo.id]);
  }

  Future<void> deleteWeeklyGoal(int id) async {
    final db = await _db;
    await db.delete('weekly_goal', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WeeklyGoal>> getAllWeeklyGoals() async {
    final db = await _db;
    final righe = await db.query('weekly_goal', orderBy: 'categoria ASC');
    return righe.map(WeeklyGoal.fromMap).toList();
  }

  /// Traduce a livello applicativo il vincolo di unicità sulla categoria:
  /// usato da GoalsViewModel per verificare l'esistenza di un obiettivo
  /// prima di inserirne uno nuovo (pre-condizione del caso d'uso "Aggiungi
  /// obiettivo settimanale").
  Future<WeeklyGoal?> getWeeklyGoalByCategoria(GoalCategory categoria) async {
    final db = await _db;
    final righe = await db.query(
      'weekly_goal',
      where: 'categoria = ?',
      whereArgs: [categoria.name],
      limit: 1,
    );
    if (righe.isEmpty) return null;
    return WeeklyGoal.fromMap(righe.first);
  }
}