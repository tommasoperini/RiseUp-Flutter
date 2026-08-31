import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../viewmodels/alarms_viewmodel.dart';
import '../widgets/alarm_edit_dialog.dart';

/// Schermata di gestione delle sveglie (RF1, RF2, RF3-bis).
///
/// È la View del pattern MVVM: non contiene logica applicativa né accede al
/// database, ma osserva [AlarmsViewModel] tramite Provider e ne invoca i
/// metodi in risposta alle azioni dell'utente.
///
/// A differenza della versione Kotlin, lo stato dei dialog di conferma non
/// risiede nel ViewModel: in Compose non è possibile attendere il risultato
/// di un dialog, e la richiesta di conferma va quindi modellata come stato
/// osservabile; in Flutter `showDialog` restituisce un Future, per cui la
/// conferma può essere attesa localmente senza sporcare il ViewModel con
/// dettagli di presentazione.
class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  /// Impedisce di riaprire il dialog di spegnimento a ogni ricostruzione
  /// mentre la sveglia è in esecuzione.
  bool _dialogSvegliaAperto = false;

  @override
  void initState() {
    super.initState();
    // Il caricamento iniziale è richiesto al termine della prima costruzione
    // del widget: non può avvenire direttamente in initState perché
    // notifyListeners() innescherebbe un rebuild mentre l'albero dei widget
    // è ancora in costruzione.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmsViewModel>().caricaSveglie();
    });
  }

  Future<void> _apriDialogNuovaSveglia() async {
    final viewModel = context.read<AlarmsViewModel>();
    final risultato = await showDialog<AlarmEditResult>(
      context: context,
      builder: (_) => const AlarmEditDialog(),
    );
    if (risultato == null) return;
    await viewModel.aggiungiSveglia(
      orario: risultato.orario,
      giorniRipetizione: risultato.giorniRipetizione,
    );
  }

  Future<void> _apriDialogModifica(Alarm sveglia) async {
    final viewModel = context.read<AlarmsViewModel>();
    final risultato = await showDialog<AlarmEditResult>(
      context: context,
      builder: (_) => AlarmEditDialog(sveglia: sveglia),
    );
    if (risultato == null) return;
    await viewModel.aggiornaSveglia(
      sveglia.copyWith(
        orario: risultato.orario,
        giorniRipetizione: risultato.giorniRipetizione,
      ),
    );
  }

  Future<void> _confermaEliminazione(Alarm sveglia) async {
    final viewModel = context.read<AlarmsViewModel>();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina sveglia'),
        content: Text(
          'Vuoi eliminare la sveglia delle ${sveglia.orarioFormattato}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma == true) await viewModel.elimina(sveglia);
  }

  /// Caso d'uso "Spegni sveglia" (RF3-bis).
  void _gestisciSvegliaSuonante(Alarm? sveglia) {
    if (sveglia == null) {
      _dialogSvegliaAperto = false;
      return;
    }
    if (_dialogSvegliaAperto) return;
    _dialogSvegliaAperto = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final viewModel = context.read<AlarmsViewModel>();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sveglia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sono le ${sveglia.orarioFormattato}!'),
              if (viewModel.erroreSuoneria != null) ...[
                const SizedBox(height: 12),
                Text(
                  viewModel.erroreSuoneria!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                viewModel.spegniSveglia();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Spegni'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sveglie')),
      floatingActionButton: FloatingActionButton(
        onPressed: _apriDialogNuovaSveglia,
        tooltip: 'Aggiungi sveglia',
        child: const Icon(Icons.add),
      ),
      body: Consumer<AlarmsViewModel>(
        builder: (context, viewModel, _) {
          _gestisciSvegliaSuonante(viewModel.svegliaSuonante);

          if (viewModel.caricamento) {
            return const Center(child: CircularProgressIndicator());
          }

          final errore = viewModel.messaggioErrore;
          if (errore != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(errore, textAlign: TextAlign.center),
              ),
            );
          }

          if (viewModel.vuota) return const _ElencoVuoto();

          final voci = viewModel.voci;
          return ListView.builder(
            itemCount: voci.length,
            itemBuilder: (context, indice) {
              final voce = voci[indice];
              return _VoceSvegliaTile(
                voce: voce,
                onTap: () => _apriDialogModifica(voce.alarm),
                onAttivazioneCambiata: (attiva) =>
                    viewModel.cambiaAttivazione(voce.alarm, attiva),
                onElimina: () => _confermaEliminazione(voce.alarm),
              );
            },
          );
        },
      ),
    );
  }
}

/// Voce dell'elenco delle sveglie.
///
/// La prossima sveglia che si attiverà è evidenziata con un colore di sfondo
/// diverso e un'etichetta, come richiesto da RF2.
class _VoceSvegliaTile extends StatelessWidget {
  const _VoceSvegliaTile({
    required this.voce,
    required this.onTap,
    required this.onAttivazioneCambiata,
    required this.onElimina,
  });

  static const List<String> _etichetteGiorni = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  final VoceSveglia voce;
  final VoidCallback onTap;
  final ValueChanged<bool> onAttivazioneCambiata;
  final VoidCallback onElimina;

  String get _descrizioneRipetizione {
    final alarm = voce.alarm;
    if (!alarm.ripetuta) return 'Una sola volta';
    final giorni = <String>[];
    for (var indice = 0; indice < 7; indice++) {
      if (alarm.ripeteIlGiorno(indice)) giorni.add(_etichetteGiorni[indice]);
    }
    return giorni.join(', ');
  }

  /// Descrive quanto manca alla prossima attivazione, per la voce evidenziata.
  String? get _descrizioneAttesa {
    final istante = voce.prossimaAttivazione;
    if (istante == null) return null;
    final attesa = istante.difference(DateTime.now());
    final ore = attesa.inHours;
    final minuti = attesa.inMinutes % 60;
    return ore == 0 ? 'fra $minuti min' : 'fra ${ore}h $minuti min';
  }

  @override
  Widget build(BuildContext context) {
    final alarm = voce.alarm;
    final schema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: voce.prossima ? schema.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Text(
              alarm.orarioFormattato,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: alarm.attiva ? null : Theme.of(context).disabledColor,
              ),
            ),
            if (voce.prossima) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Prossima'),
                visualDensity: VisualDensity.compact,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        subtitle: Text(
          voce.prossima && _descrizioneAttesa != null
              ? '$_descrizioneRipetizione · $_descrizioneAttesa'
              : _descrizioneRipetizione,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: alarm.attiva, onChanged: onAttivazioneCambiata),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Elimina',
              onPressed: onElimina,
            ),
          ],
        ),
      ),
    );
  }
}

/// Messaggio mostrato quando non è ancora stata configurata alcuna sveglia.
class _ElencoVuoto extends StatelessWidget {
  const _ElencoVuoto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nessuna sveglia configurata.\nPremi + per aggiungerne una.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}