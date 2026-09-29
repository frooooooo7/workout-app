import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Język aplikacji. Cały interfejs jest po polsku, więc wbudowane widżety
/// (kalendarz, zegar, tooltipy, etykiety czytnika ekranu) też muszą mieć
/// polskie tłumaczenia — bez delegatów `showDatePicker` z polską lokalizacją
/// kończył się „No MaterialLocalizations found”.
abstract final class AppLocalization {
  static const locale = Locale('pl', 'PL');

  static const supportedLocales = [locale];

  static const delegates = <LocalizationsDelegate<Object>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
