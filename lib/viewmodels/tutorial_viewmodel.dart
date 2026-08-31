import 'package:flutter/foundation.dart';

import '../data/app_prefs.dart';

/// Registra che il tutorial è stato visto (RF17, casi d'uso "Completa
/// tutorial" e "Saltare tutorial").
///
/// Lo scorrimento fra le pagine è interamente gestito da [TutorialScreen]
/// con lo stato del PageController: non è un dato che debba sopravvivere
/// alla chiusura dell'app. Questo ViewModel si occupa solo della
/// persistenza finale.
///
/// Non distingue fra le due conclusioni possibili: sia la conferma
/// sull'ultima pagina sia "Salta" hanno la stessa post-condizione, il
/// tutorial non viene più riproposto automaticamente all'avvio.
class TutorialViewModel extends ChangeNotifier {
  TutorialViewModel({AppPrefs? prefs}) : _prefs = prefs ?? AppPrefs.instance;

  final AppPrefs _prefs;

  bool _completato = false;
  bool _caricamento = true;

  /// True se il tutorial è già stato completato o saltato in precedenza:
  /// determina se mostrarlo automaticamente all'avvio dell'app.
  bool get completato => _completato;

  bool get caricamento => _caricamento;

  /// Da leggere una sola volta all'avvio dell'app, per decidere la
  /// destinazione di partenza (corrisponde alla lettura di TutorialPrefs
  /// fatta da MainActivity nella versione Kotlin).
  Future<void> caricaStato() async {
    _completato = await _prefs.getTutorialCompletato();
    _caricamento = false;
    notifyListeners();
  }

  Future<void> segnaCompletato() async {
    _completato = true;
    notifyListeners();
    await _prefs.setTutorialCompletato(true);
  }
}
