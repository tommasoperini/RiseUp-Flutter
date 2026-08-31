import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/report_viewmodel.dart';
import '../viewmodels/sleep_viewmodel.dart';
import '../viewmodels/study_viewmodel.dart';
import 'alarms_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'study_screen.dart';

/// Guscio di navigazione dell'applicazione.
///
/// Realizza la navigazione fra le quattro sezioni tramite una
/// [NavigationBar], con le stesse destinazioni della BottomNavBar della
/// versione Kotlin: Home, Sveglie, Studio, Report. Gli obiettivi settimanali
/// non compaiono qui perché si raggiungono dal report, accanto alle
/// statistiche che ne misurano l'avanzamento.
///
/// Le schermate sono mantenute in un [IndexedStack] anziché essere
/// ricostruite a ogni cambio di scheda: lo stato locale dei widget è così
/// preservato e non si ripete il caricamento iniziale a ogni passaggio. Lo
/// stato applicativo non risiede comunque qui ma nei ViewModel registrati
/// alla radice dell'albero, per cui la sessione di studio prosegue anche
/// quando l'utente consulta un'altra sezione.
///
/// Poiché sqflite non espone query osservabili — a differenza di Room, dove
/// i Flow aggiornano l'interfaccia da soli — al cambio di scheda si chiede
/// esplicitamente al ViewModel di destinazione di rileggere i dati.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _indiceHome = 0;
  static const int _indiceSveglie = 1;
  static const int _indiceStudio = 2;
  static const int _indiceReport = 3;

  int _indiceCorrente = _indiceHome;

  late final List<Widget> _schermate = [
    HomeScreen(onVaiASveglie: () => _cambiaScheda(_indiceSveglie)),
    const AlarmsScreen(),
    const StudyScreen(),
    const ReportScreen(),
  ];

  void _cambiaScheda(int indice) {
    setState(() => _indiceCorrente = indice);
    _aggiornaDatiScheda(indice);
  }

  void _aggiornaDatiScheda(int indice) {
    if (indice == _indiceHome) {
      context.read<SleepViewModel>().caricaStato();
    } else if (indice == _indiceStudio) {
      context.read<StudyViewModel>().caricaStato();
    } else if (indice == _indiceReport) {
      context.read<ReportViewModel>().caricaDati();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceCorrente,
        children: _schermate,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceCorrente,
        onDestinationSelected: _cambiaScheda,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Sveglie',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}