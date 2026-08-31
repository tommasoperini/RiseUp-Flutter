import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/sleep_record.dart';
import '../system/stats_calculator.dart';

/// ViewModel dell'area Sonno (RF4, RF4.1-RF4.4, RF5).
///
/// A differenza di AlarmsViewModel, che gestisce un CRUD, questo ViewModel
/// mantiene uno stato: esiste al più una sessione di sonno aperta alla volta,
/// riconoscibile a database dal fatto che il suo attributo `fineSonno` è
/// nullo (sezione 6.1 della relazione).
///
/// I calcoli statistici sono delegati a [StatsCalculator], la stessa classe
/// di sola logica usata dalla versione Kotlin, così da non duplicare qui la
/// definizione di settimana di riferimento e di durata media.
class SleepViewModel extends ChangeNotifier {
  SleepViewModel({AppDatabase? database, StatsCalculator? statsCalculator})
      : _database = database ?? AppDatabase.instance,
        _stats = statsCalculator ?? const StatsCalculator() {
    _avviaAggiornamentoPeriodico();
  }

  final AppDatabase _database;
  final StatsCalculator _stats;

  /// La durata del sonno in corso è mostrata in schermata: senza un
  /// aggiornamento periodico resterebbe ferma al valore calcolato all'ultima
  /// notifica. Un minuto è sufficiente, dato che il valore è espresso in ore
  /// e minuti.
  static const Duration _intervalloAggiornamento = Duration(minutes: 1);

  Timer? _timerAggiornamento;

  SleepRecord? _sessioneInCorso;
  List<SleepRecord> _registrazioni = const [];
  bool _caricamento = true;
  String? _messaggioErrore;

  SleepRecord? get sessioneInCorso => _sessioneInCorso;

  bool get modalitaNotteAttiva => _sessioneInCorso != null;

  List<SleepRecord> get registrazioni => List.unmodifiable(_registrazioni);

  bool get caricamento => _caricamento;

  String? get messaggioErrore => _messaggioErrore;

  void _avviaAggiornamentoPeriodico() {
    _timerAggiornamento = Timer.periodic(_intervalloAggiornamento, (_) {
      if (_sessioneInCorso != null) notifyListeners();
    });
  }

  // -----------------------------------------------------------------------
  // Caricamento
  // -----------------------------------------------------------------------

  Future<void> caricaStato() async {
    _caricamento = true;
    _messaggioErrore = null;
    notifyListeners();

    try {
      _sessioneInCorso = await _database.getSleepRecordInCorso();
      _registrazioni = await _database.getSleepRecordsConclusi();
    } catch (e) {
      _messaggioErrore = 'Impossibile caricare i dati del sonno: $e';
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // RF4.1 — Attiva modalità notte
  // -----------------------------------------------------------------------

  /// Caso d'uso "Attiva modalità notte": registra l'istante corrente come
  /// inizio del sonno.
  ///
  /// [esisteSvegliaAttiva] è fornito dalla View, che lo ricava da
  /// AlarmsViewModel: realizza la sequenza alternativa del caso d'uso,
  /// secondo cui la modalità notte non viene attivata in assenza di sveglie
  /// programmate. La verifica resta qui, e non nella View, perché è una
  /// regola applicativa e non una scelta di presentazione.
  Future<void> attivaModalitaNotte({required bool esisteSvegliaAttiva}) async {
    if (_sessioneInCorso != null) return;

    if (!esisteSvegliaAttiva) {
      _messaggioErrore =
      'Nessuna sveglia attiva: imposta una sveglia prima di avviare la modalità notte.';
      notifyListeners();
      return;
    }

    try {
      await _database.insertSleepRecord(
        SleepRecord(inizioSonno: DateTime.now()),
      );
      // Si rilegge dal database per ottenere la riga completa dell'id
      // assegnato dall'autoincremento.
      _sessioneInCorso = await _database.getSleepRecordInCorso();
      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile avviare la modalità notte: $e';
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF4.2 — Annulla modalità notte
  // -----------------------------------------------------------------------

  /// Caso d'uso "Disattiva modalità notte": annulla la dichiarazione di
  /// inizio del sonno senza registrare alcuna sessione. La riga è quindi
  /// eliminata, non conclusa.
  Future<void> annullaModalitaNotte() async {
    final sessione = _sessioneInCorso;
    if (sessione?.id == null) return;

    try {
      await _database.deleteSleepRecord(sessione!.id!);
      _sessioneInCorso = null;
      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile annullare la modalità notte: $e';
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF4.4 — Concludi modalità notte
  // -----------------------------------------------------------------------

  /// Caso d'uso "Concludi modalità notte": registra l'istante di risveglio,
  /// rendendo la sessione disponibile alle statistiche (RF5).
  Future<void> concludiModalitaNotte() async {
    final sessione = _sessioneInCorso;
    if (sessione?.id == null) return;

    try {
      await _database.updateSleepRecord(
        sessione!.copyWith(fineSonno: DateTime.now()),
      );
      _sessioneInCorso = null;
      _registrazioni = await _database.getSleepRecordsConclusi();
      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile concludere la modalità notte: $e';
    }
    notifyListeners();
  }

  /// Azzera il messaggio di errore dopo che la View lo ha mostrato, così che
  /// non venga ripresentato a ogni ricostruzione.
  void confermaLetturaErrore() {
    if (_messaggioErrore == null) return;
    _messaggioErrore = null;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF4.3 — Stato della modalità notte
  // -----------------------------------------------------------------------

  /// Tempo trascorso dall'inizio del sonno, per la visualizzazione in home.
  Duration? get durataSonnoInCorso {
    final sessione = _sessioneInCorso;
    if (sessione == null) return null;
    return DateTime.now().difference(sessione.inizioSonno);
  }

  // -----------------------------------------------------------------------
  // RF5 — Statistiche del sonno
  // -----------------------------------------------------------------------

  /// Statistiche su tutte le sessioni concluse.
  StatisticheSonno get statistiche => _stats.statisticheSonno(_registrazioni);

  /// Statistiche limitate alla settimana di riferimento, per il confronto
  /// con l'obiettivo settimanale.
  StatisticheSonno get statisticheSettimana {
    final settimana = _stats.settimanaDi();
    final dellaSettimana = _registrazioni
        .where((r) => settimana.contiene(r.inizioSonno))
        .toList();
    return _stats.statisticheSonno(dellaSettimana);
  }

  /// Minuti dormiti nella settimana corrente, usati dagli obiettivi (RF11).
  int get minutiSettimanaCorrente => statisticheSettimana.minutiTotali;

  /// Durata dell'ultima sessione conclusa, o null se non ve ne sono.
  Duration? get durataUltimaSessione =>
      _registrazioni.isEmpty ? null : _registrazioni.first.durata;

  @override
  void dispose() {
    _timerAggiornamento?.cancel();
    super.dispose();
  }
}