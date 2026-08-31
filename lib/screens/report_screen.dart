import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weekly_goal.dart';
import '../system/stats_calculator.dart';
import '../viewmodels/report_viewmodel.dart';
import '../widgets/andamento_settimanale_chart.dart';
import 'goals_screen.dart';

/// Schermata del report settimanale (RF5, RF14).
///
/// Realizza i casi d'uso "Visualizza report Sonno" e "Visualizza report
/// Studio", organizzati in due schede come nella versione Kotlin. Da qui si
/// raggiunge la schermata degli obiettivi, coerentemente con la scelta di
/// mostrare l'obiettivo accanto alla statistica che ne misura l'avanzamento.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SchedaReport.values.length,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportViewModel>().caricaDati();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Apre la schermata degli obiettivi e, al ritorno, ricarica il report:
  /// l'utente potrebbe aver aggiunto o modificato un obiettivo, cambiando i
  /// confronti mostrati qui.
  Future<void> _vaiAObiettivi() async {
    final viewModel = context.read<ReportViewModel>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
    );
    await viewModel.caricaDati();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Report'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Obiettivi settimanali',
                onPressed: _vaiAObiettivi,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              onTap: (indice) =>
                  viewModel.selezionaScheda(SchedaReport.values[indice]),
              tabs: SchedaReport.values
                  .map((scheda) => Tab(text: scheda.etichetta))
                  .toList(),
            ),
          ),
          body: viewModel.caricamento
              ? const Center(child: CircularProgressIndicator())
              : switch (viewModel.scheda) {
            SchedaReport.sonno => _SchedaSonno(
              viewModel: viewModel,
              onVaiAObiettivi: _vaiAObiettivi,
            ),
            SchedaReport.studio => _SchedaStudio(
              viewModel: viewModel,
              onVaiAObiettivi: _vaiAObiettivi,
            ),
          },
        );
      },
    );
  }
}

/// Scheda "Sonno" del report.
class _SchedaSonno extends StatelessWidget {
  const _SchedaSonno({required this.viewModel, required this.onVaiAObiettivi});

  final ReportViewModel viewModel;
  final VoidCallback onVaiAObiettivi;

  @override
  Widget build(BuildContext context) {
    final stat = viewModel.statisticheSonno;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // La carta dell'obiettivo compare sempre, anche in assenza di dati:
        // è da qui che l'utente raggiunge l'impostazione dell'obiettivo.
        _CartaObiettivoSettimanale(
          etichetta: 'Obiettivo di sonno',
          valoreRaggiunto: stat.minutiTotali,
          obiettivo: viewModel.obiettivoSonno,
          avanzamento: viewModel.avanzamentoSonno,
          onVaiAObiettivi: onVaiAObiettivi,
        ),
        if (viewModel.andamentoSonnoVisibile) ...[
          const SizedBox(height: 16),
          AndamentoSettimanaleChart(
            titolo: 'Andamento del sonno',
            punti: viewModel.andamentoSonno,
            obiettivoMinuti: viewModel.obiettivoSonno?.valoreObiettivo,
          ),
        ],
        const SizedBox(height: 16),
        if (viewModel.sonnoSenzaDati)
          const _MessaggioSenzaDati(
            testo: 'Nessuna sessione di sonno registrata in questa settimana.',
          )
        else
          _CartaStatistiche(
            titolo: 'Questa settimana',
            voci: [
              ('Notti registrate', '${stat.numeroNotti}'),
              ('Sonno totale', formattaMinuti(stat.minutiTotali)),
              ('Sonno medio a notte', formattaMinuti(stat.minutiMedi)),
              if (stat.oraMediaAddormentamento != null)
                (
                'Ora media di addormentamento',
                formattaOrario(stat.oraMediaAddormentamento!)
                ),
              if (stat.oraMediaRisveglio != null)
                ('Ora media di risveglio', formattaOrario(stat.oraMediaRisveglio!)),
            ],
          ),
      ],
    );
  }
}

/// Scheda "Studio" del report.
class _SchedaStudio extends StatelessWidget {
  const _SchedaStudio({required this.viewModel, required this.onVaiAObiettivi});

  final ReportViewModel viewModel;
  final VoidCallback onVaiAObiettivi;

  @override
  Widget build(BuildContext context) {
    final stat = viewModel.statisticheStudio;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CartaObiettivoSettimanale(
          etichetta: 'Obiettivo di studio',
          valoreRaggiunto: stat.minutiTotali,
          obiettivo: viewModel.obiettivoStudio,
          avanzamento: viewModel.avanzamentoStudio,
          onVaiAObiettivi: onVaiAObiettivi,
        ),
        if (viewModel.andamentoStudioVisibile) ...[
          const SizedBox(height: 16),
          AndamentoSettimanaleChart(
            titolo: 'Andamento dello studio',
            punti: viewModel.andamentoStudio,
            obiettivoMinuti: viewModel.obiettivoStudio?.valoreObiettivo,
          ),
        ],
        const SizedBox(height: 16),
        if (viewModel.studioSenzaDati)
          const _MessaggioSenzaDati(
            testo: 'Nessuna sessione di studio registrata in questa settimana.',
          )
        else
          _CartaStatistiche(
            titolo: 'Questa settimana',
            voci: [
              ('Sessioni svolte', '${stat.numeroSessioni}'),
              ('Studio totale', formattaMinuti(stat.minutiTotali)),
              ('Durata media', formattaMinuti(stat.minutiMedi)),
              ('Sessioni interrotte', '${stat.sessioniParziali}'),
            ],
          ),
      ],
    );
  }
}

/// Carta che confronta il valore raggiunto con l'obiettivo settimanale.
class _CartaObiettivoSettimanale extends StatelessWidget {
  const _CartaObiettivoSettimanale({
    required this.etichetta,
    required this.valoreRaggiunto,
    required this.obiettivo,
    required this.avanzamento,
    required this.onVaiAObiettivi,
  });

  final String etichetta;
  final int valoreRaggiunto;
  final WeeklyGoal? obiettivo;
  final double avanzamento;
  final VoidCallback onVaiAObiettivi;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  etichetta,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (obiettivo == null) ...[
              const Text('Nessun obiettivo impostato per questa categoria.'),
              TextButton(
                onPressed: onVaiAObiettivi,
                child: const Text('Imposta un obiettivo'),
              ),
            ] else ...[
              Text(
                '${formattaMinuti(valoreRaggiunto)} su '
                    '${formattaMinuti(obiettivo!.valoreObiettivo)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: avanzamento,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carta con un elenco di coppie etichetta-valore.
class _CartaStatistiche extends StatelessWidget {
  const _CartaStatistiche({required this.titolo, required this.voci});

  final String titolo;
  final List<(String, String)> voci;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                titolo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...voci.map((voce) {
              return ListTile(
                dense: true,
                title: Text(voce.$1),
                trailing: Text(
                  voce.$2,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Messaggio mostrato quando la settimana non contiene dati.
class _MessaggioSenzaDati extends StatelessWidget {
  const _MessaggioSenzaDati({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Text(
        testo,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}