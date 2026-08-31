import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/app_prefs.dart';
import '../models/study_session.dart';
import '../system/stats_calculator.dart';

/// Bersaglio del dialog di scelta della durata: quale delle due durate della
/// sessione (studio o pausa) l'utente sta impostando.
enum TargetDurata { studio, pausa }

/// ViewModel della modalità Studio (RF6, RF7, RF8, RF9, RF14).
///
/// A differenza della versione Kotlin, dove il timer vive in
/// StudySessionService — un Foreground Service Android che fa proseguire il
/// conteggio anche ad app chiusa, con lo StudyViewModel ridotto a fare
/// polling sullo stato persistito — qui il timer resta nel ViewModel stesso,
/// coerentemente con RNF5: nessuna esecuzione in background, la sessione
/// procede solo mentre l'applicazione è in primo piano. È lo stesso limite
/// già dichiarato per le sveglie, esteso qui alla modalità Studio.
///
/// La temporizzazione non decrementa un contatore, ma memorizza l'istante di
/// fine previsto per la fase corrente e ricava a ogni tick i secondi
/// mancanti dall'orologio di sistema, esattamente come fa
/// `secondiMancanti` nella versione Kotlin: i Timer di Dart non offrono
/// garanzie di puntualità e vengono rallentati quando l'applicazione non è
/// in primo piano, per cui un contatore decrementato accumulerebbe un
/// errore proporzionale al tempo trascorso in pausa dell'app.
class StudyViewModel extends ChangeNotifier {
  StudyViewModel({
    AppDatabase? database,
    AppPrefs? prefs,
    StatsCalculator? statsCalculator,
  })  : _database = database ?? AppDatabase.instance,
        _prefs = prefs ?? AppPrefs.instance,
        _stats = statsCalculator ?? const StatsCalculator();

  final AppDatabase _database;
  final AppPrefs _prefs;
  final StatsCalculator _stats;

  static const Duration _intervalloTick = Duration(milliseconds: 500);
  static const List<int> durateProposte = [5, 10, 15, 20, 25, 30, 45, 60];
  static const int _cicliMassimi = 12;

  Timer? _timer;

  SessionPhase _fase = SessionPhase.configurazione;
  int _durataStudioMinuti = 25;
  int _durataPausaMinuti = 5;
  int _cicliPrevisti = 1;
  int _cicliCompletati = 0;

  /// Istante in cui la fase corrente (studio o pausa) deve concludersi. È la
  /// sola grandezza temporale conservata: tutto il resto è derivato da
  /// questa e dall'ora corrente.
  DateTime? _istanteFineFase;

  StudySession? _sessioneCorrente;
  List<StudySession> _sessioni = const [];
  String? _messaggioErrore;

  SessionPhase get fase => _fase;

  bool get sessioneInCorso =>
      _fase == SessionPhase.studio || _fase == SessionPhase.pausa;

  int get durataStudioMinuti => _durataStudioMinuti;

  int get durataPausaMinuti => _durataPausaMinuti;

  int get cicliPrevisti => _cicliPrevisti;

  /// Numero del ciclo in corso, a partire da 1: coincide con
  /// `cicliCompletati + 1` finché la sessione è attiva.
  int get cicloCorrente => _cicliCompletati + 1;

  /// Durata totale stimata dell'intera sessione pianificata, in minuti.
  /// Mostrata in fase di configurazione, prima dell'avvio.
  int get minutiTotaliStimati =>
      _cicliPrevisti * (_durataStudioMinuti + _durataPausaMinuti);

  String? get messaggioErrore => _messaggioErrore;

  /// Secondi mancanti alla fine della fase corrente, ricavati
  /// dall'orologio anziché da un contatore decrementato.
  int get secondiRimanenti {
    final fine = _istanteFineFase;
    if (fine == null) return 0;
    final millisecondi = fine.difference(DateTime.now()).inMilliseconds;
    if (millisecondi <= 0) return 0;
    // Arrotondamento per eccesso, così che il conteggio mostri la durata
    // impostata nell'istante immediatamente successivo all'avvio della fase.
    return (millisecondi + 999) ~/ 1000;
  }

  int get secondiTotaliFase {
    final minuti = switch (_fase) {
      SessionPhase.studio => _durataStudioMinuti,
      SessionPhase.pausa => _durataPausaMinuti,
      SessionPhase.configurazione => 0,
    };
    return minuti * 60;
  }

  /// Da 0.0 a 1.0, per il CircularProgressIndicator.
  double get progresso {
    final totale = secondiTotaliFase;
    if (totale <= 0) return 0;
    return (totale - secondiRimanenti) / totale;
  }

  /// Tempo residuo formattato come mm:ss.
  String get tempoResiduoFormattato {
    final residui = secondiRimanenti;
    final minuti = (residui ~/ 60).toString().padLeft(2, '0');
    final secondi = (residui % 60).toString().padLeft(2, '0');
    return '$minuti:$secondi';
  }

  // -----------------------------------------------------------------------
  // Caricamento
  // -----------------------------------------------------------------------

