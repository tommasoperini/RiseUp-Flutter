import 'dart:math' as math;

import '../models/sleep_record.dart';
import '../models/study_session.dart';

/// Intervallo di una settimana, dal lunedì al lunedì successivo escluso.
class IntervalloSettimana {
  final DateTime inizio;
  final DateTime fine;

  const IntervalloSettimana({required this.inizio, required this.fine});

  bool contiene(DateTime istante) =>
      !istante.isBefore(inizio) && istante.isBefore(fine);
}

/// Un punto della serie storica settimanale mostrata nel grafico "Andamento"
/// del report: la settimana a cui si riferisce e i minuti totalizzati in
/// quella settimana, per studio o per sonno a seconda del contesto in cui è
/// prodotto.
class PuntoSettimana {
  final IntervalloSettimana settimana;
  final int minutiTotali;
  final bool settimanaCorrente;

  const PuntoSettimana({
    required this.settimana,
    required this.minutiTotali,
    required this.settimanaCorrente,
  });

  /// Etichetta breve per l'asse orizzontale, nel formato giorno/mese del
  /// lunedì della settimana (es. "24/8").
  String get etichetta => '${settimana.inizio.day}/${settimana.inizio.month}';
}

/// Statistiche sulle sessioni di studio di un intervallo.
class StatisticheStudio {
  final int numeroSessioni;
  final int minutiTotali;
  final int minutiMedi;
  final int sessioniParziali;

  const StatisticheStudio({
    this.numeroSessioni = 0,
    this.minutiTotali = 0,
    this.minutiMedi = 0,
    this.sessioniParziali = 0,
  });
}

/// Statistiche sulle sessioni di sonno di un intervallo.
///
/// Rispetto alla versione Kotlin manca `secondiMediRisveglio`: la fase di
/// risveglio non è tracciata, poiché in Flutter la sveglia non si attiva
/// autonomamente (RNF5) e il modello dati non registra gli istanti di
/// attivazione e disattivazione della suoneria.
class StatisticheSonno {
  final int numeroNotti;
  final int minutiTotali;
  final int minutiMedi;
  final DateTime? oraMediaAddormentamento;
  final DateTime? oraMediaRisveglio;

  const StatisticheSonno({
    this.numeroNotti = 0,
    this.minutiTotali = 0,
    this.minutiMedi = 0,
    this.oraMediaAddormentamento,
    this.oraMediaRisveglio,
  });
}



/// Elabora le statistiche su sonno e studio.
///
/// Classe di sola logica, priva di stato e di dipendenze da Flutter: riceve
/// le liste già lette dal database e restituisce valori aggregati. È usata
/// dai ViewModel delle aree Sonno, Studio, Report e Obiettivi.
///
/// Qui vengono calcolati i valori non memorizzati a database — la durata del
/// sonno e quella delle sessioni di studio — per evitare di duplicare
/// informazioni già ricavabili dagli istanti registrati (sezione 6.1 della
/// relazione).
class StatsCalculator {
  const StatsCalculator();

  static const int _secondiInUnGiorno = 86400;

  // -----------------------------------------------------------------------
  // Intervalli
  // -----------------------------------------------------------------------

  /// Settimana di riferimento: dal lunedì alla domenica che contengono
  /// [data]. L'estremo superiore è il lunedì successivo, escluso.
  IntervalloSettimana settimanaDi([DateTime? data]) {
    final riferimento = data ?? DateTime.now();
    final giorno = DateTime(riferimento.year, riferimento.month, riferimento.day);
    // DateTime.weekday vale 1 per lunedì: sottraendo weekday - 1 giorni si
    // ottiene sempre il lunedì della settimana in corso.
    final lunedi = giorno.subtract(Duration(days: giorno.weekday - 1));
    return IntervalloSettimana(
      inizio: lunedi,
      fine: lunedi.add(const Duration(days: 7)),
    );
  }

