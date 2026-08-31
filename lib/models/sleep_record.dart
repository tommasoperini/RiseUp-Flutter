/// Modello dati corrispondente alla tabella `sleep_record`.
///
/// Memorizza le sessioni di sonno registrate tramite la modalità notte
/// (RF4.1-RF4.4). `fineSonno` è nullable e resta nullo finché la sessione è
/// in corso: la sua nullità è il criterio con cui il sistema riconosce che
/// la modalità notte è attiva (sezione 6.1 della relazione).
///
/// Rispetto all'entity `SleepRecord` della versione Kotlin non sono presenti
/// gli attributi `istanteAttivazione`, `istanteDisattivazione` e
/// `durataRisveglio`, relativi alla fase di risveglio gestita dalla sveglia
/// di sistema: in Flutter la sveglia non si attiva autonomamente (RNF5), per
/// cui quella fase non è tracciabile. Ne consegue che le statistiche del
/// sonno non includono un tempo medio di spegnimento della sveglia.
class SleepRecord {
  final int? id;
  final DateTime inizioSonno;
  final DateTime? fineSonno;

  const SleepRecord({
    this.id,
    required this.inizioSonno,
    this.fineSonno,
  });

  /// Durata della sessione, o null se ancora in corso. Non è memorizzata a
  /// database: è calcolata a runtime dalla differenza fra gli istanti
  /// registrati, per evitare di duplicare un'informazione già ricavabile.
  Duration? get durata =>
      fineSonno == null ? null : fineSonno!.difference(inizioSonno);

  SleepRecord copyWith({
    int? id,
    DateTime? inizioSonno,
    DateTime? fineSonno,
  }) {
    return SleepRecord(
      id: id ?? this.id,
      inizioSonno: inizioSonno ?? this.inizioSonno,
      fineSonno: fineSonno ?? this.fineSonno,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'inizioSonno': inizioSonno.millisecondsSinceEpoch,
      'fineSonno': fineSonno?.millisecondsSinceEpoch,
    };
  }

  factory SleepRecord.fromMap(Map<String, Object?> map) {
    final fine = map['fineSonno'] as int?;
    return SleepRecord(
      id: map['id'] as int?,
      inizioSonno:
      DateTime.fromMillisecondsSinceEpoch(map['inizioSonno'] as int),
      fineSonno: fine == null ? null : DateTime.fromMillisecondsSinceEpoch(fine),
    );
  }
}