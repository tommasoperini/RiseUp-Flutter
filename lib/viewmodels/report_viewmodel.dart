import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/weekly_goal.dart';
import '../system/stats_calculator.dart';

/// Le due schede della schermata Report.
enum SchedaReport {
  sonno('Sonno'),
  studio('Studio');

  const SchedaReport(this.etichetta);
  final String etichetta;
}

/// ViewModel dell'area Report (RF5, RF14).
///
/// Realizza i casi d'uso "Visualizza report Sonno" e "Visualizza report
/// Studio": elabora le statistiche della settimana di riferimento, le
/// confronta con gli obiettivi settimanali impostati e calcola l'andamento
/// delle ultime sei settimane (RF14.1) mostrato nel grafico del report.
///
/// I calcoli sono delegati a [StatsCalculator], la stessa classe di sola
/// logica usata dagli altri ViewModel, così che la definizione di settimana
/// di riferimento e di durata media sia unica in tutta l'applicazione.
class ReportViewModel extends ChangeNotifier {
  ReportViewModel({AppDatabase? database, StatsCalculator? statsCalculator})
      : _database = database ?? AppDatabase.instance,
        _stats = statsCalculator ?? const StatsCalculator();

  final AppDatabase _database;
  final StatsCalculator _stats;

  SchedaReport _scheda = SchedaReport.sonno;
  StatisticheSonno _statisticheSonno = const StatisticheSonno();
  StatisticheStudio _statisticheStudio = const StatisticheStudio();
  WeeklyGoal? _obiettivoSonno;
  WeeklyGoal? _obiettivoStudio;
  List<PuntoSettimana> _andamentoSonno = const [];
  List<PuntoSettimana> _andamentoStudio = const [];
  bool _caricamento = true;
  String? _messaggioErrore;

  SchedaReport get scheda => _scheda;

  StatisticheSonno get statisticheSonno => _statisticheSonno;

  StatisticheStudio get statisticheStudio => _statisticheStudio;

  WeeklyGoal? get obiettivoSonno => _obiettivoSonno;

  WeeklyGoal? get obiettivoStudio => _obiettivoStudio;

  /// Serie delle ultime sei settimane, per la card "Andamento" del report.
  List<PuntoSettimana> get andamentoSonno => _andamentoSonno;

  List<PuntoSettimana> get andamentoStudio => _andamentoStudio;

  /// L'andamento è mostrato solo se almeno una delle settimane della serie
  /// contiene dati: altrimenti sarebbe un grafico interamente vuoto, che non
  /// aggiungerebbe informazione rispetto a non mostrarlo. La card resta
  /// visibile anche quando la sola settimana corrente è priva di dati,
  /// perché l'andamento riguarda le settimane passate — è proprio il caso in
  /// cui guardare indietro è più utile del dettaglio di oggi.
  bool get andamentoSonnoVisibile =>
      _andamentoSonno.any((punto) => punto.minutiTotali > 0);

  bool get andamentoStudioVisibile =>
      _andamentoStudio.any((punto) => punto.minutiTotali > 0);

  bool get caricamento => _caricamento;

  String? get messaggioErrore => _messaggioErrore;

  bool get sonnoSenzaDati => !_caricamento && _statisticheSonno.numeroNotti == 0;

  bool get studioSenzaDati =>
      !_caricamento && _statisticheStudio.numeroSessioni == 0;

  /// Avanzamento dell'obiettivo di sonno, fra 0 e 1. Vale 0 se nessun
  /// obiettivo è stato impostato per la categoria.
  double get avanzamentoSonno {
    final obiettivo = _obiettivoSonno;
    if (obiettivo == null) return 0;
    return _stats.avanzamento(
      _statisticheSonno.minutiTotali,
      obiettivo.valoreObiettivo,
    );
  }

  double get avanzamentoStudio {
    final obiettivo = _obiettivoStudio;
    if (obiettivo == null) return 0;
    return _stats.avanzamento(
      _statisticheStudio.minutiTotali,
      obiettivo.valoreObiettivo,
    );
  }

  void selezionaScheda(SchedaReport scheda) {
    if (_scheda == scheda) return;
    _scheda = scheda;
    notifyListeners();
  }

  /// Rilegge dal database sessioni, registrazioni e obiettivi, limitandosi
  /// alla settimana di riferimento, e ricalcola le statistiche.
  ///
  /// Nella versione Kotlin le tre sorgenti sono combinate in un unico flusso
  /// osservabile e la schermata si aggiorna da sola a ogni variazione; qui
  /// il ricalcolo è esplicito perché sqflite non espone query osservabili.
  Future<void> caricaDati() async {
    _caricamento = true;
    notifyListeners();

    try {
      final settimana = _stats.settimanaDi();

      final sessioni = await _database.getAllStudySessions();
      final registrazioni = await _database.getSleepRecordsConclusi();
      final obiettivi = await _database.getAllWeeklyGoals();

      _statisticheStudio = _stats.statisticheStudio(
        sessioni.where((s) => settimana.contiene(s.istanteInizio)).toList(),
      );
      _statisticheSonno = _stats.statisticheSonno(
        registrazioni.where((r) => settimana.contiene(r.inizioSonno)).toList(),
      );

      _obiettivoSonno = _cercaObiettivo(obiettivi, GoalCategory.sonno);
      _obiettivoStudio = _cercaObiettivo(obiettivi, GoalCategory.studio);

      // Le serie storiche riusano le stesse liste complete già lette per le
      // statistiche della settimana corrente, senza interrogare di nuovo il
      // database: StatsCalculator si occupa di suddividerle per settimana.
      _andamentoSonno = _stats.andamentoSonno(registrazioni);
      _andamentoStudio = _stats.andamentoStudio(sessioni);

      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile caricare il report: $e';
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  /// Restituisce l'obiettivo della categoria indicata, o null se non esiste.
  /// Il vincolo di unicita' sulla colonna categoria garantisce che ve ne sia
  /// al piu' uno.
  static WeeklyGoal? _cercaObiettivo(
      List<WeeklyGoal> obiettivi,
      GoalCategory categoria,
      ) {
    for (final obiettivo in obiettivi) {
      if (obiettivo.categoria == categoria) return obiettivo;
    }
    return null;
  }
}