import 'package:shared_preferences/shared_preferences.dart';

/// Incapsula l'accesso alle shared preferences (sezione 6.2 della
/// relazione): nomi delle chiavi e valori predefiniti non sono mai noti ai
/// widget, che passano sempre da questa classe.
///
/// A differenza della versione Kotlin, dove l'incapsulamento è ripartito fra
/// `TutorialPrefs` e `StudyPrefs`, qui si è preferita un'unica classe data la
/// ridotta numerosità delle chiavi.
class AppPrefs {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  static const String _chiaveTutorialCompletato = 'tutorial_completato';
  static const String _chiaveDurataStudioDefault = 'durata_studio_default';
  static const String _chiaveDurataPausaDefault = 'durata_pausa_default';

  static const int _durataStudioPredefinita = 25;
  static const int _durataPausaPredefinita = 5;

  Future<bool> getTutorialCompletato() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chiaveTutorialCompletato) ?? false;
  }

  Future<void> setTutorialCompletato(bool completato) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiaveTutorialCompletato, completato);
  }

  Future<int> getDurataStudioDefault() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chiaveDurataStudioDefault) ?? _durataStudioPredefinita;
  }

  Future<void> setDurataStudioDefault(int minuti) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chiaveDurataStudioDefault, minuti);
  }

  Future<int> getDurataPausaDefault() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chiaveDurataPausaDefault) ?? _durataPausaPredefinita;
  }

  Future<void> setDurataPausaDefault(int minuti) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chiaveDurataPausaDefault, minuti);
  }
}