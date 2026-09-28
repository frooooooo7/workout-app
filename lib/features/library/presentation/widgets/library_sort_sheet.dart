import 'package:flutter/material.dart';

import '../../../../core/widgets/app_action_sheet.dart';
import '../../domain/models/library_sort.dart';

IconData _iconFor(LibrarySort sort) => switch (sort) {
  LibrarySort.popular => Icons.local_fire_department_rounded,
  LibrarySort.alphabetical => Icons.sort_by_alpha_rounded,
  LibrarySort.newest => Icons.schedule_rounded,
  LibrarySort.favouritesFirst => Icons.star_rounded,
};

/// Wybór kolejności ćwiczeń; aktywna opcja jest podświetlona.
Future<LibrarySort?> showLibrarySortSheet(
  BuildContext context, {
  required LibrarySort current,
}) {
  return showAppActionSheet<LibrarySort>(
    context,
    title: 'Sortuj ćwiczenia',
    actions: [
      for (final sort in LibrarySort.values)
        AppSheetAction(
          value: sort,
          icon: _iconFor(sort),
          label: sort.title,
          subtitle: sort.subtitle,
          selected: sort == current,
        ),
    ],
  );
}
