import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/alarm.dart';

/// Una sveglia arricchita con i dati che servono alla lista ma che non stanno
/// a database perché dipendono dall'ora corrente: quando suonerà e se è la
/// prossima ad attivarsi.
///
/// Corrisponde alla classe VoceSveglia della versione Kotlin.
class VoceSveglia {
  final Alarm alarm;
  final DateTime? prossimaAttivazione;
  final bool prossima;

  const VoceSveglia({
    required this.alarm,
    required this.prossimaAttivazione,
    required this.prossima,
  });
}

/// ViewModel dell'area Sveglie (RF1: gestione delle sveglie; RF2:
/// individuazione della prossima sveglia; RF3-bis: segnalazione della
/// sveglia scattata mentre l'app è in esecuzione).
///
/// Estende [ChangeNotifier] secondo il pattern MVVM adottato: la View
/// osserva questa classe tramite Provider e viene ricostruita a ogni
/// invocazione di `notifyListeners()`. Il ViewModel dialoga direttamente con
/// [AppDatabase], senza livello Repository intermedio (semplificazione
/// motivata nella sezione 5.2 della relazione).
///
/// Come dichiarato in RNF5, l'app non programma la sveglia a livello di
/// sistema operativo: un [Timer] periodico verifica, solo mentre l'app è in
/// esecuzione, se una sveglia attiva è scattata.
class AlarmsViewModel extends ChangeNotifier {
  AlarmsViewModel({AppDatabase? database})
      : _database = database ?? AppDatabase.instance {
    _ultimoControllo = DateTime.now();
    _avviaControlloPeriodico();
  }

  final AppDatabase _database;
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Intervallo fra due controlli dell'orario.
  static const Duration _intervalloControllo = Duration(seconds: 30);

  /// Massimo ritardo tollerato nella rilevazione. Se l'applicazione resta
  /// sospesa a lungo, al ritorno in primo piano il timer riparte e
  /// rileverebbe come "appena scattate" sveglie di ore prima: oltre questa
  /// soglia l'occorrenza è considerata persa e non viene segnalata.
  static const Duration _tolleranzaRitardo = Duration(minutes: 5);

  Timer? _timerControllo;

  /// Istante dell'ultima verifica. Il controllo non confronta l'ora corrente
  /// con l'orario della sveglia — approccio che perderebbe l'occorrenza se
  /// nessun tick cadesse in quel minuto — ma cerca le occorrenze comprese
  /// nell'intervallo fra questo istante e adesso.
  late DateTime _ultimoControllo;

  List<Alarm> _sveglie = const [];
  bool _caricamento = true;
  String? _messaggioErrore;
  Alarm? _svegliaSuonante;

  /// Elenco delle sveglie arricchite per la visualizzazione (RF2).
  List<VoceSveglia> get voci {
    final adesso = DateTime.now();
    Alarm? prossima;
    DateTime? istanteProssima;

    for (final sveglia in _sveglie) {
      if (!sveglia.attiva) continue;
      final istante = prossimaOccorrenza(sveglia, adesso);
      if (istante == null) continue;
      if (istanteProssima == null || istante.isBefore(istanteProssima)) {
        istanteProssima = istante;
        prossima = sveglia;
      }
    }

    return _sveglie.map((sveglia) {
      return VoceSveglia(
        alarm: sveglia,
        prossimaAttivazione:
        sveglia.attiva ? prossimaOccorrenza(sveglia, adesso) : null,
        prossima: sveglia.attiva && sveglia.id == prossima?.id,
      );
    }).toList();
  }

  bool get caricamento => _caricamento;

  String? get messaggioErrore => _messaggioErrore;

  bool get vuota => !_caricamento && _sveglie.isEmpty;

  /// Sveglia attualmente in esecuzione, o null se nessuna sta suonando.
  Alarm? get svegliaSuonante => _svegliaSuonante;

  /// Prossima sveglia attiva (RF2), o null se non ne esiste alcuna.
  Alarm? get prossimaSveglia {
    for (final voce in voci) {
      if (voce.prossima) return voce.alarm;
    }
    return null;
  }

