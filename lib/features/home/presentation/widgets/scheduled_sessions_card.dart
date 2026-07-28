import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/recent_activity.dart';
import '../../domain/models/scheduled_session.dart';

class ScheduledSessionsCard extends StatelessWidget {
  const ScheduledSessionsCard({super.key, this.sessions});

  /// Gdy null — pokazywane są dane przykładowe do czasu API.
  final List<ScheduledSession>? sessions;

  static List<ScheduledSession> get mockSessions => const [
        ScheduledSession(
          kind: RecentActivityKind.strength,
          title: 'Trening nóg',
          dateLabel: 'Jutro',
          time: '18:30',
          placeName: 'Siłownia City',
        ),
        ScheduledSession(
          kind: RecentActivityKind.strength,
          title: 'Push z Janem',
          dateLabel: 'Sob, 10 maj',
          time: '08:00',
          partnerName: 'Jan K.',
          placeName: 'Siłownia City',
        ),
        ScheduledSession(
          kind: RecentActivityKind.strength,
          title: 'Pull — plecy',
          dateLabel: 'Niedz, 11 maj',
          time: '09:15',
          placeName: 'Siłownia City',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final list = sessions ?? mockSessions;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Zaplanowane sesje',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text(
                        'Kalendarz',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined,
                      color: AppColors.textMuted, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Brak zaplanowanych sesji — dodaj trening lub zaproszenie.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (context, _) => const Divider(
                height: 1,
                color: AppColors.border,
                indent: 74,
              ),
              itemBuilder: (_, i) => ScheduledSessionRow(session: list[i]),
            ),
        ],
      ),
    );
  }
}

class ScheduledSessionRow extends StatelessWidget {
  const ScheduledSessionRow({super.key, required this.session});

  final ScheduledSession session;

  static const _visual = _SessionVisual(
    icon: Icons.event_note_rounded,
    accent: Color(0xFF6C8EFF),
  );

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${session.dateLabel} · ${session.time}',
      if (session.partnerName != null) 'z ${session.partnerName}',
      if (session.placeName != null) session.placeName,
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _visual.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_visual.icon, color: _visual.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary.withValues(alpha: 0.7),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SessionVisual {
  const _SessionVisual({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;
}
