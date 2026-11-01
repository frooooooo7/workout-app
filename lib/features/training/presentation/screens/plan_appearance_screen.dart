
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/post_draft.dart';
import '../widgets/plans/plan_cover_image.dart';
import '../widgets/workout_summary/share_workout_sheet.dart' show pickPostPhoto;

/// Wynik ekranu „Wygląd planu”. [cover] mówi, co zrobić z okładką względem
/// tego, co ekran dostał.
typedef PlanAppearanceResult = ({
  String? colorKey,
  String? iconKey,
  PostPhotoChange cover,
});

/// Wybór wyglądu planu: kolor (albo „Auto” z nazwy) i znak — litera lub
/// ikona — z podglądem karty planu na żywo.
class PlanAppearanceScreen extends StatefulWidget {
  const PlanAppearanceScreen({
    super.key,
    required this.planName,
    required this.subtitle,
    required this.selectedDays,
    this.colorKey,
    this.iconKey,
    this.coverUrl,
    this.coverBytes,
    this.pickPhoto,
  });

  /// Okładka, z którą ekran startuje (z serwera albo świeżo wybrana).
  final String? coverUrl;
  final Uint8List? coverBytes;

  /// Test seam; domyślnie galeria / aparat.
  final Future<PickedPostPhoto?> Function(BuildContext, ImageSource)?
  pickPhoto;

  final String planName;

  /// „Klatka · Barki · Ramiona” pod nazwą w podglądzie.
  final String subtitle;
  final List<int> selectedDays;
  final String? colorKey;
  final String? iconKey;

  @override
  State<PlanAppearanceScreen> createState() => _PlanAppearanceScreenState();
}

class _PlanAppearanceScreenState extends State<PlanAppearanceScreen> {
  late String? _colorKey = widget.colorKey;
  late String? _iconKey = widget.iconKey;
  late bool _useIcon = widget.iconKey != null;

  late final bool _hadCover =
      (widget.coverBytes != null && widget.coverBytes!.isNotEmpty) ||
      widget.coverUrl != null;
  PickedPostPhoto? _picked;
  bool _coverRemoved = false;

  bool get _hasCover => _picked != null || (_hadCover && !_coverRemoved);

  Uint8List? get _coverBytes =>
      _picked?.bytes ?? (_coverRemoved ? null : widget.coverBytes);
  String? get _coverUrl => _picked != null || _coverRemoved
      ? null
      : widget.coverUrl;

