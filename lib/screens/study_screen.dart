import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_session.dart';
import '../viewmodels/study_viewmodel.dart';
import '../widgets/duration_picker_dialog.dart';

/// Schermata della modalità Studio (RF6, RF7, RF8, RF9).
///
/// Unica destinazione dell'area, con tre stati visivi selezionati dallo
/// stato del ViewModel: configurazione, studio, pausa — corrisponde a
/// StudyScreen nella mappa dell'architettura.
///
/// Non ha AppBar: il titolo "Nuova sessione" sta nel corpo, come nella
/// versione Kotlin.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyViewModel>().caricaStato();
    });
  }

  Future<void> _apriDialogDurata(TargetDurata target) async {
    final viewModel = context.read<StudyViewModel>();
    final valoreIniziale = target == TargetDurata.studio
        ? viewModel.durataStudioMinuti
        : viewModel.durataPausaMinuti;

    final scelta = await showDialog<int>(
      context: context,
      builder: (_) => DurationPickerDialog(
        titolo: target == TargetDurata.studio ? 'Durata studio' : 'Durata pausa',
        minutiIniziali: valoreIniziale,
      ),
    );
    if (scelta != null) await viewModel.impostaDurata(target, scelta);
  }

  Future<void> _confermaInterruzione() async {
    final viewModel = context.read<StudyViewModel>();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Interrompere la sessione?'),
        content: const Text("La sessione verrà registrata come parziale."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Interrompi'),
          ),
        ],
      ),
    );
    if (conferma == true) await viewModel.interrompiSessione();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<StudyViewModel>(
          builder: (context, viewModel, _) {
            return viewModel.sessioneInCorso
                ? _SessioneInCorsoContent(
              viewModel: viewModel,
              onInterrompi: _confermaInterruzione,
            )
                : _ConfigurazioneContent(
              viewModel: viewModel,
              onApriDialogDurata: _apriDialogDurata,
            );
          },
        ),
      ),
    );
  }
}

/// Stato: sessione in corso (fase di studio o di pausa).
class _SessioneInCorsoContent extends StatelessWidget {
  const _SessioneInCorsoContent({
    required this.viewModel,
    required this.onInterrompi,
  });

  final StudyViewModel viewModel;
  final VoidCallback onInterrompi;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final inPausa = viewModel.fase == SessionPhase.pausa;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: schema.primaryContainer,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              inPausa ? 'PAUSA' : 'STUDIO',
              style: TextStyle(color: schema.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: viewModel.progresso,
                    strokeWidth: 10,
                    color: schema.primary,
                    backgroundColor: schema.surfaceContainerHighest,
                  ),
                ),
                Text(
                  viewModel.tempoResiduoFormattato,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          IconButton.filledTonal(
            onPressed: onInterrompi,
            icon: const Icon(Icons.close),
            tooltip: 'Interrompi sessione',
          ),
          const SizedBox(height: 16),
          Text(
            'ciclo ${viewModel.cicloCorrente} di ${viewModel.cicliPrevisti}',
            style: TextStyle(color: schema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Stato: configurazione della sessione, prima dell'avvio (RF6, RF7, RF8).
class _ConfigurazioneContent extends StatelessWidget {
  const _ConfigurazioneContent({
    required this.viewModel,
    required this.onApriDialogDurata,
  });

  final StudyViewModel viewModel;
  final void Function(TargetDurata) onApriDialogDurata;

  String _formattaDurata(int minuti) {
    if (minuti < 60) return '${minuti}m';
    final ore = minuti ~/ 60;
    final resto = minuti % 60;
    return resto == 0 ? '${ore}h' : '${ore}h ${resto}m';
  }

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final totali = viewModel.minutiTotaliStimati;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Nuova sessione',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _RigaDurata(
            etichetta: 'durata studio',
            valore: _formattaDurata(viewModel.durataStudioMinuti),
            onTap: () => onApriDialogDurata(TargetDurata.studio),
          ),
          const SizedBox(height: 16),
          _RigaDurata(
            etichetta: 'durata pausa',
            valore: _formattaDurata(viewModel.durataPausaMinuti),
            onTap: () => onApriDialogDurata(TargetDurata.pausa),
          ),
          const SizedBox(height: 16),
          Text(
            'numero di cicli',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: schema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'Diminuisci cicli',
                  onPressed: viewModel.decrementaCicli,
                ),
                Text(
                  '${viewModel.cicliPrevisti}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Aumenta cicli',
                  onPressed: viewModel.incrementaCicli,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: schema.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'durata totale stimata: ${totali ~/ 60}h ${totali % 60}m',
              style: TextStyle(color: schema.onPrimaryContainer),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: viewModel.avviaSessione,
              child: const Text('Avvia sessione'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Riga "etichetta / valore / modifica" riutilizzata per le due durate.
class _RigaDurata extends StatelessWidget {
  const _RigaDurata({
    required this.etichetta,
    required this.valore,
    required this.onTap,
  });

  final String etichetta;
  final String valore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etichetta, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valore,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text(
                    'modifica',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}