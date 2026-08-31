import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/alarms_viewmodel.dart';
import '../viewmodels/sleep_viewmodel.dart';
import 'tutorial_screen.dart';

/// Schermata iniziale dell'applicazione (RF2, RF4.1, RF4.2, RF4.3, RF4.4).
///
/// Raccoglie le informazioni che l'utente consulta più spesso: la prossima
/// sveglia programmata e lo stato della modalità notte. La collocazione qui
/// non è una scelta di presentazione ma un requisito: RF4.3 prescrive che
/// sia la home a mostrare lo stato della modalità notte e, quando attiva,
/// l'orario di inizio e la prossima sveglia programmata.
///
/// Le statistiche del sonno non compaiono qui ma nel report, dove sono
/// confrontate con l'obiettivo settimanale.
///
/// L'icona nell'AppBar riapre il tutorial (RF17) in qualunque momento,
/// distinto dalla proposta automatica al primo avvio gestita da
/// AppEntryPoint: qui il tutorial è raggiunto senza che il suo esito
/// influisca sulla preferenza già registrata, dato che TutorialViewModel
/// non distingue una nuova conferma da quella iniziale.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onVaiASveglie});

  /// Invocata quando l'utente tocca la carta della prossima sveglia: la
  /// navigazione fra le sezioni e' responsabilità del guscio, non di questa
  /// schermata.
  final VoidCallback onVaiASveglie;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _apriTutorial() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TutorialScreen(
          onFine: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepViewModel>().caricaStato();
    });
  }

  /// Mostra in una snackbar l'eventuale messaggio prodotto dal ViewModel —
  /// per esempio l'assenza di sveglie attive — e ne segnala la lettura, così
  /// che non venga riproposto a ogni ricostruzione.
  void _mostraErrore(String messaggio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggio)),
      );
      context.read<SleepViewModel>().confermaLetturaErrore();
    });
  }

  Future<void> _vadoADormire() async {
    final sleepViewModel = context.read<SleepViewModel>();
    final alarmsViewModel = context.read<AlarmsViewModel>();
    await sleepViewModel.attivaModalitaNotte(
      esisteSvegliaAttiva: alarmsViewModel.esisteSvegliaAttiva,
    );
  }

  Future<void> _confermaAnnullamento() async {
    final viewModel = context.read<SleepViewModel>();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annulla modalità notte'),
        content: const Text(
          'La sessione di sonno in corso non verrà registrata. Procedere?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annulla sessione'),
          ),
        ],
      ),
    );
    if (conferma == true) await viewModel.annullaModalitaNotte();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Tutorial',
            onPressed: _apriTutorial,
          ),
        ],
      ),
      body: Consumer2<AlarmsViewModel, SleepViewModel>(
        builder: (context, alarmsViewModel, sleepViewModel, _) {
          final errore = sleepViewModel.messaggioErrore;
          if (errore != null) _mostraErrore(errore);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CartaProssimaSveglia(
                viewModel: alarmsViewModel,
                onTap: widget.onVaiASveglie,
              ),
              const SizedBox(height: 16),
              _CartaModalitaNotte(
                viewModel: sleepViewModel,
                onVadoADormire: _vadoADormire,
                onAnnulla: _confermaAnnullamento,
                onConcludi: sleepViewModel.concludiModalitaNotte,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Carta della prossima sveglia programmata (RF2).
class _CartaProssimaSveglia extends StatelessWidget {
  const _CartaProssimaSveglia({required this.viewModel, required this.onTap});

  final AlarmsViewModel viewModel;
  final VoidCallback onTap;

  String _descriviAttesa(Duration attesa) {
    final ore = attesa.inHours;
    final minuti = attesa.inMinutes % 60;
    return ore == 0 ? 'fra $minuti min' : 'fra ${ore}h $minuti min';
  }

  @override
  Widget build(BuildContext context) {
    final sveglia = viewModel.prossimaSveglia;
    final attesa = viewModel.tempoAllaProssimaSveglia;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm),
                  const SizedBox(width: 10),
                  Text(
                    'Prossima sveglia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (sveglia == null)
                Text(
                  'Nessuna sveglia attiva. Tocca per impostarne una.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      sveglia.orarioFormattato,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(width: 12),
                    if (attesa != null)
                      Text(
                        _descriviAttesa(attesa),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carta di comando della modalità notte (RF4.1, RF4.2, RF4.4).
///
/// Non ripete la prossima sveglia programmata: quell'informazione è già
/// mostrata dalla carta soprastante (RF2), e duplicarla qui sarebbe
/// ridondante.
class _CartaModalitaNotte extends StatelessWidget {
  const _CartaModalitaNotte({
    required this.viewModel,
    required this.onVadoADormire,
    required this.onAnnulla,
    required this.onConcludi,
  });

  final SleepViewModel viewModel;
  final VoidCallback onVadoADormire;
  final VoidCallback onAnnulla;
  final VoidCallback onConcludi;

  String _formattaOrario(DateTime istante) {
    final ore = istante.hour.toString().padLeft(2, '0');
    final minuti = istante.minute.toString().padLeft(2, '0');
    return '$ore:$minuti';
  }

  String _formattaDurata(Duration durata) {
    final ore = durata.inHours;
    final minuti = durata.inMinutes % 60;
    return ore == 0 ? '$minuti min' : '${ore}h $minuti min';
  }

  @override
  Widget build(BuildContext context) {
    final sessione = viewModel.sessioneInCorso;

    if (sessione == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.nightlight_round, size: 32),
              const SizedBox(height: 12),
              Text(
                'Buonanotte',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "Dichiara l'inizio del riposo: la durata del sonno verrà "
                    'calcolata fino al risveglio.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onVadoADormire,
                  child: const Text('Vado a dormire'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // A modalità notte attiva la home mostra l'orario di inizio del riposo
    // e il tempo trascorso (RF4.3); la prossima sveglia è già mostrata dalla
    // carta soprastante.
    final durata = viewModel.durataSonnoInCorso;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.bedtime, size: 32),
            const SizedBox(height: 12),
            Text(
              'Modalità notte attiva',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Riposo iniziato alle ${_formattaOrario(sessione.inizioSonno)}',
            ),
            if (durata != null)
              Text('Sono trascorse ${_formattaDurata(durata)}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConcludi,
                child: const Text('Mi sono svegliato'),
              ),
            ),
            TextButton(
              onPressed: onAnnulla,
              child: const Text('Annulla modalità notte'),
            ),
          ],
        ),
      ),
    );
  }
}