/// Una pagina del tutorial: titolo e descrizione della funzionalità
/// spiegata.
class TutorialPagina {
  final String titolo;
  final String descrizione;

  const TutorialPagina({required this.titolo, required this.descrizione});
}

/// Contenuto del tutorial (RF17).
///
/// Le pagine coprono le funzionalità della versione Flutter, nello stesso
/// ordine delle destinazioni della barra di navigazione: sveglia, sonno,
/// modalità studio, report e obiettivi.
///
/// I testi sono stati riscritti rispetto alla versione Kotlin, non tradotti
/// alla lettera: quella versione descrive la sfida di disattivazione, il
/// blocco delle applicazioni durante lo studio e il silenzioso automatico
/// basato sui sensori, nessuna delle quali è presente in questa versione
/// (sezione 3.1 della relazione). Riproporre lo stesso testo prometterebbe
/// funzionalità che l'app non ha; per lo stesso motivo la pagina sul
/// silenzioso automatico, priva di equivalente qui, non compare affatto
/// anziché essere riscritta a forza.
const List<TutorialPagina> paginetutorial = [
  TutorialPagina(
    titolo: 'Sveglia',
    descrizione:
        'Imposta una o più sveglie, singole o ripetute nei giorni che '
        'scegli. La prossima sveglia attiva è sempre in evidenza in home.',
  ),
  TutorialPagina(
    titolo: 'Sonno e modalità notte',
    descrizione:
        "Dalla home dichiara quando vai a dormire. Il sistema registra "
        "l'orario di inizio e calcola la durata del riposo quando dichiari "
        'di esserti svegliato.',
  ),
  TutorialPagina(
    titolo: 'Modalità Studio',
    descrizione:
        'Imposta la durata di studio e di pausa e il numero di cicli: la '
        'sessione alterna automaticamente le due fasi fino al loro '
        'esaurimento, o finché non la interrompi.',
  ),
  TutorialPagina(
    titolo: 'Report e obiettivi',
    descrizione:
        'Consulta le statistiche settimanali di sonno e studio, imposta un '
        "obiettivo per ciascuna categoria e segui l'andamento delle ultime "
        'settimane.',
  ),
];
