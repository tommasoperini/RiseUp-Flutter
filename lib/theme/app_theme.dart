import 'package:flutter/material.dart';

/// Palette dell'applicazione.
///
/// I valori sono gli stessi definiti in `Color.kt` nella versione Kotlin: la
/// coerenza cromatica fra le due versioni è voluta, trattandosi della stessa
/// applicazione realizzata con due tecnologie diverse.
///
/// Come nella versione Kotlin non si usa una palette generata
/// automaticamente a partire da un colore seme: i colori sono dichiarati
/// esplicitamente, così che il risultato non dipenda dall'algoritmo di
/// derivazione del framework.
abstract final class AppColors {
  // --- Tema chiaro ---
  static const Color sfondoChiaro = Color(0xFFF2F3F5);
  static const Color superficieChiara = Color(0xFFFFFFFF);
  static const Color superficieVarianteChiara = Color(0xFFEDEEF1);
  static const Color testoChiaro = Color(0xFF1B1C1E);
  static const Color testoSecondarioChiaro = Color(0xFF5C5F66);
  static const Color primarioChiaro = Color(0xFF2F6FED);
  static const Color suPrimarioChiaro = Color(0xFFFFFFFF);
  static const Color containerPrimarioChiaro = Color(0xFFDCE7FF);
  static const Color suContainerPrimarioChiaro = Color(0xFF2F6FED);

  // --- Tema scuro ---
  static const Color sfondoScuro = Color(0xFF0E0F12);
  static const Color superficieScura = Color(0xFF18191D);
  static const Color superficieVarianteScura = Color(0xFF222328);
  static const Color testoScuro = Color(0xFFECEDEF);
  static const Color testoSecondarioScuro = Color(0xFFA0A3AB);
  static const Color primarioScuro = Color(0xFF6C93FF);
  static const Color suPrimarioScuro = Color(0xFF0E1524);
  static const Color containerPrimarioScuro = Color(0xFF12294F);
  static const Color suContainerPrimarioScuro = Color(0xFF9DB8FF);

  // --- Colori semantici ---
  // Material 3 non prevede un ruolo "successo": questi colori sono quindi
  // usati direttamente nei widget, non attraverso il ColorScheme.
  static const Color verdeSuccesso = Color(0xFF2E9E5B);
  static const Color verdeSuccessoScuro = Color(0xFF3DDC84);
  static const Color rossoErrore = Color(0xFFD64545);
  static const Color rossoErroreScuro = Color(0xFFFF6B6B);
}

/// Costruisce i due temi dell'applicazione.
///
/// Lo sfondo generale e il colore delle card non sono impostati attraverso i
/// ruoli del ColorScheme ma tramite `scaffoldBackgroundColor` e `CardTheme`:
/// i nomi dei ruoli di superficie in Material 3 sono cambiati fra le versioni
/// di Flutter, e passare da queste proprietà rende il tema indipendente dalla
/// versione del framework.
abstract final class AppTheme {
  static ThemeData get chiaro => _costruisci(
    brightness: Brightness.light,
    primario: AppColors.primarioChiaro,
    suPrimario: AppColors.suPrimarioChiaro,
    containerPrimario: AppColors.containerPrimarioChiaro,
    suContainerPrimario: AppColors.suContainerPrimarioChiaro,
    sfondo: AppColors.sfondoChiaro,
    superficie: AppColors.superficieChiara,
    superficieVariante: AppColors.superficieVarianteChiara,
    testo: AppColors.testoChiaro,
    testoSecondario: AppColors.testoSecondarioChiaro,
    errore: AppColors.rossoErrore,
  );

  static ThemeData get scuro => _costruisci(
    brightness: Brightness.dark,
    primario: AppColors.primarioScuro,
    suPrimario: AppColors.suPrimarioScuro,
    containerPrimario: AppColors.containerPrimarioScuro,
    suContainerPrimario: AppColors.suContainerPrimarioScuro,
    sfondo: AppColors.sfondoScuro,
    superficie: AppColors.superficieScura,
    superficieVariante: AppColors.superficieVarianteScura,
    testo: AppColors.testoScuro,
    testoSecondario: AppColors.testoSecondarioScuro,
    errore: AppColors.rossoErroreScuro,
  );

  static ThemeData _costruisci({
    required Brightness brightness,
    required Color primario,
    required Color suPrimario,
    required Color containerPrimario,
    required Color suContainerPrimario,
    required Color sfondo,
    required Color superficie,
    required Color superficieVariante,
    required Color testo,
    required Color testoSecondario,
    required Color errore,
  }) {
    final schema = ColorScheme(
      brightness: brightness,
      primary: primario,
      onPrimary: suPrimario,
      primaryContainer: containerPrimario,
      onPrimaryContainer: suContainerPrimario,
      // La versione Kotlin non definisce un ruolo secondario distinto: si
      // riusa quindi il primario, così che gli elementi selezionati abbiano
      // lo stesso colore in entrambe le versioni.
      secondary: primario,
      onSecondary: suPrimario,
      secondaryContainer: containerPrimario,
      onSecondaryContainer: suContainerPrimario,
      error: errore,
      onError: Colors.white,
      surface: superficie,
      onSurface: testo,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      scaffoldBackgroundColor: sfondo,

      // Card piene, senza ombra e con angoli molto arrotondati, come nella
      // versione Kotlin.
      cardTheme: CardThemeData(
        color: superficieVariante,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: superficie,
        foregroundColor: testo,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        indicatorColor: containerPrimario,
        elevation: 0,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primario,
        unselectedLabelColor: testoSecondario,
        indicatorColor: primario,
        dividerColor: superficieVariante,
      ),

      // Solo la forma a pillola: l'altezza fissa e la larghezza piena non
      // vanno impostate qui, altrimenti si applicherebbero anche ai pulsanti
      // delle finestre di dialogo, che finirebbero in overflow disponendo le
      // azioni su righe separate. I pulsanti a tutta larghezza sono resi tali
      // singolarmente, dove servono.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        textColor: testo,
        iconColor: testoSecondario,
      ),

      dividerTheme: DividerThemeData(color: superficieVariante),
    );
  }
}