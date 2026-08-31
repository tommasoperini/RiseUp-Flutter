import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../system/stats_calculator.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../widgets/goal_edit_dialog.dart';

/// Schermata degli obiettivi settimanali (RF11, RF12, RF13).
///
/// È raggiunta dalla schermata Report, non dalla barra di navigazione, come
/// nella versione Kotlin: l'obiettivo si consulta insieme alle statistiche
/// che ne misurano l'avanzamento.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsViewModel>().caricaObiettivi();
    });
  }

  Future<void> _apriDialogNuovo() async {
    final viewModel = context.read<GoalsViewModel>();
    final risultato = await showDialog<GoalEditResult>(
      context: context,
      builder: (_) => GoalEditDialog(
        categorieDisponibili: viewModel.categorieDisponibili,
      ),
    );
    if (risultato == null) return;

    final riuscito = await viewModel.aggiungi(
      risultato.categoria,
      risultato.valoreObiettivo,
    );
    if (!riuscito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Esiste già un obiettivo per ${risultato.categoria.etichetta}.',
          ),
        ),
      );
    }
  }

  Future<void> _apriDialogModifica(VoceObiettivo voce) async {
    final viewModel = context.read<GoalsViewModel>();
    final risultato = await showDialog<GoalEditResult>(
      context: context,
      builder: (_) => GoalEditDialog(obiettivo: voce.obiettivo),
    );
    if (risultato == null) return;
    await viewModel.aggiorna(voce.obiettivo, risultato.valoreObiettivo);
  }

  Future<void> _confermaEliminazione(VoceObiettivo voce) async {
    final viewModel = context.read<GoalsViewModel>();
    final categoria = voce.obiettivo.categoria.etichetta.toLowerCase();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare l\'obiettivo?'),
        content: Text(
          'L\'obiettivo di $categoria verrà rimosso e i report non ne '
              'mostreranno più il confronto.',
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
    if (conferma == true) await viewModel.elimina(voce.obiettivo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Obiettivi settimanali')),
      floatingActionButton: Consumer<GoalsViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.tutteLeCategorieOccupate) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: _apriDialogNuovo,
            tooltip: 'Aggiungi obiettivo',
            child: const Icon(Icons.add),
          );
        },
      ),
      body: Consumer<GoalsViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.caricamento) {
            return const Center(child: CircularProgressIndicator());
          }
          if (viewModel.vuota) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nessun obiettivo impostato.\n'
                      'Premi + per fissare un obiettivo di sonno o di studio.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final voci = viewModel.voci;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: voci.length,
            itemBuilder: (context, indice) {
              final voce = voci[indice];
              return _CartaObiettivo(
                voce: voce,
                onTap: () => _apriDialogModifica(voce),
                onElimina: () => _confermaEliminazione(voce),
              );
            },
          );
        },
      ),
    );
  }
}

/// Carta di un singolo obiettivo, con barra di avanzamento.
///
/// Un obiettivo raggiunto è evidenziato con un colore diverso e un'icona di
/// spunta, come nella versione Kotlin.
class _CartaObiettivo extends StatelessWidget {
  const _CartaObiettivo({
    required this.voce,
    required this.onTap,
    required this.onElimina,
  });

  final VoceObiettivo voce;
  final VoidCallback onTap;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: voce.raggiunto ? schema.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (voce.raggiunto) ...[
                    const Icon(Icons.check_circle),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      voce.obiettivo.categoria.etichetta,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Elimina obiettivo',
                    onPressed: onElimina,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formattaMinuti(voce.minutiRaggiunti)} su '
                    '${formattaMinuti(voce.obiettivo.valoreObiettivo)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: voce.avanzamento,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}