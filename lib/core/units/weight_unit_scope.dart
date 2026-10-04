import 'package:flutter/widgets.dart';

import 'weight_unit.dart';

/// Po zmianie [WeightUnits.current] przebudowuje całe poddrzewo.
///
/// Ciężary formatują dziesiątki funkcji bez dostępu do `BuildContext`, więc
/// zamiast zależności od InheritedWidget w każdym widżecie oznaczamy do
/// przebudowy wszystkie elementy — jednorazowo, przy rzadkiej zmianie
/// ustawienia. Stan (nawigacja, przewinięcie, wpisany tekst) zostaje.
class WeightUnitScope extends StatefulWidget {
  const WeightUnitScope({super.key, required this.child});

  final Widget child;

  @override
  State<WeightUnitScope> createState() => _WeightUnitScopeState();
}

class _WeightUnitScopeState extends State<WeightUnitScope> {
  @override
  void initState() {
    super.initState();
    WeightUnits.notifier.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    WeightUnits.notifier.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    if (!mounted) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
