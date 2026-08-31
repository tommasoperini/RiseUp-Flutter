import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/tutorial_viewmodel.dart';
import 'main_shell.dart';
import 'tutorial_screen.dart';

/// Decide la destinazione di partenza dell'applicazione, leggendo se il
/// tutorial è già stato completato o saltato in precedenza.
///
/// Corrisponde alla lettura di TutorialPrefs fatta da MainActivity nella
/// versione Kotlin: qui la logica non sta nel punto di ingresso
/// dell'applicazione ma in un widget dedicato, per non appesantire
/// `main.dart` con una decisione di navigazione.
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TutorialViewModel>().caricaStato();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TutorialViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.caricamento) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!viewModel.completato) {
          return TutorialScreen(
            onFine: () {
              // Al termine del tutorial la navigazione sostituisce la
              // schermata anziché impilarla: l'utente non deve poter
              // tornare indietro al tutorial premendo "indietro" dalla home.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const MainShell()),
              );
            },
          );
        }

        return const MainShell();
      },
    );
  }
}
