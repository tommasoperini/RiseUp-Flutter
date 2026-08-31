/// Fase corrente della modalità Studio.
///
/// Sta nel Model perché è condivisa fra ViewModel e View: non può vivere
/// dentro un file di UI, altrimenti il ViewModel dipenderebbe dalla View.
enum SessionPhase { configurazione, studio, pausa }

/// Modello dati corrispondente alla tabella `study_session`.
///
/// Memorizza le sessioni della modalità Studio (RF6, RF7, RF8, RF9): un
/// numero di cicli di studio alternati a pause, con durate impostabili
/// indipendentemente. La sessione è inserita a database al momento
/// dell'avvio, non al termine, così che l'istante di inizio sia quello
/// reale anche se l'applicazione venisse chiusa prima della conclusione
/// (sezione 6.1 della relazione).
class StudySession {
  final int? id;
  final DateTime istanteInizio;
  final DateTime? istanteFine;

  /// Durata di una singola fase di studio, in minuti.
  final int durataStudio;

  /// Durata di una singola pausa, in minuti.
  final int durataPausa;

  /// Numero di cicli studio-pausa previsti alla configurazione.
  final int cicliPrevisti;

  /// Numero di cicli di studio effettivamente portati a termine. Una
  /// sessione interrotta prima dello scadere del timer ha
  /// `cicliCompletati < cicliPrevisti`.
  final int cicliCompletati;

  const StudySession({
    this.id,
    required this.istanteInizio,
    this.istanteFine,
    required this.durataStudio,
    required this.durataPausa,
    required this.cicliPrevisti,
    this.cicliCompletati = 0,
  });

  /// Una sessione interrotta prima dello scadere del timer è una sessione
  /// parziale. Corrisponde alla proprietà `parziale` della versione Kotlin.
  bool get parziale => cicliCompletati < cicliPrevisti;

  /// Durata realmente trascorsa, o null se la sessione è ancora in corso.
  Duration? get durataEffettiva =>
      istanteFine == null ? null : istanteFine!.difference(istanteInizio);

  /// Durata totale stimata dell'intera sessione pianificata, in minuti:
  /// cicli moltiplicati per (studio + pausa). Mostrata in fase di
  /// configurazione, prima che la sessione sia avviata.
  int get minutiTotaliStimati => cicliPrevisti * (durataStudio + durataPausa);

  StudySession copyWith({
    int? id,
    DateTime? istanteInizio,
    DateTime? istanteFine,
    int? durataStudio,
    int? durataPausa,
    int? cicliPrevisti,
    int? cicliCompletati,
  }) {
    return StudySession(
      id: id ?? this.id,
      istanteInizio: istanteInizio ?? this.istanteInizio,
      istanteFine: istanteFine ?? this.istanteFine,
      durataStudio: durataStudio ?? this.durataStudio,
      durataPausa: durataPausa ?? this.durataPausa,
      cicliPrevisti: cicliPrevisti ?? this.cicliPrevisti,
      cicliCompletati: cicliCompletati ?? this.cicliCompletati,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'istanteInizio': istanteInizio.millisecondsSinceEpoch,
      'istanteFine': istanteFine?.millisecondsSinceEpoch,
      'durataStudio': durataStudio,
      'durataPausa': durataPausa,
      'cicliPrevisti': cicliPrevisti,
      'cicliCompletati': cicliCompletati,
    };
  }

  factory StudySession.fromMap(Map<String, Object?> map) {
    final fine = map['istanteFine'] as int?;
    return StudySession(
      id: map['id'] as int?,
      istanteInizio:
      DateTime.fromMillisecondsSinceEpoch(map['istanteInizio'] as int),
      istanteFine: fine == null ? null : DateTime.fromMillisecondsSinceEpoch(fine),
      durataStudio: map['durataStudio'] as int,
      durataPausa: map['durataPausa'] as int,
      cicliPrevisti: map['cicliPrevisti'] as int,
      cicliCompletati: map['cicliCompletati'] as int,
    );
  }
}