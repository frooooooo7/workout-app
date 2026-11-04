import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/theme/app_colors.dart';

const _kSeenKey = 'history_stats_hint_seen';

/// Czy podpowiedź „Statystyki są teraz tutaj” była już pokazana. Bez dostępu
/// do pamięci wolimy ją pominąć niż pokazywać za każdym razem.
Future<bool> historyStatsHintSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

Future<void> markHistoryStatsHintSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenKey, true);
  } catch (_) {}
}

/// Jednorazowy dymek pod ikoną statystyk w nagłówku Historii — statystyki
/// przeniosły się tu z podzakładki. Znika po stuknięciu albo po kilku
/// sekundach.
class HistoryStatsHint extends StatefulWidget {
  const HistoryStatsHint({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<HistoryStatsHint> createState() => _HistoryStatsHintState();
}

class _HistoryStatsHintState extends State<HistoryStatsHint> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 7), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Statystyki są teraz pod ikoną wykresu w nagłówku',
      child: GestureDetector(
        key: const ValueKey('history-stats-hint'),
        onTap: widget.onDismiss,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Szpic wskazujący ikonę: ona stoi 110 px od prawej krawędzi
            // dymka (kalendarz i synchronizacja po jej prawej).
            Padding(
              padding: const EdgeInsets.only(right: 128),
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _NotchPainter(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: AppColors.onPrimary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Statystyki są teraz tutaj',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_NotchPainter old) => false;
}
