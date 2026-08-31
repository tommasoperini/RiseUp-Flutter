import 'package:flutter/material.dart';

import '../models/weekly_goal.dart';

/// Dati restituiti dal form di aggiunta e modifica di un obiettivo.
class GoalEditResult {
  final GoalCategory categoria;

  /// Valore obiettivo in minuti.
  final int valoreObiettivo;

  const GoalEditResult({
    required this.categoria,
    required this.valoreObiettivo,
  });
}

/// Form di aggiunta e modifica di un obiettivo settimanale (RF11, RF13).
///
/// In aggiunta, [categorieDisponibili] contiene solo le categorie non ancora
/// usate: è la traduzione in interfaccia della pre-condizione del caso d'uso
/// "Aggiungi obiettivo settimanale". In modifica la categoria non è
/// cambiabile e si modifica il solo valore, come nella versione Kotlin.
///
/// Il widget non accede né al ViewModel né al database: restituisce un
/// [GoalEditResult] tramite `Navigator.pop`, lasciando alla schermata
/// chiamante il compito di invocare il ViewModel.
class GoalEditDialog extends StatefulWidget {
  const GoalEditDialog({
    super.key,
    this.obiettivo,
    this.categorieDisponibili = const [],
  });

  /// Null in aggiunta, valorizzato in modifica.
  final WeeklyGoal? obiettivo;

  /// Significativo solo in aggiunta.
  final List<GoalCategory> categorieDisponibili;

  @override
  State<GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<GoalEditDialog> {
  /// Limite superiore: una settimana intera espressa in ore.
  static const int _maxOre = 168;

  GoalCategory? _categoria;
  late int _ore;
  late int _minuti;

  bool get _modifica => widget.obiettivo != null;

  int get _valoreObiettivo => _ore * 60 + _minuti;

  bool get _salvabile => _categoria != null && _valoreObiettivo > 0;

  @override
  void initState() {
    super.initState();
    final esistente = widget.obiettivo;
    if (esistente != null) {
      _categoria = esistente.categoria;
      _ore = esistente.valoreObiettivo ~/ 60;
      _minuti = esistente.valoreObiettivo % 60;
    } else {
      _categoria = widget.categorieDisponibili.isEmpty
          ? null
          : widget.categorieDisponibili.first;
      _ore = 10;
      _minuti = 0;
    }
  }

  void _cambiaOre(int delta) {
    setState(() => _ore = (_ore + delta).clamp(0, _maxOre));
  }

  void _cambiaMinuti(int delta) {
    setState(() {
      var totale = _minuti + delta;
      if (totale >= 60) {
        totale -= 60;
        _ore = (_ore + 1).clamp(0, _maxOre);
      } else if (totale < 0) {
        totale += 60;
        _ore = (_ore - 1).clamp(0, _maxOre);
      }
      _minuti = totale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_modifica ? 'Modifica obiettivo' : 'Nuovo obiettivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (_modifica)
            Chip(label: Text(_categoria!.etichetta))
          else
            Wrap(
              spacing: 8,
              children: widget.categorieDisponibili.map((categoria) {
                return ChoiceChip(
                  label: Text(categoria.etichetta),
                  selected: _categoria == categoria,
                  onSelected: (_) => setState(() => _categoria = categoria),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          Text(
            'Obiettivo settimanale',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SelettoreValore(
                etichetta: 'ore',
                valore: _ore,
                onIncrementa: () => _cambiaOre(1),
                onDecrementa: () => _cambiaOre(-1),
              ),
              const SizedBox(width: 16),
              _SelettoreValore(
                etichetta: 'min',
                valore: _minuti,
                onIncrementa: () => _cambiaMinuti(15),
                onDecrementa: () => _cambiaMinuti(-15),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _salvabile
              ? () => Navigator.of(context).pop(
            GoalEditResult(
              categoria: _categoria!,
              valoreObiettivo: _valoreObiettivo,
            ),
          )
              : null,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

/// Selettore numerico con pulsanti di incremento e decremento.
class _SelettoreValore extends StatelessWidget {
  const _SelettoreValore({
    required this.etichetta,
    required this.valore,
    required this.onIncrementa,
    required this.onDecrementa,
  });

  final String etichetta;
  final int valore;
  final VoidCallback onIncrementa;
  final VoidCallback onDecrementa;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: onIncrementa,
        ),
        Text('$valore', style: Theme.of(context).textTheme.headlineSmall),
        Text(etichetta, style: Theme.of(context).textTheme.labelSmall),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: onDecrementa,
        ),
      ],
    );
  }
}