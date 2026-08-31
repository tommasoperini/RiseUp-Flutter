import 'package:flutter/material.dart';

/// Dialog di scelta di una durata espressa in minuti (RF6).
///
/// Corrisponde al DurationPickerDialog della versione Kotlin ed è aperto
/// dalla riga "durata studio" della schermata Studio. Restituisce la durata
/// scelta tramite `Navigator.pop`, oppure null se l'utente annulla.
class DurationPickerDialog extends StatefulWidget {
  const DurationPickerDialog({
    super.key,
    required this.titolo,
    required this.minutiIniziali,
    this.minimo = 5,
    this.massimo = 180,
    this.passo = 5,
  });

  final String titolo;
  final int minutiIniziali;
  final int minimo;
  final int massimo;

  /// Incremento applicato dai pulsanti e dal cursore.
  final int passo;

  @override
  State<DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<DurationPickerDialog> {
  late int _minuti;

  @override
  void initState() {
    super.initState();
    _minuti = widget.minutiIniziali.clamp(widget.minimo, widget.massimo);
  }

  void _cambia(int delta) {
    setState(() {
      _minuti = (_minuti + delta).clamp(widget.minimo, widget.massimo);
    });
  }

  String get _etichetta {
    if (_minuti < 60) return '${_minuti}m';
    final ore = _minuti ~/ 60;
    final resto = _minuti % 60;
    return resto == 0 ? '${ore}h' : '${ore}h ${resto}m';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titolo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: () => _cambia(-widget.passo),
              ),
              Text(
                _etichetta,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => _cambia(widget.passo),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _minuti.toDouble(),
            min: widget.minimo.toDouble(),
            max: widget.massimo.toDouble(),
            divisions: (widget.massimo - widget.minimo) ~/ widget.passo,
            label: _etichetta,
            onChanged: (valore) => setState(() => _minuti = valore.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_minuti),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}