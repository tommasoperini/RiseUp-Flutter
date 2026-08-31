import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tutorial_pagina.dart';
import '../viewmodels/tutorial_viewmodel.dart';

/// Sequenza di schermate informative sul funzionamento dell'app (RF17).
///
/// È raggiunta in due modi: come destinazione di partenza al primo avvio
/// (decisione presa in [MainShell] leggendo [TutorialViewModel]) oppure
/// richiamata in un secondo momento dall'icona nella home. [onFine] gestisce
/// entrambi i casi allo stesso modo dal punto di vista di questa schermata:
/// chi la chiama sa dove andare dopo, qui non viene deciso.
///
/// Usa un [PageView] al posto dell'HorizontalPager di Compose: è
/// l'equivalente diretto in Flutter, con lo stesso comportamento di
/// scorrimento a pagine intere.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onFine});

  final VoidCallback onFine;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _paginaCorrente = 0;

  bool get _ultimaPagina => _paginaCorrente == paginetutorial.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completaTutorial() async {
    await context.read<TutorialViewModel>().segnaCompletato();
    widget.onFine();
  }

  /// "Avanti" scorre di una pagina alla volta finché non si è sull'ultima,
  /// dove il pulsante diventa la conferma di conclusione ("Inizia") e
  /// chiude il tutorial: è la sequenza principale del caso d'uso, in cui lo
  /// scorrimento e la conferma finale sono due passi distinti.
  void _avanti() {
    if (_ultimaPagina) {
      _completaTutorial();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                // "Salta" è sempre disponibile, in qualunque pagina ci si
                // trovi: è il caso d'uso "Saltare tutorial", che estende
                // "Completa tutorial" e ha la stessa post-condizione.
                child: TextButton(
                  onPressed: _completaTutorial,
                  child: const Text('Salta'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: paginetutorial.length,
                onPageChanged: (indice) {
                  setState(() => _paginaCorrente = indice);
                },
                itemBuilder: (context, indice) {
                  return _ContenutoPagina(pagina: paginetutorial[indice]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _IndicatorePagine(
                numeroPagine: paginetutorial.length,
                paginaCorrente: _paginaCorrente,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _avanti,
                  // Sull'ultima pagina il pulsante diventa la conferma
                  // esplicita di conclusione richiesta dal caso d'uso
                  // "Completa tutorial".
                  child: Text(_ultimaPagina ? 'Inizia' : 'Avanti'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContenutoPagina extends StatelessWidget {
  const _ContenutoPagina({required this.pagina});

  final TutorialPagina pagina;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pagina.titolo,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            pagina.descrizione,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _IndicatorePagine extends StatelessWidget {
  const _IndicatorePagine({
    required this.numeroPagine,
    required this.paginaCorrente,
  });

  final int numeroPagine;
  final int paginaCorrente;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(numeroPagine, (indice) {
        final attiva = indice == paginaCorrente;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: attiva ? 10 : 8,
          height: attiva ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: attiva ? schema.primary : schema.surfaceContainerHighest,
          ),
        );
      }),
    );
  }
}
