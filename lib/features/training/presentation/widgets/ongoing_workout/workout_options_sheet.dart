import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

/// Co wybrano w arkuszu opcji treningu (zamyka arkusz).
enum WorkoutOptionsAction {
  rest,
  plates,
  note,
  swap,
  exercises,
  removeExercise,
  discard,
}

/// Arkusz opcji w trakcie treningu: cztery szybkie kafelki (przerwa,
/// talerze, notatka, zamiana), grupa „Ćwiczenia” i przełączniki kolumn.
/// „Odrzuć cały trening” stoi osobno na samym dole.
///
/// Przełączniki RIR i tempo działają od razu i nie zamykają arkusza.
Future<WorkoutOptionsAction?> showWorkoutOptionsSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool hasExercise,
  required bool restActive,
  required bool Function() rirVisible,
  required bool Function() tempoVisible,
  required VoidCallback onToggleRir,
  required VoidCallback onToggleTempo,
}) {
  return showModalBottomSheet<WorkoutOptionsAction>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => _WorkoutOptionsSheet(
      title: title,
      subtitle: subtitle,
      hasExercise: hasExercise,
      restActive: restActive,
      rirVisible: rirVisible,
      tempoVisible: tempoVisible,
      onToggleRir: onToggleRir,
      onToggleTempo: onToggleTempo,
    ),
  );
}

class _WorkoutOptionsSheet extends StatefulWidget {
  const _WorkoutOptionsSheet({
    required this.title,
    required this.subtitle,
    required this.hasExercise,
    required this.restActive,
    required this.rirVisible,
    required this.tempoVisible,
    required this.onToggleRir,
    required this.onToggleTempo,
  });

  final String title;
  final String subtitle;
  final bool hasExercise;
  final bool restActive;
  final bool Function() rirVisible;
  final bool Function() tempoVisible;
  final VoidCallback onToggleRir;
  final VoidCallback onToggleTempo;

  @override
  State<_WorkoutOptionsSheet> createState() => _WorkoutOptionsSheetState();
}

class _WorkoutOptionsSheetState extends State<_WorkoutOptionsSheet> {
  void _pop(WorkoutOptionsAction action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final hasExercise = widget.hasExercise;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _QuickTile(
                  key: const ValueKey('options-rest'),
                  icon: widget.restActive
                      ? Icons.timer_off_outlined
                      : Icons.timer_outlined,
                  label: widget.restActive ? 'Stop przerwy' : 'Przerwa',
                  highlighted: true,
                  onTap: () => _pop(WorkoutOptionsAction.rest),
                ),
                if (hasExercise) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _QuickTile(
                    key: const ValueKey('options-plates'),
                    icon: Icons.fitness_center_rounded,
                    label: 'Talerze',
                    onTap: () => _pop(WorkoutOptionsAction.plates),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickTile(
                    key: const ValueKey('options-note'),
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Notatka',
                    onTap: () => _pop(WorkoutOptionsAction.note),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _QuickTile(
                    key: const ValueKey('options-swap'),
                    icon: Icons.swap_horiz_rounded,
                    label: 'Zamień',
                    onTap: () => _pop(WorkoutOptionsAction.swap),
                  ),
                ],
              ],
            ),
            if (hasExercise) ...[
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('Ćwiczenia'),
              _Group(
                children: [
                  _GroupRow(
                    key: const ValueKey('options-exercises'),
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Lista i kolejność',
                    subtitle: 'Przejdź do ćwiczenia albo przestaw',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _pop(WorkoutOptionsAction.exercises),
                  ),
                  _GroupRow(
                    key: const ValueKey('options-remove'),
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Usuń z tego treningu',
                    subtitle: 'Plan zostaje bez zmian',
                    destructive: true,
                    onTap: () => _pop(WorkoutOptionsAction.removeExercise),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('Widok tabeli'),
              Row(
                children: [
                  Expanded(
                    child: _ToggleTile(
                      key: const ValueKey('options-rir'),
                      label: 'Kolumna RIR',
                      value: widget.rirVisible(),
                      onTap: () {
                        widget.onToggleRir();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _ToggleTile(
                      key: const ValueKey('options-tempo'),
                      label: 'Kolumna tempo',
                      value: widget.tempoVisible(),
                      onTap: () {
                        widget.onToggleTempo();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('options-discard'),
              onPressed: () => _pop(WorkoutOptionsAction.discard),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Odrzuć cały trening'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.strengthWeak,
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(
                  color: AppColors.strengthWeak.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textLabel,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.onPrimary : AppColors.textPrimary;
    return Expanded(
      child: Material(
        color: highlighted ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: highlighted ? fg : AppColors.primaryVariant,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: AppColors.tile,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: 52,
                  color: AppColors.borderStrong,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.strengthWeak : AppColors.textPrimary;
    final iconColor = destructive
        ? AppColors.strengthWeak
        : AppColors.primaryVariant;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Material(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: (_) {},
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
