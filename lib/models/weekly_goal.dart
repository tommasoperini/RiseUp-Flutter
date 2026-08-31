/// Le due categorie su cui si può fissare un obiettivo settimanale.
///
/// Corrisponde all'enum `GoalCategory` della versione Kotlin, etichetta
/// compresa. In sqflite non esiste un TypeConverter automatico come in Room:
/// la conversione da e verso la rappresentazione testuale memorizzata a
/// database è realizzata dai metodi `name` e `values.byName`.
enum GoalCategory {
  sonno('Sonno'),
  studio('Studio');

  const GoalCategory(this.etichetta);

  /// Nome leggibile della categoria, usato nell'interfaccia.
  final String etichetta;

  static GoalCategory fromName(String name) => GoalCategory.values.byName(name);
}

/// Modello dati corrispondente alla tabella `weekly_goal`.
///
/// Obiettivo settimanale di sonno o di studio, espresso in minuti. Invariato
/// rispetto all'entity `WeeklyGoal` della versione Kotlin.
///
/// Il vincolo di unicità su `categoria`, dichiarato nello schema della
/// tabella, traduce la pre-condizione del caso d'uso "Aggiungi obiettivo
/// settimanale": non può esistere più di un obiettivo per la medesima
/// categoria.
class WeeklyGoal {
  final int? id;
  final GoalCategory categoria;

  /// Valore obiettivo, espresso in minuti da raggiungere nella settimana.
  final int valoreObiettivo;
  final DateTime dataCreazione;

  const WeeklyGoal({
    this.id,
    required this.categoria,
    required this.valoreObiettivo,
    required this.dataCreazione,
  });

  WeeklyGoal copyWith({
    int? id,
    GoalCategory? categoria,
    int? valoreObiettivo,
    DateTime? dataCreazione,
  }) {
    return WeeklyGoal(
      id: id ?? this.id,
      categoria: categoria ?? this.categoria,
      valoreObiettivo: valoreObiettivo ?? this.valoreObiettivo,
      dataCreazione: dataCreazione ?? this.dataCreazione,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'categoria': categoria.name,
      'valoreObiettivo': valoreObiettivo,
      'dataCreazione': dataCreazione.millisecondsSinceEpoch,
    };
  }

  factory WeeklyGoal.fromMap(Map<String, Object?> map) {
    return WeeklyGoal(
      id: map['id'] as int?,
      categoria: GoalCategory.fromName(map['categoria'] as String),
      valoreObiettivo: map['valoreObiettivo'] as int,
      dataCreazione:
      DateTime.fromMillisecondsSinceEpoch(map['dataCreazione'] as int),
    );
  }
}