  IntervalloSettimana settimanaPrecedente([DateTime? data]) =>
      settimanaDi((data ?? DateTime.now()).subtract(const Duration(days: 7)));



  /// Le ultime [numeroSettimane] settimane, dalla più vecchia alla più
  /// recente, con quella corrente come ultimo elemento. Corrisponde
  /// all'iterazione di `settimanaPrecedente` usata dalla versione Kotlin per
  /// popolare il grafico "Andamento" del report.
  List<IntervalloSettimana> ultimeSettimane({int numeroSettimane = 6}) {
    final settimane = <IntervalloSettimana>[];
    var corrente = settimanaDi();
    settimane.add(corrente);
    for (var i = 1; i < numeroSettimane; i++) {
      corrente = settimanaDi(corrente.inizio.subtract(const Duration(days: 7)));
      settimane.add(corrente);
    }
    return settimane.reversed.toList();
  }

  /// Serie storica dei minuti di studio nelle ultime [numeroSettimane]
  /// settimane, per il grafico "Andamento dello studio".
  List<PuntoSettimana> andamentoStudio(
      List<StudySession> sessioni, {
        int numeroSettimane = 6,
      }) {
    final settimanaAttuale = settimanaDi();
    return ultimeSettimane(numeroSettimane: numeroSettimane).map((settimana) {
      final dellaSettimana = sessioni
          .where((s) => settimana.contiene(s.istanteInizio))
          .toList();
      return PuntoSettimana(
        settimana: settimana,
        minutiTotali: statisticheStudio(dellaSettimana).minutiTotali,
        settimanaCorrente: settimana.inizio == settimanaAttuale.inizio,
      );
    }).toList();
  }

  /// Serie storica dei minuti di sonno nelle ultime [numeroSettimane]
  /// settimane, per il grafico "Andamento del sonno".
  List<PuntoSettimana> andamentoSonno(
      List<SleepRecord> registrazioni, {
        int numeroSettimane = 6,
      }) {
    final settimanaAttuale = settimanaDi();
    return ultimeSettimane(numeroSettimane: numeroSettimane).map((settimana) {
      final dellaSettimana = registrazioni
          .where((r) => settimana.contiene(r.inizioSonno))
          .toList();
      return PuntoSettimana(
        settimana: settimana,
        minutiTotali: statisticheSonno(dellaSettimana).minutiTotali,
        settimanaCorrente: settimana.inizio == settimanaAttuale.inizio,
      );
    }).toList();
  }

  // -----------------------------------------------------------------------
  // Studio
  // -----------------------------------------------------------------------

  /// Minuti di studio effettivi di una sessione: il tempo realmente
  /// trascorso fra inizio e fine, non la durata pianificata.
  ///
  /// Usare `durataStudio` sovrastimerebbe sistematicamente le sessioni
  /// interrotte, la cui durata reale è inferiore a quella impostata.
  ///
  /// Il valore è arrotondato al minuto più vicino, non troncato:
  /// `Duration.inMinutes` tronca per difetto, il che farebbe scomparire ogni
  /// sessione più breve di un minuto (0 minuti anziché 1), sottostimando
  /// sistematicamente il totale se ci sono più sessioni brevi.
  int minutiStudio(StudySession sessione) {
    final durata = sessione.durataEffettiva;
    if (durata == null) return 0;
    if (durata.inMilliseconds <= 0) return 0;
    return (durata.inSeconds / 60).round();
  }

  StatisticheStudio statisticheStudio(List<StudySession> sessioni) {
    final concluse = sessioni.where((s) => s.istanteFine != null).toList();
    if (concluse.isEmpty) return const StatisticheStudio();

    var minutiTotali = 0;
    for (final sessione in concluse) {
      minutiTotali += minutiStudio(sessione);
    }
    return StatisticheStudio(
      numeroSessioni: concluse.length,
      minutiTotali: minutiTotali,
      minutiMedi: minutiTotali ~/ concluse.length,
      sessioniParziali: concluse.where((s) => s.parziale).length,
    );
  }

