import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/app_entry_point.dart';
import 'theme/app_theme.dart';
import 'viewmodels/alarms_viewmodel.dart';
import 'viewmodels/goals_viewmodel.dart';
import 'viewmodels/report_viewmodel.dart';
import 'viewmodels/sleep_viewmodel.dart';
import 'viewmodels/study_viewmodel.dart';
import 'viewmodels/tutorial_viewmodel.dart';

/// Punto di ingresso dell'applicazione.
///
/// I ViewModel sono registrati alla radice dell'albero dei widget tramite
/// MultiProvider: sfruttando il meccanismo dell'InheritedWidget, ogni widget
/// discendente può accedervi con `context.read`/`context.watch` senza che le
/// istanze debbano essere passate esplicitamente nei costruttori dei livelli
/// intermedi.
///
/// La registrazione avviene qui, e non nelle singole schermate, perché i
/// ViewModel devono sopravvivere al cambio di sezione — i timer della
/// sessione di studio e della rilevazione delle sveglie devono restare in
/// esecuzione — e perché la home accede contemporaneamente ad
/// AlarmsViewModel e SleepViewModel.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudySleepTrackerApp());
}

class StudySleepTrackerApp extends StatelessWidget {
  const StudySleepTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmsViewModel()),
        ChangeNotifierProvider(create: (_) => SleepViewModel()),
        ChangeNotifierProvider(create: (_) => StudyViewModel()),
        ChangeNotifierProvider(create: (_) => GoalsViewModel()),
        ChangeNotifierProvider(create: (_) => ReportViewModel()),
        ChangeNotifierProvider(create: (_) => TutorialViewModel()),
      ],
      child: MaterialApp(
        title: 'Study & Sleep Tracker',
        theme: AppTheme.chiaro,
        darkTheme: AppTheme.scuro,
        // Il tema segue l'impostazione di sistema, come fa la versione
        // Kotlin tramite isSystemInDarkTheme().
        themeMode: ThemeMode.system,
        home: const AppEntryPoint(),
      ),
    );
  }
}