  /// Istante della prossima attivazione, per il riepilogo in schermata.
  DateTime? get istanteProssimaSveglia {
    for (final voce in voci) {
      if (voce.prossima) return voce.prossimaAttivazione;
    }
    return null;
  }

  Duration? get tempoAllaProssimaSveglia =>
      istanteProssimaSveglia?.difference(DateTime.now());

  /// True se esiste almeno una sveglia attiva: serve alla pre-condizione del
  /// caso d'uso "Attiva modalità notte".
  bool get esisteSvegliaAttiva => prossimaSveglia != null;

  // -----------------------------------------------------------------------
  // Caricamento
  // -----------------------------------------------------------------------

  Future<void> caricaSveglie() async {
    _caricamento = true;
    _messaggioErrore = null;
    notifyListeners();

    try {
      _sveglie = await _database.getAllAlarms();
    } catch (e) {
      _messaggioErrore = 'Impossibile caricare le sveglie: $e';
      _sveglie = const [];
    } finally {
      _caricamento = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // RF1 — Creazione, modifica, attivazione ed eliminazione
  // -----------------------------------------------------------------------

  /// Caso d'uso "Aggiungi sveglia".
  Future<void> aggiungiSveglia({
    required int orario,
    int giorniRipetizione = 0,
  }) async {
    await _eseguiEAggiorna(
          () => _database.insertAlarm(
        Alarm(orario: orario, giorniRipetizione: giorniRipetizione),
      ),
    );
  }

  /// Caso d'uso "Modifica sveglia".
  Future<void> aggiornaSveglia(Alarm sveglia) async {
    await _eseguiEAggiorna(() => _database.updateAlarm(sveglia));
  }

  /// Sequenza alternativa del caso d'uso "Modifica sveglia": lo switch sulla
  /// voce di elenco attiva o disattiva la sola programmazione.
  Future<void> cambiaAttivazione(Alarm sveglia, bool attiva) async {
    await _eseguiEAggiorna(
          () => _database.updateAlarm(sveglia.copyWith(attiva: attiva)),
    );
  }

  /// Caso d'uso "Elimina sveglia".
  Future<void> elimina(Alarm sveglia) async {
    if (sveglia.id == null) return;
    await _eseguiEAggiorna(() => _database.deleteAlarm(sveglia.id!));
  }

  /// Esegue un'operazione di scrittura e ricarica l'elenco, così che la lista
  /// mostrata rispecchi sempre il contenuto del database (unica fonte di
  /// verità) anziché una copia aggiornata a mano.
  Future<void> _eseguiEAggiorna(Future<void> Function() operazione) async {
    try {
      await operazione();
      _sveglie = await _database.getAllAlarms();
      _messaggioErrore = null;
    } catch (e) {
      _messaggioErrore = 'Operazione non riuscita: $e';
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // RF3-bis — Attivazione e spegnimento della sveglia
  // -----------------------------------------------------------------------

  void _avviaControlloPeriodico() {
    _timerControllo = Timer.periodic(
      _intervalloControllo,
          (_) => _controllaSveglieScattate(),
    );
  }

  /// Verifica se una sveglia attiva è scattata nell'intervallo fra
  /// [_ultimoControllo] e l'istante corrente.
  ///
  /// L'intervallo, e non il singolo minuto, è il criterio corretto: i [Timer]
  /// di Dart non offrono garanzie di puntualità e vengono rallentati quando
  /// l'applicazione non è in primo piano, quindi un controllo basato
  /// sull'uguaglianza col minuto corrente perderebbe silenziosamente le
  /// occorrenze.
  void _controllaSveglieScattate() {
    final adesso = DateTime.now();
    final precedente = _ultimoControllo;
    _ultimoControllo = adesso;

    if (_svegliaSuonante != null) return;

    for (final sveglia in _sveglie) {
      if (!sveglia.attiva) continue;

      // Prima occorrenza successiva all'ultimo controllo: se cade prima di
      // adesso, la sveglia è scattata nel frattempo.
      final occorrenza = prossimaOccorrenza(sveglia, precedente);
      if (occorrenza == null) continue;
      if (occorrenza.isAfter(adesso)) continue;
      if (adesso.difference(occorrenza) > _tolleranzaRitardo) continue;

      _faiSuonare(sveglia);
      return;
    }
  }

  /// Percorso della suoneria all'interno degli asset. AssetSource antepone
  /// da sé il prefisso `assets/`, per cui il file atteso è
  /// `assets/sounds/alarm_tone.mp3`, dichiarato nel pubspec.yaml.
  static const String _percorsoSuoneria = 'sounds/alarm_tone.mp3';

  Future<void> _faiSuonare(Alarm sveglia) async {
    _svegliaSuonante = sveglia;
    notifyListeners();

    try {
      // La riproduzione è in ciclo continuo finché l'utente non spegne la
      // sveglia: una traccia breve riprodotta una volta sola passerebbe
      // facilmente inosservata.
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(_percorsoSuoneria));
    } catch (e) {
      // L'errore non deve impedire la segnalazione visiva della sveglia: il
      // dialog di spegnimento resta comunque aperto. Senza questa cattura
      // l'eccezione andrebbe persa, non essendo la chiamata attesa, e la
      // suoneria risulterebbe muta senza alcuna indicazione della causa.
      debugPrint('Riproduzione della suoneria non riuscita: $e');
      _erroreSuoneria = 'Suoneria non riprodotta: verifica che il file '
          'assets/$_percorsoSuoneria sia presente e dichiarato nel pubspec.';
      notifyListeners();
    }
  }

  String? _erroreSuoneria;

  /// Eventuale problema nella riproduzione della suoneria, mostrato accanto
  /// alla segnalazione di sveglia in corso.
  String? get erroreSuoneria => _erroreSuoneria;

  /// Caso d'uso "Spegni sveglia" (RF3-bis): interrompe la suoneria e, se la
  /// sveglia non è ripetuta, la disattiva — come fa `dopoAttivazione` nella
  /// versione Kotlin.
  Future<void> spegniSveglia() async {
    final sveglia = _svegliaSuonante;
    if (sveglia == null) return;

    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Arresto della suoneria non riuscito: $e');
    }
    _svegliaSuonante = null;
    _erroreSuoneria = null;

    if (!sveglia.ripetuta) {
      await cambiaAttivazione(sveglia, false);
    } else {
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Calcolo della prossima attivazione
  // -----------------------------------------------------------------------

  /// Primo istante successivo a [riferimento] in cui [sveglia] deve suonare.
  ///
  /// Se non è ripetuta, oggi all'orario indicato oppure domani se è passato.
  /// Se è ripetuta, il primo giorno utile fra quelli selezionati.
  ///
  /// Riproduce il metodo `prossimaAttivazione` di AlarmScheduler nella
  /// versione Kotlin, con la differenza che qui non esiste alcuna
  /// programmazione a livello di sistema operativo.
  static DateTime? prossimaOccorrenza(Alarm sveglia, DateTime riferimento) {
    final mezzanotte = DateTime(
      riferimento.year,
      riferimento.month,
      riferimento.day,
    );

    if (!sveglia.ripetuta) {
      final oggi = mezzanotte.add(Duration(minutes: sveglia.orario));
      return oggi.isAfter(riferimento)
          ? oggi
          : oggi.add(const Duration(days: 1));
    }

    // Si esaminano gli otto giorni successivi: il giorno corrente più una
    // settimana completa, così da coprire il caso in cui l'unica ripetizione
    // sia oggi ma a orario già trascorso.
    for (var scarto = 0; scarto <= 7; scarto++) {
      final giorno = mezzanotte.add(Duration(days: scarto));
      // DateTime.weekday vale 1 per lunedì e 7 per domenica; la maschera usa
      // invece l'indice 0 per lunedì.
      if (!sveglia.ripeteIlGiorno(giorno.weekday - 1)) continue;
      final istante = giorno.add(Duration(minutes: sveglia.orario));
      if (istante.isAfter(riferimento)) return istante;
    }
    return null;
  }

  @override
  void dispose() {
    _timerControllo?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}