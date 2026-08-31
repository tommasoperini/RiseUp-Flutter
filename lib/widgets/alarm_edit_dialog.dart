import 'package:flutter/material.dart';

import '../models/alarm.dart';

/// Dati restituiti dal dialog di creazione/modifica di una sveglia.
class AlarmEditResult {
  /// Orario in minuti dalla mezzanotte (0-1439).
  final int orario;

  /// Maschera di bit dei giorni di ripetizione (bit 0 = lunedì).
  final int giorniRipetizione;

  const AlarmEditResult({
    required this.orario,
    required this.giorniRipetizione,
  });
}

/// Dialog per l'inserimento e la modifica di una sveglia (RF1).
///
/// È un widget riutilizzato dai casi d'uso "Crea sveglia" e "Modifica
/// sveglia": se [sveglia] è null il dialog si apre in modalità creazione,
/// altrimenti precompila i campi con i valori esistenti.
///
/// Non accede né al ViewModel né al database: si limita a restituire un
/// [AlarmEditResult] tramite `Navigator.pop`, lasciando alla schermata
/// chiamante il compito di invocare il ViewModel. In questo modo il widget
/// resta una View pura, senza logica applicativa.
class AlarmEditDialog extends StatefulWidget {
  const AlarmEditDialog({super.key, this.sveglia});

  final Alarm? sveglia;

  @override
  State<AlarmEditDialog> createState() => _AlarmEditDialogState();
}

class _AlarmEditDialogState extends State<AlarmEditDialog> {
  static const List<String> _etichetteGiorni = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  late TimeOfDay _orario;
  late int _giorniRipetizione;

  @override
  void initState() {
    super.initState();
    final esistente = widget.sveglia;
    if (esistente != null) {
      _orario = TimeOfDay(
        hour: esistente.orario ~/ 60,
        minute: esistente.orario % 60,
      );
      _giorniRipetizione = esistente.giorniRipetizione;
    } else {
      _orario = const TimeOfDay(hour: 7, minute: 0);
      _giorniRipetizione = 0;
    }
  }

  Future<void> _scegliOrario() async {
    final scelto = await showTimePicker(
      context: context,
      initialTime: _orario,
    );
    if (scelto != null) {
      setState(() => _orario = scelto);
    }
  }

  void _commutaGiorno(int indice) {
    setState(() {
      _giorniRipetizione ^= (1 << indice);
    });
  }

  String get _orarioFormattato {
    final ore = _orario.hour.toString().padLeft(2, '0');
    final minuti = _orario.minute.toString().padLeft(2, '0');
    return '$ore:$minuti';
  }

  @override
  Widget build(BuildContext context) {
    final inModifica = widget.sveglia != null;

    return AlertDialog(
      title: Text(inModifica ? 'Modifica sveglia' : 'Nuova sveglia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: TextButton(
              onPressed: _scegliOrario,
              child: Text(
                _orarioFormattato,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ripeti',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(7, (indice) {
              final selezionato = (_giorniRipetizione & (1 << indice)) != 0;
              return FilterChip(
                label: Text(_etichetteGiorni[indice]),
                selected: selezionato,
                onSelected: (_) => _commutaGiorno(indice),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _giorniRipetizione == 0
                ? 'Nessun giorno selezionato: la sveglia suonerà una sola volta.'
                : 'La sveglia si ripeterà nei giorni selezionati.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            AlarmEditResult(
              orario: _orario.hour * 60 + _orario.minute,
              giorniRipetizione: _giorniRipetizione,
            ),
          ),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}