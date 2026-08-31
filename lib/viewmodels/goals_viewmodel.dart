import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/weekly_goal.dart';
import '../system/stats_calculator.dart';

/// Un obiettivo con il suo stato di avanzamento nella settimana corrente.
///
/// Corrisponde alla classe `VoceObiettivo` della versione Kotlin: raccoglie
/// l'obiettivo memorizzato a database e i valori derivati, che dipendono
/// dalle sessioni registrate e non sono quindi persistiti.
class VoceObiettivo {
  final WeeklyGoal obiettivo;
  final int minutiRaggiunti;
  final double avanzamento;
  final bool raggiunto;

  const VoceObiettivo({
    required this.obiettivo,
    required this.minutiRaggiunti,
    required this.avanzamento,
    required this.raggiunto,
  });
}

/// ViewModel degli obiettivi settimanali (RF11, RF12, RF13).
///
/// Realizza il caso d'uso "Imposta obiettivo settimanale", che è il caso di
/// ingresso dell'area: da esso sono raggiungibili aggiunta, modifica ed
/// eliminazione.
///
/// Come il corrispondente ViewModel Kotlin, accede a tre insiemi di dati —
/// obiettivi, sessioni di studio e registrazioni di sonno — perché
/// l'avanzamento di un obiettivo dipende dalle sessioni della settimana. A
/// differenza della versione Kotlin, dove i tre flussi sono combinati e la
/// schermata si aggiorna da sola, qui il ricalcolo è esplicito: sqflite non
/// offre query osservabili come Room, quindi i dati vanno riletti quando la
/// schermata torna visibile.
class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel({AppDatabase? database, StatsCalculator? statsCalculator})
      : _database = database ?? AppDatabase.instance,
        _stats = statsCalculator ?? const StatsCalculator();

  final AppDatabase _database;
  final StatsCalculator _stats;

  List<VoceObiettivo> _voci = const [];
  bool _caricamento = true;
  String? _messaggioErrore;

  List<VoceObiettivo> get voci => List.unmodifiable(_voci);

  bool get caricamento => _caricamento;

  String? get messaggioErrore => _messaggioErrore;

  bool get vuota => !_caricamento && _voci.isEmpty;

  /// True quando esiste già un obiettivo per ogni categoria: la View
  /// disabilita l'aggiunta, traducendo in interfaccia la pre-condizione del
  /// caso d'uso "Aggiungi obiettivo settimanale".
  bool get tutteLeCategorieOccupate =>
      _voci.length >= GoalCategory.values.length;

  /// Categorie per cui non esiste ancora un obiettivo.
  List<GoalCategory> get categorieDisponibili {
    final occupate = _voci.map((v) => v.obiettivo.categoria).toSet();
    return GoalCategory.values
        .where((categoria) => !occupate.contains(categoria))
        .toList();
  }

  // -----------------------------------------------------------------------
  // Caricamento
  // -----------------------------------------------------------------------

  /// Rilegge obiettivi e sessioni e ricalcola l'avanzamento.
  Future<void> caricaObiettivi() async {
    _caricamento = true;
    notifyListeners();

    try {
      final settimana = _stats.settimanaDi();

      final obiettivi = await _database.getAllWeeklyGoals();
      final sessioni = await _database.getAllStudySessions();
      final registrazioni = await _database.getSleepRecordsConclusi();

      final minutiStudio = _stats
          .statisticheStudio(sessioni
          .where((s) => settimana.contiene(s.istanteInizio))
          .toList())
          .minutiTotali;

      final minutiSonno = _stats
          .statisticheSonno(registrazioni
          .where((r) => settimana.contiene(r.inizioSonno))
          .toList())
          .minutiTotali;

      _voci = obiettivi.map((obiettivo) {
        final raggiunti = switch (obiettivo.categoria) {
          GoalCategory.studio => minutiStudio,
          GoalCategory.sonno => minutiSonno,
        };
        return VoceObiettivo(
          obiettivo: obiettivo,
          minutiRaggiunti: raggiunti,
          avanzamento: _stats.avanzamento(raggiunti, obiettivo.valoreObiettivo),
          raggiunto:
          _stats.obiettivoRaggiunto(raggiunti, obiettivo.valoreObiettivo),
        );
      }).toList();

      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Impossibile caricare gli obiettivi: $e';
      _voci = const [];
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // RF11 — Aggiunta
  // -----------------------------------------------------------------------

  /// Caso d'uso "Aggiungi obiettivo settimanale".
  ///
  /// Restituisce false se esiste già un obiettivo per la categoria indicata,
  /// anziché propagare l'eccezione di violazione del vincolo di unicità: la
  /// View può così mostrare un messaggio senza conoscere dettagli di
  /// persistenza. È la stessa scelta fatta da `GoalRepository.aggiungi`
  /// nella versione Kotlin.
  Future<bool> aggiungi(GoalCategory categoria, int valoreObiettivo) async {
    if (valoreObiettivo <= 0) return false;

    try {
      final esistente = await _database.getWeeklyGoalByCategoria(categoria);
      if (esistente != null) return false;

      await _database.insertWeeklyGoal(
        WeeklyGoal(
          categoria: categoria,
          valoreObiettivo: valoreObiettivo,
          dataCreazione: DateTime.now(),
        ),
      );
      await caricaObiettivi();
      return true;
    } catch (e) {
      _messaggioErrore = 'Impossibile salvare l\'obiettivo: $e';
      notifyListeners();
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // RF13 — Modifica
  // -----------------------------------------------------------------------

  /// Caso d'uso "Modifica obiettivo settimanale". La categoria non è
  /// modificabile: si cambia il solo valore, come nella versione Kotlin.
  Future<void> aggiorna(WeeklyGoal obiettivo, int nuovoValore) async {
    if (nuovoValore <= 0) return;
    try {
      await _database.updateWeeklyGoal(
        obiettivo.copyWith(valoreObiettivo: nuovoValore),
      );
      await caricaObiettivi();
    } catch (e) {
      _messaggioErrore = 'Impossibile aggiornare l\'obiettivo: $e';
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // RF12 — Eliminazione
  // -----------------------------------------------------------------------

  /// Caso d'uso "Elimina obiettivo settimanale".
  Future<void> elimina(WeeklyGoal obiettivo) async {
    if (obiettivo.id == null) return;
    try {
      await _database.deleteWeeklyGoal(obiettivo.id!);
      await caricaObiettivi();
    } catch (e) {
      _messaggioErrore = 'Impossibile eliminare l\'obiettivo: $e';
      notifyListeners();
    }
  }
}