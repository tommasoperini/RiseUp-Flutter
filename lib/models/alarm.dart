/// Modello dati corrispondente alla tabella `alarm`.
///
/// Memorizza le sveglie configurate dall'utente. Rispetto all'entity `Alarm`
/// della versione Kotlin non sono presenti gli attributi `suoneriaUri` e
/// `tipoSfida`, legati alla suoneria configurabile e alla sfida di
/// disattivazione, entrambe escluse dalla versione Flutter (-FLUTTER).
///
/// `orario` è espresso in minuti dalla mezzanotte: 7:30 corrisponde a 450.
/// `giorniRipetizione` è una maschera di bit, bit 0 = lunedì ... bit 6 =
/// domenica. Il valore 0 identifica una sveglia non ripetuta, che suona una
/// volta sola.
class Alarm {
  final int? id;
  final int orario;
  final int giorniRipetizione;
  final bool attiva;

  const Alarm({
    this.id,
    required this.orario,
    this.giorniRipetizione = 0,
    this.attiva = true,
  });

  /// Ora della sveglia (0-23).
  int get ora => orario ~/ 60;

  /// Minuto della sveglia (0-59).
  int get minuto => orario % 60;

  /// True se la sveglia si ripete in almeno un giorno della settimana.
  bool get ripetuta => giorniRipetizione != 0;

  /// Orario formattato come HH:mm, per la visualizzazione in interfaccia.
  String get orarioFormattato {
    final h = ora.toString().padLeft(2, '0');
    final m = minuto.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// True se la sveglia si ripete nel giorno indicato
  /// (indice 0 = lunedì ... 6 = domenica).
  bool ripeteIlGiorno(int indiceGiorno) =>
      (giorniRipetizione & (1 << indiceGiorno)) != 0;

  Alarm copyWith({
    int? id,
    int? orario,
    int? giorniRipetizione,
    bool? attiva,
  }) {
    return Alarm(
      id: id ?? this.id,
      orario: orario ?? this.orario,
      giorniRipetizione: giorniRipetizione ?? this.giorniRipetizione,
      attiva: attiva ?? this.attiva,
    );
  }

  /// Converte l'oggetto in una Map utilizzabile da sqflite.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'orario': orario,
      'giorniRipetizione': giorniRipetizione,
      'attiva': attiva ? 1 : 0,
    };
  }

  /// Ricostruisce l'oggetto a partire da una riga letta dal database.
  factory Alarm.fromMap(Map<String, Object?> map) {
    return Alarm(
      id: map['id'] as int?,
      orario: map['orario'] as int,
      giorniRipetizione: map['giorniRipetizione'] as int,
      attiva: (map['attiva'] as int) == 1,
    );
  }
}

/// Converte un insieme di indici di giorno (0 = lunedì) nella maschera di bit
/// memorizzata a database. Equivalente dell'estensione `aMaschera` Kotlin.
int giorniAMaschera(Set<int> giorni) =>
    giorni.fold(0, (acc, giorno) => acc | (1 << giorno));

/// Operazione inversa: dalla maschera all'insieme degli indici di giorno.
Set<int> mascheraAGiorni(int maschera) {
  final giorni = <int>{};
  for (var i = 0; i < 7; i++) {
    if (maschera & (1 << i) != 0) giorni.add(i);
  }
  return giorni;
}

/// Compone l'orario, in minuti dalla mezzanotte, a partire da ore e minuti.
int orarioDaOreMinuti(int ora, int minuto) => ora * 60 + minuto;