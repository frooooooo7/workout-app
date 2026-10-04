import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../utils/paged_users.dart';

const pagedListRetryKey = Key('paged-list-retry');

/// Ostatni wiersz listy [PagedUsers]: gdy dojdzie do niego przewijanie,
/// doładowuje kolejną stronę; przy błędzie pokazuje „Spróbuj ponownie”.
class PagedListFooter extends StatefulWidget {
  const PagedListFooter({super.key, required this.pager});

  final PagedUsers pager;

  @override
  State<PagedListFooter> createState() => _PagedListFooterState();
}

class _PagedListFooterState extends State<PagedListFooter> {
  @override
  void initState() {
    super.initState();
    _requestMore();
  }

  @override
  void didUpdateWidget(PagedListFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestMore();
  }

  /// Po klatce — wczytanie zmienia stan listy, a ta właśnie się buduje.
  void _requestMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pager = widget.pager;
      if (!mounted || pager.moreFailed) return;
      pager.loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pager = widget.pager;
    if (pager.moreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(
          children: [
            const Text(
              'Nie udało się wczytać kolejnych osób.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            TextButton(
              key: pagedListRetryKey,
              onPressed: pager.loadMore,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
