import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../system/stats_calculator.dart';

/// Grafico a barre dell'andamento settimanale, mostrato nel report sia per
/// il sonno sia per lo studio ("Andamento dello studio"/"Andamento del
/// sonno" nella versione Kotlin), corrispondente a CartaAndamento.
///
/// Rispetto a un CustomPainter scritto a mano, fl_chart evita di dover
/// reimplementare interazione e tooltip per un caso d'uso che nella versione
/// Kotlin usa comunque un Canvas dedicato: il vantaggio di evitare una
/// dipendenza in più non compensa la quantità di codice risparmiata.
///
/// La visibilità della card è decisa dal ViewModel
/// (`andamentoSonnoVisibile`/`andamentoStudioVisibile`): un grafico con
/// tutte le settimane a zero non aggiungerebbe informazione, per cui non
/// viene mostrato affatto, anziché mostrare barre vuote.
class AndamentoSettimanaleChart extends StatelessWidget {
  const AndamentoSettimanaleChart({
    super.key,
    required this.titolo,
    required this.punti,
    this.obiettivoMinuti,
  });

  final String titolo;
  final List<PuntoSettimana> punti;

  /// Obiettivo settimanale, in minuti totali. Se presente e positivo, è
  /// disegnato come riferimento orizzontale tratteggiato, come nella
  /// versione Kotlin.
  final int? obiettivoMinuti;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;
    final haObiettivo = obiettivoMinuti != null && obiettivoMinuti! > 0;

    final massimoDati = punti
        .map((p) => p.minutiTotali)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final massimo = haObiettivo && obiettivoMinuti! > massimoDati
        ? obiettivoMinuti!
        : massimoDati;
    // Un valore massimo di 60 minuti quando tutte le settimane sono vuote e
    // non c'è obiettivo evita che l'asse verticale collassi a zero,
    // mantenendo leggibile la griglia.
    final massimoAsse = massimo == 0 ? 60.0 : massimo * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titolo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: massimoAsse,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => schema.inverseSurface,
                      getTooltipItem: (group, _, rod, __) {
                        final punto = punti[group.x.toInt()];
                        return BarTooltipItem(
                          '${punto.etichetta}\n${formattaMinuti(rod.toY.round())}',
                          TextStyle(
                            color: schema.onInverseSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (valore, meta) {
                          final indice = valore.round();
                          if (indice < 0 || indice >= punti.length) {
                            return const SizedBox.shrink();
                          }
                          final punto = punti[indice];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              punto.etichetta,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: punto.settimanaCorrente
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: punto.settimanaCorrente
                                    ? schema.primary
                                    : schema.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < punti.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: punti[i].minutiTotali.toDouble(),
                            width: 22,
                            borderRadius: BorderRadius.circular(6),
                            color: punti[i].settimanaCorrente
                                ? schema.primary
                                : schema.primary.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                  ],
                  extraLinesData: !haObiettivo
                      ? const ExtraLinesData()
                      : ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: obiettivoMinuti!.toDouble(),
                        color: schema.error,
                        strokeWidth: 2,
                        dashArray: const [8, 5],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (haObiettivo) ...[
              const SizedBox(height: 8),
              Text(
                "La linea tratteggiata indica l'obiettivo settimanale",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: schema.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}