  Future<void> caricaStato() async {
    try {
      _durataStudioMinuti = await _prefs.getDurataStudioDefault();
      _durataPausaMinuti = await _prefs.getDurataPausaDefault();
      _sessioni = await _database.getAllStudySessions();
      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile caricare i dati dello studio: $e';
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF6, RF7 — Impostazione delle durate e del numero di cicli
  // -----------------------------------------------------------------------

  /// Casi d'uso "Imposta timer studio"/"Imposta timer di pausa". La durata
  /// scelta è persistita come nuovo valore predefinito, così da essere
  /// riproposta agli avvii successivi.
  Future<void> impostaDurata(TargetDurata target, int minuti) async {
    if (sessioneInCorso || minuti <= 0) return;

    switch (target) {
      case TargetDurata.studio:
        _durataStudioMinuti = minuti;
        notifyListeners();
        await _prefs.setDurataStudioDefault(minuti);
      case TargetDurata.pausa:
        _durataPausaMinuti = minuti;
        notifyListeners();
        await _prefs.setDurataPausaDefault(minuti);
    }
  }

  void incrementaCicli() {
    if (sessioneInCorso) return;
    if (_cicliPrevisti >= _cicliMassimi) return;
    _cicliPrevisti++;
    notifyListeners();
  }

  void decrementaCicli() {
    if (sessioneInCorso) return;
    if (_cicliPrevisti <= 1) return;
    _cicliPrevisti--;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF8 — Avvio della sessione
  // -----------------------------------------------------------------------

  /// Caso d'uso "Avvia modalità Studio". La sessione è inserita a database
  /// subito, e non al termine, così che l'istante di inizio sia quello
  /// reale anche se l'applicazione venisse chiusa prima della conclusione.
  Future<void> avviaSessione() async {
    if (sessioneInCorso) return;

    try {
      final adesso = DateTime.now();
      final sessione = StudySession(
        istanteInizio: adesso,
        durataStudio: _durataStudioMinuti,
        durataPausa: _durataPausaMinuti,
        cicliPrevisti: _cicliPrevisti,
        cicliCompletati: 0,
      );
      final id = await _database.insertStudySession(sessione);

      _sessioneCorrente = sessione.copyWith(id: id);
      _cicliCompletati = 0;
      _fase = SessionPhase.studio;
      _istanteFineFase = adesso.add(Duration(minutes: _durataStudioMinuti));
      _messaggioErrore = null;
      _avviaTick();
    } catch (e) {
      _messaggioErrore = 'Impossibile avviare la sessione: $e';
    }
    notifyListeners();
  }

  /// Il tick non fa avanzare il conteggio: si limita a chiedere alla View di
  /// ridisegnarsi e a verificare se la fase corrente è terminata.
  void _avviaTick() {
    _timer?.cancel();
    _timer = Timer.periodic(_intervalloTick, (_) {
      if (secondiRimanenti <= 0) {
        _avanzaFase();
      } else {
        notifyListeners();
      }
    });
  }

  /// Fa avanzare la sessione allo scadere della fase corrente: dalla fase di
  /// studio si passa alla pausa dello stesso ciclo; dalla pausa si passa al
  /// ciclo successivo, oppure — se era l'ultimo ciclo previsto — la sessione
  /// si conclude regolarmente (caso d'uso "Terminare timer Studio").
  void _avanzaFase() {
    switch (_fase) {
      case SessionPhase.studio:
        _fase = SessionPhase.pausa;
        _istanteFineFase =
            DateTime.now().add(Duration(minutes: _durataPausaMinuti));
        notifyListeners();

      case SessionPhase.pausa:
        _cicliCompletati++;
        if (_cicliCompletati >= _cicliPrevisti) {
          _concludi(cicliCompletati: _cicliCompletati);
        } else {
          _fase = SessionPhase.studio;
          _istanteFineFase =
              DateTime.now().add(Duration(minutes: _durataStudioMinuti));
          notifyListeners();
        }

      case SessionPhase.configurazione:
        break;
    }
  }

  // -----------------------------------------------------------------------
  // RF9 — Interruzione anticipata
  // -----------------------------------------------------------------------

  /// Caso d'uso "Interrompi modalità Studio": la sessione è registrata come
  /// parziale, con `cicliCompletati` inferiore a `cicliPrevisti`.
  Future<void> interrompiSessione() async {
    if (!sessioneInCorso) return;
    await _concludi(cicliCompletati: _cicliCompletati);
  }

  /// Registra a database la conclusione della sessione, regolare o
  /// anticipata che sia: la distinzione è ricavabile dal confronto fra
  /// `cicliCompletati` e `cicliPrevisti` (proprietà `parziale` del Model),
  /// per cui non serve un parametro separato.
  Future<void> _concludi({required int cicliCompletati}) async {
    _timer?.cancel();
    _timer = null;

    final sessione = _sessioneCorrente;
    if (sessione?.id != null) {
      try {
        await _database.updateStudySession(
          sessione!.copyWith(
            istanteFine: DateTime.now(),
            cicliCompletati: cicliCompletati,
          ),
        );
        _sessioni = await _database.getAllStudySessions();
      } catch (e) {
        _messaggioErrore = 'Impossibile registrare la sessione: $e';
      }
    }

    _sessioneCorrente = null;
    _istanteFineFase = null;
    _cicliCompletati = 0;
    _fase = SessionPhase.configurazione;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF14 — Statistiche dello studio
  // -----------------------------------------------------------------------

  /// Sessioni concluse, complete o parziali che siano.
  List<StudySession> get sessioniConcluse =>
      _sessioni.where((s) => s.istanteFine != null).toList();

  /// Statistiche complessive su tutte le sessioni registrate.
  StatisticheStudio get statistiche => _stats.statisticheStudio(_sessioni);

  /// Statistiche limitate alla settimana di riferimento, per il confronto
  /// con l'obiettivo settimanale.
  StatisticheStudio get statisticheSettimana {
    final settimana = _stats.settimanaDi();
    final dellaSettimana = _sessioni
        .where((s) => settimana.contiene(s.istanteInizio))
        .toList();
    return _stats.statisticheStudio(dellaSettimana);
  }

  int get minutiSettimanaCorrente => statisticheSettimana.minutiTotali;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}