import 'package:flutter/widgets.dart';

/// Chowa klawiaturę: zdejmuje fokus z pola tekstowego.
///
/// Wołamy to przed otwarciem nowego ekranu albo arkusza. Bez tego pole
/// zostaje „w pamięci” trasy i po powrocie dostaje fokus z powrotem — a z
/// nim klawiatura wyskakuje sama (np. po wybraniu ćwiczenia z listy).
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Do `TextField.onTapOutside`: dotknięcie poza polem (przycisk, odhaczenie
/// serii, przewinięcie listy) chowa klawiaturę. Dotknięcie innego pola
/// tekstowego się nie liczy — fokus przechodzi płynnie, bez mrugnięcia
/// klawiatury.
void hideKeyboardOnTapOutside(PointerDownEvent _) => hideKeyboard();