  // -----------------------------------------------------------------------
  // Sonno
  // -----------------------------------------------------------------------

  /// Minuti di sonno effettivi di una registrazione, con lo stesso
  /// arrotondamento (non troncamento) usato in [minutiStudio].
  int minutiSonno(SleepRecord record) {
    final durata = record.durata;
    if (durata == null) return 0;
    if (durata.inMilliseconds <= 0) return 0;
    return (durata.inSeconds / 60).round();
  }

  StatisticheSonno statisticheSonno(List<SleepRecord> registrazioni) {
    final concluse =
    registrazioni.where((r) => r.fineSonno != null).toList();
    if (concluse.isEmpty) return const StatisticheSonno();

    var minutiTotali = 0;
    for (final record in concluse) {
      minutiTotali += minutiSonno(record);
    }

    return StatisticheSonno(
      numeroNotti: concluse.length,
      minutiTotali: minutiTotali,
      minutiMedi: minutiTotali ~/ concluse.length,
      oraMediaAddormentamento:
      oraMedia(concluse.map((r) => r.inizioSonno).toList()),
      oraMediaRisveglio:
      oraMedia(concluse.map((r) => r.fineSonno!).toList()),
    );
  }

  /// Media di un insieme di orari.
  ///
  /// Non è una media aritmetica sui minuti dalla mezzanotte: gli orari di
  /// addormentamento cadono a cavallo della mezzanotte, e la media fra le
  /// 23:00 e l'01:00 darebbe le 12:00 anziché mezzanotte. Gli orari sono
  /// quindi trattati come angoli su un cerchio di 24 ore e mediati come
  /// vettori, riportando poi il risultato a un orario.
  ///
  /// Il valore restituito è un [DateTime] di cui sono significative le sole
  /// componenti di ora e minuto.
  DateTime? oraMedia(List<DateTime> istanti) {
    if (istanti.isEmpty) return null;

    var sommaSeno = 0.0;
    var sommaCoseno = 0.0;

    for (final istante in istanti) {
      final secondiDelGiorno =
          istante.hour * 3600 + istante.minute * 60 + istante.second;
      final angolo = 2 * math.pi * secondiDelGiorno / _secondiInUnGiorno;
      sommaSeno += math.sin(angolo);
      sommaCoseno += math.cos(angolo);
    }

    final angoloMedio = math.atan2(sommaSeno, sommaCoseno);
    final normalizzato =
    angoloMedio < 0 ? angoloMedio + 2 * math.pi : angoloMedio;
    var secondi = (normalizzato / (2 * math.pi) * _secondiInUnGiorno).round();
    secondi = secondi.clamp(0, _secondiInUnGiorno - 1);

    return DateTime(2000, 1, 1).add(Duration(seconds: secondi));
  }

  // -----------------------------------------------------------------------
  // Obiettivi
  // -----------------------------------------------------------------------

  /// Avanzamento fra 0 e 1, pronto per una barra di progresso.
  double avanzamento(int valoreRaggiunto, int valoreObiettivo) {
    if (valoreObiettivo <= 0) return 0;
    return (valoreRaggiunto / valoreObiettivo).clamp(0.0, 1.0);
  }

  bool obiettivoRaggiunto(int valoreRaggiunto, int valoreObiettivo) =>
      valoreObiettivo > 0 && valoreRaggiunto >= valoreObiettivo;
}

/// Formatta una quantità di minuti come "2h 30m", o "45m" se sotto l'ora.
String formattaMinuti(int minuti) =>
    minuti < 60 ? '${minuti}m' : '${minuti ~/ 60}h ${minuti % 60}m';

/// Formatta un orario come HH:mm.
String formattaOrario(DateTime istante) {
  final ore = istante.hour.toString().padLeft(2, '0');
  final minuti = istante.minute.toString().padLeft(2, '0');
  return '$ore:$minuti';
}