  Future<void> _changeCover() async {
    final pick = widget.pickPhoto ?? pickPostPhoto;
    final picker = ImagePicker();
    ImageSource source = ImageSource.gallery;
    if (picker.supportsImageSource(ImageSource.camera)) {
      final chosen = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Zrób zdjęcie'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                key: const ValueKey('plan-cover-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Wybierz z galerii'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (chosen == null || !mounted) return;
      source = chosen;
    }
    final photo = await pick(context, source);
    if (photo == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _picked = photo;
      _coverRemoved = false;
    });
  }

  void _removeCover() {
    HapticFeedback.selectionClick();
    setState(() {
      _picked = null;
      _coverRemoved = true;
    });
  }

  PostPhotoChange get _coverChange {
    final picked = _picked;
    if (picked != null) return SetPostPhoto(picked);
    if (_coverRemoved && _hadCover) return const RemovePostPhoto();
    return const KeepPostPhoto();
  }

  Color get _color => _colorKey == null
      ? PlanColors.automatic(widget.planName)
      : PlanColors.choices[_colorKey]!;

  void _pickColor(String? key) {
    if (key == _colorKey) return;
    HapticFeedback.selectionClick();
    setState(() => _colorKey = key);
  }

  void _pickIcon(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _iconKey = key;
      _useIcon = true;
    });
  }

  void _setMode(bool useIcon) {
    if (useIcon == _useIcon) return;
    setState(() {
      _useIcon = useIcon;
      if (useIcon) _iconKey ??= PlanIcons.choices.keys.first;
    });
  }

  void _done() {
    final PlanAppearanceResult result = (
      colorKey: _colorKey,
      iconKey: _useIcon ? _iconKey : null,
      cover: _coverChange,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.planName.trim().isEmpty
        ? 'Nowy plan'
        : widget.planName.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Wygląd planu',
              onBack: () => Navigator.of(context).maybePop(),
              actions: [_DoneButton(onTap: _done)],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: _color),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    builder: (context, color, _) => _Preview(
                      name: name,
                      subtitle: widget.subtitle,
                      days: widget.selectedDays,
                      color: color ?? _color,
                      iconKey: _useIcon ? _iconKey : null,
                      coverBytes: _coverBytes,
                      coverUrl: _coverUrl,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SectionLabel('ZDJĘCIE OKŁADKI'),
                  const SizedBox(height: 12),
                  _CoverPicker(
                    bytes: _coverBytes,
                    url: _coverUrl,
                    color: _color,
                    onPick: _changeCover,
                    onRemove: _hasCover ? _removeCover : null,
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(
                    'KOLOR',
                    trailing: _colorKey == null
                        ? 'Auto'
                        : PlanColors.choiceLabels[_colorKey]!,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Swatch(
                        key: const ValueKey('plan-color-auto'),
                        color: null,
                        label: 'Auto',
                        selected: _colorKey == null,
                        onTap: () => _pickColor(null),
                      ),
                      for (final entry in PlanColors.choices.entries)
                        _Swatch(
                          key: ValueKey('plan-color-${entry.key}'),
                          color: entry.value,
                          label: PlanColors.choiceLabels[entry.key]!,
                          selected: _colorKey == entry.key,
                          onTap: () => _pickColor(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('ZNAK PLANU')),
                      _ModeToggle(useIcon: _useIcon, onChanged: _setMode),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _useIcon ? 1 : 0.45,
                    child: GridView.count(
                      crossAxisCount: 6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final entry in PlanIcons.choices.entries)
                          _IconTile(
                            key: ValueKey('plan-icon-${entry.key}'),
                            icon: entry.value,
                            label: PlanIcons.labels[entry.key]!,
                            selected: _useIcon && _iconKey == entry.key,
                            color: _color,
                            onTap: () => _pickIcon(entry.key),
                          ),
                      ],
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

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          key: const ValueKey('plan-appearance-done'),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Text(
            'Gotowe',
            style: TextStyle(
              color: Color(0xFF8FB2FF),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.eyebrow)),
        if (trailing != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              trailing!,
              key: ValueKey(trailing),
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Karta planu tak, jak będzie wyglądać: znak, nazwa, dni i przycisk startu
/// w wybranym kolorze.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.subtitle,
    required this.days,
    required this.color,
    required this.iconKey,
    this.coverBytes,
    this.coverUrl,
  });

  final String name;
  final String subtitle;
  final List<int> days;
  final Color color;
  final String? iconKey;
  final Uint8List? coverBytes;
  final String? coverUrl;

  static const _dayLetters = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderStrong),
        gradient: RadialGradient(
          center: const Alignment(0.9, -1),
          radius: 1.1,
          colors: [color.withValues(alpha: 0.16), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PODGLĄD', style: AppTextStyles.eyebrow),
          const SizedBox(height: 12),
          Row(
            children: [
              if (coverBytes != null || coverUrl != null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: color.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md - 1.5),
                    child: SizedBox.expand(
                      child: PlanCoverImage(
                        url: coverUrl,
                        bytes: coverBytes,
                        cacheWidth: 160,
                      ),
                    ),
                  ),
                )
              else
                PlanBadge(
                  name: name,
                  color: color,
                  iconKey: iconKey,
                  size: 48,
                  radius: AppRadius.md,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayDot(
                  letter: _dayLetters[day - 1],
                  planned: days.contains(day),
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: PlanColors.onAccent(color),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rozpocznij $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PlanColors.onAccent(color),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okładka planu: puste pole „Dodaj zdjęcie” albo zdjęcie 16:9 z przyciskami
/// „Zmień” i „Usuń”.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.bytes,
    required this.url,
    required this.color,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? url;
  final Color color;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasCover = bytes != null || url != null;
    if (!hasCover) {
      return Semantics(
        button: true,
        label: 'Dodaj zdjęcie okładki',
        excludeSemantics: true,
        child: AppPressable(
          onTap: onPick,
          pressedScale: 0.98,
          child: Container(
            key: const ValueKey('plan-cover-add'),
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: color, size: 26),
                const SizedBox(height: 8),
                const Text(
                  'Dodaj zdjęcie',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Opcjonalne. Pokaże się na liście i w planie.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surfaceVariant),
            PlanCoverImage(url: url, bytes: bytes, cacheWidth: 900),
            Positioned(
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  _CoverButton(
                    key: const ValueKey('plan-cover-change'),
                    icon: Icons.edit_outlined,
                    label: 'Zmień',
                    onTap: onPick,
                  ),
                  const SizedBox(width: 8),
                  if (onRemove != null)
                    _CoverButton(
                      key: const ValueKey('plan-cover-remove'),
                      icon: Icons.delete_outline_rounded,
                      label: 'Usuń',
                      onTap: onRemove!,
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

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.95,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.planned,
    required this.color,
  });

  final String letter;
  final bool planned;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(letter, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: planned ? color.withValues(alpha: 0.18) : null,
            border: Border.all(
              color: planned ? color : AppColors.borderStrong,
              width: planned ? 2 : 1,
            ),
          ),
          child: planned
              ? Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// `null` — „Auto”.
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Kolor: $label',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.9,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          width: 44,
          height: 44,
          padding: EdgeInsets.all(selected ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? (color ?? AppColors.textPrimary)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? AppColors.tile,
              border: color == null
                  ? Border.all(color: AppColors.borderStrong)
                  : null,
            ),
            alignment: Alignment.center,
            child: color == null
                ? const Text(
                    'Auto',
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: PlanColors.onAccent(color),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.useIcon, required this.onChanged});

  final bool useIcon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = useIcon == value;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: ValueKey('plan-mark-${value ? 'icon' : 'letter'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceVariant : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('Litera', false), option('Ikona', true)],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ikona: $label',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : AppColors.tile,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: selected ? color : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? color : AppColors.iconOnTile,
          ),
        ),
      ),
    );
  }
}
